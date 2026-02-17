/**
 * Content Prediction Service
 *
 * Predicts what content you'll want to watch next based on:
 * - Viewing patterns (time of day, day of week)
 * - Trakt calendar (upcoming episodes)
 * - Watch history continuation
 * - Genre preferences by mood/time
 *
 * Pre-caches metadata and streaming availability to reduce latency.
 */

import { secureConfigService } from '../config/SecureConfigService';
import { traktCalendarService } from '../trakt/TraktCalendarService';

export interface PredictedContent {
  id: string;
  type: 'movie' | 'episode' | 'show';
  title: string;
  showTitle?: string;
  season?: number;
  episode?: number;
  poster?: string;
  backdrop?: string;
  confidence: number; // 0-1
  reason: PredictionReason;
  tmdbId?: number;
  imdbId?: string;
  airDate?: Date;
  // Pre-fetched data
  streamingAvailability?: StreamingOption[];
  isInPlex?: boolean;
}

export type PredictionReason =
  | 'next_episode'          // Continue watching
  | 'new_episode'           // New episode just aired
  | 'trending'              // Popular content
  | 'time_pattern'          // Usually watched at this time
  | 'genre_preference'      // Matches genre preferences
  | 'recommendation'        // AI/Trakt recommendation
  | 'calendar'              // From Trakt calendar
  | 'recently_added_plex';  // New in Plex library

export interface StreamingOption {
  provider: string;
  providerId: number;
  region: string;
  type: 'flatrate' | 'rent' | 'buy';
  link?: string;
}

interface ViewingPattern {
  dayOfWeek: number; // 0-6
  hourOfDay: number; // 0-23
  genres: string[];
  averageDuration: number; // minutes
}

interface UserProfile {
  patterns: ViewingPattern[];
  favoriteGenres: string[];
  watchedShows: Map<string, { lastEpisode: { season: number; episode: number }; lastWatched: Date }>;
  lastUpdated: Date;
}

class ContentPredictionService {
  private static instance: ContentPredictionService;

  private predictions: PredictedContent[] = [];
  private userProfile: UserProfile;
  private cache: Map<string, { data: any; expires: Date }> = new Map();
  private isPreloading = false;

  private constructor() {
    this.userProfile = this.loadProfile();
  }

  static getInstance(): ContentPredictionService {
    if (!ContentPredictionService.instance) {
      ContentPredictionService.instance = new ContentPredictionService();
    }
    return ContentPredictionService.instance;
  }

  /**
   * Generate predictions for what the user might want to watch
   */
  async generatePredictions(limit: number = 10): Promise<PredictedContent[]> {
    console.log('ContentPredictionService: Generating predictions');
    const predictions: PredictedContent[] = [];

    // 1. Get upcoming episodes from Trakt calendar (highest confidence)
    try {
      const calendarItems = await traktCalendarService.getMyShows(undefined, 7);
      const now = new Date();

      for (const item of calendarItems.slice(0, 5)) {
        const airDate = new Date(item.first_aired);
        const hasAired = airDate <= now;

        predictions.push({
          id: `trakt-${item.show.ids.trakt}-s${item.episode.season}e${item.episode.number}`,
          type: 'episode',
          title: item.episode.title,
          showTitle: item.show.title,
          season: item.episode.season,
          episode: item.episode.number,
          confidence: hasAired ? 0.95 : 0.7, // Higher if already aired
          reason: hasAired ? 'new_episode' : 'calendar',
          tmdbId: item.show.ids.tmdb,
          imdbId: item.show.ids.imdb,
          airDate,
        });
      }
    } catch (error) {
      console.warn('ContentPredictionService: Failed to get calendar', error);
    }

    // 2. Continue watching (shows with progress)
    for (const [showId, progress] of this.userProfile.watchedShows) {
      // Next episode prediction
      predictions.push({
        id: `continue-${showId}`,
        type: 'episode',
        title: `Episode ${progress.lastEpisode.episode + 1}`,
        showTitle: showId, // Would need to resolve actual title
        season: progress.lastEpisode.season,
        episode: progress.lastEpisode.episode + 1,
        confidence: this.calculateContinueConfidence(progress.lastWatched),
        reason: 'next_episode',
      });
    }

    // 3. Time-based patterns
    const currentPatterns = this.getCurrentPatterns();
    if (currentPatterns.length > 0) {
      // Add time-based suggestions (would need trending API)
      for (const pattern of currentPatterns.slice(0, 2)) {
        predictions.push({
          id: `pattern-${pattern.genres.join('-')}`,
          type: 'movie',
          title: `${pattern.genres[0]} content`, // Placeholder
          confidence: 0.6,
          reason: 'time_pattern',
        });
      }
    }

    // Sort by confidence and deduplicate
    const sorted = predictions
      .sort((a, b) => b.confidence - a.confidence)
      .slice(0, limit);

    this.predictions = sorted;

    // Pre-fetch metadata for top predictions
    this.preloadMetadata(sorted.slice(0, 5));

    return sorted;
  }

  /**
   * Get current predictions
   */
  getPredictions(): PredictedContent[] {
    return this.predictions;
  }

  /**
   * Pre-load metadata and streaming availability
   */
  private async preloadMetadata(predictions: PredictedContent[]): Promise<void> {
    if (this.isPreloading) return;
    this.isPreloading = true;

    console.log(`ContentPredictionService: Pre-loading metadata for ${predictions.length} items`);

    const tmdbConfig = secureConfigService.getTMDB();
    if (!tmdbConfig.accessToken && !tmdbConfig.apiKey) {
      this.isPreloading = false;
      return;
    }

    const userConfig = secureConfigService.getUser();

    for (const prediction of predictions) {
      if (!prediction.tmdbId) continue;

      const cacheKey = `tmdb-${prediction.tmdbId}`;
      if (this.cache.has(cacheKey)) continue;

      try {
        // Fetch metadata
        const type = prediction.type === 'movie' ? 'movie' : 'tv';
        const headers: Record<string, string> = { Accept: 'application/json' };
        let baseUrl = `https://api.themoviedb.org/3/${type}/${prediction.tmdbId}`;

        if (tmdbConfig.accessToken) {
          headers['Authorization'] = `Bearer ${tmdbConfig.accessToken}`;
        } else {
          baseUrl += `?api_key=${tmdbConfig.apiKey}`;
        }

        const [metaResponse, providersResponse] = await Promise.all([
          fetch(baseUrl, { headers }),
          fetch(`${baseUrl}/watch/providers${tmdbConfig.accessToken ? '' : '&'}`, { headers }),
        ]);

        if (metaResponse.ok) {
          const meta = await metaResponse.json() as { poster_path?: string; backdrop_path?: string };
          prediction.poster = meta.poster_path
            ? `https://image.tmdb.org/t/p/w500${meta.poster_path}`
            : undefined;
          prediction.backdrop = meta.backdrop_path
            ? `https://image.tmdb.org/t/p/w1280${meta.backdrop_path}`
            : undefined;
        }

        if (providersResponse.ok) {
          const providers = await providersResponse.json() as {
            results?: Record<string, { flatrate?: Array<{ provider_id: number; provider_name: string }> }>;
          };
          const countryProviders = providers.results?.[userConfig.country];
          if (countryProviders?.flatrate) {
            prediction.streamingAvailability = countryProviders.flatrate.map(p => ({
              provider: p.provider_name,
              providerId: p.provider_id,
              region: userConfig.country,
              type: 'flatrate' as const,
            }));
          }
        }

        // Cache for 1 hour
        this.cache.set(cacheKey, {
          data: prediction,
          expires: new Date(Date.now() + 60 * 60 * 1000),
        });
      } catch (error) {
        console.warn(`ContentPredictionService: Failed to preload ${prediction.tmdbId}`, error);
      }
    }

    this.isPreloading = false;
  }

  /**
   * Record that user watched something (for learning)
   */
  recordWatch(content: {
    showId?: string;
    season?: number;
    episode?: number;
    genres?: string[];
    duration?: number;
  }): void {
    const now = new Date();
    const pattern: ViewingPattern = {
      dayOfWeek: now.getDay(),
      hourOfDay: now.getHours(),
      genres: content.genres || [],
      averageDuration: content.duration || 45,
    };

    // Add to patterns
    this.userProfile.patterns.push(pattern);

    // Keep only last 100 patterns
    if (this.userProfile.patterns.length > 100) {
      this.userProfile.patterns = this.userProfile.patterns.slice(-100);
    }

    // Update genre preferences
    for (const genre of content.genres || []) {
      if (!this.userProfile.favoriteGenres.includes(genre)) {
        this.userProfile.favoriteGenres.push(genre);
      }
    }

    // Update show progress
    if (content.showId && content.season !== undefined && content.episode !== undefined) {
      this.userProfile.watchedShows.set(content.showId, {
        lastEpisode: { season: content.season, episode: content.episode },
        lastWatched: now,
      });
    }

    this.userProfile.lastUpdated = now;
    this.saveProfile();
  }

  /**
   * Get matching patterns for current time
   */
  private getCurrentPatterns(): ViewingPattern[] {
    const now = new Date();
    const currentDay = now.getDay();
    const currentHour = now.getHours();

    return this.userProfile.patterns.filter(p =>
      p.dayOfWeek === currentDay &&
      Math.abs(p.hourOfDay - currentHour) <= 2
    );
  }

  /**
   * Calculate confidence for continue watching
   */
  private calculateContinueConfidence(lastWatched: Date): number {
    const daysSince = (Date.now() - lastWatched.getTime()) / (1000 * 60 * 60 * 24);

    if (daysSince < 1) return 0.9;
    if (daysSince < 3) return 0.8;
    if (daysSince < 7) return 0.6;
    if (daysSince < 30) return 0.4;
    return 0.2;
  }

  /**
   * Load user profile from storage
   */
  private loadProfile(): UserProfile {
    try {
      const stored = localStorage.getItem('thea_user_profile');
      if (stored) {
        const parsed = JSON.parse(stored);
        parsed.watchedShows = new Map(parsed.watchedShows || []);
        parsed.lastUpdated = new Date(parsed.lastUpdated);
        return parsed;
      }
    } catch { /* ignore */ }

    return {
      patterns: [],
      favoriteGenres: [],
      watchedShows: new Map(),
      lastUpdated: new Date(),
    };
  }

  /**
   * Save user profile to storage
   */
  private saveProfile(): void {
    try {
      const toSave = {
        ...this.userProfile,
        watchedShows: Array.from(this.userProfile.watchedShows.entries()),
      };
      localStorage.setItem('thea_user_profile', JSON.stringify(toSave));
    } catch { /* ignore */ }
  }

  /**
   * Clear cache
   */
  clearCache(): void {
    this.cache.clear();
    this.predictions = [];
  }
}

export const contentPredictionService = ContentPredictionService.getInstance();
