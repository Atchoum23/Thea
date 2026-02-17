/**
 * Download Monitor Service
 *
 * Monitors qBittorrent for:
 * - Download progress updates
 * - Completion notifications
 * - Error detection and retry logic
 * - Automatic post-processing triggers
 *
 * Works via Sync Bridge which proxies to qBittorrent API.
 *
 * @see https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-4.1)
 */

import { secureConfigService } from '../config/SecureConfigService';

export interface TorrentInfo {
  hash: string;
  name: string;
  size: number;
  progress: number; // 0-1
  dlspeed: number; // bytes/sec
  eta: number; // seconds, -1 if unknown
  state: TorrentState;
  category: string;
  tags: string;
  addedOn: number; // Unix timestamp
  completedOn: number; // Unix timestamp, 0 if not complete
  savePath: string;
  contentPath: string;
  ratio: number;
  seedingTime: number;
  numSeeds: number;
  numLeechs: number;
}

export type TorrentState =
  | 'error'
  | 'missingFiles'
  | 'uploading'
  | 'pausedUP'
  | 'queuedUP'
  | 'stalledUP'
  | 'checkingUP'
  | 'forcedUP'
  | 'allocating'
  | 'downloading'
  | 'metaDL'
  | 'pausedDL'
  | 'queuedDL'
  | 'stalledDL'
  | 'checkingDL'
  | 'forcedDL'
  | 'checkingResumeData'
  | 'moving'
  | 'unknown';

export interface DownloadProgress {
  hash: string;
  name: string;
  progress: number;
  speed: number;
  eta: string; // formatted
  state: 'downloading' | 'seeding' | 'paused' | 'error' | 'completed' | 'checking';
  category: string;
}

export interface DownloadCompletion {
  hash: string;
  name: string;
  category: string;
  savePath: string;
  size: number;
  completedAt: Date;
  seedingRatio: number;
}

type ProgressListener = (downloads: DownloadProgress[]) => void;
type CompletionListener = (completion: DownloadCompletion) => void;
type ErrorListener = (error: { hash: string; name: string; error: string }) => void;

class DownloadMonitorService {
  private static instance: DownloadMonitorService;

  private progressListeners: Set<ProgressListener> = new Set();
  private completionListeners: Set<CompletionListener> = new Set();
  private errorListeners: Set<ErrorListener> = new Set();

  private previousStates: Map<string, TorrentState> = new Map();
  private knownTorrents: Map<string, TorrentInfo> = new Map();
  private pollInterval: ReturnType<typeof setInterval> | null = null;
  private isPolling = false;

  private constructor() {}

  static getInstance(): DownloadMonitorService {
    if (!DownloadMonitorService.instance) {
      DownloadMonitorService.instance = new DownloadMonitorService();
    }
    return DownloadMonitorService.instance;
  }

  /**
   * Start monitoring downloads
   */
  start(intervalMs: number = 5000): void {
    if (this.pollInterval) return;

    console.log('DownloadMonitorService: Starting download monitoring');
    this.pollInterval = setInterval(() => this.pollDownloads(), intervalMs);
    this.pollDownloads();
  }

  /**
   * Stop monitoring
   */
  stop(): void {
    if (this.pollInterval) {
      clearInterval(this.pollInterval);
      this.pollInterval = null;
      console.log('DownloadMonitorService: Stopped monitoring');
    }
  }

  /**
   * Poll qBittorrent for torrent status
   */
  private async pollDownloads(): Promise<void> {
    if (this.isPolling) return;
    this.isPolling = true;

    try {
      const torrents = await this.fetchTorrents();
      this.processTorrents(torrents);
    } catch (error) {
      console.warn('DownloadMonitorService: Poll failed', error);
    } finally {
      this.isPolling = false;
    }
  }

  /**
   * Fetch torrents from qBittorrent via Sync Bridge
   */
  private async fetchTorrents(): Promise<TorrentInfo[]> {
    const syncConfig = secureConfigService.getSyncBridge();
    if (!syncConfig.url) return [];

    const response = await fetch(`${syncConfig.url}/qbittorrent/torrents/info`, {
      headers: {
        'X-Device-Token': syncConfig.deviceToken,
      },
    });

    if (!response.ok) {
      throw new Error(`qBittorrent API error: ${response.status}`);
    }

    return await response.json() as TorrentInfo[];
  }

  /**
   * Process torrent list and detect state changes
   */
  private processTorrents(torrents: TorrentInfo[]): void {
    const downloads: DownloadProgress[] = [];

    for (const torrent of torrents) {
      const previousState = this.previousStates.get(torrent.hash);
      // previousTorrent reserved for future state comparison logic
      void this.knownTorrents.get(torrent.hash);

      // Detect completion
      if (previousState && this.isDownloading(previousState) && this.isComplete(torrent.state)) {
        this.notifyCompletion({
          hash: torrent.hash,
          name: torrent.name,
          category: torrent.category,
          savePath: torrent.contentPath || torrent.savePath,
          size: torrent.size,
          completedAt: new Date(torrent.completedOn * 1000),
          seedingRatio: torrent.ratio,
        });
      }

      // Detect errors
      if (torrent.state === 'error' || torrent.state === 'missingFiles') {
        if (previousState !== torrent.state) {
          this.notifyError({
            hash: torrent.hash,
            name: torrent.name,
            error: torrent.state === 'error' ? 'Download error' : 'Missing files',
          });
        }
      }

      // Track active downloads
      if (this.isDownloading(torrent.state) || this.isSeeding(torrent.state)) {
        downloads.push({
          hash: torrent.hash,
          name: torrent.name,
          progress: Math.round(torrent.progress * 100),
          speed: torrent.dlspeed,
          eta: this.formatEta(torrent.eta),
          state: this.mapState(torrent.state),
          category: torrent.category,
        });
      }

      // Update tracking
      this.previousStates.set(torrent.hash, torrent.state);
      this.knownTorrents.set(torrent.hash, torrent);
    }

    // Notify progress listeners
    if (downloads.length > 0 || this.previousStates.size > 0) {
      for (const listener of this.progressListeners) {
        try {
          listener(downloads);
        } catch (error) {
          console.error('DownloadMonitorService: Progress listener error', error);
        }
      }
    }

    // Clean up old torrents no longer in the list
    const currentHashes = new Set(torrents.map(t => t.hash));
    for (const hash of this.previousStates.keys()) {
      if (!currentHashes.has(hash)) {
        this.previousStates.delete(hash);
        this.knownTorrents.delete(hash);
      }
    }
  }

  /**
   * Check if state indicates downloading
   */
  private isDownloading(state: TorrentState): boolean {
    return ['downloading', 'metaDL', 'queuedDL', 'stalledDL', 'forcedDL', 'checkingDL', 'allocating'].includes(state);
  }

  /**
   * Check if state indicates complete/seeding
   */
  private isComplete(state: TorrentState): boolean {
    return ['uploading', 'pausedUP', 'queuedUP', 'stalledUP', 'forcedUP', 'checkingUP'].includes(state);
  }

  /**
   * Check if state indicates seeding
   */
  private isSeeding(state: TorrentState): boolean {
    return ['uploading', 'stalledUP', 'forcedUP'].includes(state);
  }

  /**
   * Map qBittorrent state to simplified state
   */
  private mapState(state: TorrentState): DownloadProgress['state'] {
    if (state === 'error' || state === 'missingFiles') return 'error';
    if (state.includes('paused')) return 'paused';
    if (state.includes('checking')) return 'checking';
    if (this.isSeeding(state)) return 'seeding';
    if (this.isDownloading(state)) return 'downloading';
    return 'completed';
  }

  /**
   * Format ETA to human-readable string
   */
  private formatEta(seconds: number): string {
    if (seconds < 0 || seconds === 8640000) return '∞';
    if (seconds < 60) return `${seconds}s`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ${Math.floor((seconds % 3600) / 60)}m`;
    return `${Math.floor(seconds / 86400)}d ${Math.floor((seconds % 86400) / 3600)}h`;
  }

  /**
   * Notify completion listeners
   */
  private notifyCompletion(completion: DownloadCompletion): void {
    console.log(`DownloadMonitorService: Download complete - ${completion.name}`);
    for (const listener of this.completionListeners) {
      try {
        listener(completion);
      } catch (error) {
        console.error('DownloadMonitorService: Completion listener error', error);
      }
    }
  }

  /**
   * Notify error listeners
   */
  private notifyError(error: { hash: string; name: string; error: string }): void {
    console.error(`DownloadMonitorService: Download error - ${error.name}: ${error.error}`);
    for (const listener of this.errorListeners) {
      try {
        listener(error);
      } catch (err) {
        console.error('DownloadMonitorService: Error listener error', err);
      }
    }
  }

  /**
   * Get current download status
   */
  async getStatus(): Promise<{
    activeCount: number;
    totalSpeed: number;
    downloads: DownloadProgress[];
  }> {
    const torrents = await this.fetchTorrents();
    const active = torrents.filter(t => this.isDownloading(t.state));

    return {
      activeCount: active.length,
      totalSpeed: active.reduce((sum, t) => sum + t.dlspeed, 0),
      downloads: active.map(t => ({
        hash: t.hash,
        name: t.name,
        progress: Math.round(t.progress * 100),
        speed: t.dlspeed,
        eta: this.formatEta(t.eta),
        state: this.mapState(t.state),
        category: t.category,
      })),
    };
  }

  /**
   * Pause a download
   */
  async pause(hash: string): Promise<boolean> {
    const syncConfig = secureConfigService.getSyncBridge();
    if (!syncConfig.url) return false;

    try {
      const response = await fetch(`${syncConfig.url}/qbittorrent/torrents/pause`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Device-Token': syncConfig.deviceToken,
        },
        body: JSON.stringify({ hashes: hash }),
      });
      return response.ok;
    } catch {
      return false;
    }
  }

  /**
   * Resume a download
   */
  async resume(hash: string): Promise<boolean> {
    const syncConfig = secureConfigService.getSyncBridge();
    if (!syncConfig.url) return false;

    try {
      const response = await fetch(`${syncConfig.url}/qbittorrent/torrents/resume`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Device-Token': syncConfig.deviceToken,
        },
        body: JSON.stringify({ hashes: hash }),
      });
      return response.ok;
    } catch {
      return false;
    }
  }

  /**
   * Delete a download
   */
  async delete(hash: string, deleteFiles: boolean = false): Promise<boolean> {
    const syncConfig = secureConfigService.getSyncBridge();
    if (!syncConfig.url) return false;

    try {
      const response = await fetch(`${syncConfig.url}/qbittorrent/torrents/delete`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Device-Token': syncConfig.deviceToken,
        },
        body: JSON.stringify({ hashes: hash, deleteFiles }),
      });
      return response.ok;
    } catch {
      return false;
    }
  }

  // Subscription methods
  onProgress(listener: ProgressListener): () => void {
    this.progressListeners.add(listener);
    return () => this.progressListeners.delete(listener);
  }

  onCompletion(listener: CompletionListener): () => void {
    this.completionListeners.add(listener);
    return () => this.completionListeners.delete(listener);
  }

  onError(listener: ErrorListener): () => void {
    this.errorListeners.add(listener);
    return () => this.errorListeners.delete(listener);
  }
}

export const downloadMonitorService = DownloadMonitorService.getInstance();
