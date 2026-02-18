/**
 * Smart Watch Service - Intelligent Content Access
 *
 * When user asks "How can I watch Movie X?", this service:
 * 1. Checks availability across all configured streaming services
 * 2. Considers geo-restrictions and VPN options
 * 3. Recommends the best way to watch
 * 4. Can automatically orchestrate VPN + app launch
 */

import {
  streamingAvailabilityService,
  StreamingAccount,
  ContentAvailability,
  StreamingContentInfo,
} from './StreamingAvailabilityService';
import { nordVPNProxyService } from '../vpn/NordVPNProxyService';
import { ProviderRegistry } from '../ai/ProviderRegistry';

export interface WatchOption {
  id: string;
  priority: number; // Lower is better
  method: 'direct' | 'vpn' | 'download' | 'rent' | 'buy';
  service?: string;
  serviceIcon?: string;
  country?: string;
  countryCode?: string;
  quality?: string;
  hasAds?: boolean;
  price?: { amount: number; currency: string };
  estimatedStartTime?: number; // seconds until playback starts
  steps: WatchStep[];
  pros: string[];
  cons: string[];
}

export interface WatchStep {
  action: 'vpn_connect' | 'vpn_disconnect' | 'launch_app' | 'navigate' | 'search' | 'download' | 'wait' | 'user_action';
  description: string;
  automated: boolean;
  params?: Record<string, any>;
}

export interface WatchRecommendation {
  contentTitle: string;
  contentType: 'movie' | 'show' | 'episode';
  contentId: string;
  traktId?: number;
  imdbId?: string;
  options: WatchOption[];
  bestOption: WatchOption;
  needsDownload: boolean;
  vpnRequired: boolean;
  userCountry: string;
}

export interface WatchProgress {
  step: number;
  totalSteps: number;
  currentAction: string;
  status: 'pending' | 'in_progress' | 'completed' | 'failed' | 'waiting_user';
  error?: string;
}

class SmartWatchService {
  private static instance: SmartWatchService;
  private userCountry: string = 'fr'; // Default, will be detected/configured
  private watchProgress: WatchProgress | null = null;
  private progressCallback: ((progress: WatchProgress) => void) | null = null;

  private constructor() {
    this.loadConfig();
  }

  static getInstance(): SmartWatchService {
    if (!SmartWatchService.instance) {
      SmartWatchService.instance = new SmartWatchService();
    }
    return SmartWatchService.instance;
  }

  private loadConfig(): void {
    const saved = localStorage.getItem('thea_user_country');
    if (saved) {
      this.userCountry = saved;
    }
  }

  setUserCountry(country: string): void {
    this.userCountry = country.toLowerCase();
    localStorage.setItem('thea_user_country', this.userCountry);
  }

  getUserCountry(): string {
    return this.userCountry;
  }

  /**
   * Find the best way to watch content
   */
  async findBestWayToWatch(
    title: string,
    type: 'movie' | 'show' | 'episode',
    options?: {
      traktId?: number;
      imdbId?: string;
      season?: number;
      episode?: number;
      preferQuality?: string;
      avoidAds?: boolean;
    }
  ): Promise<WatchRecommendation> {
    const watchOptions: WatchOption[] = [];
    const showId = options?.traktId?.toString() || title;

    // 1. Get availability from streaming service
    const recommendation = await streamingAvailabilityService.shouldAutoDownload(
      showId,
      title,
      type === 'episode' ? 'show' : type,
      options?.season,
      options?.episode
    );

    // 2. Get configured accounts to check
    const accounts = streamingAvailabilityService.getAccounts();

    // 3. Build watch options based on availability
    // Direct streaming options
    if (recommendation.bestStreamingOption) {
      const opt = recommendation.bestStreamingOption;
      watchOptions.push(this.createDirectOption(opt, title));
    }

    // 4. Check SmartDNS/geo-unblocking options
    // SmartDNS is the only viable option for streaming apps on Samsung TV
    if (nordVPNProxyService.isSmartDNSEnabled()) {
      // Look for content available in other countries
      for (const account of accounts) {
        if (account.country !== this.userCountry) {
          watchOptions.push(this.createSmartDNSOption(account, title));
        }
      }
    } else if (nordVPNProxyService.isConfigured()) {
      // Suggest enabling SmartDNS
      watchOptions.push(this.createSmartDNSSetupOption(title));
    }

    // 5. Add download option
    const downloadOption = this.createDownloadOption(title, type);
    watchOptions.push(downloadOption);

    // 6. Add rent/buy options
    if (recommendation.shouldDownload && recommendation.reasons.includes('requires_payment')) {
      watchOptions.push(this.createRentOption(title));
      watchOptions.push(this.createBuyOption(title));
    }

    // Sort by priority
    watchOptions.sort((a, b) => a.priority - b.priority);

    // Apply user preferences
    const filteredOptions = this.applyPreferences(watchOptions, options);

    return {
      contentTitle: title,
      contentType: type,
      contentId: showId,
      traktId: options?.traktId,
      imdbId: options?.imdbId,
      options: filteredOptions,
      bestOption: filteredOptions[0],
      needsDownload: filteredOptions[0]?.method === 'download',
      vpnRequired: filteredOptions[0]?.method === 'vpn',
      userCountry: this.userCountry,
    };
  }

  /**
   * Create direct streaming option
   */
  private createDirectOption(info: StreamingContentInfo, title: string): WatchOption {
    const hasAds = info.hasAds;
    const quality = info.maxQuality || '1080p';

    return {
      id: `direct_${info.accountId}`,
      priority: hasAds ? 20 : (quality === '4K' ? 5 : 10),
      method: 'direct',
      service: info.appName,
      quality,
      hasAds,
      estimatedStartTime: 5,
      steps: [
        {
          action: 'launch_app',
          description: `Open ${info.appName}`,
          automated: true,
          params: { appId: this.getAppId(info.appId) },
        },
        {
          action: 'search',
          description: `Search for "${title}"`,
          automated: false,
          params: { query: title },
        },
      ],
      pros: [
        'Available now',
        hasAds ? '' : 'No ads',
        quality === '4K' ? '4K quality' : '',
      ].filter(Boolean),
      cons: hasAds ? ['Has advertisements'] : [],
    };
  }

  /**
   * Create SmartDNS-based watch option
   * SmartDNS is the ONLY way to geo-unblock streaming apps on Samsung TV
   * (native VPN apps don't exist for Tizen, and the VPN API is native-only)
   */
  private createSmartDNSOption(account: StreamingAccount, title: string): WatchOption {
    const countryName = this.getCountryName(account.country);

    return {
      id: `smartdns_${account.appId}_${account.country}`,
      priority: 25 + (this.getCountryLatencyScore(account.country) * 3),
      method: 'vpn', // SmartDNS acts like VPN for geo-unblocking
      service: account.appName,
      country: countryName,
      countryCode: account.country,
      quality: account.features.maxQuality,
      hasAds: account.features.hasAds,
      estimatedStartTime: 5, // No connection delay with SmartDNS
      steps: [
        {
          action: 'launch_app',
          description: `Open ${account.appName}`,
          automated: true,
          params: { appId: this.getAppId(account.appId) },
        },
        {
          action: 'search',
          description: `Navigate to "${title}"`,
          automated: false,
          params: { query: title },
        },
        {
          action: 'user_action',
          description: 'Watch content',
          automated: false,
        },
      ],
      pros: [
        `Available in ${countryName} via SmartDNS`,
        'No download required',
        'No speed impact (DNS only)',
        account.features.maxQuality === '4K' ? '4K available' : '',
      ].filter(Boolean),
      cons: [
        'SmartDNS must be configured on TV',
        'May need to restart app if country changed',
      ],
    };
  }

  /**
   * Create option to set up SmartDNS
   */
  private createSmartDNSSetupOption(title: string): WatchOption {
    const smartDNS = nordVPNProxyService.getSmartDNSConfig();

    return {
      id: 'smartdns_setup',
      priority: 35,
      method: 'vpn',
      service: 'NordVPN SmartDNS',
      estimatedStartTime: 300, // ~5 min setup
      steps: [
        {
          action: 'user_action',
          description: 'Go to TV Settings > General > Network > IP Settings',
          automated: false,
        },
        {
          action: 'user_action',
          description: `Set DNS to: ${smartDNS.primary} / ${smartDNS.secondary}`,
          automated: false,
        },
        {
          action: 'user_action',
          description: `Register your IP at ${nordVPNProxyService.getSmartDNSRegistrationUrl()}`,
          automated: false,
        },
        {
          action: 'user_action',
          description: 'Restart TV and launch streaming app',
          automated: false,
        },
      ],
      pros: [
        'Unlocks geo-restricted content',
        'Works with Netflix, Prime, Disney+, etc.',
        'No speed reduction',
        'One-time setup',
      ],
      cons: [
        'Requires initial configuration',
        'IP must be registered on NordVPN site',
      ],
    };
  }

  /**
   * Create download option
   */
  private createDownloadOption(title: string, type: string): WatchOption {
    return {
      id: 'download',
      priority: 50,
      method: 'download',
      quality: '1080p',
      estimatedStartTime: 600,
      steps: [
        {
          action: 'download',
          description: `Search and download "${title}"`,
          automated: true,
          params: { title, type },
        },
        {
          action: 'wait',
          description: 'Wait for download to complete',
          automated: true,
          params: { checkInterval: 30 },
        },
        {
          action: 'launch_app',
          description: 'Open Plex',
          automated: true,
          params: { appId: 'plex' },
        },
      ],
      pros: [
        'Best quality available',
        'No streaming buffering',
        'Permanent access',
      ],
      cons: [
        'Takes time to download',
        'Uses storage space',
      ],
    };
  }

  /**
   * Create rent option
   */
  private createRentOption(title: string): WatchOption {
    return {
      id: 'rent',
      priority: 55,
      method: 'rent',
      service: 'iTunes/Prime Video',
      price: { amount: 4.99, currency: 'EUR' },
      estimatedStartTime: 10,
      steps: [
        {
          action: 'user_action',
          description: 'Complete rental on preferred store',
          automated: false,
        },
      ],
      pros: ['Cheaper than buying', 'Immediate access'],
      cons: ['Limited time access (48h)'],
    };
  }

  /**
   * Create buy option
   */
  private createBuyOption(title: string): WatchOption {
    return {
      id: 'buy',
      priority: 60,
      method: 'buy',
      service: 'iTunes/Prime Video',
      price: { amount: 14.99, currency: 'EUR' },
      estimatedStartTime: 10,
      steps: [
        {
          action: 'user_action',
          description: 'Complete purchase on preferred store',
          automated: false,
        },
      ],
      pros: ['Permanent access', 'Best quality'],
      cons: ['Requires payment'],
    };
  }

  /**
   * Apply user preferences to filter/sort options
   */
  private applyPreferences(
    options: WatchOption[],
    prefs?: { preferQuality?: string; avoidAds?: boolean }
  ): WatchOption[] {
    let filtered = [...options];

    if (prefs?.avoidAds) {
      filtered = filtered.map(opt => ({
        ...opt,
        priority: opt.hasAds ? opt.priority + 100 : opt.priority,
      }));
    }

    if (prefs?.preferQuality === '4k' || prefs?.preferQuality === '4K') {
      filtered = filtered.map(opt => ({
        ...opt,
        priority: opt.quality === '4K' || opt.quality === '4k' ? opt.priority - 5 : opt.priority,
      }));
    }

    return filtered.sort((a, b) => a.priority - b.priority);
  }

  /**
   * Execute watch option automatically
   */
  async executeWatchOption(
    option: WatchOption,
    onProgress?: (progress: WatchProgress) => void
  ): Promise<{ success: boolean; error?: string }> {
    this.progressCallback = onProgress || null;

    const totalSteps = option.steps.filter(s => s.automated).length;
    let currentStep = 0;

    for (const step of option.steps) {
      if (!step.automated) {
        this.updateProgress({
          step: currentStep,
          totalSteps,
          currentAction: step.description,
          status: 'waiting_user',
        });
        continue;
      }

      currentStep++;
      this.updateProgress({
        step: currentStep,
        totalSteps,
        currentAction: step.description,
        status: 'in_progress',
      });

      try {
        await this.executeStep(step);
      } catch (error) {
        this.updateProgress({
          step: currentStep,
          totalSteps,
          currentAction: step.description,
          status: 'failed',
          error: error instanceof Error ? error.message : 'Unknown error',
        });
        return {
          success: false,
          error: error instanceof Error ? error.message : 'Step failed',
        };
      }
    }

    this.updateProgress({
      step: totalSteps,
      totalSteps,
      currentAction: 'Complete',
      status: 'completed',
    });

    return { success: true };
  }

  /**
   * Execute a single step
   */
  private async executeStep(step: WatchStep): Promise<void> {
    switch (step.action) {
      case 'wait':
        await new Promise(resolve =>
          setTimeout(resolve, (step.params?.seconds || 5) * 1000)
        );
        break;

      case 'launch_app':
        if (typeof tizen !== 'undefined' && tizen.application) {
          try {
            const appId = step.params?.appId || '';
            await new Promise<void>((resolve, reject) => {
              tizen.application.launch(
                appId,
                resolve,
                (error: any) => reject(new Error(error.message || 'App launch failed'))
              );
            });
          } catch (error) {
            console.warn('Could not launch app:', error);
          }
        }
        break;

      case 'download':
        // Trigger auto-download service
        console.log('Would trigger download for:', step.params);
        break;

      case 'vpn_connect':
      case 'vpn_disconnect':
        // Not applicable on Tizen - SmartDNS is always-on
        console.log('VPN actions not available on Tizen. Use SmartDNS instead.');
        break;

      default:
        console.log('Step requires user action:', step.description);
    }
  }

  /**
   * Update progress and notify callback
   */
  private updateProgress(progress: WatchProgress): void {
    this.watchProgress = progress;
    if (this.progressCallback) {
      this.progressCallback(progress);
    }
  }

  /**
   * Get Tizen app ID for a streaming service
   */
  private getAppId(appId: string): string {
    const appIds: Record<string, string> = {
      netflix: 'org.nicetizen.netflix',
      prime: 'org.nicetizen.primevideo',
      disney: 'com.disney.disneyplus',
      apple: 'com.apple.tvplus',
      hbo: 'com.hbo.max',
      canal: 'com.canal.canalplus',
      plex: 'plex.plexapp',
      youtube: 'com.google.youtube',
      paramount: 'com.paramount.paramountplus',
      hulu: 'com.hulu.huluapp',
    };
    return appIds[appId] || appId;
  }

  /**
   * Get country name from code
   */
  private getCountryName(code: string): string {
    const names: Record<string, string> = {
      us: 'United States',
      gb: 'United Kingdom',
      ca: 'Canada',
      de: 'Germany',
      fr: 'France',
      nl: 'Netherlands',
      au: 'Australia',
      jp: 'Japan',
      es: 'Spain',
      it: 'Italy',
      br: 'Brazil',
      mx: 'Mexico',
      in: 'India',
      kr: 'South Korea',
    };
    return names[code.toLowerCase()] || code.toUpperCase();
  }

  /**
   * Get latency score for country (lower is better)
   */
  private getCountryLatencyScore(code: string): number {
    const latencies: Record<string, number> = {
      fr: 0,
      de: 1,
      nl: 1,
      gb: 1,
      es: 1,
      it: 1,
      us: 3,
      ca: 3,
      br: 4,
      mx: 4,
      au: 5,
      jp: 4,
      kr: 4,
      in: 4,
    };
    return latencies[code.toLowerCase()] ?? 3;
  }

  /**
   * Use AI to interpret natural language watch request
   */
  async interpretWatchRequest(query: string): Promise<{
    title: string;
    type: 'movie' | 'show' | 'episode';
    season?: number;
    episode?: number;
  } | null> {
    try {
      const provider = ProviderRegistry.defaultProvider;
      if (!provider) return null;

      const prompt = `Extract content information from this watch request. Return JSON only.

Request: "${query}"

Return format:
{
  "title": "exact title",
  "type": "movie" | "show" | "episode",
  "season": number or null,
  "episode": number or null
}

Examples:
- "How can I watch Dune 2?" → {"title": "Dune: Part Two", "type": "movie"}
- "Where can I see Breaking Bad?" → {"title": "Breaking Bad", "type": "show"}
- "I want to watch The Bear S3E1" → {"title": "The Bear", "type": "episode", "season": 3, "episode": 1}`;

      const messages = [{ role: 'user' as const, content: prompt }];
      const models = ProviderRegistry.availableModels;
      const defaultModel = models.find(m => m.provider === provider.id)?.id || models[0]?.id || '';

      const stream = await provider.chat(messages, defaultModel, { stream: false });

      let response = '';
      for await (const chunk of stream) {
        if (chunk.type === 'content') {
          response += chunk.content;
        }
      }

      const jsonMatch = response.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        return JSON.parse(jsonMatch[0]);
      }
    } catch (error) {
      console.error('Failed to interpret watch request:', error);
    }

    return null;
  }
}

// Declare tizen global for TypeScript
declare const tizen: {
  application: {
    launch: (
      appId: string,
      successCallback: () => void,
      errorCallback: (error: { message: string }) => void
    ) => void;
  };
};

export const smartWatchService = SmartWatchService.getInstance();
