/**
 * Trakt Calendar Service
 *
 * Monitors your Trakt calendar for upcoming episodes and movies.
 * Triggers auto-download when new episodes are available.
 *
 * Features:
 * - Fetch upcoming episodes from shows you're watching
 * - Get premieres and season finales
 * - Sync with watchlist
 * - Trigger downloads when episodes air
 */

import { secureConfigService } from '../config/SecureConfigService';

export interface TraktShow {
  title: string;
  year: number;
  ids: {
    trakt: number;
    slug: string;
    tvdb?: number;
    imdb?: string;
    tmdb?: number;
  };
}

export interface TraktEpisode {
  season: number;
  number: number;
  title: string;
  ids: {
    trakt: number;
    tvdb?: number;
    imdb?: string;
    tmdb?: number;
  };
  runtime?: number;
  overview?: string;
}

export interface TraktCalendarItem {
  first_aired: string; // ISO date
  episode: TraktEpisode;
  show: TraktShow;
}

export interface TraktMovie {
  title: string;
  year: number;
  ids: {
    trakt: number;
    slug: string;
    imdb?: string;
    tmdb?: number;
  };
  released?: string;
}

export interface TraktMovieCalendarItem {
  released: string; // ISO date
  movie: TraktMovie;
}

export interface UpcomingContent {
  shows: TraktCalendarItem[];
  movies: TraktMovieCalendarItem[];
  airingToday: TraktCalendarItem[];
  airingThisWeek: TraktCalendarItem[];
  premieres: TraktCalendarItem[];
}

class TraktCalendarService {
  private static instance: TraktCalendarService;
  private cache: Map<string, { data: any; timestamp: number }> = new Map();
  private readonly CACHE_DURATION = 15 * 60 * 1000; // 15 minutes

  private constructor() {}

  static getInstance(): TraktCalendarService {
    if (!TraktCalendarService.instance) {
      TraktCalendarService.instance = new TraktCalendarService();
    }
    return TraktCalendarService.instance;
  }

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  private getAuthHeaders(): Record<string, string> {
    const config = secureConfigService.getTrakt();

    if (!config.clientId) {
      throw new Error('Trakt client ID not configured');
    }

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'trakt-api-key': config.clientId,
      'trakt-api-version': '2',
    };

    if (config.accessToken) {
      headers['Authorization'] = `Bearer ${config.accessToken}`;
    }

    return headers;
  }

  isAuthenticated(): boolean {
    const config = secureConfigService.getTrakt();
    return !!(config.clientId && config.accessToken);
  }

  // ============================================================
  // CALENDAR ENDPOINTS
  // ============================================================

  /**
   * Get upcoming episodes from your calendar
   * Requires OAuth authentication
   */
  async getMyShows(startDate?: string, days: number = 7): Promise<TraktCalendarItem[]> {
    if (!this.isAuthenticated()) {
      throw new Error('Trakt authentication required');
    }

    const start = startDate || this.formatDate(new Date());
    const cacheKey = `my-shows-${start}-${days}`;

    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const data = await this.request(`/calendars/my/shows/${start}/${days}`);
    this.setCache(cacheKey, data);
    return data;
  }

  /**
   * Get new show premieres
   */
  async getPremieres(startDate?: string, days: number = 30): Promise<TraktCalendarItem[]> {
    const start = startDate || this.formatDate(new Date());
    const cacheKey = `premieres-${start}-${days}`;

    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const endpoint = this.isAuthenticated()
      ? `/calendars/my/shows/premieres/${start}/${days}`
      : `/calendars/all/shows/premieres/${start}/${days}`;

    const data = await this.request(endpoint);
    this.setCache(cacheKey, data);
    return data;
  }

  /**
   * Get new shows (not just premieres but new series entirely)
   */
  async getNewShows(startDate?: string, days: number = 30): Promise<TraktCalendarItem[]> {
    const start = startDate || this.formatDate(new Date());
    const cacheKey = `new-shows-${start}-${days}`;

    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const endpoint = this.isAuthenticated()
      ? `/calendars/my/shows/new/${start}/${days}`
      : `/calendars/all/shows/new/${start}/${days}`;

    const data = await this.request(endpoint);
    this.setCache(cacheKey, data);
    return data;
  }

  /**
   * Get upcoming movies from your calendar
   */
  async getMyMovies(startDate?: string, days: number = 30): Promise<TraktMovieCalendarItem[]> {
    if (!this.isAuthenticated()) {
      throw new Error('Trakt authentication required');
    }

    const start = startDate || this.formatDate(new Date());
    const cacheKey = `my-movies-${start}-${days}`;

    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const data = await this.request(`/calendars/my/movies/${start}/${days}`);
    this.setCache(cacheKey, data);
    return data;
  }

  /**
   * Get all upcoming movies (public)
   */
  async getAllMovies(startDate?: string, days: number = 30): Promise<TraktMovieCalendarItem[]> {
    const start = startDate || this.formatDate(new Date());
    const cacheKey = `all-movies-${start}-${days}`;

    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const data = await this.request(`/calendars/all/movies/${start}/${days}`);
    this.setCache(cacheKey, data);
    return data;
  }

  // ============================================================
  // AGGREGATED DATA
  // ============================================================

  /**
   * Get all upcoming content organized by category
   */
  async getUpcomingContent(): Promise<UpcomingContent> {
    const today = this.formatDate(new Date());
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const tomorrow = this.formatDate(new Date(Date.now() + 24 * 60 * 60 * 1000));

    let shows: TraktCalendarItem[] = [];
    let movies: TraktMovieCalendarItem[] = [];
    let premieres: TraktCalendarItem[] = [];

    try {
      if (this.isAuthenticated()) {
        [shows, movies, premieres] = await Promise.all([
          this.getMyShows(today, 14),
          this.getMyMovies(today, 30),
          this.getPremieres(today, 30),
        ]);
      } else {
        premieres = await this.getPremieres(today, 30);
      }
    } catch (error) {
      console.error('Failed to fetch Trakt calendar:', error);
    }

    // Filter episodes airing today
    const airingToday = shows.filter(item => {
      const airDate = item.first_aired.split('T')[0];
      return airDate === today;
    });

    // Filter episodes airing this week
    const weekFromNow = this.formatDate(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000));
    const airingThisWeek = shows.filter(item => {
      const airDate = item.first_aired.split('T')[0];
      return airDate >= today && airDate <= weekFromNow;
    });

    return {
      shows,
      movies,
      airingToday,
      airingThisWeek,
      premieres,
    };
  }

  /**
   * Get episodes that aired recently (for catching up / auto-download)
   */
  async getRecentlyAired(daysBack: number = 3): Promise<TraktCalendarItem[]> {
    if (!this.isAuthenticated()) {
      return [];
    }

    const startDate = this.formatDate(new Date(Date.now() - daysBack * 24 * 60 * 60 * 1000));
    return this.getMyShows(startDate, daysBack + 1);
  }

  /**
   * Check if a specific episode has aired
   */
  isEpisodeAired(item: TraktCalendarItem): boolean {
    const airDate = new Date(item.first_aired);
    return airDate <= new Date();
  }

  // ============================================================
  // WATCHLIST
  // ============================================================

  /**
   * Get shows from watchlist
   */
  async getWatchlistShows(): Promise<TraktShow[]> {
    if (!this.isAuthenticated()) {
      throw new Error('Trakt authentication required');
    }

    const cacheKey = 'watchlist-shows';
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const data = await this.request('/users/me/watchlist/shows');
    const shows = data.map((item: any) => item.show);
    this.setCache(cacheKey, shows);
    return shows;
  }

  /**
   * Get movies from watchlist
   */
  async getWatchlistMovies(): Promise<TraktMovie[]> {
    if (!this.isAuthenticated()) {
      throw new Error('Trakt authentication required');
    }

    const cacheKey = 'watchlist-movies';
    const cached = this.getFromCache(cacheKey);
    if (cached) return cached;

    const data = await this.request('/users/me/watchlist/movies');
    const movies = data.map((item: any) => item.movie);
    this.setCache(cacheKey, movies);
    return movies;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  private formatDate(date: Date): string {
    return date.toISOString().split('T')[0];
  }

  private async request(endpoint: string): Promise<any> {
    const response = await fetch(`https://api.trakt.tv${endpoint}`, {
      headers: this.getAuthHeaders(),
    });

    if (!response.ok) {
      if (response.status === 401) {
        throw new Error('Trakt authentication expired');
      }
      throw new Error(`Trakt API error: ${response.status}`);
    }

    return response.json();
  }

  private getFromCache(key: string): any | null {
    const cached = this.cache.get(key);
    if (cached && Date.now() - cached.timestamp < this.CACHE_DURATION) {
      return cached.data;
    }
    return null;
  }

  private setCache(key: string, data: any): void {
    this.cache.set(key, { data, timestamp: Date.now() });
  }

  /**
   * Clear cache
   */
  clearCache(): void {
    this.cache.clear();
  }
}

export const traktCalendarService = TraktCalendarService.getInstance();
