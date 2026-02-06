/**
 * Trakt API Types
 * See: https://trakt.docs.apiary.io/
 */

// Authentication
export interface TraktTokens {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
  createdAt: number;
  tokenType: 'Bearer';
}

export interface TraktDeviceCode {
  deviceCode: string;
  userCode: string;
  verificationUrl: string;
  expiresIn: number;
  interval: number;
}

// Media identifiers
export interface TraktIds {
  trakt: number;
  slug: string;
  imdb?: string;
  tmdb?: number;
  tvdb?: number;
}

// Movie
export interface TraktMovie {
  title: string;
  year: number;
  ids: TraktIds;
}

export interface TraktMovieExtended extends TraktMovie {
  tagline?: string;
  overview?: string;
  released?: string;
  runtime?: number;
  country?: string;
  trailer?: string;
  homepage?: string;
  status?: string;
  rating?: number;
  votes?: number;
  genres?: string[];
  certification?: string;
}

// Show
export interface TraktShow {
  title: string;
  year: number;
  ids: TraktIds;
}

export interface TraktShowExtended extends TraktShow {
  overview?: string;
  firstAired?: string;
  runtime?: number;
  certification?: string;
  network?: string;
  country?: string;
  trailer?: string;
  homepage?: string;
  status?: string;
  rating?: number;
  votes?: number;
  genres?: string[];
  airedEpisodes?: number;
}

// Episode
export interface TraktEpisode {
  season: number;
  number: number;
  title: string;
  ids: TraktIds;
}

export interface TraktEpisodeExtended extends TraktEpisode {
  overview?: string;
  rating?: number;
  votes?: number;
  firstAired?: string;
  runtime?: number;
}

// Season
export interface TraktSeason {
  number: number;
  ids: TraktIds;
}

// Search results
export interface TraktSearchResult {
  type: 'movie' | 'show' | 'episode' | 'person' | 'list';
  score: number;
  movie?: TraktMovie;
  show?: TraktShow;
  episode?: TraktEpisode;
}

// History item
export interface TraktHistoryItem {
  id: number;
  watchedAt: string;
  action: 'scrobble' | 'checkin' | 'watch';
  type: 'movie' | 'episode';
  movie?: TraktMovie;
  show?: TraktShow;
  episode?: TraktEpisode;
}

// Check-in
export interface TraktCheckin {
  id: number;
  watchedAt: string;
  sharing: TraktSharing;
  movie?: TraktMovie;
  show?: TraktShow;
  episode?: TraktEpisode;
}

export interface TraktSharing {
  twitter: boolean;
  tumblr: boolean;
}

// Watchlist item
export interface TraktWatchlistItem {
  rank: number;
  id: number;
  listedAt: string;
  notes?: string;
  type: 'movie' | 'show' | 'season' | 'episode';
  movie?: TraktMovie;
  show?: TraktShow;
  season?: TraktSeason;
  episode?: TraktEpisode;
}

// Progress
export interface TraktShowProgress {
  aired: number;
  completed: number;
  lastWatchedAt?: string;
  resetAt?: string;
  seasons: TraktSeasonProgress[];
  nextEpisode?: TraktEpisode;
  lastEpisode?: TraktEpisode;
}

export interface TraktSeasonProgress {
  number: number;
  title?: string;
  aired: number;
  completed: number;
  episodes: TraktEpisodeProgress[];
}

export interface TraktEpisodeProgress {
  number: number;
  completed: boolean;
  lastWatchedAt?: string;
}

// User
export interface TraktUser {
  username: string;
  private: boolean;
  name?: string;
  vip: boolean;
  vipEp: boolean;
  ids: {
    slug: string;
    uuid?: string;
  };
}

// Stats
export interface TraktStats {
  movies: {
    plays: number;
    watched: number;
    minutes: number;
    collected: number;
    ratings: number;
    comments: number;
  };
  shows: {
    watched: number;
    collected: number;
    ratings: number;
    comments: number;
  };
  seasons: {
    ratings: number;
    comments: number;
  };
  episodes: {
    plays: number;
    watched: number;
    minutes: number;
    collected: number;
    ratings: number;
    comments: number;
  };
}

// API responses
export interface TraktPaginatedResponse<T> {
  items: T[];
  page: number;
  limit: number;
  pageCount: number;
  itemCount: number;
}

// Error
export interface TraktError {
  error: string;
  errorDescription?: string;
}

// Check-in request
export interface TraktCheckinRequest {
  movie?: TraktMovie;
  show?: TraktShow;
  episode?: TraktEpisode;
  sharing?: Partial<TraktSharing>;
  message?: string;
  venueId?: string;
  venueName?: string;
  appVersion?: string;
  appDate?: string;
}

// History sync request
export interface TraktHistorySyncRequest {
  movies?: Array<{
    watchedAt?: string;
    ids: Partial<TraktIds>;
  }>;
  shows?: Array<{
    watchedAt?: string;
    ids: Partial<TraktIds>;
  }>;
  episodes?: Array<{
    watchedAt?: string;
    ids: Partial<TraktIds>;
  }>;
}
