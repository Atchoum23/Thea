/**
 * Trakt API Client
 * Handles all Trakt API interactions
 */

import type {
  TraktMovie,
  TraktShow,
  TraktEpisode,
  TraktSearchResult,
  TraktHistoryItem,
  TraktCheckin,
  TraktCheckinRequest,
  TraktShowProgress,
  TraktUser,
  TraktStats,
  TraktWatchlistItem,
} from '../../types/trakt';
import { TraktAuth } from './TraktAuth';
import { API_URLS, API_VERSIONS, APP_INFO } from '../../config/constants';

/**
 * Trakt API Client
 */
class TraktClientClass {
  private clientId: string = '';

  /**
   * Configure client ID
   */
  configure(clientId: string): void {
    this.clientId = clientId;
  }

  /**
   * Make authenticated request to Trakt API
   */
  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const accessToken = await TraktAuth.getValidAccessToken();

    if (!accessToken) {
      throw new Error('Not authenticated with Trakt');
    }

    const response = await fetch(`${API_URLS.TRAKT}${endpoint}`, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
        'trakt-api-key': this.clientId,
        'trakt-api-version': API_VERSIONS.TRAKT,
        ...options.headers,
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Trakt API error ${response.status}: ${errorText}`);
    }

    // Handle 204 No Content
    if (response.status === 204) {
      return {} as T;
    }

    return response.json();
  }

  // ==================== Check-in ====================

  /**
   * Check in to a movie
   */
  async checkInMovie(
    movie: TraktMovie,
    message?: string
  ): Promise<TraktCheckin> {
    const body: TraktCheckinRequest = {
      movie,
      sharing: { twitter: false, tumblr: false },
      message,
      appVersion: APP_INFO.VERSION,
    };

    return this.request<TraktCheckin>('/checkin', {
      method: 'POST',
      body: JSON.stringify(body),
    });
  }

  /**
   * Check in to an episode
   */
  async checkInEpisode(
    show: TraktShow,
    episode: TraktEpisode,
    message?: string
  ): Promise<TraktCheckin> {
    const body: TraktCheckinRequest = {
      show,
      episode,
      sharing: { twitter: false, tumblr: false },
      message,
      appVersion: APP_INFO.VERSION,
    };

    return this.request<TraktCheckin>('/checkin', {
      method: 'POST',
      body: JSON.stringify(body),
    });
  }

  /**
   * Cancel active check-in
   */
  async cancelCheckIn(): Promise<void> {
    await this.request('/checkin', { method: 'DELETE' });
  }

  // ==================== Search ====================

  /**
   * Search for movies
   */
  async searchMovies(query: string, limit = 10): Promise<TraktSearchResult[]> {
    const encoded = encodeURIComponent(query);
    return this.request<TraktSearchResult[]>(
      `/search/movie?query=${encoded}&limit=${limit}`
    );
  }

  /**
   * Search for shows
   */
  async searchShows(query: string, limit = 10): Promise<TraktSearchResult[]> {
    const encoded = encodeURIComponent(query);
    return this.request<TraktSearchResult[]>(
      `/search/show?query=${encoded}&limit=${limit}`
    );
  }

  /**
   * Search for both movies and shows
   */
  async search(query: string, limit = 10): Promise<TraktSearchResult[]> {
    const encoded = encodeURIComponent(query);
    return this.request<TraktSearchResult[]>(
      `/search/movie,show?query=${encoded}&limit=${limit}`
    );
  }

  /**
   * Lookup by external ID (IMDB, TMDB, TVDB)
   */
  async lookupByExternalId(
    type: 'imdb' | 'tmdb' | 'tvdb',
    id: string
  ): Promise<TraktSearchResult[]> {
    return this.request<TraktSearchResult[]>(`/search/${type}/${id}`);
  }

  // ==================== History ====================

  /**
   * Get user's watch history
   */
  async getHistory(
    type: 'movies' | 'shows' | 'episodes' = 'movies',
    page = 1,
    limit = 20
  ): Promise<TraktHistoryItem[]> {
    return this.request<TraktHistoryItem[]>(
      `/users/me/history/${type}?page=${page}&limit=${limit}`
    );
  }

  /**
   * Add items to history
   */
  async addToHistory(items: {
    movies?: Array<{ watched_at?: string; ids: { trakt?: number; imdb?: string; tmdb?: number } }>;
    shows?: Array<{ watched_at?: string; ids: { trakt?: number; imdb?: string; tmdb?: number } }>;
    episodes?: Array<{ watched_at?: string; ids: { trakt?: number; imdb?: string; tmdb?: number } }>;
  }): Promise<{ added: { movies: number; episodes: number } }> {
    return this.request('/sync/history', {
      method: 'POST',
      body: JSON.stringify(items),
    });
  }

  /**
   * Remove items from history
   */
  async removeFromHistory(items: {
    movies?: Array<{ ids: { trakt?: number; imdb?: string; tmdb?: number } }>;
    shows?: Array<{ ids: { trakt?: number; imdb?: string; tmdb?: number } }>;
    episodes?: Array<{ ids: { trakt?: number; imdb?: string; tmdb?: number } }>;
  }): Promise<{ deleted: { movies: number; episodes: number } }> {
    return this.request('/sync/history/remove', {
      method: 'POST',
      body: JSON.stringify(items),
    });
  }

  // ==================== Watchlist ====================

  /**
   * Get user's watchlist
   */
  async getWatchlist(
    type: 'movies' | 'shows' = 'movies'
  ): Promise<TraktWatchlistItem[]> {
    return this.request<TraktWatchlistItem[]>(`/users/me/watchlist/${type}`);
  }

  /**
   * Add to watchlist
   */
  async addToWatchlist(items: {
    movies?: Array<{ ids: { trakt?: number; imdb?: string; tmdb?: number } }>;
    shows?: Array<{ ids: { trakt?: number; imdb?: string; tmdb?: number } }>;
  }): Promise<{ added: { movies: number; shows: number } }> {
    return this.request('/sync/watchlist', {
      method: 'POST',
      body: JSON.stringify(items),
    });
  }

  // ==================== Progress ====================

  /**
   * Get show progress
   */
  async getShowProgress(showId: string | number): Promise<TraktShowProgress> {
    return this.request<TraktShowProgress>(
      `/shows/${showId}/progress/watched`
    );
  }

  /**
   * Get all shows in progress (up next)
   */
  async getUpNext(): Promise<
    Array<{ show: TraktShow; progress: TraktShowProgress }>
  > {
    return this.request('/users/me/watched/shows?extended=full');
  }

  // ==================== User ====================

  /**
   * Get current user profile
   */
  async getCurrentUser(): Promise<TraktUser> {
    return this.request<TraktUser>('/users/me');
  }

  /**
   * Get user stats
   */
  async getUserStats(): Promise<TraktStats> {
    return this.request<TraktStats>('/users/me/stats');
  }

  // ==================== Recommendations ====================

  /**
   * Get movie recommendations
   */
  async getMovieRecommendations(limit = 10): Promise<TraktMovie[]> {
    return this.request<TraktMovie[]>(
      `/recommendations/movies?limit=${limit}`
    );
  }

  /**
   * Get show recommendations
   */
  async getShowRecommendations(limit = 10): Promise<TraktShow[]> {
    return this.request<TraktShow[]>(`/recommendations/shows?limit=${limit}`);
  }

  // ==================== Helper Methods ====================

  /**
   * Parse natural language into show/episode
   * Uses AI to extract show name, season, and episode from user input
   */
  async parseWatchQuery(
    query: string,
    aiParser: (prompt: string) => Promise<string>
  ): Promise<{
    type: 'movie' | 'show';
    title: string;
    season?: number;
    episode?: number;
  } | null> {
    const prompt = `Parse this viewing query into structured data. Return JSON only.
Query: "${query}"

If it's a TV show episode, return:
{"type": "show", "title": "<show name>", "season": <number>, "episode": <number>}

If it's a movie, return:
{"type": "movie", "title": "<movie name>"}

If you can't parse it, return null.`;

    try {
      const response = await aiParser(prompt);
      const parsed = JSON.parse(response);
      return parsed;
    } catch {
      return null;
    }
  }

  /**
   * Find and check in based on natural language query
   */
  async smartCheckIn(
    query: string,
    aiParser: (prompt: string) => Promise<string>
  ): Promise<TraktCheckin | null> {
    // Parse the query
    const parsed = await this.parseWatchQuery(query, aiParser);
    if (!parsed) return null;

    if (parsed.type === 'movie') {
      // Search for movie
      const results = await this.searchMovies(parsed.title, 1);
      if (results.length === 0 || !results[0].movie) return null;

      return this.checkInMovie(results[0].movie);
    } else {
      // Search for show
      const showResults = await this.searchShows(parsed.title, 1);
      if (showResults.length === 0 || !showResults[0].show) return null;

      const show = showResults[0].show;

      // Create episode object
      const episode: TraktEpisode = {
        season: parsed.season || 1,
        number: parsed.episode || 1,
        title: '',
        ids: { trakt: 0, slug: '' },
      };

      return this.checkInEpisode(show, episode);
    }
  }
}

// Export singleton
export const TraktClient = new TraktClientClass();
