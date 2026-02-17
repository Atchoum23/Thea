/**
 * Auto Download Service
 * Automatically monitors Trakt for new episodes and downloads torrents to Plex
 *
 * Features:
 * - Monitors shows in progress and watchlist
 * - Checks for new episodes on configurable schedule
 * - Checks streaming availability before downloading
 * - AI-powered release research for quality/safety
 * - Retry logic until download succeeds
 * - Downloads to Plex via qBittorrent
 * - Language and subtitle preferences
 * - Cross-device sync and notifications
 */

import { smartHubService, TorrentSearchResult } from '../hub/SmartHubService';
import { aiTorrentSearchService, UserPreferences } from '../search/AITorrentSearchService';
import { releaseResearchService } from './ReleaseResearchService';
import {
  streamingAvailabilityService,
  AvailabilityRecommendation,
  DownloadReason,
} from '../streaming/StreamingAvailabilityService';

// Quality priority - "highest" means try 4K first, then 1080p, then 720p
export type QualityPriority = 'highest' | '4K' | '1080p' | '720p' | 'smallest';

export interface AutoDownloadConfig {
  enabled: boolean;

  // Schedule settings
  checkIntervalMinutes: number; // How often to check for new releases
  retryIntervalMinutes: number; // How often to retry failed downloads
  maxRetries: number; // Max retries before giving up (0 = unlimited)

  // Source filtering
  onlyInProgress: boolean; // Only download shows in progress
  includeWatchlist: boolean; // Include watchlist shows

  // Quality settings
  qualityPriority: QualityPriority;
  minSeeders: number;
  maxFileSizeGB: number; // 0 = no limit
  preferHDR: boolean;
  preferDolbyVision: boolean;
  preferAtmos: boolean;
  qualityPreferences: UserPreferences;

  // Language settings
  preferredAudioLanguages: string[]; // ISO codes: en, fr, de, etc.
  requiredAudioLanguages: string[]; // Must have at least one
  preferredSubtitleLanguages: string[];
  downloadSubtitles: boolean; // Auto-download subtitles from OpenSubtitles

  // Timing settings
  delayHoursAfterAir: number; // Wait for better releases
  autoSelectBest: boolean; // Auto-select best torrent

  // Streaming integration
  checkStreamingFirst: boolean; // Check if available on streaming before downloading
  downloadIfDelayed: boolean; // Download if streaming has delay
  downloadIfAdsOnly: boolean; // Download if only ad-supported tier
  downloadIfLowQuality: boolean; // Download if streaming quality is lower
  downloadIfMissingLanguage: boolean; // Download if missing preferred language
  maxAcceptableDelayDays: number; // Max streaming delay to accept

  // Show management
  excludedShows: string[];

  // Notifications
  notifications: {
    onNewEpisode: boolean;
    onDownloadStart: boolean;
    onDownloadComplete: boolean;
    onRetry: boolean;
    onError: boolean;
  };
}

export interface PendingDownload {
  id: string;
  traktId: string;
  showTitle: string;
  season: number;
  episode: number;
  episodeTitle: string;
  airDate: string;
  eligibleAt: string;
  status: 'pending' | 'waiting' | 'searching' | 'downloading' | 'completed' | 'failed' | 'skipped';
  torrent?: TorrentSearchResult;
  error?: string;
  retryCount: number;
  nextRetryAt?: string;
  streamingCheck?: AvailabilityRecommendation;
  downloadReason?: DownloadReason[];
  createdAt: string;
  updatedAt: string;
}

export interface AutoDownloadStats {
  totalDownloaded: number;
  totalFailed: number;
  totalSkipped: number;
  totalRetries: number;
  lastCheck: string | null;
  nextCheck: string | null;
  pendingCount: number;
  waitingCount: number;
  activeDownloads: number;
}

const DEFAULT_CONFIG: AutoDownloadConfig = {
  enabled: false,

  // Schedule - check every hour, retry every hour
  checkIntervalMinutes: 60,
  retryIntervalMinutes: 60,
  maxRetries: 0, // Unlimited retries

  // Sources
  onlyInProgress: false,
  includeWatchlist: true,

  // Quality - highest available by default
  qualityPriority: 'highest',
  minSeeders: 5,
  maxFileSizeGB: 0, // No limit for highest quality
  preferHDR: true,
  preferDolbyVision: true,
  preferAtmos: true,
  qualityPreferences: {
    preferredQuality: '4K',
    preferredCodec: 'x265',
    preferredReleaseGroups: ['FLUX', 'NTb', 'SPARKS', 'RARBG'],
    avoidReleaseGroups: ['YIFY', 'eztv'],
    preferHDR: true,
    preferDolbyAtmos: true,
  },

  // Language - English by default
  preferredAudioLanguages: ['en'],
  requiredAudioLanguages: ['en'],
  preferredSubtitleLanguages: ['en'],
  downloadSubtitles: true,

  // Timing
  delayHoursAfterAir: 2, // Wait 2 hours for better releases
  autoSelectBest: true,

  // Streaming integration - enabled by default
  checkStreamingFirst: true,
  downloadIfDelayed: true,
  downloadIfAdsOnly: true,
  downloadIfLowQuality: true,
  downloadIfMissingLanguage: true,
  maxAcceptableDelayDays: 0, // No delay accepted

  // Show management
  excludedShows: [],

  // All notifications enabled
  notifications: {
    onNewEpisode: true,
    onDownloadStart: true,
    onDownloadComplete: true,
    onRetry: true,
    onError: true,
  },
};

class AutoDownloadService {
  private config: AutoDownloadConfig = DEFAULT_CONFIG;
  private pendingDownloads: Map<string, PendingDownload> = new Map();
  private checkInterval: ReturnType<typeof setInterval> | null = null;
  private retryInterval: ReturnType<typeof setInterval> | null = null;
  private stats: AutoDownloadStats = {
    totalDownloaded: 0,
    totalFailed: 0,
    totalSkipped: 0,
    totalRetries: 0,
    lastCheck: null,
    nextCheck: null,
    pendingCount: 0,
    waitingCount: 0,
    activeDownloads: 0,
  };
  private syncBridgeUrl: string = '';
  private notificationCallback: ((message: string, type: 'info' | 'success' | 'error') => void) | null = null;

  /**
   * Initialize the service
   */
  initialize(syncBridgeUrl: string): void {
    this.syncBridgeUrl = syncBridgeUrl;
    this.loadConfig();
    this.loadPendingDownloads();
    this.loadStats();

    // Load streaming preferences
    streamingAvailabilityService.loadPreferences();

    if (this.config.enabled) {
      this.start();
    }
  }

  /**
   * Set notification callback
   */
  setNotificationCallback(callback: (message: string, type: 'info' | 'success' | 'error') => void): void {
    this.notificationCallback = callback;
  }

  /**
   * Get current configuration
   */
  getConfig(): AutoDownloadConfig {
    return { ...this.config };
  }

  /**
   * Update configuration
   */
  updateConfig(updates: Partial<AutoDownloadConfig>): void {
    this.config = { ...this.config, ...updates };
    this.saveConfig();

    // Restart if enabled state changed
    if ('enabled' in updates) {
      if (updates.enabled) {
        this.start();
      } else {
        this.stop();
      }
    }

    // Update intervals if changed
    if (('checkIntervalMinutes' in updates || 'retryIntervalMinutes' in updates) && this.config.enabled) {
      this.stop();
      this.start();
    }
  }

  /**
   * Start the auto-download service
   */
  start(): void {
    if (this.checkInterval) {
      return; // Already running
    }

    console.log('[AutoDownload] Starting service...');
    this.notify('Auto-download service started', 'info');

    // Run first check immediately
    this.checkForNewEpisodes();

    // Schedule periodic checks for new episodes
    const checkMs = this.config.checkIntervalMinutes * 60 * 1000;
    this.checkInterval = setInterval(() => {
      this.checkForNewEpisodes();
    }, checkMs);

    // Schedule retry checks
    const retryMs = this.config.retryIntervalMinutes * 60 * 1000;
    this.retryInterval = setInterval(() => {
      this.processRetries();
    }, retryMs);

    this.updateNextCheckTime();
  }

  /**
   * Stop the auto-download service
   */
  stop(): void {
    if (this.checkInterval) {
      clearInterval(this.checkInterval);
      this.checkInterval = null;
    }
    if (this.retryInterval) {
      clearInterval(this.retryInterval);
      this.retryInterval = null;
    }
    console.log('[AutoDownload] Service stopped');
    this.notify('Auto-download service stopped', 'info');
    this.stats.nextCheck = null;
    this.saveStats();
  }

  /**
   * Check if service is running
   */
  isRunning(): boolean {
    return this.checkInterval !== null;
  }

  /**
   * Get statistics
   */
  getStats(): AutoDownloadStats {
    return {
      ...this.stats,
      pendingCount: Array.from(this.pendingDownloads.values())
        .filter(d => d.status === 'pending' || d.status === 'searching').length,
      waitingCount: Array.from(this.pendingDownloads.values())
        .filter(d => d.status === 'waiting').length,
      activeDownloads: Array.from(this.pendingDownloads.values())
        .filter(d => d.status === 'downloading').length,
    };
  }

  /**
   * Get pending downloads
   */
  getPendingDownloads(): PendingDownload[] {
    return Array.from(this.pendingDownloads.values())
      .sort((a, b) => new Date(a.airDate).getTime() - new Date(b.airDate).getTime());
  }

  /**
   * Manually trigger a check
   */
  async triggerCheck(): Promise<void> {
    await this.checkForNewEpisodes();
    await this.processRetries();
  }

  /**
   * Skip a pending download
   */
  skipDownload(id: string): void {
    const download = this.pendingDownloads.get(id);
    if (download) {
      download.status = 'skipped';
      download.updatedAt = new Date().toISOString();
      this.stats.totalSkipped++;
      this.savePendingDownloads();
      this.saveStats();
    }
  }

  /**
   * Retry a download immediately
   */
  async retryDownload(id: string): Promise<void> {
    const download = this.pendingDownloads.get(id);
    if (download && (download.status === 'failed' || download.status === 'waiting' || download.status === 'skipped')) {
      download.status = 'pending';
      download.error = undefined;
      download.retryCount = 0;
      download.updatedAt = new Date().toISOString();
      this.savePendingDownloads();
      await this.processDownload(download);
    }
  }

  /**
   * Add show to exclusion list
   */
  excludeShow(showTitle: string): void {
    if (!this.config.excludedShows.includes(showTitle)) {
      this.config.excludedShows.push(showTitle);
      this.saveConfig();
    }
  }

  /**
   * Remove show from exclusion list
   */
  includeShow(showTitle: string): void {
    this.config.excludedShows = this.config.excludedShows.filter(s => s !== showTitle);
    this.saveConfig();
  }

  // ================================================================
  // PRIVATE METHODS
  // ================================================================

  /**
   * Check Trakt for new episodes
   */
  private async checkForNewEpisodes(): Promise<void> {
    console.log('[AutoDownload] Checking for new episodes...');
    this.stats.lastCheck = new Date().toISOString();

    try {
      // Get new releases from Trakt via Smart Hub
      const releases = await smartHubService.getNewReleases({
        days: 3,
        includeWatchlist: this.config.includeWatchlist,
        includeProgress: true,
      });

      // Filter to only episodes (not movies)
      const newEpisodes = releases.filter(r =>
        r.type === 'episode' &&
        r.trakt.episode &&
        !this.config.excludedShows.includes(r.title)
      );

      console.log(`[AutoDownload] Found ${newEpisodes.length} new episodes`);

      for (const episode of newEpisodes) {
        const id = `${episode.trakt.show?.ids.trakt}-S${episode.trakt.episode?.season}E${episode.trakt.episode?.number}`;

        // Skip if already processed
        if (this.pendingDownloads.has(id)) {
          continue;
        }

        // Calculate eligibility time
        const airDate = new Date(episode.releaseDate);
        const eligibleAt = new Date(airDate.getTime() + this.config.delayHoursAfterAir * 60 * 60 * 1000);

        // Check streaming availability first
        let streamingCheck: AvailabilityRecommendation | undefined;
        let shouldDownload = true;

        if (this.config.checkStreamingFirst) {
          streamingCheck = await streamingAvailabilityService.shouldAutoDownload(
            episode.trakt.show?.ids.trakt.toString() || '',
            episode.title,
            'show',
            episode.trakt.episode?.season,
            episode.trakt.episode?.number
          );

          // Determine if we should download based on streaming check
          shouldDownload = this.shouldDownloadBasedOnStreaming(streamingCheck);
        }

        if (!shouldDownload) {
          console.log(`[AutoDownload] Skipping "${episode.title}" - available on streaming: ${streamingCheck?.explanation}`);
          continue;
        }

        const pending: PendingDownload = {
          id,
          traktId: episode.trakt.show?.ids.trakt.toString() || '',
          showTitle: episode.title,
          season: episode.trakt.episode?.season || 0,
          episode: episode.trakt.episode?.number || 0,
          episodeTitle: episode.trakt.episode?.title || '',
          airDate: episode.releaseDate,
          eligibleAt: eligibleAt.toISOString(),
          status: 'pending',
          retryCount: 0,
          streamingCheck,
          downloadReason: streamingCheck?.reasons,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        };

        this.pendingDownloads.set(id, pending);

        if (this.config.notifications.onNewEpisode) {
          const reason = streamingCheck?.reasons[0]
            ? ` (${this.getReasonText(streamingCheck.reasons[0])})`
            : '';
          this.notify(
            `New episode: ${episode.title} S${pending.season}E${pending.episode}${reason}`,
            'info'
          );
        }
      }

      this.savePendingDownloads();

      // Process eligible downloads
      await this.processEligibleDownloads();

    } catch (error) {
      console.error('[AutoDownload] Check failed:', error);
      if (this.config.notifications.onError) {
        this.notify('Failed to check for new episodes', 'error');
      }
    }

    this.updateNextCheckTime();
    this.saveStats();
  }

  /**
   * Determine if we should download based on streaming availability
   */
  private shouldDownloadBasedOnStreaming(check: AvailabilityRecommendation): boolean {
    // If streaming service says to download, trust it
    if (check.shouldDownload) {
      // But verify against our specific preferences
      for (const reason of check.reasons) {
        switch (reason) {
          case 'delayed_release':
            if (!this.config.downloadIfDelayed) return false;
            break;
          case 'has_ads':
            if (!this.config.downloadIfAdsOnly) return false;
            break;
          case 'low_quality':
            if (!this.config.downloadIfLowQuality) return false;
            break;
          case 'missing_language':
            if (!this.config.downloadIfMissingLanguage) return false;
            break;
        }
      }
      return true;
    }

    // Streaming is available and acceptable
    return false;
  }

  /**
   * Get human-readable reason text
   */
  private getReasonText(reason: DownloadReason): string {
    const texts: Record<DownloadReason, string> = {
      'not_available': 'not on streaming',
      'delayed_release': 'delayed on streaming',
      'requires_payment': 'requires payment',
      'has_ads': 'ads only',
      'low_quality': 'low quality',
      'missing_language': 'missing language',
      'partial_availability': 'partial availability',
      'expiring_soon': 'expiring soon',
      'extended_version': 'no extended version',
      'geo_blocked': 'geo-blocked',
    };
    return texts[reason] || reason;
  }

  /**
   * Process downloads that are eligible (past delay time)
   */
  private async processEligibleDownloads(): Promise<void> {
    const now = new Date();
    const eligible = Array.from(this.pendingDownloads.values())
      .filter(d =>
        d.status === 'pending' &&
        new Date(d.eligibleAt) <= now
      );

    console.log(`[AutoDownload] Processing ${eligible.length} eligible downloads`);

    for (const download of eligible) {
      await this.processDownload(download);
    }
  }

  /**
   * Process retries for waiting downloads
   */
  private async processRetries(): Promise<void> {
    const now = new Date();
    const retryable = Array.from(this.pendingDownloads.values())
      .filter(d =>
        d.status === 'waiting' &&
        d.nextRetryAt &&
        new Date(d.nextRetryAt) <= now &&
        (this.config.maxRetries === 0 || d.retryCount < this.config.maxRetries)
      );

    if (retryable.length === 0) return;

    console.log(`[AutoDownload] Processing ${retryable.length} retries`);

    for (const download of retryable) {
      download.status = 'pending';
      download.retryCount++;
      this.stats.totalRetries++;

      if (this.config.notifications.onRetry) {
        this.notify(
          `Retry #${download.retryCount}: ${download.showTitle} S${download.season}E${download.episode}`,
          'info'
        );
      }

      await this.processDownload(download);
    }

    this.saveStats();
  }

  /**
   * Process a single download with AI-powered release research
   */
  private async processDownload(download: PendingDownload): Promise<void> {
    console.log(`[AutoDownload] Processing: ${download.showTitle} S${download.season}E${download.episode}`);

    download.status = 'searching';
    download.updatedAt = new Date().toISOString();
    this.savePendingDownloads();

    try {
      // Build search query with language preferences
      const sNum = String(download.season).padStart(2, '0');
      const eNum = String(download.episode).padStart(2, '0');
      let query = `${download.showTitle} S${sNum}E${eNum}`;

      // Add language hint if not English
      if (this.config.preferredAudioLanguages[0] !== 'en') {
        query += ` ${this.config.preferredAudioLanguages[0].toUpperCase()}`;
      }

      // Search for torrents using AI-optimized search
      const searchResult = await aiTorrentSearchService.searchFromVoice(query);

      if (searchResult.torrents.length === 0) {
        throw new Error('NO_RESULTS');
      }

      // AI-POWERED RELEASE RESEARCH
      console.log(`[AutoDownload] Researching ${searchResult.torrents.length} releases...`);
      const researchResult = await releaseResearchService.researchReleases(
        searchResult.torrents,
        query,
        {
          preferQuality: this.config.qualityPriority === 'highest' || this.config.qualityPriority === '4K',
          preferSpeed: true,
          preferSafety: true,
          maxFileSizeGB: this.config.maxFileSizeGB > 0 ? this.config.maxFileSizeGB : undefined,
        }
      );

      console.log(`[AutoDownload] Research complete. Notes: ${researchResult.researchNotes}`);

      // Filter by language if specified
      let candidates = researchResult.torrents.filter(analysis => {
        // Check audio language in title
        if (this.config.requiredAudioLanguages.length > 0) {
          const title = analysis.torrent.title.toLowerCase();
          // Allow if title doesn't specify language (assume English) or matches required
          const specifiedLanguage = title.match(/\b(french|german|spanish|italian|russian|multi)\b/i);
          if (specifiedLanguage) {
            const langMap: Record<string, string> = {
              'french': 'fr', 'german': 'de', 'spanish': 'es',
              'italian': 'it', 'russian': 'ru', 'multi': 'multi'
            };
            const lang = langMap[specifiedLanguage[0].toLowerCase()];
            if (lang !== 'multi' && !this.config.requiredAudioLanguages.includes(lang)) {
              return false;
            }
          }
        }
        return true;
      });

      // Filter to safe releases
      const safeReleases = candidates.filter(a =>
        a.recommendation === 'highly_recommended' ||
        a.recommendation === 'recommended' ||
        a.recommendation === 'acceptable'
      );

      if (safeReleases.length === 0) {
        const cautionReleases = candidates.filter(a => a.recommendation === 'caution');
        if (cautionReleases.length > 0) {
          candidates = cautionReleases;
          console.log('[AutoDownload] Only cautionary releases available');
        } else if (candidates.length === 0) {
          throw new Error('NO_SAFE_RELEASES');
        }
      } else {
        candidates = safeReleases;
      }

      // Apply additional filters
      candidates = candidates.filter(a => a.torrent.seeders >= this.config.minSeeders);

      if (this.config.maxFileSizeGB > 0) {
        const maxBytes = this.config.maxFileSizeGB * 1024 * 1024 * 1024;
        candidates = candidates.filter(a => a.torrent.size <= maxBytes);
      }

      if (candidates.length === 0) {
        throw new Error('NO_MATCHING_QUALITY');
      }

      // Select best torrent
      const bestAnalysis = candidates[0];
      const bestTorrent = bestAnalysis.torrent;

      console.log(`[AutoDownload] Selected: "${bestTorrent.title}"`);
      console.log(`[AutoDownload] Score: ${bestAnalysis.score}/100, Recommendation: ${bestAnalysis.recommendation}`);

      // Start download
      download.torrent = bestTorrent;
      download.status = 'downloading';
      download.updatedAt = new Date().toISOString();
      this.savePendingDownloads();

      if (this.config.notifications.onDownloadStart) {
        const groupInfo = bestAnalysis.releaseGroupInfo?.name || 'Unknown';
        this.notify(
          `Downloading: ${download.showTitle} S${download.season}E${download.episode} (${groupInfo})`,
          'info'
        );
      }

      const result = await smartHubService.downloadTorrent(bestTorrent);

      if (result.success) {
        download.status = 'completed';
        this.stats.totalDownloaded++;

        if (this.config.notifications.onDownloadComplete) {
          this.notify(
            `Download started: ${download.showTitle} S${download.season}E${download.episode}`,
            'success'
          );
        }

        // Download subtitles if enabled
        if (this.config.downloadSubtitles) {
          await this.downloadSubtitles(download);
        }
      } else {
        throw new Error(result.message);
      }

    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : 'Unknown error';

      // Determine if we should retry
      const shouldRetry = errorMsg === 'NO_RESULTS' ||
                          errorMsg === 'NO_SAFE_RELEASES' ||
                          errorMsg === 'NO_MATCHING_QUALITY';

      if (shouldRetry && (this.config.maxRetries === 0 || download.retryCount < this.config.maxRetries)) {
        // Schedule for retry
        download.status = 'waiting';
        download.error = errorMsg === 'NO_RESULTS'
          ? 'No torrents available yet - will retry'
          : errorMsg === 'NO_MATCHING_QUALITY'
          ? 'No torrents matching quality criteria - will retry'
          : 'No safe releases found - will retry';
        download.nextRetryAt = new Date(Date.now() + this.config.retryIntervalMinutes * 60 * 1000).toISOString();

        console.log(`[AutoDownload] Scheduled for retry at ${download.nextRetryAt}`);
      } else {
        // Final failure
        download.status = 'failed';
        download.error = errorMsg;
        this.stats.totalFailed++;

        if (this.config.notifications.onError) {
          this.notify(
            `Download failed: ${download.showTitle} - ${errorMsg}`,
            'error'
          );
        }
      }
    }

    download.updatedAt = new Date().toISOString();
    this.savePendingDownloads();
    this.saveStats();
  }

  /**
   * Download subtitles for a show
   */
  private async downloadSubtitles(download: PendingDownload): Promise<void> {
    // Would integrate with OpenSubtitles API
    // For now, just log
    console.log(`[AutoDownload] Would download subtitles for: ${download.showTitle} S${download.season}E${download.episode}`);
    console.log(`[AutoDownload] Languages: ${this.config.preferredSubtitleLanguages.join(', ')}`);
  }

  /**
   * Send notification
   */
  private notify(message: string, type: 'info' | 'success' | 'error'): void {
    if (this.notificationCallback) {
      this.notificationCallback(message, type);
    }
    console.log(`[AutoDownload] ${type.toUpperCase()}: ${message}`);

    // Also send to sync bridge for cross-device notifications
    this.sendCrossDeviceNotification(message, type);
  }

  /**
   * Send notification to other devices via sync bridge
   */
  private async sendCrossDeviceNotification(message: string, type: string): Promise<void> {
    try {
      const deviceToken = localStorage.getItem('deviceToken');
      if (!deviceToken || !this.syncBridgeUrl) return;

      await fetch(`${this.syncBridgeUrl}/sync/notifications`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Device-Token': deviceToken,
        },
        body: JSON.stringify({
          type: 'auto-download',
          message,
          level: type,
          timestamp: new Date().toISOString(),
        }),
      });
    } catch {
      // Ignore notification failures
    }
  }

  /**
   * Update next check time
   */
  private updateNextCheckTime(): void {
    if (this.config.enabled) {
      const next = new Date(Date.now() + this.config.checkIntervalMinutes * 60 * 1000);
      this.stats.nextCheck = next.toISOString();
    } else {
      this.stats.nextCheck = null;
    }
  }

  /**
   * Export configuration for sync to other devices
   */
  exportConfig(): string {
    return JSON.stringify({
      config: this.config,
      stats: this.stats,
      pendingDownloads: Array.from(this.pendingDownloads.entries()),
      version: 2,
      exportedAt: new Date().toISOString(),
    });
  }

  /**
   * Import configuration from another device
   */
  importConfig(configJson: string): void {
    try {
      const data = JSON.parse(configJson);
      if (data.version >= 1) {
        this.config = { ...DEFAULT_CONFIG, ...data.config };
        this.stats = { ...this.stats, ...data.stats };
        if (data.pendingDownloads) {
          this.pendingDownloads = new Map(data.pendingDownloads);
        }
        this.saveConfig();
        this.saveStats();
        this.savePendingDownloads();
      }
    } catch (error) {
      console.error('[AutoDownload] Failed to import config:', error);
      throw new Error('Invalid configuration format');
    }
  }

  // Persistence methods

  private loadConfig(): void {
    try {
      const saved = localStorage.getItem('thea_autodownload_config');
      if (saved) {
        this.config = { ...DEFAULT_CONFIG, ...JSON.parse(saved) };
      }
    } catch (error) {
      console.error('[AutoDownload] Failed to load config:', error);
    }
  }

  private saveConfig(): void {
    try {
      localStorage.setItem('thea_autodownload_config', JSON.stringify(this.config));
    } catch (error) {
      console.error('[AutoDownload] Failed to save config:', error);
    }
  }

  private loadPendingDownloads(): void {
    try {
      const saved = localStorage.getItem('thea_autodownload_pending');
      if (saved) {
        const arr: [string, PendingDownload][] = JSON.parse(saved);
        this.pendingDownloads = new Map(arr);
      }
    } catch (error) {
      console.error('[AutoDownload] Failed to load pending downloads:', error);
    }
  }

  private savePendingDownloads(): void {
    try {
      const arr = Array.from(this.pendingDownloads.entries());
      localStorage.setItem('thea_autodownload_pending', JSON.stringify(arr));
    } catch (error) {
      console.error('[AutoDownload] Failed to save pending downloads:', error);
    }
  }

  private loadStats(): void {
    try {
      const saved = localStorage.getItem('thea_autodownload_stats');
      if (saved) {
        this.stats = { ...this.stats, ...JSON.parse(saved) };
      }
    } catch (error) {
      console.error('[AutoDownload] Failed to load stats:', error);
    }
  }

  private saveStats(): void {
    try {
      localStorage.setItem('thea_autodownload_stats', JSON.stringify(this.stats));
    } catch (error) {
      console.error('[AutoDownload] Failed to save stats:', error);
    }
  }
}

// Singleton instance
export const autoDownloadService = new AutoDownloadService();
