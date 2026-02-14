/**
 * Episode Monitor Service
 *
 * Proactive, autonomous monitoring of your TV shows:
 * 1. Monitors Trakt calendar for new episodes
 * 2. Checks Plex library to see if you already have it
 * 3. Checks streaming services for availability
 * 4. Auto-downloads if not available elsewhere
 * 5. Notifies you when content is ready
 *
 * This is the brain that makes Thea truly autonomous.
 */

import { traktCalendarService, TraktCalendarItem } from '../trakt/TraktCalendarService';
import { plexService } from '../plex/PlexService';
import { watchAvailabilityService } from '../streaming/WatchAvailabilityService';
import { torrentQualityService, TorrentInfo } from '../torrent/TorrentQualityService';
import { releaseIntelligenceService, DownloadDecision } from './ReleaseIntelligenceService';
import { secureConfigService } from '../config/SecureConfigService';
import { SYNC_BRIDGE_URL } from '../../config/constants';

export interface MonitoredEpisode {
  show: {
    title: string;
    tmdbId?: number;
    tvdbId?: number;
    imdbId?: string;
  };
  episode: {
    season: number;
    number: number;
    title: string;
    airDate: string;
  };
  status: 'pending' | 'checking' | 'available_plex' | 'available_streaming' | 'downloading' | 'downloaded' | 'failed';
  source?: 'plex' | 'streaming' | 'download';
  streamingService?: string;
  downloadProgress?: number;
  error?: string;
  lastChecked: number;
}

export interface MonitorConfig {
  enabled: boolean;
  checkIntervalMinutes: number;
  autoDownload: boolean;
  notifyOnAvailable: boolean;
  notifyOnDownloaded: boolean;
  // Only download if not available on streaming
  preferStreaming: boolean;
  // Use AI-powered timing instead of fixed delay
  useIntelligentTiming: boolean;
  // Fallback: Wait N hours after air time before downloading (if AI disabled)
  downloadDelayHours: number;
  // Minimum quality for downloads
  minQuality: '720p' | '1080p' | '2160p';
}

const DEFAULT_CONFIG: MonitorConfig = {
  enabled: true,
  checkIntervalMinutes: 30,
  autoDownload: true,
  notifyOnAvailable: true,
  notifyOnDownloaded: true,
  preferStreaming: true,
  useIntelligentTiming: true, // AI-powered timing enabled by default
  downloadDelayHours: 2, // Fallback: Wait 2 hours if AI disabled
  minQuality: '1080p',
};

const STORAGE_KEY = 'thea_episode_monitor';
const CONFIG_KEY = 'thea_episode_monitor_config';

class EpisodeMonitorService {
  private static instance: EpisodeMonitorService;
  private config: MonitorConfig;
  private monitoredEpisodes: Map<string, MonitoredEpisode> = new Map();
  private checkInterval: ReturnType<typeof setInterval> | null = null;
  private isRunning = false;

  private constructor() {
    this.config = this.loadConfig();
    this.loadState();

    if (this.config.enabled) {
      this.start();
    }
  }

  static getInstance(): EpisodeMonitorService {
    if (!EpisodeMonitorService.instance) {
      EpisodeMonitorService.instance = new EpisodeMonitorService();
    }
    return EpisodeMonitorService.instance;
  }

  // ============================================================
  // CONFIGURATION
  // ============================================================

  private loadConfig(): MonitorConfig {
    try {
      const saved = localStorage.getItem(CONFIG_KEY);
      if (saved) {
        return { ...DEFAULT_CONFIG, ...JSON.parse(saved) };
      }
    } catch {
      // Ignore
    }
    return { ...DEFAULT_CONFIG };
  }

  private saveConfig(): void {
    localStorage.setItem(CONFIG_KEY, JSON.stringify(this.config));
  }

  private loadState(): void {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        const data = JSON.parse(saved);
        this.monitoredEpisodes = new Map(Object.entries(data));
      }
    } catch {
      // Ignore
    }
  }

  private saveState(): void {
    const data = Object.fromEntries(this.monitoredEpisodes);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  }

  getConfig(): MonitorConfig {
    return { ...this.config };
  }

  updateConfig(updates: Partial<MonitorConfig>): void {
    this.config = { ...this.config, ...updates };
    this.saveConfig();

    // Restart if enabled state changed
    if (updates.enabled !== undefined) {
      if (updates.enabled) {
        this.start();
      } else {
        this.stop();
      }
    }
  }

  // ============================================================
  // LIFECYCLE
  // ============================================================

  start(): void {
    if (this.isRunning) return;

    console.log('EpisodeMonitor: Starting...');
    this.isRunning = true;

    // Initial check
    this.runCheck();

    // Schedule periodic checks
    this.checkInterval = setInterval(
      () => this.runCheck(),
      this.config.checkIntervalMinutes * 60 * 1000
    );
  }

  stop(): void {
    if (!this.isRunning) return;

    console.log('EpisodeMonitor: Stopping...');
    this.isRunning = false;

    if (this.checkInterval) {
      clearInterval(this.checkInterval);
      this.checkInterval = null;
    }
  }

  isActive(): boolean {
    return this.isRunning;
  }

  // ============================================================
  // MAIN CHECK LOOP
  // ============================================================

  async runCheck(): Promise<void> {
    console.log('EpisodeMonitor: Running check...');

    try {
      // 1. Get upcoming episodes from Trakt
      const upcoming = await traktCalendarService.getUpcomingContent();

      // 2. Also check recently aired episodes (might have missed them)
      const recent = await traktCalendarService.getRecentlyAired(3);

      // Combine and deduplicate
      const allEpisodes = [...upcoming.airingToday, ...recent];
      const uniqueEpisodes = this.deduplicateEpisodes(allEpisodes);

      console.log(`EpisodeMonitor: Found ${uniqueEpisodes.length} episodes to check`);

      // 3. Check each episode
      for (const item of uniqueEpisodes) {
        await this.checkEpisode(item);
      }

      this.saveState();

    } catch (error) {
      console.error('EpisodeMonitor: Check failed', error);
    }
  }

  private deduplicateEpisodes(episodes: TraktCalendarItem[]): TraktCalendarItem[] {
    const seen = new Set<string>();
    return episodes.filter(ep => {
      const key = `${ep.show.ids.trakt}-s${ep.episode.season}e${ep.episode.number}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }

  private getEpisodeKey(item: TraktCalendarItem): string {
    return `${item.show.ids.trakt}-s${item.episode.season}e${item.episode.number}`;
  }

  // ============================================================
  // EPISODE CHECKING
  // ============================================================

  private async checkEpisode(item: TraktCalendarItem): Promise<void> {
    const key = this.getEpisodeKey(item);

    // Skip if already processed successfully
    const existing = this.monitoredEpisodes.get(key);
    if (existing && ['available_plex', 'available_streaming', 'downloaded'].includes(existing.status)) {
      return;
    }

    // Check if episode has actually aired
    const airDate = new Date(item.first_aired);
    const now = new Date();
    if (airDate > now) {
      // Not aired yet - just track it
      this.updateEpisodeStatus(item, 'pending');
      return;
    }

    this.updateEpisodeStatus(item, 'checking');

    // 1. Check Plex first
    const plexResult = await plexService.checkEpisode({
      showTmdbId: item.show.ids.tmdb,
      showTvdbId: item.show.ids.tvdb,
      showTitle: item.show.title,
      season: item.episode.season,
      episode: item.episode.number,
    });

    if (plexResult.found) {
      this.updateEpisodeStatus(item, 'available_plex', { source: 'plex' });
      await this.notify(`${item.show.title} S${item.episode.season}E${item.episode.number} is ready on Plex!`);
      return;
    }

    // 2. Check streaming availability
    if (this.config.preferStreaming && item.show.ids.tmdb) {
      const availability = await watchAvailabilityService.checkAvailability(
        item.show.ids.tmdb,
        'tv',
        item.show.title
      );

      if (availability.bestOption.action === 'stream') {
        this.updateEpisodeStatus(item, 'available_streaming', {
          source: 'streaming',
          streamingService: availability.bestOption.details.provider?.providerName,
        });
        await this.notify(
          `${item.show.title} S${item.episode.season}E${item.episode.number} is available on ${availability.bestOption.details.provider?.providerName}!`
        );
        return;
      }
    }

    // 3. Auto-download if enabled
    if (this.config.autoDownload) {
      await this.handleDownloadDecision(item);
    }
  }

  /**
   * Use intelligent timing to decide when to download
   */
  private async handleDownloadDecision(item: TraktCalendarItem): Promise<void> {
    const airDate = new Date(item.first_aired);
    const now = new Date();
    const hoursSinceAir = (now.getTime() - airDate.getTime()) / (1000 * 60 * 60);

    if (this.config.useIntelligentTiming) {
      // AI-powered timing: Get download decision
      const decision = await releaseIntelligenceService.makeDownloadDecision({
        showId: String(item.show.ids.trakt),
        showTitle: item.show.title,
        season: item.episode.season,
        episode: item.episode.number,
        airTime: airDate,
        network: undefined, // Could be enhanced to get network from Trakt
      });

      console.log(`EpisodeMonitor: Decision for ${item.show.title} S${item.episode.season}E${item.episode.number}:`, {
        shouldDownload: decision.shouldDownload,
        reason: decision.reason,
        confidence: decision.confidence,
        recommendedWait: decision.recommendedWaitMinutes,
      });

      if (decision.shouldDownload) {
        await this.downloadEpisode(item);
      } else if (decision.recommendedWaitMinutes > 0) {
        // Schedule a re-check
        console.log(`EpisodeMonitor: Will re-check in ${decision.recommendedWaitMinutes} minutes`);
      }
    } else {
      // Fallback: Use fixed delay
      const shouldDownload = hoursSinceAir >= this.config.downloadDelayHours;
      if (shouldDownload) {
        await this.downloadEpisode(item);
      }
    }
  }

  private updateEpisodeStatus(
    item: TraktCalendarItem,
    status: MonitoredEpisode['status'],
    extra?: Partial<MonitoredEpisode>
  ): void {
    const key = this.getEpisodeKey(item);

    const episode: MonitoredEpisode = {
      show: {
        title: item.show.title,
        tmdbId: item.show.ids.tmdb,
        tvdbId: item.show.ids.tvdb,
        imdbId: item.show.ids.imdb,
      },
      episode: {
        season: item.episode.season,
        number: item.episode.number,
        title: item.episode.title,
        airDate: item.first_aired,
      },
      status,
      lastChecked: Date.now(),
      ...extra,
    };

    this.monitoredEpisodes.set(key, episode);
  }

  // ============================================================
  // DOWNLOAD
  // ============================================================

  private async downloadEpisode(item: TraktCalendarItem): Promise<void> {
    const key = this.getEpisodeKey(item);

    try {
      this.updateEpisodeStatus(item, 'downloading');

      // Search for torrent
      const searchQuery = `${item.show.title} S${String(item.episode.season).padStart(2, '0')}E${String(item.episode.number).padStart(2, '0')}`;

      const syncConfig = secureConfigService.getSyncBridge();
      if (!syncConfig.url) {
        throw new Error('Sync bridge not configured');
      }

      // Search via Prowlarr
      const searchResponse = await fetch(`${syncConfig.url}/torrents/search?q=${encodeURIComponent(searchQuery)}&category=tv`, {
        headers: {
          'X-Device-Token': syncConfig.deviceToken || '',
        },
      });

      if (!searchResponse.ok) {
        throw new Error('Search failed');
      }

      const searchData = await searchResponse.json() as { results: Array<{
        title: string;
        size: number;
        seeders: number;
        magnetUrl?: string;
        downloadUrl?: string;
      }> };

      if (!searchData.results || searchData.results.length === 0) {
        throw new Error('No torrents found');
      }

      // Parse and score torrents
      const torrents: TorrentInfo[] = searchData.results.map(r => ({
        ...torrentQualityService.parseTorrentTitle(r.title),
        title: r.title,
        size: r.size,
        seeders: r.seeders,
      }));

      // Select best quality
      const best = torrentQualityService.selectBest(torrents);
      if (!best || best.score < 0) {
        throw new Error('No acceptable quality torrents found');
      }

      const selectedTorrent = searchData.results.find(r => r.title === best.torrent.title);
      if (!selectedTorrent) {
        throw new Error('Selected torrent not found');
      }

      // Download via qBittorrent
      const downloadResponse = await fetch(`${syncConfig.url}/torrents/download`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Device-Token': syncConfig.deviceToken || '',
        },
        body: JSON.stringify({
          magnetUrl: selectedTorrent.magnetUrl,
          downloadUrl: selectedTorrent.downloadUrl,
          title: selectedTorrent.title,
          category: 'tv',
        }),
      });

      if (!downloadResponse.ok) {
        throw new Error('Download failed');
      }

      this.updateEpisodeStatus(item, 'downloaded', { source: 'download' });

      // Record this successful download to improve AI timing
      if (this.config.useIntelligentTiming) {
        releaseIntelligenceService.recordRelease({
          showId: String(item.show.ids.trakt),
          showTitle: item.show.title,
          airTime: new Date(item.first_aired),
          downloadTime: new Date(),
          quality: (best.torrent.resolution as '720p' | '1080p' | '2160p') || '1080p',
          network: undefined, // Could be enhanced
        });
      }

      if (this.config.notifyOnDownloaded) {
        await this.notify(
          `Downloading: ${item.show.title} S${item.episode.season}E${item.episode.number}\n` +
          `Quality: ${best.reasons.slice(0, 3).join(', ')}`
        );
      }

    } catch (error) {
      console.error(`Failed to download ${key}:`, error);
      this.updateEpisodeStatus(item, 'failed', {
        error: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  private async notify(message: string): Promise<void> {
    // Dispatch event for UI
    window.dispatchEvent(new CustomEvent('thea-notification', {
      detail: { message, type: 'episode-monitor' },
    }));

    // Send to sync-bridge for Mac/iPhone notification
    try {
      const syncConfig = secureConfigService.getSyncBridge();
      if (syncConfig.url && syncConfig.deviceToken) {
        await fetch(`${syncConfig.url}/notifications/push`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Device-Token': syncConfig.deviceToken,
          },
          body: JSON.stringify({
            type: 'episode_available',
            title: 'New Episode Available',
            message,
            timestamp: Date.now(),
          }),
        });
      }
    } catch (error) {
      console.error('Failed to send notification:', error);
    }
  }

  // ============================================================
  // PUBLIC API
  // ============================================================

  getMonitoredEpisodes(): MonitoredEpisode[] {
    return Array.from(this.monitoredEpisodes.values())
      .sort((a, b) => new Date(b.episode.airDate).getTime() - new Date(a.episode.airDate).getTime());
  }

  getStatus(): {
    running: boolean;
    episodeCount: number;
    pendingCount: number;
    downloadingCount: number;
    lastCheck: number | null;
  } {
    const episodes = Array.from(this.monitoredEpisodes.values());
    const lastChecked = episodes.reduce((max, ep) => Math.max(max, ep.lastChecked), 0);

    return {
      running: this.isRunning,
      episodeCount: episodes.length,
      pendingCount: episodes.filter(e => e.status === 'pending' || e.status === 'checking').length,
      downloadingCount: episodes.filter(e => e.status === 'downloading').length,
      lastCheck: lastChecked || null,
    };
  }

  /**
   * Manually trigger a check
   */
  async forceCheck(): Promise<void> {
    await this.runCheck();
  }

  /**
   * Clear all monitored episodes
   */
  clearHistory(): void {
    this.monitoredEpisodes.clear();
    this.saveState();
  }
}

export const episodeMonitorService = EpisodeMonitorService.getInstance();
