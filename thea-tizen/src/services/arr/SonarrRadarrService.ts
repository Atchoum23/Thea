/**
 * Sonarr & Radarr Integration Service
 *
 * Integrates with the *arr stack for superior media automation:
 * - Sonarr: TV show management
 * - Radarr: Movie management
 *
 * Benefits over manual downloading:
 * - Quality upgrades (auto-replace with better quality)
 * - Proper file naming & organization
 * - Failed download handling & retries
 * - Release delay profiles
 * - Direct Plex integration
 *
 * @see https://wiki.servarr.com/
 * @see https://sonarr.tv/
 * @see https://radarr.video/
 */


// ============================================================
// TYPES
// ============================================================

export interface ArrConfig {
  sonarr: {
    url: string;
    apiKey: string;
    enabled: boolean;
  };
  radarr: {
    url: string;
    apiKey: string;
    enabled: boolean;
  };
}

export interface SonarrSeries {
  id: number;
  title: string;
  sortTitle: string;
  status: 'continuing' | 'ended' | 'upcoming';
  overview: string;
  previousAiring?: string;
  network?: string;
  year: number;
  path: string;
  qualityProfileId: number;
  seasonFolder: boolean;
  monitored: boolean;
  tvdbId: number;
  tvRageId?: number;
  imdbId?: string;
  titleSlug: string;
  genres: string[];
  tags: number[];
  added: string;
  ratings: { votes: number; value: number };
  statistics: {
    seasonCount: number;
    episodeFileCount: number;
    episodeCount: number;
    totalEpisodeCount: number;
    sizeOnDisk: number;
    percentOfEpisodes: number;
  };
  images: Array<{ coverType: string; url: string }>;
}

export interface SonarrEpisode {
  id: number;
  seriesId: number;
  episodeFileId: number;
  seasonNumber: number;
  episodeNumber: number;
  title: string;
  airDate: string;
  airDateUtc: string;
  overview?: string;
  hasFile: boolean;
  monitored: boolean;
  absoluteEpisodeNumber?: number;
}

export interface RadarrMovie {
  id: number;
  title: string;
  sortTitle: string;
  sizeOnDisk: number;
  status: 'released' | 'inCinemas' | 'announced' | 'deleted';
  overview: string;
  inCinemas?: string;
  physicalRelease?: string;
  digitalRelease?: string;
  year: number;
  hasFile: boolean;
  path: string;
  qualityProfileId: number;
  monitored: boolean;
  minimumAvailability: string;
  isAvailable: boolean;
  folderName: string;
  runtime: number;
  cleanTitle: string;
  imdbId?: string;
  tmdbId: number;
  titleSlug: string;
  genres: string[];
  tags: number[];
  added: string;
  ratings: { votes: number; value: number };
  images: Array<{ coverType: string; url: string }>;
}

export interface QualityProfile {
  id: number;
  name: string;
  upgradeAllowed: boolean;
  cutoff: number;
  items: Array<{ quality: { id: number; name: string }; allowed: boolean }>;
}

export interface RootFolder {
  id: number;
  path: string;
  accessible: boolean;
  freeSpace: number;
}

export interface CommandResult {
  id: number;
  name: string;
  commandName: string;
  status: 'queued' | 'started' | 'completed' | 'failed';
  queued: string;
  started?: string;
  ended?: string;
  stateChangeTime: string;
  sendUpdatesToClient: boolean;
  updateScheduledTask: boolean;
}

// ============================================================
// SERVICE
// ============================================================

class SonarrRadarrService {
  private static instance: SonarrRadarrService;
  private config: ArrConfig;

  private constructor() {
    this.config = this.loadConfig();
  }

  static getInstance(): SonarrRadarrService {
    if (!SonarrRadarrService.instance) {
      SonarrRadarrService.instance = new SonarrRadarrService();
    }
    return SonarrRadarrService.instance;
  }

  // ============================================================
  // CONFIGURATION
  // ============================================================

  private loadConfig(): ArrConfig {
    try {
      const saved = localStorage.getItem('thea_arr_config');
      if (saved) {
        return JSON.parse(saved);
      }
    } catch { /* ignore */ }

    return {
      sonarr: { url: '', apiKey: '', enabled: false },
      radarr: { url: '', apiKey: '', enabled: false },
    };
  }

  saveConfig(config: Partial<ArrConfig>): void {
    this.config = { ...this.config, ...config };
    localStorage.setItem('thea_arr_config', JSON.stringify(this.config));
  }

  getConfig(): ArrConfig {
    return { ...this.config };
  }

  // ============================================================
  // SONARR API
  // ============================================================

  /**
   * Test Sonarr connection
   */
  async testSonarr(): Promise<{ success: boolean; version?: string; error?: string }> {
    if (!this.config.sonarr.url || !this.config.sonarr.apiKey) {
      return { success: false, error: 'Not configured' };
    }

    try {
      const response = await this.sonarrFetch('/api/v3/system/status');
      const data = await response.json() as { version: string };
      return { success: true, version: data.version };
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
    }
  }

  /**
   * Get all series from Sonarr
   */
  async getSeries(): Promise<SonarrSeries[]> {
    const response = await this.sonarrFetch('/api/v3/series');
    return await response.json() as SonarrSeries[];
  }

  /**
   * Search for a series by name
   */
  async searchSeries(term: string): Promise<SonarrSeries[]> {
    const response = await this.sonarrFetch(`/api/v3/series/lookup?term=${encodeURIComponent(term)}`);
    return await response.json() as SonarrSeries[];
  }

  /**
   * Get series by TVDB ID
   */
  async getSeriesByTvdbId(tvdbId: number): Promise<SonarrSeries | null> {
    const series = await this.getSeries();
    return series.find(s => s.tvdbId === tvdbId) || null;
  }

  /**
   * Add a series to Sonarr
   */
  async addSeries(series: Partial<SonarrSeries> & { tvdbId: number; title: string }): Promise<SonarrSeries> {
    // Get quality profiles and root folders
    const [profiles, folders] = await Promise.all([
      this.getSonarrQualityProfiles(),
      this.getSonarrRootFolders(),
    ]);

    if (profiles.length === 0 || folders.length === 0) {
      throw new Error('No quality profiles or root folders configured');
    }

    const body = {
      ...series,
      qualityProfileId: series.qualityProfileId || profiles[0].id,
      rootFolderPath: folders[0].path,
      monitored: true,
      seasonFolder: true,
      addOptions: {
        monitor: 'all',
        searchForMissingEpisodes: true,
      },
    };

    const response = await this.sonarrFetch('/api/v3/series', {
      method: 'POST',
      body: JSON.stringify(body),
    });

    return await response.json() as SonarrSeries;
  }

  /**
   * Get episodes for a series
   */
  async getEpisodes(seriesId: number): Promise<SonarrEpisode[]> {
    const response = await this.sonarrFetch(`/api/v3/episode?seriesId=${seriesId}`);
    return await response.json() as SonarrEpisode[];
  }

  /**
   * Search for missing episodes
   */
  async searchMissingEpisodes(seriesId: number): Promise<CommandResult> {
    const response = await this.sonarrFetch('/api/v3/command', {
      method: 'POST',
      body: JSON.stringify({
        name: 'SeriesSearch',
        seriesId,
      }),
    });
    return await response.json() as CommandResult;
  }

  /**
   * Get quality profiles
   */
  async getSonarrQualityProfiles(): Promise<QualityProfile[]> {
    const response = await this.sonarrFetch('/api/v3/qualityprofile');
    return await response.json() as QualityProfile[];
  }

  /**
   * Get root folders
   */
  async getSonarrRootFolders(): Promise<RootFolder[]> {
    const response = await this.sonarrFetch('/api/v3/rootfolder');
    return await response.json() as RootFolder[];
  }

  /**
   * Get Sonarr calendar (upcoming episodes)
   */
  async getSonarrCalendar(start?: Date, end?: Date): Promise<SonarrEpisode[]> {
    const params = new URLSearchParams();
    if (start) params.set('start', start.toISOString());
    if (end) params.set('end', end.toISOString());

    const response = await this.sonarrFetch(`/api/v3/calendar?${params}`);
    return await response.json() as SonarrEpisode[];
  }

  // ============================================================
  // RADARR API
  // ============================================================

  /**
   * Test Radarr connection
   */
  async testRadarr(): Promise<{ success: boolean; version?: string; error?: string }> {
    if (!this.config.radarr.url || !this.config.radarr.apiKey) {
      return { success: false, error: 'Not configured' };
    }

    try {
      const response = await this.radarrFetch('/api/v3/system/status');
      const data = await response.json() as { version: string };
      return { success: true, version: data.version };
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
    }
  }

  /**
   * Get all movies from Radarr
   */
  async getMovies(): Promise<RadarrMovie[]> {
    const response = await this.radarrFetch('/api/v3/movie');
    return await response.json() as RadarrMovie[];
  }

  /**
   * Search for a movie by name
   */
  async searchMovies(term: string): Promise<RadarrMovie[]> {
    const response = await this.radarrFetch(`/api/v3/movie/lookup?term=${encodeURIComponent(term)}`);
    return await response.json() as RadarrMovie[];
  }

  /**
   * Get movie by TMDB ID
   */
  async getMovieByTmdbId(tmdbId: number): Promise<RadarrMovie | null> {
    const movies = await this.getMovies();
    return movies.find(m => m.tmdbId === tmdbId) || null;
  }

  /**
   * Add a movie to Radarr
   */
  async addMovie(movie: Partial<RadarrMovie> & { tmdbId: number; title: string }): Promise<RadarrMovie> {
    // Get quality profiles and root folders
    const [profiles, folders] = await Promise.all([
      this.getRadarrQualityProfiles(),
      this.getRadarrRootFolders(),
    ]);

    if (profiles.length === 0 || folders.length === 0) {
      throw new Error('No quality profiles or root folders configured');
    }

    const body = {
      ...movie,
      qualityProfileId: movie.qualityProfileId || profiles[0].id,
      rootFolderPath: folders[0].path,
      monitored: true,
      minimumAvailability: 'released',
      addOptions: {
        searchForMovie: true,
      },
    };

    const response = await this.radarrFetch('/api/v3/movie', {
      method: 'POST',
      body: JSON.stringify(body),
    });

    return await response.json() as RadarrMovie;
  }

  /**
   * Search for a movie download
   */
  async searchMovie(movieId: number): Promise<CommandResult> {
    const response = await this.radarrFetch('/api/v3/command', {
      method: 'POST',
      body: JSON.stringify({
        name: 'MoviesSearch',
        movieIds: [movieId],
      }),
    });
    return await response.json() as CommandResult;
  }

  /**
   * Get quality profiles
   */
  async getRadarrQualityProfiles(): Promise<QualityProfile[]> {
    const response = await this.radarrFetch('/api/v3/qualityprofile');
    return await response.json() as QualityProfile[];
  }

  /**
   * Get root folders
   */
  async getRadarrRootFolders(): Promise<RootFolder[]> {
    const response = await this.radarrFetch('/api/v3/rootfolder');
    return await response.json() as RootFolder[];
  }

  /**
   * Get Radarr calendar (upcoming movies)
   */
  async getRadarrCalendar(start?: Date, end?: Date): Promise<RadarrMovie[]> {
    const params = new URLSearchParams();
    if (start) params.set('start', start.toISOString());
    if (end) params.set('end', end.toISOString());

    const response = await this.radarrFetch(`/api/v3/calendar?${params}`);
    return await response.json() as RadarrMovie[];
  }

  // ============================================================
  // HELPERS
  // ============================================================

  private async sonarrFetch(endpoint: string, options: RequestInit = {}): Promise<Response> {
    const url = `${this.config.sonarr.url}${endpoint}`;
    const response = await fetch(url, {
      ...options,
      headers: {
        'X-Api-Key': this.config.sonarr.apiKey,
        'Content-Type': 'application/json',
        ...options.headers,
      },
    });

    if (!response.ok) {
      throw new Error(`Sonarr API error: ${response.status}`);
    }

    return response;
  }

  private async radarrFetch(endpoint: string, options: RequestInit = {}): Promise<Response> {
    const url = `${this.config.radarr.url}${endpoint}`;
    const response = await fetch(url, {
      ...options,
      headers: {
        'X-Api-Key': this.config.radarr.apiKey,
        'Content-Type': 'application/json',
        ...options.headers,
      },
    });

    if (!response.ok) {
      throw new Error(`Radarr API error: ${response.status}`);
    }

    return response;
  }

  // ============================================================
  // HIGH-LEVEL HELPERS
  // ============================================================

  /**
   * Check if a show is in Sonarr
   */
  async isShowMonitored(tvdbId: number): Promise<boolean> {
    if (!this.config.sonarr.enabled) return false;
    const series = await this.getSeriesByTvdbId(tvdbId);
    return series !== null && series.monitored;
  }

  /**
   * Check if a movie is in Radarr
   */
  async isMovieMonitored(tmdbId: number): Promise<boolean> {
    if (!this.config.radarr.enabled) return false;
    const movie = await this.getMovieByTmdbId(tmdbId);
    return movie !== null && movie.monitored;
  }

  /**
   * Add content to the appropriate *arr app
   */
  async addContent(content: {
    type: 'movie' | 'show';
    title: string;
    tmdbId?: number;
    tvdbId?: number;
    year?: number;
  }): Promise<{ success: boolean; error?: string }> {
    try {
      if (content.type === 'movie' && content.tmdbId && this.config.radarr.enabled) {
        // Search for movie in Radarr lookup
        const results = await this.searchMovies(content.title);
        const match = results.find(m => m.tmdbId === content.tmdbId);

        if (match) {
          await this.addMovie(match);
          return { success: true };
        } else {
          return { success: false, error: 'Movie not found in Radarr lookup' };
        }
      } else if (content.type === 'show' && content.tvdbId && this.config.sonarr.enabled) {
        // Search for series in Sonarr lookup
        const results = await this.searchSeries(content.title);
        const match = results.find(s => s.tvdbId === content.tvdbId);

        if (match) {
          await this.addSeries(match);
          return { success: true };
        } else {
          return { success: false, error: 'Series not found in Sonarr lookup' };
        }
      }

      return { success: false, error: 'Invalid content type or missing ID' };
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
    }
  }
}

export const sonarrRadarrService = SonarrRadarrService.getInstance();
