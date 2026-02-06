/**
 * TMDB Streaming Service
 *
 * Uses The Movie Database (TMDB) API to get real streaming availability data.
 * TMDB provides JustWatch data for free via their API.
 *
 * Features:
 * - Real streaming availability by country
 * - Deep links to streaming services
 * - Flatrate (subscription), Rent, Buy options
 * - Provider logos and names
 *
 * @see https://developer.themoviedb.org/reference/movie-watch-providers
 */

import { secureConfigService } from '../config/SecureConfigService';

export interface TMDBWatchProvider {
  logo_path: string;
  provider_id: number;
  provider_name: string;
  display_priority: number;
}

export interface TMDBWatchProviderResult {
  link: string; // JustWatch deep link
  flatrate?: TMDBWatchProvider[]; // Subscription services
  rent?: TMDBWatchProvider[];
  buy?: TMDBWatchProvider[];
  ads?: TMDBWatchProvider[]; // Free with ads
  free?: TMDBWatchProvider[]; // Free
}

export interface TMDBWatchProviders {
  id: number;
  results: Record<string, TMDBWatchProviderResult>; // Keyed by country code (US, GB, FR, etc.)
}

export interface StreamingOption {
  providerId: number;
  providerName: string;
  logoUrl: string;
  type: 'subscription' | 'rent' | 'buy' | 'ads' | 'free';
  deepLink: string;
  country: string;
  countryCode: string;
}

export interface ContentStreamingInfo {
  tmdbId: number;
  title: string;
  type: 'movie' | 'tv';
  posterUrl?: string;
  options: StreamingOption[];
  optionsByCountry: Record<string, StreamingOption[]>;
  availableCountries: string[];
  lastUpdated: number;
}

// TMDB provider ID to our app ID mapping (default/international)
const PROVIDER_APP_MAP: Record<number, string> = {
  8: 'netflix',
  9: 'prime',
  337: 'disney',
  2: 'apple',
  384: 'hbo', // HBO Max
  531: 'paramount',
  386: 'peacock',
  15: 'hulu',
  381: 'canal', // Canal+
  350: 'apple', // Apple TV+
  1899: 'hbo', // Max
  283: 'crunchyroll',
  192: 'youtube', // YouTube Premium
  3: 'youtube', // Google Play Movies
  10: 'prime', // Amazon Video
};

// Switzerland-specific: Bundled services via Canal+ Switzerland (Swisscom TV subscription)
const PROVIDER_APP_MAP_CH: Record<number, string> = {
  ...PROVIDER_APP_MAP,
  384: 'canal_ch',   // HBO Max → Canal+ Switzerland
  1899: 'canal_ch',  // Max → Canal+ Switzerland
  531: 'canal_ch',   // Paramount+ → Canal+ Switzerland
  381: 'canal_ch',   // Canal+ → Canal+ Switzerland
  1773: 'canal_ch',  // Canal+ Séries → Canal+ Switzerland
};

/**
 * Switzerland bundled streaming services
 * Via Swisscom TV subscription → Canal+ Switzerland → HBO Max & Paramount+ content
 */
interface BundledServiceInfo {
  originalProviderId: number;
  originalProviderName: string;
  accessViaProviderId: number;
  accessViaProviderName: string;
  note: string;
}

const SWISS_BUNDLED_SERVICES: BundledServiceInfo[] = [
  {
    originalProviderId: 384,
    originalProviderName: 'HBO Max',
    accessViaProviderId: 381,
    accessViaProviderName: 'Canal+ Switzerland',
    note: 'Included with Canal+ Switzerland via Swisscom TV',
  },
  {
    originalProviderId: 1899,
    originalProviderName: 'Max',
    accessViaProviderId: 381,
    accessViaProviderName: 'Canal+ Switzerland',
    note: 'Included with Canal+ Switzerland via Swisscom TV',
  },
  {
    originalProviderId: 531,
    originalProviderName: 'Paramount+',
    accessViaProviderId: 381,
    accessViaProviderName: 'Canal+ Switzerland',
    note: 'Included with Canal+ Switzerland via Swisscom TV',
  },
];

// Country code to name mapping
const COUNTRY_NAMES: Record<string, string> = {
  US: 'United States',
  GB: 'United Kingdom',
  CA: 'Canada',
  AU: 'Australia',
  DE: 'Germany',
  FR: 'France',
  ES: 'Spain',
  IT: 'Italy',
  NL: 'Netherlands',
  BE: 'Belgium',
  CH: 'Switzerland',
  AT: 'Austria',
  SE: 'Sweden',
  NO: 'Norway',
  DK: 'Denmark',
  FI: 'Finland',
  JP: 'Japan',
  KR: 'South Korea',
  BR: 'Brazil',
  MX: 'Mexico',
  AR: 'Argentina',
  IN: 'India',
  NZ: 'New Zealand',
  IE: 'Ireland',
  PT: 'Portugal',
  PL: 'Poland',
  CZ: 'Czech Republic',
  HU: 'Hungary',
  RO: 'Romania',
  GR: 'Greece',
  TR: 'Turkey',
  ZA: 'South Africa',
  SG: 'Singapore',
  HK: 'Hong Kong',
  TW: 'Taiwan',
  TH: 'Thailand',
  MY: 'Malaysia',
  PH: 'Philippines',
  ID: 'Indonesia',
};

class TMDBStreamingService {
  private static instance: TMDBStreamingService;
  private cache: Map<string, ContentStreamingInfo> = new Map();
  private cacheExpiry = 24 * 60 * 60 * 1000; // 24 hours

  private constructor() {
    // Subscribe to config changes to stay in sync
    secureConfigService.subscribe(() => {
      // Config changed, clear cache to use new credentials if needed
    });
  }

  static getInstance(): TMDBStreamingService {
    if (!TMDBStreamingService.instance) {
      TMDBStreamingService.instance = new TMDBStreamingService();
    }
    return TMDBStreamingService.instance;
  }

  /**
   * Get current TMDB configuration from SecureConfigService
   */
  private getConfig() {
    return secureConfigService.getTMDB();
  }

  /**
   * Configure TMDB API access
   */
  setApiKey(apiKey: string): void {
    secureConfigService.setTMDB({ apiKey });
  }

  setAccessToken(accessToken: string): void {
    secureConfigService.setTMDB({ accessToken });
  }

  isConfigured(): boolean {
    return secureConfigService.isTMDBConfigured();
  }

  /**
   * Get streaming availability for a movie
   */
  async getMovieStreamingInfo(
    tmdbId: number,
    title?: string
  ): Promise<ContentStreamingInfo | null> {
    const cacheKey = `movie:${tmdbId}`;
    const cached = this.cache.get(cacheKey);

    if (cached && Date.now() - cached.lastUpdated < this.cacheExpiry) {
      return cached;
    }

    try {
      const providers = await this.fetchWatchProviders('movie', tmdbId);
      const info = this.parseProviders(tmdbId, title || '', 'movie', providers);

      this.cache.set(cacheKey, info);
      return info;
    } catch (error) {
      console.error('Failed to get movie streaming info:', error);
      return null;
    }
  }

  /**
   * Get streaming availability for a TV show
   */
  async getTVStreamingInfo(
    tmdbId: number,
    title?: string
  ): Promise<ContentStreamingInfo | null> {
    const cacheKey = `tv:${tmdbId}`;
    const cached = this.cache.get(cacheKey);

    if (cached && Date.now() - cached.lastUpdated < this.cacheExpiry) {
      return cached;
    }

    try {
      const providers = await this.fetchWatchProviders('tv', tmdbId);
      const info = this.parseProviders(tmdbId, title || '', 'tv', providers);

      this.cache.set(cacheKey, info);
      return info;
    } catch (error) {
      console.error('Failed to get TV streaming info:', error);
      return null;
    }
  }

  /**
   * Search TMDB for a movie or TV show
   */
  async search(
    query: string,
    type: 'movie' | 'tv' | 'multi' = 'multi'
  ): Promise<Array<{ id: number; title: string; type: 'movie' | 'tv'; year?: string; posterUrl?: string }>> {
    if (!this.isConfigured()) {
      throw new Error('TMDB API not configured');
    }

    const response = await this.makeRequest(`/search/${type}`, {
      query,
      include_adult: 'false',
    });

    const results = response.results || [];

    return results.slice(0, 10).map((item: any) => ({
      id: item.id,
      title: item.title || item.name,
      type: item.media_type || type,
      year: (item.release_date || item.first_air_date)?.split('-')[0],
      posterUrl: item.poster_path
        ? `https://image.tmdb.org/t/p/w200${item.poster_path}`
        : undefined,
    }));
  }

  /**
   * Convert TMDB ID to Trakt or IMDB ID
   */
  async getExternalIds(
    tmdbId: number,
    type: 'movie' | 'tv'
  ): Promise<{ imdb_id?: string; tvdb_id?: number }> {
    const response = await this.makeRequest(`/${type}/${tmdbId}/external_ids`);
    return {
      imdb_id: response.imdb_id,
      tvdb_id: response.tvdb_id,
    };
  }

  /**
   * Get available streaming providers for a region
   */
  async getAvailableProviders(
    region: string = 'US'
  ): Promise<Array<{ id: number; name: string; logoUrl: string }>> {
    const response = await this.makeRequest('/watch/providers/movie', {
      watch_region: region,
    });

    return (response.results || []).map((p: any) => ({
      id: p.provider_id,
      name: p.provider_name,
      logoUrl: `https://image.tmdb.org/t/p/original${p.logo_path}`,
    }));
  }

  /**
   * Find where content is available in a specific country
   */
  async findInCountry(
    tmdbId: number,
    type: 'movie' | 'tv',
    countryCode: string
  ): Promise<StreamingOption[]> {
    const info = type === 'movie'
      ? await this.getMovieStreamingInfo(tmdbId)
      : await this.getTVStreamingInfo(tmdbId);

    if (!info) return [];

    return info.optionsByCountry[countryCode.toUpperCase()] || [];
  }

  /**
   * Find all countries where content is available on a specific service
   */
  async findOnService(
    tmdbId: number,
    type: 'movie' | 'tv',
    providerName: string
  ): Promise<string[]> {
    const info = type === 'movie'
      ? await this.getMovieStreamingInfo(tmdbId)
      : await this.getTVStreamingInfo(tmdbId);

    if (!info) return [];

    const countries: string[] = [];
    const lowerName = providerName.toLowerCase();

    for (const [countryCode, options] of Object.entries(info.optionsByCountry)) {
      if (options.some(o => o.providerName.toLowerCase().includes(lowerName))) {
        countries.push(countryCode);
      }
    }

    return countries;
  }

  /**
   * Fetch watch providers from TMDB API
   */
  private async fetchWatchProviders(
    type: 'movie' | 'tv',
    tmdbId: number
  ): Promise<TMDBWatchProviders> {
    return this.makeRequest(`/${type}/${tmdbId}/watch/providers`);
  }

  /**
   * Parse TMDB providers into our format
   */
  private parseProviders(
    tmdbId: number,
    title: string,
    type: 'movie' | 'tv',
    data: TMDBWatchProviders
  ): ContentStreamingInfo {
    const options: StreamingOption[] = [];
    const optionsByCountry: Record<string, StreamingOption[]> = {};

    for (const [countryCode, result] of Object.entries(data.results || {})) {
      const countryOptions: StreamingOption[] = [];

      // Process each type of availability
      const processProviders = (
        providers: TMDBWatchProvider[] | undefined,
        watchType: StreamingOption['type']
      ) => {
        if (!providers) return;

        for (const provider of providers) {
          const option: StreamingOption = {
            providerId: provider.provider_id,
            providerName: provider.provider_name,
            logoUrl: `https://image.tmdb.org/t/p/original${provider.logo_path}`,
            type: watchType,
            deepLink: result.link,
            country: COUNTRY_NAMES[countryCode] || countryCode,
            countryCode,
          };

          countryOptions.push(option);
          options.push(option);
        }
      };

      processProviders(result.flatrate, 'subscription');
      processProviders(result.free, 'free');
      processProviders(result.ads, 'ads');
      processProviders(result.rent, 'rent');
      processProviders(result.buy, 'buy');

      if (countryOptions.length > 0) {
        optionsByCountry[countryCode] = countryOptions;
      }
    }

    return {
      tmdbId,
      title,
      type,
      options,
      optionsByCountry,
      availableCountries: Object.keys(optionsByCountry),
      lastUpdated: Date.now(),
    };
  }

  /**
   * Make authenticated request to TMDB API
   */
  private async makeRequest(
    endpoint: string,
    params?: Record<string, string>
  ): Promise<any> {
    if (!this.isConfigured()) {
      throw new Error('TMDB API not configured. Set API key or access token.');
    }

    const config = this.getConfig();
    const url = new URL(`https://api.themoviedb.org/3${endpoint}`);

    if (params) {
      for (const [key, value] of Object.entries(params)) {
        url.searchParams.set(key, value);
      }
    }

    // Use access token (v4) or API key (v3)
    const headers: Record<string, string> = {
      'Accept': 'application/json',
    };

    if (config.accessToken) {
      headers['Authorization'] = `Bearer ${config.accessToken}`;
    } else if (config.apiKey) {
      url.searchParams.set('api_key', config.apiKey);
    }

    const response = await fetch(url.toString(), { headers });

    if (!response.ok) {
      throw new Error(`TMDB API error: ${response.status}`);
    }

    return response.json();
  }

  /**
   * Get provider app ID from TMDB provider ID
   * Uses region-specific mapping for bundled services
   */
  getAppIdForProvider(providerId: number, region: string = 'US'): string | undefined {
    if (region === 'CH') {
      return PROVIDER_APP_MAP_CH[providerId];
    }
    return PROVIDER_APP_MAP[providerId];
  }

  /**
   * Check if a provider is accessible via a bundled service in Switzerland
   * E.g., HBO Max content is accessible via Canal+ Switzerland
   */
  getBundledServiceInfo(providerId: number, region: string = 'CH'): BundledServiceInfo | undefined {
    if (region !== 'CH') return undefined;
    return SWISS_BUNDLED_SERVICES.find(s => s.originalProviderId === providerId);
  }

  /**
   * Get all bundled services for a region
   */
  getBundledServices(region: string = 'CH'): BundledServiceInfo[] {
    if (region !== 'CH') return [];
    return SWISS_BUNDLED_SERVICES;
  }

  /**
   * Clear the cache
   */
  clearCache(): void {
    this.cache.clear();
  }
}

export const tmdbStreamingService = TMDBStreamingService.getInstance();
