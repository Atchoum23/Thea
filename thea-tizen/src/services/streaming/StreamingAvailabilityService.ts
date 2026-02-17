/**
 * Streaming Availability Service
 * Tracks which shows/movies are available on which streaming apps
 * and determines if auto-download is needed based on availability rules
 */

export type StreamingAppId =
  | 'netflix' | 'prime' | 'disney' | 'apple' | 'hbo' | 'paramount'
  | 'peacock' | 'hulu' | 'canal' | 'canal_ch' | 'plex' | 'youtube' | 'crunchyroll'
  | 'swisscom' | 'other';

/**
 * Canal+ Switzerland bundled services
 * Via Swisscom TV subscription → Canal+ Switzerland → Access to:
 * - HBO Max content
 * - Paramount+ content
 * All accessible through the Canal+ app
 */
export interface BundledStreamingInfo {
  mainProvider: StreamingAppId;      // canal_ch
  accessedVia: 'swisscom';           // Subscription through Swisscom TV
  includedServices: StreamingAppId[]; // hbo, paramount
}

export interface StreamingAccount {
  id: string;
  appId: StreamingAppId;
  appName: string;
  accountName: string; // e.g., "Family", "Personal", "Work"
  email?: string;
  country: string; // ISO country code (US, FR, GB, etc.)
  tier: 'free' | 'ad-supported' | 'standard' | 'premium' | '4k';
  features: {
    maxQuality: '480p' | '720p' | '1080p' | '4K';
    hasAds: boolean;
    simultaneousStreams: number;
    downloadable: boolean;
    hdr: boolean;
    dolbyVision: boolean;
    dolbyAtmos: boolean;
  };
  isActive: boolean;
}

export interface ContentAvailability {
  showId: string; // Trakt ID
  title: string;
  type: 'movie' | 'show';
  // Per-streaming-app availability
  availability: StreamingContentInfo[];
  // Calculated recommendation
  recommendation: AvailabilityRecommendation;
}

export interface StreamingContentInfo {
  accountId: string;
  appId: StreamingAppId;
  appName: string;
  accountName: string;
  // Availability details
  isAvailable: boolean;
  availableSeasons?: number[]; // For shows
  missingSeasons?: number[]; // Seasons not on this service
  // Quality/features
  maxQuality: '480p' | '720p' | '1080p' | '4K';
  hasHDR: boolean;
  hasDolbyVision: boolean;
  hasDolbyAtmos: boolean;
  audioLanguages: string[];
  subtitleLanguages: string[];
  // Access restrictions
  requiresPayment: boolean; // Extra purchase required
  paymentAmount?: number;
  hasAds: boolean;
  releaseDelay?: number; // Days after original air date
  expiresAt?: string; // If content is leaving soon
  isExtendedCut: boolean; // vs theatrical
  // Regional
  country: string;
  isGeoBlocked: boolean; // Available but blocked in your region
}

export type DownloadReason =
  | 'not_available' // Not on any streaming service
  | 'delayed_release' // Available but with delay
  | 'requires_payment' // Would need to pay extra
  | 'has_ads' // Only available with ads
  | 'low_quality' // Available but not in desired quality
  | 'missing_language' // Missing preferred audio/subtitle
  | 'partial_availability' // Only some seasons available
  | 'expiring_soon' // Content leaving streaming
  | 'extended_version' // Want director's cut etc
  | 'geo_blocked'; // Available elsewhere but not in your region

export interface AvailabilityRecommendation {
  shouldDownload: boolean;
  reasons: DownloadReason[];
  bestStreamingOption?: StreamingContentInfo;
  explanation: string;
  priority: 'low' | 'medium' | 'high' | 'critical';
}

export interface UserStreamingPreferences {
  // Accounts
  accounts: StreamingAccount[];

  // Quality requirements
  minimumQuality: '480p' | '720p' | '1080p' | '4K';
  requireHDR: boolean;
  requireDolbyVision: boolean;
  requireDolbyAtmos: boolean;

  // Language requirements
  preferredAudioLanguages: string[]; // ISO codes: en, fr, de, etc.
  requiredAudioLanguages: string[]; // Must have at least one
  preferredSubtitleLanguages: string[];
  requiredSubtitleLanguages: string[];

  // Content preferences
  acceptAds: boolean;
  maxAcceptableDelay: number; // Days - download if delay exceeds this
  maxAcceptablePayment: number; // Amount in local currency - download if price exceeds
  downloadExpiringContent: boolean; // Auto-download if leaving soon
  downloadExtendedVersions: boolean; // Prefer director's cuts etc

  // Per-show overrides
  showOverrides: Map<string, ShowOverride>;
}

export interface ShowOverride {
  showId: string;
  title: string;
  // Override defaults
  alwaysDownload?: boolean;
  neverDownload?: boolean;
  preferredStreamingApp?: StreamingAppId;
  preferredAccount?: string;
  qualityOverride?: '480p' | '720p' | '1080p' | '4K';
  languageOverride?: string[];
}

// Quality ranking for comparison
const QUALITY_RANK: Record<string, number> = {
  '480p': 1,
  '720p': 2,
  '1080p': 3,
  '4K': 4,
};

class StreamingAvailabilityService {
  private preferences: UserStreamingPreferences = {
    accounts: [],
    minimumQuality: '1080p',
    requireHDR: false,
    requireDolbyVision: false,
    requireDolbyAtmos: false,
    preferredAudioLanguages: ['en'],
    requiredAudioLanguages: ['en'],
    preferredSubtitleLanguages: ['en'],
    requiredSubtitleLanguages: [],
    acceptAds: false,
    maxAcceptableDelay: 0, // No delay accepted by default
    maxAcceptablePayment: 0, // No extra payment accepted
    downloadExpiringContent: true,
    downloadExtendedVersions: true,
    showOverrides: new Map(),
  };

  private availabilityCache: Map<string, ContentAvailability> = new Map();
  private cacheExpiry = 24 * 60 * 60 * 1000; // 24 hours

  /**
   * Get user's streaming preferences
   */
  getPreferences(): UserStreamingPreferences {
    return { ...this.preferences };
  }

  /**
   * Update streaming preferences
   */
  updatePreferences(updates: Partial<UserStreamingPreferences>): void {
    this.preferences = { ...this.preferences, ...updates };
    this.savePreferences();
  }

  /**
   * Add a streaming account
   */
  addAccount(account: StreamingAccount): void {
    // Remove existing account with same ID
    this.preferences.accounts = this.preferences.accounts.filter(a => a.id !== account.id);
    this.preferences.accounts.push(account);
    this.savePreferences();
  }

  /**
   * Remove a streaming account
   */
  removeAccount(accountId: string): void {
    this.preferences.accounts = this.preferences.accounts.filter(a => a.id !== accountId);
    this.savePreferences();
  }

  /**
   * Get all configured streaming accounts
   */
  getAccounts(): StreamingAccount[] {
    return [...this.preferences.accounts];
  }

  /**
   * Set show-specific override
   */
  setShowOverride(override: ShowOverride): void {
    this.preferences.showOverrides.set(override.showId, override);
    this.savePreferences();
  }

  /**
   * Remove show-specific override
   */
  removeShowOverride(showId: string): void {
    this.preferences.showOverrides.delete(showId);
    this.savePreferences();
  }

  /**
   * Check if a show/movie should be auto-downloaded
   * This is the main decision function
   */
  async shouldAutoDownload(
    showId: string,
    title: string,
    type: 'movie' | 'show',
    season?: number,
    _episode?: number
  ): Promise<AvailabilityRecommendation> {
    // Check for show-specific override first
    const override = this.preferences.showOverrides.get(showId);
    if (override?.alwaysDownload) {
      return {
        shouldDownload: true,
        reasons: ['not_available'], // Forced download
        explanation: `Auto-download forced by user preference for "${title}"`,
        priority: 'high',
      };
    }
    if (override?.neverDownload) {
      return {
        shouldDownload: false,
        reasons: [],
        explanation: `Auto-download disabled by user preference for "${title}"`,
        priority: 'low',
      };
    }

    // Get availability from all configured streaming services
    const availability = await this.getContentAvailability(showId, title, type, season);

    // Analyze availability and make recommendation
    return this.analyzeAvailability(availability, override);
  }

  /**
   * Get content availability across all streaming services
   */
  async getContentAvailability(
    showId: string,
    title: string,
    type: 'movie' | 'show',
    season?: number
  ): Promise<ContentAvailability> {
    // Check cache
    const cacheKey = `${showId}-${season || 'all'}`;
    const cached = this.availabilityCache.get(cacheKey);
    if (cached) {
      return cached;
    }

    // In production, this would query JustWatch API or similar
    // For now, we simulate based on configured accounts
    const availability: StreamingContentInfo[] = [];

    for (const account of this.preferences.accounts) {
      // Simulate availability check
      // In production: const info = await this.checkJustWatch(showId, account);
      const info = await this.simulateAvailabilityCheck(showId, title, type, account, season);
      if (info) {
        availability.push(info);
      }
    }

    const contentBase = { showId, title, type, availability };
    const result: ContentAvailability = {
      ...contentBase,
      recommendation: this.analyzeAvailability(contentBase),
    };

    // Cache result
    this.availabilityCache.set(cacheKey, result);

    return result;
  }

  /**
   * Analyze availability and determine if download is needed
   */
  private analyzeAvailability(
    content: Omit<ContentAvailability, 'recommendation'>,
    override?: ShowOverride
  ): AvailabilityRecommendation {
    const reasons: DownloadReason[] = [];
    let bestOption: StreamingContentInfo | undefined;
    let bestScore = -1;

    // Quality requirement (with override)
    const requiredQuality = override?.qualityOverride || this.preferences.minimumQuality;
    const requiredQualityRank = QUALITY_RANK[requiredQuality];

    // Language requirements (with override)
    const requiredAudio = override?.languageOverride || this.preferences.requiredAudioLanguages;

    for (const option of content.availability) {
      if (!option.isAvailable) continue;

      let score = 0;
      const optionIssues: DownloadReason[] = [];

      // Check quality
      const qualityRank = QUALITY_RANK[option.maxQuality];
      if (qualityRank >= requiredQualityRank) {
        score += 20;
      } else {
        optionIssues.push('low_quality');
      }

      // Bonus for HDR/DV/Atmos
      if (this.preferences.requireHDR && !option.hasHDR) {
        optionIssues.push('low_quality');
      } else if (option.hasHDR) {
        score += 5;
      }
      if (option.hasDolbyVision) score += 5;
      if (option.hasDolbyAtmos) score += 5;

      // Check language
      const hasRequiredAudio = requiredAudio.some(lang =>
        option.audioLanguages.includes(lang)
      );
      if (hasRequiredAudio) {
        score += 15;
      } else {
        optionIssues.push('missing_language');
      }

      // Check ads
      if (option.hasAds && !this.preferences.acceptAds) {
        optionIssues.push('has_ads');
      } else if (!option.hasAds) {
        score += 10;
      }

      // Check payment
      if (option.requiresPayment) {
        if (option.paymentAmount && option.paymentAmount > this.preferences.maxAcceptablePayment) {
          optionIssues.push('requires_payment');
        } else {
          score -= 5; // Small penalty for extra payment
        }
      } else {
        score += 10;
      }

      // Check delay
      if (option.releaseDelay && option.releaseDelay > this.preferences.maxAcceptableDelay) {
        optionIssues.push('delayed_release');
      }

      // Check expiring
      if (option.expiresAt) {
        const daysUntilExpiry = (new Date(option.expiresAt).getTime() - Date.now()) / (1000 * 60 * 60 * 24);
        if (daysUntilExpiry < 30 && this.preferences.downloadExpiringContent) {
          optionIssues.push('expiring_soon');
        }
      }

      // Check geo-blocking
      if (option.isGeoBlocked) {
        optionIssues.push('geo_blocked');
        score = 0; // Can't use this option
      }

      // Check partial availability (for shows)
      if (option.missingSeasons && option.missingSeasons.length > 0) {
        optionIssues.push('partial_availability');
        score -= 10;
      }

      // Check extended version preference
      if (this.preferences.downloadExtendedVersions && !option.isExtendedCut) {
        // Might want extended version
        optionIssues.push('extended_version');
      }

      // If this option has no blocking issues, consider it
      if (score > bestScore && optionIssues.length === 0) {
        bestScore = score;
        bestOption = option;
      }

      // Collect all issues for reporting
      reasons.push(...optionIssues.filter(r => !reasons.includes(r)));
    }

    // Determine final recommendation
    const shouldDownload = !bestOption || reasons.length > 0;

    let priority: 'low' | 'medium' | 'high' | 'critical' = 'low';
    if (reasons.includes('not_available')) {
      priority = 'high';
    } else if (reasons.includes('delayed_release') || reasons.includes('expiring_soon')) {
      priority = 'medium';
    } else if (reasons.includes('low_quality') || reasons.includes('missing_language')) {
      priority = 'medium';
    }

    // Generate explanation
    let explanation: string;
    if (!shouldDownload && bestOption) {
      explanation = `Available on ${bestOption.appName} (${bestOption.accountName}) in ${bestOption.maxQuality}`;
      if (bestOption.hasHDR) explanation += ' with HDR';
    } else if (content.availability.length === 0) {
      explanation = 'Not available on any configured streaming service';
      reasons.push('not_available');
      priority = 'critical';
    } else {
      const reasonTexts = reasons.map(r => this.getReasonText(r));
      explanation = `Download recommended: ${reasonTexts.join(', ')}`;
    }

    return {
      shouldDownload,
      reasons: shouldDownload ? (reasons.length > 0 ? reasons : ['not_available']) : [],
      bestStreamingOption: bestOption,
      explanation,
      priority,
    };
  }

  /**
   * Get human-readable text for download reason
   */
  private getReasonText(reason: DownloadReason): string {
    const texts: Record<DownloadReason, string> = {
      'not_available': 'not available on streaming',
      'delayed_release': 'release delayed on streaming',
      'requires_payment': 'requires extra payment',
      'has_ads': 'only available with ads',
      'low_quality': 'streaming quality too low',
      'missing_language': 'missing required language',
      'partial_availability': 'only partially available',
      'expiring_soon': 'leaving streaming soon',
      'extended_version': 'extended version not available',
      'geo_blocked': 'geo-blocked in your region',
    };
    return texts[reason];
  }

  /**
   * Simulate availability check (replace with real API in production)
   */
  private async simulateAvailabilityCheck(
    showId: string,
    title: string,
    type: 'movie' | 'show',
    account: StreamingAccount,
    _season?: number
  ): Promise<StreamingContentInfo | null> {
    // In production, this would call JustWatch API or similar
    // For now, return mock data based on account configuration

    // Simulate that content might be available
    const isAvailable = Math.random() > 0.3; // 70% chance available

    if (!isAvailable) return null;

    return {
      accountId: account.id,
      appId: account.appId,
      appName: account.appName,
      accountName: account.accountName,
      isAvailable: true,
      maxQuality: account.features.maxQuality,
      hasHDR: account.features.hdr,
      hasDolbyVision: account.features.dolbyVision,
      hasDolbyAtmos: account.features.dolbyAtmos,
      audioLanguages: ['en', 'fr'], // Would come from API
      subtitleLanguages: ['en', 'fr', 'es'],
      requiresPayment: Math.random() > 0.8, // 20% chance needs payment
      hasAds: account.features.hasAds,
      releaseDelay: Math.random() > 0.7 ? Math.floor(Math.random() * 14) : 0,
      isExtendedCut: false,
      country: account.country,
      isGeoBlocked: false,
    };
  }

  /**
   * Clear availability cache
   */
  clearCache(): void {
    this.availabilityCache.clear();
  }

  /**
   * Save preferences to localStorage
   */
  private savePreferences(): void {
    try {
      const toSave = {
        ...this.preferences,
        showOverrides: Array.from(this.preferences.showOverrides.entries()),
      };
      localStorage.setItem('thea_streaming_preferences', JSON.stringify(toSave));
    } catch (error) {
      console.error('[StreamingAvailability] Failed to save preferences:', error);
    }
  }

  /**
   * Load preferences from localStorage
   */
  loadPreferences(): void {
    try {
      const saved = localStorage.getItem('thea_streaming_preferences');
      if (saved) {
        const parsed = JSON.parse(saved);
        this.preferences = {
          ...this.preferences,
          ...parsed,
          showOverrides: new Map(parsed.showOverrides || []),
        };
      }
    } catch (error) {
      console.error('[StreamingAvailability] Failed to load preferences:', error);
    }
  }

  /**
   * Export configuration for sync to other devices
   */
  exportConfig(): string {
    return JSON.stringify({
      preferences: {
        ...this.preferences,
        showOverrides: Array.from(this.preferences.showOverrides.entries()),
      },
      version: 1,
      exportedAt: new Date().toISOString(),
    });
  }

  /**
   * Import configuration from another device
   */
  importConfig(configJson: string): void {
    try {
      const config = JSON.parse(configJson);
      if (config.version === 1) {
        this.preferences = {
          ...config.preferences,
          showOverrides: new Map(config.preferences.showOverrides || []),
        };
        this.savePreferences();
      }
    } catch (error) {
      console.error('[StreamingAvailability] Failed to import config:', error);
      throw new Error('Invalid configuration format');
    }
  }
}

// Singleton instance
export const streamingAvailabilityService = new StreamingAvailabilityService();
