/**
 * Plex Media Server Integration
 *
 * Checks your local Plex library for content before suggesting downloads.
 * Connects to Plex server "MSM3U" running on Mac.
 *
 * Features:
 * - Check if movie/show exists in library
 * - Search by TMDB/IMDB/TVDB ID for accurate matching
 * - Get playback deep links
 * - Monitor for new content additions
 */

import { STREAMING_ACCOUNTS } from '../../config/secrets';

export interface PlexServer {
  name: string;
  address: string;
  port: number;
  token: string;
  machineIdentifier?: string;
}

export interface PlexLibrary {
  key: string;
  type: 'movie' | 'show';
  title: string;
  uuid: string;
}

export interface PlexMediaItem {
  ratingKey: string;
  title: string;
  year?: number;
  type: 'movie' | 'show' | 'season' | 'episode';
  thumb?: string;
  guids: PlexGuid[];
  addedAt: number;
  // For TV shows
  leafCount?: number; // Total episodes
  viewedLeafCount?: number; // Watched episodes
}

export interface PlexGuid {
  id: string; // e.g., "imdb://tt1234567", "tmdb://12345", "tvdb://12345"
}

export interface PlexCheckResult {
  found: boolean;
  item?: PlexMediaItem;
  playUrl?: string;
  missingEpisodes?: number;
}

// Default Plex server configuration
const DEFAULT_PLEX_CONFIG: PlexServer = {
  name: 'MSM3U',
  address: 'localhost',
  port: 32400,
  token: '', // Will be loaded from secrets or localStorage
};

const STORAGE_KEY = 'thea_plex_config';

class PlexService {
  private static instance: PlexService;
  private server: PlexServer;
  private libraries: PlexLibrary[] = [];
  private connected = false;

  private constructor() {
    this.server = this.loadConfig();
  }

  static getInstance(): PlexService {
    if (!PlexService.instance) {
      PlexService.instance = new PlexService();
    }
    return PlexService.instance;
  }

  // ============================================================
  // CONFIGURATION
  // ============================================================

  private loadConfig(): PlexServer {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        return { ...DEFAULT_PLEX_CONFIG, ...JSON.parse(saved) };
      }
    } catch {
      // Ignore
    }

    // Check if Plex is configured in STREAMING_ACCOUNTS
    const plexAccount = STREAMING_ACCOUNTS.find(a => a.providerName === 'Plex');
    if (plexAccount?.localServer) {
      return {
        ...DEFAULT_PLEX_CONFIG,
        name: plexAccount.localServer.name,
      };
    }

    return DEFAULT_PLEX_CONFIG;
  }

  private saveConfig(): void {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(this.server));
  }

  /**
   * Configure Plex server connection
   */
  configure(config: Partial<PlexServer>): void {
    this.server = { ...this.server, ...config };
    this.saveConfig();
    this.connected = false;
  }

  /**
   * Set Plex authentication token
   */
  setToken(token: string): void {
    this.server.token = token;
    this.saveConfig();
  }

  /**
   * Check if Plex is configured
   */
  isConfigured(): boolean {
    return !!this.server.token;
  }

  // ============================================================
  // CONNECTION
  // ============================================================

  /**
   * Connect to Plex server and fetch libraries
   */
  async connect(): Promise<boolean> {
    if (!this.server.token) {
      console.warn('Plex: No token configured');
      return false;
    }

    try {
      // Fetch server info
      const response = await this.request('/');
      if (response.MediaContainer) {
        this.server.machineIdentifier = response.MediaContainer.machineIdentifier;
        console.log(`Plex: Connected to ${response.MediaContainer.friendlyName}`);
      }

      // Fetch libraries
      await this.fetchLibraries();
      this.connected = true;
      return true;
    } catch (error) {
      console.error('Plex: Connection failed', error);
      this.connected = false;
      return false;
    }
  }

  /**
   * Fetch available libraries
   */
  private async fetchLibraries(): Promise<void> {
    const response = await this.request('/library/sections');
    const directories = response.MediaContainer?.Directory || [];

    this.libraries = directories
      .filter((d: any) => d.type === 'movie' || d.type === 'show')
      .map((d: any) => ({
        key: d.key,
        type: d.type as 'movie' | 'show',
        title: d.title,
        uuid: d.uuid,
      }));

    console.log(`Plex: Found ${this.libraries.length} libraries`);
  }

  // ============================================================
  // CONTENT CHECKING
  // ============================================================

  /**
   * Check if a movie exists in Plex library
   */
  async checkMovie(params: {
    title?: string;
    year?: number;
    tmdbId?: number;
    imdbId?: string;
  }): Promise<PlexCheckResult> {
    if (!this.connected) {
      await this.connect();
    }

    if (!this.connected) {
      return { found: false };
    }

    const movieLibraries = this.libraries.filter(l => l.type === 'movie');

    for (const library of movieLibraries) {
      // Try GUID search first (most accurate)
      if (params.tmdbId) {
        const result = await this.searchByGuid(library.key, `tmdb://${params.tmdbId}`);
        if (result) return this.formatResult(result);
      }

      if (params.imdbId) {
        const result = await this.searchByGuid(library.key, `imdb://${params.imdbId}`);
        if (result) return this.formatResult(result);
      }

      // Fallback to title search
      if (params.title) {
        const result = await this.searchByTitle(library.key, params.title, params.year);
        if (result) return this.formatResult(result);
      }
    }

    return { found: false };
  }

  /**
   * Check if a TV show exists in Plex library
   */
  async checkShow(params: {
    title?: string;
    year?: number;
    tmdbId?: number;
    tvdbId?: number;
    imdbId?: string;
  }): Promise<PlexCheckResult> {
    if (!this.connected) {
      await this.connect();
    }

    if (!this.connected) {
      return { found: false };
    }

    const showLibraries = this.libraries.filter(l => l.type === 'show');

    for (const library of showLibraries) {
      // Try GUID search first
      if (params.tmdbId) {
        const result = await this.searchByGuid(library.key, `tmdb://${params.tmdbId}`);
        if (result) return this.formatShowResult(result);
      }

      if (params.tvdbId) {
        const result = await this.searchByGuid(library.key, `tvdb://${params.tvdbId}`);
        if (result) return this.formatShowResult(result);
      }

      if (params.imdbId) {
        const result = await this.searchByGuid(library.key, `imdb://${params.imdbId}`);
        if (result) return this.formatShowResult(result);
      }

      // Fallback to title search
      if (params.title) {
        const result = await this.searchByTitle(library.key, params.title, params.year, 'show');
        if (result) return this.formatShowResult(result);
      }
    }

    return { found: false };
  }

  /**
   * Check if a specific episode exists
   */
  async checkEpisode(params: {
    showTitle?: string;
    showTmdbId?: number;
    showTvdbId?: number;
    season: number;
    episode: number;
  }): Promise<PlexCheckResult> {
    // First find the show
    const showResult = await this.checkShow({
      title: params.showTitle,
      tmdbId: params.showTmdbId,
      tvdbId: params.showTvdbId,
    });

    if (!showResult.found || !showResult.item) {
      return { found: false };
    }

    // Then check for the specific episode
    try {
      const episodesResponse = await this.request(
        `/library/metadata/${showResult.item.ratingKey}/allLeaves?includeGuids=1`
      );
      const episodes = episodesResponse.MediaContainer?.Metadata || [];

      const episode = episodes.find((e: any) =>
        e.parentIndex === params.season && e.index === params.episode
      );

      if (episode) {
        return {
          found: true,
          item: this.parseMediaItem(episode),
          playUrl: this.buildPlayUrl(episode.ratingKey),
        };
      }
    } catch (error) {
      console.error('Plex: Episode check failed', error);
    }

    return { found: false, missingEpisodes: 1 };
  }

  /**
   * Search by external GUID (TMDB/IMDB/TVDB)
   */
  private async searchByGuid(libraryKey: string, guid: string): Promise<any | null> {
    try {
      const response = await this.request(
        `/library/sections/${libraryKey}/all?includeGuids=1`
      );
      const items = response.MediaContainer?.Metadata || [];

      for (const item of items) {
        const guids = item.Guid || [];
        if (guids.some((g: any) => g.id === guid)) {
          return item;
        }
      }
    } catch (error) {
      console.error('Plex: GUID search failed', error);
    }
    return null;
  }

  /**
   * Search by title
   */
  private async searchByTitle(
    libraryKey: string,
    title: string,
    year?: number,
    type?: string
  ): Promise<any | null> {
    try {
      const response = await this.request(
        `/library/sections/${libraryKey}/search?query=${encodeURIComponent(title)}&includeGuids=1`
      );
      const items = response.MediaContainer?.Metadata || [];

      // Find best match
      for (const item of items) {
        const titleMatch = item.title.toLowerCase() === title.toLowerCase();
        const yearMatch = !year || item.year === year;
        const typeMatch = !type || item.type === type;

        if (titleMatch && yearMatch && typeMatch) {
          return item;
        }
      }

      // Partial match
      for (const item of items) {
        const typeMatch = !type || item.type === type;
        if (typeMatch && item.title.toLowerCase().includes(title.toLowerCase())) {
          return item;
        }
      }
    } catch (error) {
      console.error('Plex: Title search failed', error);
    }
    return null;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  private parseMediaItem(data: any): PlexMediaItem {
    return {
      ratingKey: data.ratingKey,
      title: data.title,
      year: data.year,
      type: data.type,
      thumb: data.thumb,
      guids: (data.Guid || []).map((g: any) => ({ id: g.id })),
      addedAt: data.addedAt,
      leafCount: data.leafCount,
      viewedLeafCount: data.viewedLeafCount,
    };
  }

  private formatResult(item: any): PlexCheckResult {
    return {
      found: true,
      item: this.parseMediaItem(item),
      playUrl: this.buildPlayUrl(item.ratingKey),
    };
  }

  private formatShowResult(item: any): PlexCheckResult {
    const result = this.formatResult(item);

    // Calculate missing episodes
    if (item.leafCount && item.viewedLeafCount !== undefined) {
      result.missingEpisodes = 0; // We have the show, episodes may or may not be complete
    }

    return result;
  }

  private buildPlayUrl(ratingKey: string): string {
    // Plex web app URL
    if (this.server.machineIdentifier) {
      return `https://app.plex.tv/desktop/#!/server/${this.server.machineIdentifier}/details?key=%2Flibrary%2Fmetadata%2F${ratingKey}`;
    }
    return `plex://play/?metadataKey=/library/metadata/${ratingKey}`;
  }

  /**
   * Make authenticated request to Plex server
   */
  private async request(endpoint: string): Promise<any> {
    const url = `http://${this.server.address}:${this.server.port}${endpoint}`;
    const separator = endpoint.includes('?') ? '&' : '?';

    const response = await fetch(`${url}${separator}X-Plex-Token=${this.server.token}`, {
      headers: {
        'Accept': 'application/json',
      },
    });

    if (!response.ok) {
      throw new Error(`Plex API error: ${response.status}`);
    }

    return response.json();
  }

  // ============================================================
  // PUBLIC UTILITIES
  // ============================================================

  /**
   * Get Plex server status
   */
  getStatus(): { configured: boolean; connected: boolean; serverName: string } {
    return {
      configured: this.isConfigured(),
      connected: this.connected,
      serverName: this.server.name,
    };
  }

  /**
   * Get libraries
   */
  getLibraries(): PlexLibrary[] {
    return [...this.libraries];
  }

  /**
   * Test connection
   */
  async testConnection(): Promise<{ success: boolean; error?: string; serverName?: string }> {
    try {
      const response = await this.request('/');
      return {
        success: true,
        serverName: response.MediaContainer?.friendlyName,
      };
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Connection failed',
      };
    }
  }
}

export const plexService = PlexService.getInstance();
