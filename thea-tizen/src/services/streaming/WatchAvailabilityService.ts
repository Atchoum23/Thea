/**
 * Watch Availability Service
 *
 * Intelligent service that determines the BEST way to watch content:
 * 1. Check if available on streaming services you have
 * 2. Check if SmartDNS can unlock it in another region
 * 3. Only suggest downloading as last resort
 *
 * This prevents unnecessary downloads when content is streamable.
 */

import { tmdbStreamingService, StreamingOption } from './TMDBStreamingService';
import { secureConfigService } from '../config/SecureConfigService';
import { ipMonitorService } from '../vpn/IPMonitorService';
import { STREAMING_ACCOUNTS } from '../../config/secrets';

export interface StreamingAccount {
  providerId: number;
  providerName: string;
  active: boolean;
  // Regions where account works (e.g., ['US', 'CH'] for Netflix)
  regions?: string[];
  // Additional metadata
  notes?: string;
  customProvider?: boolean;
  appleAccountRegion?: string;
  localServer?: {
    name: string;
    type: string;
  };
}

export interface WatchRecommendation {
  action: 'stream' | 'stream_with_smartdns' | 'download' | 'unavailable';
  priority: number; // 1 = best, higher = worse
  reason: string;
  details: {
    provider?: StreamingOption;
    requiredRegion?: string;
    smartDNSRequired?: boolean;
    downloadReason?: string;
  };
}

export interface ContentAvailability {
  tmdbId: number;
  title: string;
  type: 'movie' | 'tv';
  userCountry: string;
  recommendations: WatchRecommendation[];
  bestOption: WatchRecommendation;
  availableInUserCountry: boolean;
  availableWithSmartDNS: boolean;
  streamingOptions: StreamingOption[];
}

// Load streaming accounts from secrets.ts (user configured)
const DEFAULT_STREAMING_ACCOUNTS: StreamingAccount[] = STREAMING_ACCOUNTS.map(account => ({
  providerId: account.providerId,
  providerName: account.providerName,
  active: account.active,
  regions: account.regions,
  notes: account.notes,
  customProvider: account.customProvider,
  appleAccountRegion: account.appleAccountRegion,
  localServer: account.localServer,
}));

// Regions that SmartDNS can typically unlock
const SMARTDNS_SUPPORTED_REGIONS = ['US', 'GB', 'CA', 'AU', 'DE', 'FR', 'JP', 'RU'];

class WatchAvailabilityService {
  private static instance: WatchAvailabilityService;
  private streamingAccounts: StreamingAccount[] = [];
  private readonly STORAGE_KEY = 'thea_streaming_accounts';

  private constructor() {
    this.loadAccounts();
  }

  static getInstance(): WatchAvailabilityService {
    if (!WatchAvailabilityService.instance) {
      WatchAvailabilityService.instance = new WatchAvailabilityService();
    }
    return WatchAvailabilityService.instance;
  }

  /**
   * Load streaming accounts from localStorage
   */
  private loadAccounts(): void {
    try {
      const saved = localStorage.getItem(this.STORAGE_KEY);
      if (saved) {
        this.streamingAccounts = JSON.parse(saved);
      } else {
        this.streamingAccounts = [...DEFAULT_STREAMING_ACCOUNTS];
      }
    } catch {
      this.streamingAccounts = [...DEFAULT_STREAMING_ACCOUNTS];
    }
  }

  /**
   * Save streaming accounts
   */
  private saveAccounts(): void {
    localStorage.setItem(this.STORAGE_KEY, JSON.stringify(this.streamingAccounts));
  }

  /**
   * Get user's streaming accounts
   */
  getStreamingAccounts(): StreamingAccount[] {
    return [...this.streamingAccounts];
  }

  /**
   * Update a streaming account
   */
  setStreamingAccount(providerId: number, active: boolean, regions?: string[]): void {
    const account = this.streamingAccounts.find(a => a.providerId === providerId);
    if (account) {
      account.active = active;
      if (regions) account.regions = regions;
    }
    this.saveAccounts();
  }

  /**
   * Add a new streaming account
   */
  addStreamingAccount(account: StreamingAccount): void {
    const existing = this.streamingAccounts.find(a => a.providerId === account.providerId);
    if (existing) {
      Object.assign(existing, account);
    } else {
      this.streamingAccounts.push(account);
    }
    this.saveAccounts();
  }

  /**
   * Check if content is available on local Plex server
   */
  private async checkPlexAvailability(title: string, type: 'movie' | 'tv'): Promise<boolean> {
    const plexAccount = this.streamingAccounts.find(
      a => a.providerName === 'Plex' && a.active && a.localServer
    );

    if (!plexAccount) return false;

    // TODO: Integrate with Plex API to check library
    // For now, return false - will be implemented when Plex integration is added
    // This would query: http://localhost:32400/library/sections/X/search?query=TITLE
    return false;
  }

  /**
   * Check availability and get watch recommendations
   */
  async checkAvailability(
    tmdbId: number,
    type: 'movie' | 'tv',
    title?: string
  ): Promise<ContentAvailability> {
    const userConfig = secureConfigService.getUser();
    const userCountry = userConfig.country;
    const smartDNSEnabled = secureConfigService.isSmartDNSEnabled();
    const smartDNSValid = ipMonitorService.isSmartDNSIPValid();

    // Get streaming info from TMDB
    const streamingInfo = type === 'movie'
      ? await tmdbStreamingService.getMovieStreamingInfo(tmdbId, title)
      : await tmdbStreamingService.getTVStreamingInfo(tmdbId, title);

    const recommendations: WatchRecommendation[] = [];
    const activeAccounts = this.streamingAccounts.filter(a => a.active);

    // 0. Check Plex first (local server = best option)
    if (title) {
      const onPlex = await this.checkPlexAvailability(title, type);
      if (onPlex) {
        recommendations.push({
          action: 'stream',
          priority: 0, // Highest priority - local content
          reason: 'Available on your Plex server (MSM3U)',
          details: {
            provider: {
              providerId: 0,
              providerName: 'Plex',
              logoUrl: '',
              type: 'subscription',
              deepLink: 'plex://',
              country: 'Local',
              countryCode: 'LOCAL',
            },
          },
        });
      }
    }

    if (streamingInfo) {
      // Check user's country first
      const localOptions = streamingInfo.optionsByCountry[userCountry] || [];
      const subscriptionOptions = localOptions.filter(o => o.type === 'subscription');

      // 1. Check if available locally on user's streaming services
      for (const option of subscriptionOptions) {
        const hasAccount = activeAccounts.some(a => a.providerId === option.providerId);
        if (hasAccount) {
          recommendations.push({
            action: 'stream',
            priority: 1,
            reason: `Available on ${option.providerName} in ${userCountry}`,
            details: { provider: option },
          });
        }
      }

      // 2. Check SmartDNS-accessible regions
      if (smartDNSEnabled) {
        for (const region of SMARTDNS_SUPPORTED_REGIONS) {
          if (region === userCountry) continue; // Already checked

          const regionOptions = streamingInfo.optionsByCountry[region] || [];
          const regionSubs = regionOptions.filter(o => o.type === 'subscription');

          for (const option of regionSubs) {
            const account = activeAccounts.find(a => a.providerId === option.providerId);
            if (account) {
              // Check if account works in this region
              const accountWorksInRegion = !account.regions || account.regions.includes(region);
              if (accountWorksInRegion) {
                recommendations.push({
                  action: 'stream_with_smartdns',
                  priority: smartDNSValid ? 2 : 3,
                  reason: smartDNSValid
                    ? `Stream on ${option.providerName} (${region} library via SmartDNS)`
                    : `Available on ${option.providerName} (${region}) - SmartDNS needs re-activation`,
                  details: {
                    provider: option,
                    requiredRegion: region,
                    smartDNSRequired: true,
                  },
                });
              }
            }
          }
        }
      }

      // 3. Check for free/ad-supported options
      const freeOptions = localOptions.filter(o => o.type === 'free' || o.type === 'ads');
      for (const option of freeOptions) {
        const avoidAds = userConfig.avoidAds && option.type === 'ads';
        recommendations.push({
          action: 'stream',
          priority: avoidAds ? 4 : 2,
          reason: option.type === 'free'
            ? `Free on ${option.providerName}`
            : `Free with ads on ${option.providerName}`,
          details: { provider: option },
        });
      }
    }

    // 4. Download as fallback
    if (recommendations.length === 0) {
      recommendations.push({
        action: 'download',
        priority: 5,
        reason: 'Not available on your streaming services',
        details: {
          downloadReason: 'Content not found on configured streaming accounts',
        },
      });
    } else {
      // Also add download as an option (user might prefer it)
      recommendations.push({
        action: 'download',
        priority: 10,
        reason: 'Download for offline viewing',
        details: {
          downloadReason: 'User preference',
        },
      });
    }

    // Sort by priority
    recommendations.sort((a, b) => a.priority - b.priority);

    const locallyAvailable = recommendations.some(
      r => r.action === 'stream' && r.priority <= 2
    );
    const smartDNSAvailable = recommendations.some(
      r => r.action === 'stream_with_smartdns'
    );

    return {
      tmdbId,
      title: title || `Unknown (${tmdbId})`,
      type,
      userCountry,
      recommendations,
      bestOption: recommendations[0],
      availableInUserCountry: locallyAvailable,
      availableWithSmartDNS: smartDNSAvailable,
      streamingOptions: streamingInfo?.options || [],
    };
  }

  /**
   * Quick check: Should we download or can we stream?
   */
  async shouldDownload(
    tmdbId: number,
    type: 'movie' | 'tv',
    title?: string
  ): Promise<{ download: boolean; reason: string; alternative?: WatchRecommendation }> {
    const availability = await this.checkAvailability(tmdbId, type, title);

    if (availability.bestOption.action === 'stream') {
      return {
        download: false,
        reason: availability.bestOption.reason,
        alternative: availability.bestOption,
      };
    }

    if (availability.bestOption.action === 'stream_with_smartdns') {
      // SmartDNS is available - user might prefer streaming
      return {
        download: false,
        reason: availability.bestOption.reason,
        alternative: availability.bestOption,
      };
    }

    return {
      download: true,
      reason: 'Not available on your streaming services',
    };
  }

  /**
   * Get a human-readable summary
   */
  async getWatchSummary(
    tmdbId: number,
    type: 'movie' | 'tv',
    title?: string
  ): Promise<string> {
    const availability = await this.checkAvailability(tmdbId, type, title);
    const best = availability.bestOption;

    switch (best.action) {
      case 'stream':
        return `✅ Stream on ${best.details.provider?.providerName}`;
      case 'stream_with_smartdns':
        return `🌍 Stream via SmartDNS (${best.details.requiredRegion} ${best.details.provider?.providerName})`;
      case 'download':
        return `⬇️ Download recommended`;
      default:
        return `❓ Availability unknown`;
    }
  }
}

export const watchAvailabilityService = WatchAvailabilityService.getInstance();
