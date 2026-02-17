/**
 * Smart Hub Service
 * Combines Trakt calendar, streaming app availability, and deep linking
 * Shows new releases from watchlist/progress on TV startup
 */

import { tvSystemService, InstalledApp } from '../tv/TVSystemService';

export interface TraktCalendarItem {
  id: string;
  type: 'episode' | 'movie';
  title: string;
  // Episode specific
  show?: {
    title: string;
    ids: { trakt: number; imdb?: string; tmdb?: number; slug: string };
    year: number;
    overview?: string;
    poster?: string;
  };
  episode?: {
    season: number;
    number: number;
    title: string;
    ids: { trakt: number; imdb?: string; tmdb?: number };
    overview?: string;
  };
  // Movie specific
  movie?: {
    title: string;
    year: number;
    ids: { trakt: number; imdb?: string; tmdb?: number; slug: string };
    overview?: string;
    poster?: string;
  };
  // Air date
  firstAired?: string;
  released?: string;
  // Source
  source: 'calendar' | 'watchlist' | 'progress';
}

export interface StreamingAvailability {
  appId: string;
  appName: string;
  available: boolean;
  deepLinkUrl?: string;
  contentId?: string;
  // External IDs for matching
  externalIds?: {
    netflix?: string;
    prime?: string;
    disney?: string;
    apple?: string;
    plex?: string;
  };
}

export interface SmartHubItem {
  id: string;
  type: 'episode' | 'movie';
  title: string;
  subtitle?: string;
  overview?: string;
  posterUrl?: string;
  backdropUrl?: string;
  releaseDate: string;
  isNewRelease: boolean;
  source: 'calendar' | 'watchlist' | 'progress';
  trakt: TraktCalendarItem;
  streaming: StreamingAvailability[];
  preferredApp?: StreamingAvailability;
  needsTorrent: boolean;
}

// JustWatch-like service IDs mapped to app names
// eslint-disable-next-line @typescript-eslint/no-unused-vars
const STREAMING_SERVICE_MAP: Record<string, string[]> = {
  'netflix': ['Netflix', 'com.netflix.ninja', '3201907018807'],
  'amazon': ['Prime Video', 'com.amazon.avod', '3201910019365'],
  'prime': ['Prime Video', 'com.amazon.avod', '3201910019365'],
  'disney': ['Disney+', '3201901017640'],
  'disneyplus': ['Disney+', '3201901017640'],
  'apple': ['Apple TV', '3201807016598'],
  'appletv': ['Apple TV', '3201807016598'],
  'hbo': ['Max', 'HBO Max'],
  'max': ['Max', 'HBO Max'],
  'hulu': ['Hulu'],
  'paramount': ['Paramount+'],
  'peacock': ['Peacock'],
  'plex': ['Plex', '3201512006963'],
  'canal': ['Canal+'],
  'canalplus': ['Canal+'],
  'youtube': ['YouTube', '111299001912'],
  'crunchyroll': ['Crunchyroll'],
};

// TMDB image base URL
const TMDB_IMAGE_BASE = 'https://image.tmdb.org/t/p';

class SmartHubService {
  private syncBridgeUrl: string = '';
  private traktAccessToken: string = '';
  private traktClientId: string = '';
  private tmdbApiKey: string = '';

  /**
   * Configure the service
   */
  configure(options: {
    syncBridgeUrl: string;
    traktAccessToken?: string;
    traktClientId?: string;
    tmdbApiKey?: string;
  }): void {
    this.syncBridgeUrl = options.syncBridgeUrl;
    this.traktAccessToken = options.traktAccessToken || '';
    this.traktClientId = options.traktClientId || '';
    this.tmdbApiKey = options.tmdbApiKey || '';
  }

  /**
   * Get all new releases for the Smart Hub home screen
   * Called when TV turns on or app launches
   */
  async getNewReleases(options: {
    days?: number;
    includeWatchlist?: boolean;
    includeProgress?: boolean;
  } = {}): Promise<SmartHubItem[]> {
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const { days = 7, includeWatchlist = true, includeProgress = true } = options;

    try {
      // Fetch from sync bridge (which proxies to Trakt)
      const response = await fetch(
        `${this.syncBridgeUrl}/trakt/calendar?days=${days}&type=all`,
        {
          headers: {
            'Authorization': `Bearer ${this.traktAccessToken}`,
            'trakt-api-key': this.traktClientId,
          },
        }
      );

      if (!response.ok) {
        throw new Error(`Failed to fetch calendar: ${response.status}`);
      }

      const data = await response.json();
      const items: SmartHubItem[] = [];

      // Process calendar shows (new episodes)
      if (data.calendar?.shows) {
        for (const entry of data.calendar.shows) {
          items.push(await this.processCalendarShow(entry));
        }
      }

      // Process calendar movies
      if (data.calendar?.movies) {
        for (const entry of data.calendar.movies) {
          items.push(await this.processCalendarMovie(entry));
        }
      }

      // Process watchlist shows (if enabled)
      if (includeWatchlist && data.watchlist?.shows) {
        for (const entry of data.watchlist.shows) {
          const item = await this.processWatchlistShow(entry);
          if (item) items.push(item);
        }
      }

      // Process watchlist movies (if enabled)
      if (includeWatchlist && data.watchlist?.movies) {
        for (const entry of data.watchlist.movies) {
          const item = await this.processWatchlistMovie(entry);
          if (item) items.push(item);
        }
      }

      // Sort by release date (newest first)
      items.sort((a, b) => {
        const dateA = new Date(a.releaseDate).getTime();
        const dateB = new Date(b.releaseDate).getTime();
        return dateB - dateA;
      });

      // Mark new releases (within last 3 days)
      const threeDaysAgo = Date.now() - 3 * 24 * 60 * 60 * 1000;
      items.forEach(item => {
        item.isNewRelease = new Date(item.releaseDate).getTime() > threeDaysAgo;
      });

      return items;
    } catch (error) {
      console.error('Failed to get new releases:', error);
      return [];
    }
  }

  /**
   * Check streaming availability for a specific title
   */
  async checkStreamingAvailability(
    item: TraktCalendarItem
  ): Promise<StreamingAvailability[]> {
    const installedApps = tvSystemService.getStreamingApps();
    const availability: StreamingAvailability[] = [];

    // Get external IDs (would come from JustWatch API or TMDB in production)
    const externalIds = await this.getExternalIds(item);

    for (const app of installedApps) {
      const streamingAvail: StreamingAvailability = {
        appId: app.id,
        appName: app.name,
        available: false,
        externalIds,
      };

      // Check if content is available on this platform
      // In production, this would query JustWatch or similar API
      const isAvailable = await this.checkPlatformAvailability(app, item, externalIds);

      if (isAvailable) {
        streamingAvail.available = true;
        streamingAvail.contentId = this.getContentId(app.name, externalIds);
        streamingAvail.deepLinkUrl = this.buildDeepLink(app, item, externalIds);
      }

      availability.push(streamingAvail);
    }

    return availability;
  }

  /**
   * Launch content in the best available app
   */
  async launchContent(item: SmartHubItem): Promise<boolean> {
    // Try preferred app first
    if (item.preferredApp?.available && item.preferredApp.deepLinkUrl) {
      const success = await tvSystemService.deepLinkToContent(
        item.preferredApp.appName,
        item.preferredApp.contentId || '',
        item.type === 'episode' ? 'episode' : 'movie'
      );
      if (success) return true;
    }

    // Try other available streaming apps
    for (const streaming of item.streaming) {
      if (streaming.available) {
        const success = await tvSystemService.deepLinkToContent(
          streaming.appName,
          streaming.contentId || '',
          item.type === 'episode' ? 'episode' : 'movie'
        );
        if (success) return true;
      }
    }

    // No streaming option available
    return false;
  }

  /**
   * Search for torrent if not available on streaming
   */
  async searchTorrent(item: SmartHubItem): Promise<TorrentSearchResult[]> {
    const query = item.type === 'episode'
      ? `${item.trakt.show?.title} S${String(item.trakt.episode?.season).padStart(2, '0')}E${String(item.trakt.episode?.number).padStart(2, '0')}`
      : item.trakt.movie?.title || item.title;

    const category = item.type === 'episode' ? 'tv' : 'movies';

    try {
      const response = await fetch(
        `${this.syncBridgeUrl}/torrents/search?q=${encodeURIComponent(query)}&category=${category}`,
        {
          headers: {
            'X-Device-Token': localStorage.getItem('deviceToken') || '',
          },
        }
      );

      if (!response.ok) {
        throw new Error(`Torrent search failed: ${response.status}`);
      }

      const data = await response.json();
      return data.results || [];
    } catch (error) {
      console.error('Torrent search failed:', error);
      return [];
    }
  }

  /**
   * Download torrent to Plex server
   */
  async downloadTorrent(torrent: TorrentSearchResult): Promise<{ success: boolean; message: string }> {
    try {
      const response = await fetch(`${this.syncBridgeUrl}/torrents/download`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Device-Token': localStorage.getItem('deviceToken') || '',
        },
        body: JSON.stringify({
          magnetUrl: torrent.magnetUrl,
          downloadUrl: torrent.downloadUrl,
          title: torrent.title,
        }),
      });

      if (!response.ok) {
        const error = await response.json();
        return { success: false, message: error.message || 'Download failed' };
      }

      const result = await response.json();
      return { success: true, message: result.message || 'Download started' };
    } catch (error) {
      return {
        success: false,
        message: error instanceof Error ? error.message : 'Download failed',
      };
    }
  }

  /**
   * Get download status from Transmission
   */
  async getDownloadStatus(): Promise<TorrentStatus[]> {
    try {
      const response = await fetch(`${this.syncBridgeUrl}/torrents/status`, {
        headers: {
          'X-Device-Token': localStorage.getItem('deviceToken') || '',
        },
      });

      if (!response.ok) {
        return [];
      }

      const data = await response.json();
      return data.torrents || [];
    } catch (error) {
      console.error('Failed to get download status:', error);
      return [];
    }
  }

  // Private helper methods

  private async processCalendarShow(entry: any): Promise<SmartHubItem> {
    const show = entry.show;
    const episode = entry.episode;

    const traktItem: TraktCalendarItem = {
      id: `show-${show.ids.trakt}-${episode.season}-${episode.number}`,
      type: 'episode',
      title: show.title,
      show: {
        title: show.title,
        ids: show.ids,
        year: show.year,
        overview: show.overview,
      },
      episode: {
        season: episode.season,
        number: episode.number,
        title: episode.title,
        ids: episode.ids,
        overview: episode.overview,
      },
      firstAired: entry.first_aired,
      source: 'calendar',
    };

    const streaming = await this.checkStreamingAvailability(traktItem);
    const preferredApp = streaming.find(s => s.available);
    const needsTorrent = !streaming.some(s => s.available);

    return {
      id: traktItem.id,
      type: 'episode',
      title: show.title,
      subtitle: `S${episode.season}E${episode.number}: ${episode.title}`,
      overview: episode.overview || show.overview,
      posterUrl: await this.getPosterUrl(show.ids.tmdb, 'tv'),
      releaseDate: entry.first_aired,
      isNewRelease: false,
      source: 'calendar',
      trakt: traktItem,
      streaming,
      preferredApp,
      needsTorrent,
    };
  }

  private async processCalendarMovie(entry: any): Promise<SmartHubItem> {
    const movie = entry.movie;

    const traktItem: TraktCalendarItem = {
      id: `movie-${movie.ids.trakt}`,
      type: 'movie',
      title: movie.title,
      movie: {
        title: movie.title,
        year: movie.year,
        ids: movie.ids,
        overview: movie.overview,
      },
      released: entry.released,
      source: 'calendar',
    };

    const streaming = await this.checkStreamingAvailability(traktItem);
    const preferredApp = streaming.find(s => s.available);
    const needsTorrent = !streaming.some(s => s.available);

    return {
      id: traktItem.id,
      type: 'movie',
      title: movie.title,
      subtitle: `(${movie.year})`,
      overview: movie.overview,
      posterUrl: await this.getPosterUrl(movie.ids.tmdb, 'movie'),
      releaseDate: entry.released,
      isNewRelease: false,
      source: 'calendar',
      trakt: traktItem,
      streaming,
      preferredApp,
      needsTorrent,
    };
  }

  private async processWatchlistShow(entry: any): Promise<SmartHubItem | null> {
    const show = entry.show;
    if (!show) return null;

    // Only include if it has aired recently or has upcoming episodes
    const traktItem: TraktCalendarItem = {
      id: `watchlist-show-${show.ids.trakt}`,
      type: 'episode',
      title: show.title,
      show: {
        title: show.title,
        ids: show.ids,
        year: show.year,
        overview: show.overview,
      },
      source: 'watchlist',
    };

    const streaming = await this.checkStreamingAvailability(traktItem);
    const preferredApp = streaming.find(s => s.available);
    const needsTorrent = !streaming.some(s => s.available);

    return {
      id: traktItem.id,
      type: 'episode',
      title: show.title,
      subtitle: 'From Watchlist',
      overview: show.overview,
      posterUrl: await this.getPosterUrl(show.ids.tmdb, 'tv'),
      releaseDate: entry.listed_at || new Date().toISOString(),
      isNewRelease: false,
      source: 'watchlist',
      trakt: traktItem,
      streaming,
      preferredApp,
      needsTorrent,
    };
  }

  private async processWatchlistMovie(entry: any): Promise<SmartHubItem | null> {
    const movie = entry.movie;
    if (!movie) return null;

    const traktItem: TraktCalendarItem = {
      id: `watchlist-movie-${movie.ids.trakt}`,
      type: 'movie',
      title: movie.title,
      movie: {
        title: movie.title,
        year: movie.year,
        ids: movie.ids,
        overview: movie.overview,
      },
      source: 'watchlist',
    };

    const streaming = await this.checkStreamingAvailability(traktItem);
    const preferredApp = streaming.find(s => s.available);
    const needsTorrent = !streaming.some(s => s.available);

    return {
      id: traktItem.id,
      type: 'movie',
      title: movie.title,
      subtitle: movie.year ? `(${movie.year})` : 'From Watchlist',
      overview: movie.overview,
      posterUrl: await this.getPosterUrl(movie.ids.tmdb, 'movie'),
      releaseDate: entry.listed_at || new Date().toISOString(),
      isNewRelease: false,
      source: 'watchlist',
      trakt: traktItem,
      streaming,
      preferredApp,
      needsTorrent,
    };
  }

  private async getExternalIds(item: TraktCalendarItem): Promise<StreamingAvailability['externalIds']> {
    // In production, this would query JustWatch API or similar
    // For now, we return the IDs we have from Trakt
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const ids = item.type === 'episode' ? item.show?.ids : item.movie?.ids;
    return {
      // These would be populated from JustWatch/Streaming availability API
    };
  }

  private async checkPlatformAvailability(
    app: InstalledApp,
    _item: TraktCalendarItem,
    _externalIds: StreamingAvailability['externalIds']
  ): Promise<boolean> {
    // In production, this would check against JustWatch or streaming APIs
    // For now, we return true for Plex (where torrents go) and randomize others for demo
    if (app.name.toLowerCase() === 'plex') {
      return true; // Plex is always "available" since we can download to it
    }
    // Mock availability for demo purposes
    return Math.random() > 0.5;
  }

  private getContentId(_appName: string, _externalIds?: StreamingAvailability['externalIds']): string {
    // In production, map the external IDs to platform-specific content IDs
    return '';
  }

  private buildDeepLink(
    app: InstalledApp,
    item: TraktCalendarItem,
    externalIds?: StreamingAvailability['externalIds']
  ): string | undefined {
    // Deep link formats vary by app
    const appNameLower = app.name.toLowerCase();

    if (appNameLower.includes('netflix')) {
      return `netflix://title/${externalIds?.netflix || ''}`;
    }
    if (appNameLower.includes('prime')) {
      return `primevideo://?titleId=${externalIds?.prime || ''}`;
    }
    if (appNameLower.includes('disney')) {
      return `disneyplus://content/${externalIds?.disney || ''}`;
    }
    if (appNameLower.includes('plex')) {
      return `plex://play`;
    }

    return undefined;
  }

  private async getPosterUrl(tmdbId: number | undefined, type: 'movie' | 'tv'): Promise<string | undefined> {
    if (!tmdbId || !this.tmdbApiKey) {
      return undefined;
    }

    try {
      const response = await fetch(
        `https://api.themoviedb.org/3/${type}/${tmdbId}?api_key=${this.tmdbApiKey}`
      );

      if (!response.ok) {
        return undefined;
      }

      const data = await response.json();
      if (data.poster_path) {
        return `${TMDB_IMAGE_BASE}/w342${data.poster_path}`;
      }
    } catch (error) {
      console.error('Failed to get poster:', error);
    }

    return undefined;
  }
}

// Types for torrent functionality
export interface TorrentSearchResult {
  id: string;
  title: string;
  size: number;
  sizeFormatted: string;
  seeders: number;
  leechers: number;
  indexer: string;
  downloadUrl?: string;
  magnetUrl?: string;
  infoUrl?: string;
  publishDate: string;
  categories: number[];
}

export interface TorrentStatus {
  id: number;
  name: string;
  status: string;
  progress: number;
  eta: string | null;
  speed: string;
  size: string;
}

// Singleton instance
export const smartHubService = new SmartHubService();
