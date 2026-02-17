/**
 * Watch Assistant - AI-powered "How to Watch" recommendations
 *
 * Integrates with:
 * - TMDB for streaming availability
 * - SmartWatchService for recommendation logic
 * - Chat interface for natural language interaction
 */

import { tmdbStreamingService, ContentStreamingInfo } from '../streaming/TMDBStreamingService';
import { smartWatchService, WatchRecommendation } from '../streaming/SmartWatchService';
import { nordVPNProxyService } from '../vpn/NordVPNProxyService';
import { streamingAvailabilityService, StreamingAppId } from '../streaming/StreamingAvailabilityService';

export interface WatchQuery {
  query: string;
  parsed?: {
    title: string;
    type: 'movie' | 'show' | 'episode';
    season?: number;
    episode?: number;
    year?: number;
  };
}

export interface WatchResponse {
  title: string;
  type: 'movie' | 'tv';
  tmdbId?: number;
  posterUrl?: string;
  streamingInfo?: ContentStreamingInfo;
  recommendation?: WatchRecommendation;
  summary: string;
  options: WatchOptionSummary[];
  bestOption?: WatchOptionSummary;
  needsVPN: boolean;
  availableInCountry: boolean;
  userCountry: string;
}

export interface WatchOptionSummary {
  method: string;
  service?: string;
  country?: string;
  quality?: string;
  price?: string;
  hasAds?: boolean;
  description: string;
  actionRequired: string;
}

class WatchAssistant {
  private static instance: WatchAssistant;
  private userCountry: string = 'FR';

  private constructor() {
    this.loadConfig();
  }

  static getInstance(): WatchAssistant {
    if (!WatchAssistant.instance) {
      WatchAssistant.instance = new WatchAssistant();
    }
    return WatchAssistant.instance;
  }

  private loadConfig(): void {
    const saved = localStorage.getItem('thea_user_country');
    if (saved) {
      this.userCountry = saved.toUpperCase();
    }
    this.detectCountry();
  }

  /**
   * Auto-detect user's country from IP
   */
  private async detectCountry(): Promise<void> {
    try {
      const response = await fetch('https://ipapi.co/json/');
      if (response.ok) {
        const data = await response.json() as { country_code: string };
        if (data.country_code) {
          this.userCountry = data.country_code.toUpperCase();
          localStorage.setItem('thea_user_country', this.userCountry);
          smartWatchService.setUserCountry(this.userCountry.toLowerCase());
        }
      }
    } catch (error) {
      console.warn('Could not detect country:', error);
    }
  }

  /**
   * Process a "how to watch" query
   */
  async processQuery(query: string): Promise<WatchResponse> {
    // 1. Parse the query to extract content info
    const parsed = await this.parseQuery(query);

    if (!parsed) {
      throw new Error('Could not understand the query. Please try: "How can I watch [title]?"');
    }

    // 2. Search TMDB for the content
    const tmdbType = parsed.type === 'show' || parsed.type === 'episode' ? 'tv' : 'movie';
    const searchResults = await tmdbStreamingService.search(parsed.title, tmdbType);

    if (searchResults.length === 0) {
      throw new Error(`Could not find "${parsed.title}" in our database.`);
    }

    const match = searchResults[0];

    // 3. Get streaming availability
    const streamingInfo = match.type === 'movie'
      ? await tmdbStreamingService.getMovieStreamingInfo(match.id, match.title)
      : await tmdbStreamingService.getTVStreamingInfo(match.id, match.title);

    // 4. Generate recommendation
    const recommendation = await smartWatchService.findBestWayToWatch(
      match.title,
      match.type === 'tv' ? 'show' : 'movie',
      {
        traktId: match.id,
        season: parsed.season,
        episode: parsed.episode,
      }
    );

    // 5. Build response
    const availableInCountry = streamingInfo?.availableCountries.includes(this.userCountry) ?? false;
    const options = this.buildOptionSummaries(streamingInfo, recommendation);

    const needsVPN = !availableInCountry &&
      (streamingInfo?.availableCountries.length ?? 0) > 0 &&
      nordVPNProxyService.isConfigured();

    return {
      title: match.title,
      type: match.type,
      tmdbId: match.id,
      posterUrl: match.posterUrl,
      streamingInfo: streamingInfo || undefined,
      recommendation,
      summary: this.generateSummary(match.title, availableInCountry, streamingInfo, needsVPN),
      options,
      bestOption: options[0],
      needsVPN,
      availableInCountry,
      userCountry: this.userCountry,
    };
  }

  /**
   * Parse natural language query
   */
  private async parseQuery(query: string): Promise<WatchQuery['parsed'] | null> {
    // Try simple regex patterns first
    const patterns = [
      // "How can I watch Movie X" or "Where to watch Movie X"
      /(?:how\s+(?:can|do)\s+i|where\s+(?:can|to))\s+(?:watch|see|stream)\s+(.+?)(?:\?|$)/i,
      // "Watch Movie X" or "I want to watch Movie X"
      /(?:i\s+want\s+to\s+)?watch\s+(.+?)(?:\?|$)/i,
      // "Find Movie X"
      /find\s+(.+?)(?:\?|$)/i,
      // "Movie X streaming" or "Is Movie X on Netflix"
      /(.+?)\s+(?:streaming|on\s+\w+)(?:\?|$)/i,
    ];

    let title: string | null = null;

    for (const pattern of patterns) {
      const match = query.match(pattern);
      if (match) {
        title = match[1].trim();
        break;
      }
    }

    // Fallback: use the whole query
    if (!title) {
      title = query.replace(/[?!]/g, '').trim();
    }

    // Check for season/episode patterns
    let season: number | undefined;
    let episode: number | undefined;
    let type: 'movie' | 'show' | 'episode' = 'movie';

    const seMatch = title.match(/[Ss](\d+)[Ee](\d+)/);
    if (seMatch) {
      season = parseInt(seMatch[1]);
      episode = parseInt(seMatch[2]);
      type = 'episode';
      title = title.replace(seMatch[0], '').trim();
    }

    const sMatch = title.match(/\s+[Ss]eason\s+(\d+)/i);
    if (sMatch) {
      season = parseInt(sMatch[1]);
      type = 'show';
      title = title.replace(sMatch[0], '').trim();
    }

    // Check for year
    let year: number | undefined;
    const yearMatch = title.match(/\s*\((\d{4})\)\s*$/);
    if (yearMatch) {
      year = parseInt(yearMatch[1]);
      title = title.replace(yearMatch[0], '').trim();
    }

    // Determine type from keywords
    if (title.match(/\b(?:series|show|tv)\b/i)) {
      type = 'show';
      title = title.replace(/\b(?:series|show|tv)\b/gi, '').trim();
    } else if (title.match(/\b(?:movie|film)\b/i)) {
      type = 'movie';
      title = title.replace(/\b(?:movie|film)\b/gi, '').trim();
    }

    // Clean up
    title = title.replace(/\s+/g, ' ').trim();

    if (!title) return null;

    return { title, type, season, episode, year };
  }

  /**
   * Build option summaries from streaming info
   */
  private buildOptionSummaries(
    streamingInfo: ContentStreamingInfo | null,
    _recommendation: WatchRecommendation
  ): WatchOptionSummary[] {
    const summaries: WatchOptionSummary[] = [];
    const accounts = streamingAvailabilityService.getAccounts();
    const accountServices = new Set(accounts.map(a => a.appId));

    // Options from TMDB streaming info
    if (streamingInfo) {
      const countryOptions = streamingInfo.optionsByCountry[this.userCountry] || [];

      // Subscription options the user has
      for (const option of countryOptions) {
        if (option.type === 'subscription') {
          const appId = tmdbStreamingService.getAppIdForProvider(option.providerId);
          const hasAccount = appId ? accountServices.has(appId as StreamingAppId) : false;

          summaries.push({
            method: hasAccount ? 'stream' : 'subscribe',
            service: option.providerName,
            country: this.userCountry,
            description: hasAccount
              ? `Available on ${option.providerName}`
              : `Available on ${option.providerName} (requires subscription)`,
            actionRequired: hasAccount
              ? `Open ${option.providerName}`
              : `Subscribe to ${option.providerName}`,
          });
        }
      }

      // Free options
      for (const option of countryOptions) {
        if (option.type === 'free' || option.type === 'ads') {
          summaries.push({
            method: 'free',
            service: option.providerName,
            hasAds: option.type === 'ads',
            description: option.type === 'ads'
              ? `Free with ads on ${option.providerName}`
              : `Free on ${option.providerName}`,
            actionRequired: `Open ${option.providerName}`,
          });
        }
      }

      // Rent/Buy options
      for (const option of countryOptions) {
        if (option.type === 'rent') {
          summaries.push({
            method: 'rent',
            service: option.providerName,
            price: '€4.99', // Would come from API
            description: `Rent on ${option.providerName}`,
            actionRequired: `Rent for ~€4.99`,
          });
        }
        if (option.type === 'buy') {
          summaries.push({
            method: 'buy',
            service: option.providerName,
            price: '€14.99',
            description: `Buy on ${option.providerName}`,
            actionRequired: `Buy for ~€14.99`,
          });
        }
      }

      // VPN options for other countries
      if (nordVPNProxyService.isSmartDNSEnabled()) {
        for (const [countryCode, options] of Object.entries(streamingInfo.optionsByCountry)) {
          if (countryCode === this.userCountry) continue;

          const subscriptions = options.filter(o => o.type === 'subscription');
          for (const option of subscriptions.slice(0, 2)) {
            const appId = tmdbStreamingService.getAppIdForProvider(option.providerId);
            const hasAccount = appId ? accountServices.has(appId as StreamingAppId) : false;

            if (hasAccount) {
              summaries.push({
                method: 'smartdns',
                service: option.providerName,
                country: option.country,
                description: `Available on ${option.providerName} in ${option.country}`,
                actionRequired: `SmartDNS to ${option.country}, then open ${option.providerName}`,
              });
            }
          }
        }
      }
    }

    // Always add download option
    summaries.push({
      method: 'download',
      quality: '1080p',
      description: 'Download via torrent to Plex',
      actionRequired: 'Search and download torrent',
    });

    // Sort by preference
    const methodOrder = ['stream', 'free', 'smartdns', 'rent', 'download', 'buy', 'subscribe'];
    summaries.sort((a, b) =>
      methodOrder.indexOf(a.method) - methodOrder.indexOf(b.method)
    );

    return summaries;
  }

  /**
   * Generate human-readable summary
   */
  private generateSummary(
    title: string,
    availableInCountry: boolean,
    streamingInfo: ContentStreamingInfo | null,
    needsVPN: boolean
  ): string {
    if (!streamingInfo) {
      return `I couldn't find streaming information for "${title}". You may need to download it.`;
    }

    const countryOptions = streamingInfo.optionsByCountry[this.userCountry] || [];
    const subscriptions = countryOptions.filter(o => o.type === 'subscription');
    const freeOptions = countryOptions.filter(o => o.type === 'free' || o.type === 'ads');

    if (subscriptions.length > 0) {
      const services = subscriptions.map(o => o.providerName).join(', ');
      return `"${title}" is available to stream on ${services} in your country.`;
    }

    if (freeOptions.length > 0) {
      const services = freeOptions.map(o => o.providerName).join(', ');
      return `"${title}" is free to watch on ${services}${freeOptions.some(o => o.type === 'ads') ? ' (with ads)' : ''}.`;
    }

    if (needsVPN && nordVPNProxyService.isSmartDNSEnabled()) {
      const otherCountries = streamingInfo.availableCountries.slice(0, 3);
      return `"${title}" isn't available in ${this.userCountry}, but you can watch it via SmartDNS in ${otherCountries.join(', ')}.`;
    }

    const rentOptions = countryOptions.filter(o => o.type === 'rent');
    if (rentOptions.length > 0) {
      return `"${title}" is available to rent on ${rentOptions[0].providerName}.`;
    }

    return `"${title}" isn't available on your streaming services. I recommend downloading it.`;
  }

  /**
   * Generate AI chat response for watch query
   */
  async generateChatResponse(query: string): Promise<string> {
    try {
      const result = await this.processQuery(query);

      let response = `## ${result.title}\n\n`;
      response += result.summary + '\n\n';

      if (result.options.length > 0) {
        response += '### Your Options:\n\n';

        for (let i = 0; i < Math.min(5, result.options.length); i++) {
          const opt = result.options[i];
          const emoji = this.getMethodEmoji(opt.method);
          response += `${i + 1}. ${emoji} **${opt.description}**\n`;
          response += `   → ${opt.actionRequired}\n\n`;
        }
      }

      if (result.needsVPN && !nordVPNProxyService.isSmartDNSEnabled()) {
        response += '\n💡 **Tip:** Set up SmartDNS on your TV to access content from other countries.\n';
      }

      return response;
    } catch (error) {
      return `Sorry, I couldn't process that request. ${error instanceof Error ? error.message : ''}\n\nTry asking: "How can I watch [movie or show name]?"`;
    }
  }

  private getMethodEmoji(method: string): string {
    const emojis: Record<string, string> = {
      stream: '📺',
      free: '🆓',
      smartdns: '🌍',
      rent: '💰',
      buy: '🛒',
      download: '⬇️',
      subscribe: '➕',
    };
    return emojis[method] || '•';
  }

  /**
   * Get user's country
   */
  getUserCountry(): string {
    return this.userCountry;
  }

  /**
   * Set user's country
   */
  setUserCountry(country: string): void {
    this.userCountry = country.toUpperCase();
    localStorage.setItem('thea_user_country', this.userCountry);
    smartWatchService.setUserCountry(country.toLowerCase());
  }
}

export const watchAssistant = WatchAssistant.getInstance();
