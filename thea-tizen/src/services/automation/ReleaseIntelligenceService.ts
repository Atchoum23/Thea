/**
 * Release Intelligence Service
 *
 * AI-powered optimal download timing based on:
 * - Historical release patterns for each show
 * - Show popularity and source (streaming vs broadcast)
 * - Day of week and time of day patterns
 * - Quality availability progression (720p → 1080p → 4K)
 * - Current torrent availability check
 *
 * Instead of hardcoded delays, learns and adapts to each show's release patterns.
 */

import { torrentQualityService, TorrentInfo, ScoredTorrent } from '../torrent/TorrentQualityService';
import { secureConfigService } from '../config/SecureConfigService';

export interface ReleasePattern {
  showId: string; // Trakt or TMDB ID
  showTitle: string;
  // Historical data
  averageDelayMinutes: number;
  minDelayMinutes: number;
  maxDelayMinutes: number;
  sampleCount: number;
  // Quality progression
  firstQualityAvailable: '720p' | '1080p' | '2160p';
  timeToPreferredQuality: number; // minutes after air
  // Source info
  source: 'streaming' | 'broadcast' | 'cable' | 'unknown';
  releaseDay: number; // 0-6 (Sunday-Saturday)
  releaseHourUTC: number;
  // Reliability
  consistencyScore: number; // 0-1, how predictable is this show
  lastUpdated: number;
}

export interface DownloadDecision {
  shouldDownload: boolean;
  reason: string;
  recommendedWaitMinutes: number;
  confidence: number; // 0-1
  bestAvailable?: ScoredTorrent;
  expectedBetterQuality?: {
    quality: string;
    estimatedWaitMinutes: number;
  };
}

export interface ReleaseCheck {
  showTitle: string;
  season: number;
  episode: number;
  airTime: Date;
  currentTime: Date;
  minutesSinceAir: number;
  torrentsFound: number;
  bestQuality?: string;
  bestScore?: number;
}

const STORAGE_KEY = 'thea_release_patterns';

// Default patterns for common show types
const DEFAULT_PATTERNS: Record<string, Partial<ReleasePattern>> = {
  // Streaming originals (Netflix, Disney+, etc.) - releases at midnight, immediate availability
  streaming: {
    averageDelayMinutes: 15,
    minDelayMinutes: 5,
    maxDelayMinutes: 60,
    source: 'streaming',
    consistencyScore: 0.95,
  },
  // US broadcast (CBS, NBC, ABC, FOX)
  broadcast: {
    averageDelayMinutes: 90,
    minDelayMinutes: 30,
    maxDelayMinutes: 240,
    source: 'broadcast',
    consistencyScore: 0.8,
  },
  // Cable (HBO, AMC, FX)
  cable: {
    averageDelayMinutes: 45,
    minDelayMinutes: 15,
    maxDelayMinutes: 120,
    source: 'cable',
    consistencyScore: 0.85,
  },
  // Unknown/default
  unknown: {
    averageDelayMinutes: 120,
    minDelayMinutes: 30,
    maxDelayMinutes: 360,
    source: 'unknown',
    consistencyScore: 0.5,
  },
};

// Networks/services mapped to pattern types
const NETWORK_PATTERNS: Record<string, string> = {
  'netflix': 'streaming',
  'disney+': 'streaming',
  'disney plus': 'streaming',
  'amazon': 'streaming',
  'prime video': 'streaming',
  'apple tv+': 'streaming',
  'hbo max': 'cable',
  'max': 'cable',
  'hbo': 'cable',
  'hulu': 'streaming',
  'paramount+': 'streaming',
  'peacock': 'streaming',
  'amc': 'cable',
  'fx': 'cable',
  'showtime': 'cable',
  'cbs': 'broadcast',
  'nbc': 'broadcast',
  'abc': 'broadcast',
  'fox': 'broadcast',
  'the cw': 'broadcast',
  'bbc': 'broadcast',
  'itv': 'broadcast',
  'canal+': 'cable',
};

class ReleaseIntelligenceService {
  private static instance: ReleaseIntelligenceService;
  private patterns: Map<string, ReleasePattern> = new Map();

  private constructor() {
    this.loadPatterns();
  }

  static getInstance(): ReleaseIntelligenceService {
    if (!ReleaseIntelligenceService.instance) {
      ReleaseIntelligenceService.instance = new ReleaseIntelligenceService();
    }
    return ReleaseIntelligenceService.instance;
  }

  private loadPatterns(): void {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        const data = JSON.parse(saved);
        this.patterns = new Map(Object.entries(data));
      }
    } catch {
      // Ignore
    }
  }

  private savePatterns(): void {
    const data = Object.fromEntries(this.patterns);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  }

  // ============================================================
  // PATTERN LEARNING
  // ============================================================

  /**
   * Record a successful download to learn from
   */
  recordRelease(params: {
    showId: string;
    showTitle: string;
    airTime: Date;
    downloadTime: Date;
    quality: '720p' | '1080p' | '2160p';
    network?: string;
  }): void {
    const { showId, showTitle, airTime, downloadTime, quality, network } = params;

    const delayMinutes = (downloadTime.getTime() - airTime.getTime()) / (1000 * 60);
    const existing = this.patterns.get(showId);

    if (existing) {
      // Update existing pattern with new data point
      const newSampleCount = existing.sampleCount + 1;
      const newAverage = (existing.averageDelayMinutes * existing.sampleCount + delayMinutes) / newSampleCount;

      this.patterns.set(showId, {
        ...existing,
        averageDelayMinutes: newAverage,
        minDelayMinutes: Math.min(existing.minDelayMinutes, delayMinutes),
        maxDelayMinutes: Math.max(existing.maxDelayMinutes, delayMinutes),
        sampleCount: newSampleCount,
        // Update consistency score based on variance
        consistencyScore: this.calculateConsistency(existing, delayMinutes),
        lastUpdated: Date.now(),
      });
    } else {
      // Create new pattern
      const networkType = network ? this.detectNetworkType(network) : 'unknown';
      const defaultPattern = DEFAULT_PATTERNS[networkType];

      this.patterns.set(showId, {
        showId,
        showTitle,
        averageDelayMinutes: delayMinutes,
        minDelayMinutes: delayMinutes,
        maxDelayMinutes: delayMinutes,
        sampleCount: 1,
        firstQualityAvailable: quality,
        timeToPreferredQuality: delayMinutes,
        source: defaultPattern.source || 'unknown',
        releaseDay: airTime.getUTCDay(),
        releaseHourUTC: airTime.getUTCHours(),
        consistencyScore: 0.5, // Start neutral
        lastUpdated: Date.now(),
      });
    }

    this.savePatterns();
  }

  private calculateConsistency(existing: ReleasePattern, newDelay: number): number {
    // Calculate how much this new data point deviates from average
    const deviation = Math.abs(newDelay - existing.averageDelayMinutes);
    const expectedRange = existing.maxDelayMinutes - existing.minDelayMinutes;

    if (expectedRange === 0) return existing.consistencyScore;

    const normalizedDeviation = deviation / expectedRange;
    // Blend with existing score, weighing recent data more
    return existing.consistencyScore * 0.7 + (1 - Math.min(normalizedDeviation, 1)) * 0.3;
  }

  private detectNetworkType(network: string): string {
    const normalized = network.toLowerCase().trim();
    for (const [key, type] of Object.entries(NETWORK_PATTERNS)) {
      if (normalized.includes(key)) {
        return type;
      }
    }
    return 'unknown';
  }

  // ============================================================
  // DOWNLOAD DECISION
  // ============================================================

  /**
   * Decide whether to download now or wait
   */
  async makeDownloadDecision(params: {
    showId: string;
    showTitle: string;
    season: number;
    episode: number;
    airTime: Date;
    network?: string;
    searchResults?: TorrentInfo[];
  }): Promise<DownloadDecision> {
    const { showId, showTitle, season, episode, airTime, network, searchResults } = params;
    const now = new Date();
    const minutesSinceAir = (now.getTime() - airTime.getTime()) / (1000 * 60);

    // Get or create pattern for this show
    let pattern = this.patterns.get(showId);
    if (!pattern) {
      const networkType = network ? this.detectNetworkType(network) : 'unknown';
      pattern = {
        showId,
        showTitle,
        ...DEFAULT_PATTERNS[networkType],
        sampleCount: 0,
        firstQualityAvailable: '1080p',
        timeToPreferredQuality: DEFAULT_PATTERNS[networkType].averageDelayMinutes || 120,
        releaseDay: airTime.getUTCDay(),
        releaseHourUTC: airTime.getUTCHours(),
        lastUpdated: Date.now(),
      } as ReleasePattern;
    }

    // If we have search results, evaluate them
    let bestAvailable: ScoredTorrent | undefined;
    if (searchResults && searchResults.length > 0) {
      bestAvailable = torrentQualityService.selectBest(searchResults) || undefined;
    }

    const prefs = torrentQualityService.getPreferences();
    const preferredRes = prefs.preferredResolution;

    // Decision logic
    return this.evaluateDecision({
      pattern,
      minutesSinceAir,
      bestAvailable,
      preferredRes,
    });
  }

  private evaluateDecision(params: {
    pattern: ReleasePattern;
    minutesSinceAir: number;
    bestAvailable?: ScoredTorrent;
    preferredRes: string;
  }): DownloadDecision {
    const { pattern, minutesSinceAir, bestAvailable, preferredRes } = params;

    // Case 1: No torrents found yet
    if (!bestAvailable) {
      const expectedWait = Math.max(0, pattern.minDelayMinutes - minutesSinceAir);
      return {
        shouldDownload: false,
        reason: 'No torrents available yet',
        recommendedWaitMinutes: Math.max(15, expectedWait),
        confidence: pattern.consistencyScore,
      };
    }

    // Case 2: Excellent quality already available
    const hasPreferredQuality = bestAvailable.torrent.resolution === preferredRes;
    const hasGoodScore = bestAvailable.score > 3000; // Quality threshold
    const hasNoWarnings = bestAvailable.warnings.length === 0;

    if (hasPreferredQuality && hasGoodScore && hasNoWarnings) {
      return {
        shouldDownload: true,
        reason: `Preferred quality (${preferredRes}) available with good score`,
        recommendedWaitMinutes: 0,
        confidence: 0.95,
        bestAvailable,
      };
    }

    // Case 3: Waited long enough based on pattern
    const waitedLongEnough = minutesSinceAir >= pattern.averageDelayMinutes;
    const waitedTooLong = minutesSinceAir >= pattern.maxDelayMinutes;

    if (waitedTooLong) {
      return {
        shouldDownload: true,
        reason: 'Waited maximum expected time - downloading best available',
        recommendedWaitMinutes: 0,
        confidence: 0.8,
        bestAvailable,
      };
    }

    // Case 4: Have decent quality but might get better
    if (bestAvailable.score > 2000) {
      const timeToExpectedBetter = pattern.timeToPreferredQuality - minutesSinceAir;

      if (timeToExpectedBetter <= 0 || waitedLongEnough) {
        return {
          shouldDownload: true,
          reason: 'Good quality available and waited expected time',
          recommendedWaitMinutes: 0,
          confidence: pattern.consistencyScore,
          bestAvailable,
        };
      }

      // Worth waiting for better quality
      return {
        shouldDownload: false,
        reason: `Good quality available, but better likely in ${Math.round(timeToExpectedBetter)} minutes`,
        recommendedWaitMinutes: Math.min(timeToExpectedBetter, 60), // Cap at 1 hour
        confidence: pattern.consistencyScore * 0.8,
        bestAvailable,
        expectedBetterQuality: {
          quality: preferredRes,
          estimatedWaitMinutes: Math.round(timeToExpectedBetter),
        },
      };
    }

    // Case 5: Only poor quality available
    const expectedBetterIn = pattern.averageDelayMinutes - minutesSinceAir;

    if (expectedBetterIn > 0) {
      return {
        shouldDownload: false,
        reason: `Only ${bestAvailable.torrent.resolution || 'unknown'} quality available, better expected soon`,
        recommendedWaitMinutes: Math.min(expectedBetterIn, 60),
        confidence: pattern.consistencyScore * 0.7,
        bestAvailable,
        expectedBetterQuality: {
          quality: preferredRes,
          estimatedWaitMinutes: Math.round(expectedBetterIn),
        },
      };
    }

    // Fallback: Download what we have
    return {
      shouldDownload: true,
      reason: 'Downloading best available after expected wait time',
      recommendedWaitMinutes: 0,
      confidence: 0.6,
      bestAvailable,
    };
  }

  // ============================================================
  // UTILITIES
  // ============================================================

  /**
   * Get pattern for a show
   */
  getPattern(showId: string): ReleasePattern | undefined {
    return this.patterns.get(showId);
  }

  /**
   * Get all learned patterns
   */
  getAllPatterns(): ReleasePattern[] {
    return Array.from(this.patterns.values());
  }

  /**
   * Estimate when a show will be available
   */
  estimateAvailability(showId: string, airTime: Date): {
    earliestMinutes: number;
    expectedMinutes: number;
    latestMinutes: number;
    confidence: number;
  } {
    const pattern = this.patterns.get(showId);

    if (pattern && pattern.sampleCount >= 3) {
      return {
        earliestMinutes: pattern.minDelayMinutes,
        expectedMinutes: pattern.averageDelayMinutes,
        latestMinutes: pattern.maxDelayMinutes,
        confidence: pattern.consistencyScore,
      };
    }

    // Use defaults
    return {
      earliestMinutes: 30,
      expectedMinutes: 90,
      latestMinutes: 240,
      confidence: 0.5,
    };
  }

  /**
   * Clear all learned patterns
   */
  clearPatterns(): void {
    this.patterns.clear();
    this.savePatterns();
  }

  /**
   * Export patterns for backup
   */
  exportPatterns(): string {
    return JSON.stringify(Object.fromEntries(this.patterns), null, 2);
  }

  /**
   * Import patterns from backup
   */
  importPatterns(json: string): boolean {
    try {
      const data = JSON.parse(json);
      this.patterns = new Map(Object.entries(data));
      this.savePatterns();
      return true;
    } catch {
      return false;
    }
  }
}

export const releaseIntelligenceService = ReleaseIntelligenceService.getInstance();
