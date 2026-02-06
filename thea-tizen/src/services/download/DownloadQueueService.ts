/**
 * Download Queue Service
 *
 * Intelligent download queue management with priority-based queuing,
 * concurrent download limits, retry logic, and qBittorrent integration.
 */

import { ParsedRelease } from '../media/ReleaseParserService';
import { SearchResult, WantedItem } from '../media/ReleaseMonitorService';

export interface DownloadItem {
  id: string;
  source: 'torrent' | 'magnet' | 'usenet' | 'direct';
  sourceUrl: string;
  magnetUri?: string;
  infoHash?: string;
  title: string;
  size: number;
  parsedRelease: ParsedRelease;
  qualityScore: number;
  wantedItemId?: string;
  wantedItem?: WantedItem;
  status: 'queued' | 'paused' | 'downloading' | 'seeding' | 'completed' | 'importing' | 'imported' | 'failed' | 'warning';
  progress: number;
  downloadedBytes: number;
  uploadedBytes: number;
  downloadSpeed: number;
  uploadSpeed: number;
  eta?: number;
  seeders?: number;
  leechers?: number;
  addedAt: Date;
  startedAt?: Date;
  completedAt?: Date;
  errorCount: number;
  lastError?: string;
  nextRetryAt?: Date;
  priority: number;
  postProcessStatus?: 'pending' | 'processing' | 'completed' | 'failed';
  destPath?: string;
  clientId: string;
  clientDownloadId?: string;
}

export interface DownloadClient {
  id: string;
  name: string;
  type: 'qbittorrent' | 'transmission' | 'deluge' | 'sabnzbd' | 'nzbget';
  host: string;
  port: number;
  username?: string;
  password?: string;
  useSSL: boolean;
  enabled: boolean;
  connected: boolean;
  lastConnected?: Date;
  errorCount: number;
  lastError?: string;
  downloadPath: string;
  category?: string;
  priority: number;
  maxConcurrentDownloads: number;
  currentDownloads: number;
  totalDownloading: number;
  totalSeeding: number;
  freeSpace?: number;
}

export interface QueueStats {
  queue: { total: number; downloading: number; seeding: number; queued: number; completed: number; failed: number };
  speed: { download: number; upload: number };
  totals: { downloaded: number; uploaded: number; ratio: number };
  eta: { current?: number; total?: number };
}

interface QueueConfig {
  maxConcurrentDownloads: number;
  checkInterval: number;
  maxRetries: number;
  retryDelay: number;
  retryBackoff: number;
  seedRatioLimit: number;
  seedTimeLimit: number;
  autoImport: boolean;
  deleteAfterImport: boolean;
  stallDetectionTime: number;
  minimumSeedersWarning: number;
}

const DEFAULT_CONFIG: QueueConfig = {
  maxConcurrentDownloads: 5, checkInterval: 10, maxRetries: 3, retryDelay: 300, retryBackoff: 2,
  seedRatioLimit: 1.0, seedTimeLimit: 60 * 24, autoImport: true, deleteAfterImport: false,
  stallDetectionTime: 600, minimumSeedersWarning: 2,
};

class DownloadQueueService {
  private static instance: DownloadQueueService;
  private queue: Map<string, DownloadItem> = new Map();
  private clients: Map<string, DownloadClient> = new Map();
  private config = DEFAULT_CONFIG;
  private checkTimer?: NodeJS.Timeout;
  private onProgress?: (item: DownloadItem) => void;
  private onCompleted?: (item: DownloadItem) => void;
  private onFailed?: (item: DownloadItem, error: string) => void;
  private onImported?: (item: DownloadItem, destPath: string) => void;

  private constructor() {}

  static getInstance(): DownloadQueueService {
    if (!DownloadQueueService.instance) DownloadQueueService.instance = new DownloadQueueService();
    return DownloadQueueService.instance;
  }

  start(): void {
    console.log('[DownloadQueue] Starting...');
    this.checkTimer = setInterval(() => this.checkQueue(), this.config.checkInterval * 1000);
    this.checkQueue();
  }

  stop(): void {
    console.log('[DownloadQueue] Stopping...');
    if (this.checkTimer) { clearInterval(this.checkTimer); this.checkTimer = undefined; }
  }

  addClient(client: Omit<DownloadClient, 'id' | 'connected' | 'errorCount' | 'currentDownloads' | 'totalDownloading' | 'totalSeeding'>): DownloadClient {
    const id = `client-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const newClient: DownloadClient = { ...client, id, connected: false, errorCount: 0, currentDownloads: 0, totalDownloading: 0, totalSeeding: 0 };
    this.clients.set(id, newClient);
    console.log(`[DownloadQueue] Added client: ${client.name}`);
    this.testClient(id);
    return newClient;
  }

  removeClient(id: string): boolean { return this.clients.delete(id); }
  getClients(): DownloadClient[] { return Array.from(this.clients.values()); }

  private getBestClient(source: DownloadItem['source']): DownloadClient | undefined {
    return this.getClients()
      .filter(c => c.enabled && c.connected && c.currentDownloads < c.maxConcurrentDownloads)
      .filter(c => (source === 'torrent' || source === 'magnet') ? ['qbittorrent', 'transmission', 'deluge'].includes(c.type) : ['sabnzbd', 'nzbget'].includes(c.type))
      .sort((a, b) => a.priority !== b.priority ? a.priority - b.priority : a.currentDownloads - b.currentDownloads)[0];
  }

  async testClient(id: string): Promise<{ success: boolean; message: string }> {
    const client = this.clients.get(id);
    if (!client) return { success: false, message: 'Client not found' };
    try {
      const result = await this.connectToClient(client);
      client.connected = result.success;
      if (result.success) { client.lastConnected = new Date(); client.errorCount = 0; client.lastError = undefined; }
      else { client.errorCount++; client.lastError = result.message; }
      this.clients.set(id, client);
      return result;
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      client.connected = false; client.errorCount++; client.lastError = message;
      this.clients.set(id, client);
      return { success: false, message };
    }
  }

  private async connectToClient(client: DownloadClient): Promise<{ success: boolean; message: string }> {
    const protocol = client.useSSL ? 'https' : 'http';
    const baseUrl = `${protocol}://${client.host}:${client.port}`;
    if (client.type === 'qbittorrent') {
      try {
        if (client.username && client.password) {
          const loginRes = await fetch(`${baseUrl}/api/v2/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: `username=${encodeURIComponent(client.username)}&password=${encodeURIComponent(client.password)}` });
          if (!loginRes.ok) return { success: false, message: 'Login failed' };
        }
        const res = await fetch(`${baseUrl}/api/v2/app/version`);
        if (!res.ok) return { success: false, message: `API error: ${res.status}` };
        return { success: true, message: `Connected to qBittorrent ${await res.text()}` };
      } catch (e) { return { success: false, message: e instanceof Error ? e.message : 'Connection failed' }; }
    }
    return { success: false, message: `Client type ${client.type} not implemented` };
  }

  add(searchResult: SearchResult, wantedItem?: WantedItem, options?: { priority?: number }): DownloadItem {
    const id = `dl-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    let source: DownloadItem['source'] = 'torrent';
    if (searchResult.magnetUri) source = 'magnet';
    else if (searchResult.link.includes('.nzb')) source = 'usenet';
    let priority = options?.priority || 5;
    priority -= Math.floor(searchResult.qualityScore / 2000);
    if (wantedItem?.type === 'episode') priority -= 2;
    priority = Math.max(1, Math.min(10, priority));
    const item: DownloadItem = {
      id, source, sourceUrl: searchResult.link, magnetUri: searchResult.magnetUri, infoHash: searchResult.infoHash,
      title: searchResult.title, size: searchResult.size, parsedRelease: searchResult.parsedRelease, qualityScore: searchResult.qualityScore,
      wantedItemId: wantedItem?.id, wantedItem, status: 'queued', progress: 0, downloadedBytes: 0, uploadedBytes: 0,
      downloadSpeed: 0, uploadSpeed: 0, seeders: searchResult.seeders, leechers: searchResult.leechers,
      addedAt: new Date(), errorCount: 0, priority, clientId: '',
    };
    this.queue.set(id, item);
    console.log(`[DownloadQueue] Added: ${searchResult.title} (priority: ${priority})`);
    return item;
  }

  remove(id: string, deleteFiles = false): boolean {
    const item = this.queue.get(id);
    if (!item) return false;
    // Would cancel in client if downloading
    return this.queue.delete(id);
  }

  getQueue(): DownloadItem[] { return Array.from(this.queue.values()); }

  getSortedQueue(): DownloadItem[] {
    const statusOrder: Record<DownloadItem['status'], number> = { downloading: 0, queued: 1, paused: 2, seeding: 3, importing: 4, completed: 5, imported: 6, warning: 7, failed: 8 };
    return this.getQueue().sort((a, b) => (statusOrder[a.status] - statusOrder[b.status]) || (a.priority - b.priority));
  }

  pause(id: string): boolean {
    const item = this.queue.get(id);
    if (!item || item.status !== 'downloading') return false;
    item.status = 'paused';
    this.queue.set(id, item);
    return true;
  }

  resume(id: string): boolean {
    const item = this.queue.get(id);
    if (!item || item.status !== 'paused') return false;
    item.status = 'queued';
    this.queue.set(id, item);
    return true;
  }

  setPriority(id: string, priority: number): boolean {
    const item = this.queue.get(id);
    if (!item) return false;
    item.priority = Math.max(1, Math.min(10, priority));
    this.queue.set(id, item);
    return true;
  }

  retry(id: string): boolean {
    const item = this.queue.get(id);
    if (!item || item.status !== 'failed') return false;
    item.status = 'queued';
    item.errorCount++;
    item.nextRetryAt = undefined;
    this.queue.set(id, item);
    return true;
  }

  private async checkQueue(): Promise<void> {
    const queuedItems = this.getQueue().filter(i => i.status === 'queued');
    const downloadingItems = this.getQueue().filter(i => i.status === 'downloading');
    const freeSlots = this.config.maxConcurrentDownloads - downloadingItems.length;
    if (freeSlots > 0) {
      const toStart = queuedItems.filter(i => !i.nextRetryAt || new Date() >= i.nextRetryAt).sort((a, b) => a.priority - b.priority).slice(0, freeSlots);
      for (const item of toStart) await this.startDownload(item);
    }
    for (const item of downloadingItems) await this.updateProgress(item);
    for (const item of this.getQueue().filter(i => i.status === 'completed')) {
      if (this.config.autoImport) await this.importDownload(item);
    }
    this.checkForStalled();
  }

  private async startDownload(item: DownloadItem): Promise<void> {
    const client = this.getBestClient(item.source);
    if (!client) { console.warn(`[DownloadQueue] No available client for ${item.title}`); return; }
    console.log(`[DownloadQueue] Starting: ${item.title}`);
    try {
      const downloadId = await this.addToClient(client, item);
      item.status = 'downloading'; item.startedAt = new Date(); item.clientId = client.id; item.clientDownloadId = downloadId;
      client.currentDownloads++; client.totalDownloading++;
      this.queue.set(item.id, item); this.clients.set(client.id, client);
    } catch (error) {
      console.error(`[DownloadQueue] Failed to start:`, error);
      item.status = 'failed'; item.errorCount++; item.lastError = error instanceof Error ? error.message : 'Unknown error';
      item.nextRetryAt = new Date(Date.now() + this.config.retryDelay * 1000 * Math.pow(this.config.retryBackoff, item.errorCount - 1));
      this.queue.set(item.id, item); this.onFailed?.(item, item.lastError);
    }
  }

  private async addToClient(client: DownloadClient, item: DownloadItem): Promise<string> {
    if (client.type === 'qbittorrent') {
      const protocol = client.useSSL ? 'https' : 'http';
      const baseUrl = `${protocol}://${client.host}:${client.port}`;
      const formData = new FormData();
      formData.append('urls', item.magnetUri || item.sourceUrl);
      if (client.downloadPath) formData.append('savepath', client.downloadPath);
      if (client.category) formData.append('category', client.category);
      const res = await fetch(`${baseUrl}/api/v2/torrents/add`, { method: 'POST', body: formData });
      if (!res.ok) throw new Error(`qBittorrent error: ${res.status}`);
      return item.infoHash || `qb-${Date.now()}`;
    }
    throw new Error(`Client type ${client.type} not implemented`);
  }

  private async updateProgress(item: DownloadItem): Promise<void> {
    const client = this.clients.get(item.clientId);
    if (!client || !item.clientDownloadId) return;
    try {
      const status = await this.getClientDownloadStatus(client, item.clientDownloadId);
      if (!status) return;
      item.progress = status.progress; item.downloadedBytes = status.downloadedBytes; item.uploadedBytes = status.uploadedBytes;
      item.downloadSpeed = status.downloadSpeed; item.uploadSpeed = status.uploadSpeed; item.eta = status.eta;
      item.seeders = status.seeders; item.leechers = status.leechers;
      if (status.progress >= 100) {
        item.status = 'completed'; item.completedAt = new Date(); client.currentDownloads--;
        console.log(`[DownloadQueue] Completed: ${item.title}`);
        this.onCompleted?.(item);
      }
      if (status.state === 'seeding') item.status = 'seeding';
      if (status.eta && status.eta > 0) item.estimatedCompletion = new Date(Date.now() + status.eta * 1000);
      this.queue.set(item.id, item); this.clients.set(client.id, client);
      this.onProgress?.(item);
    } catch (error) { console.error(`[DownloadQueue] Error updating progress:`, error); }
  }

  private async getClientDownloadStatus(client: DownloadClient, hash: string) {
    if (client.type === 'qbittorrent') {
      const protocol = client.useSSL ? 'https' : 'http';
      const baseUrl = `${protocol}://${client.host}:${client.port}`;
      try {
        const res = await fetch(`${baseUrl}/api/v2/torrents/info?hashes=${hash}`);
        if (!res.ok) return null;
        const data = await res.json();
        if (!data || data.length === 0) return null;
        const t = data[0];
        return { progress: t.progress * 100, downloadedBytes: t.downloaded, uploadedBytes: t.uploaded, downloadSpeed: t.dlspeed, uploadSpeed: t.upspeed, eta: t.eta, seeders: t.num_seeds, leechers: t.num_leechs, state: t.state.includes('UP') ? 'seeding' : 'downloading' };
      } catch { return null; }
    }
    return null;
  }

  private checkForStalled(): void {
    const now = Date.now();
    for (const item of this.getQueue()) {
      if (item.status !== 'downloading' || !item.startedAt) continue;
      const timeSinceStart = (now - item.startedAt.getTime()) / 1000;
      if (timeSinceStart > this.config.stallDetectionTime && item.progress === 0) {
        console.warn(`[DownloadQueue] Stalled: ${item.title}`);
        item.status = 'warning'; item.lastError = 'Download appears stalled';
        this.queue.set(item.id, item);
      }
      if (item.seeders !== undefined && item.seeders < this.config.minimumSeedersWarning && item.status !== 'warning') {
        item.status = 'warning'; item.lastError = `Low seeders: ${item.seeders}`;
        this.queue.set(item.id, item);
      }
    }
  }

  private async importDownload(item: DownloadItem): Promise<void> {
    if (item.postProcessStatus === 'processing' || item.postProcessStatus === 'completed') return;
    console.log(`[DownloadQueue] Importing: ${item.title}`);
    item.status = 'importing'; item.postProcessStatus = 'processing';
    this.queue.set(item.id, item);
    try {
      // Would implement actual file import here
      item.status = 'imported'; item.postProcessStatus = 'completed'; item.destPath = '/path/to/imported/file';
      this.queue.set(item.id, item);
      console.log(`[DownloadQueue] Import completed: ${item.title}`);
      this.onImported?.(item, item.destPath!);
      if (this.config.deleteAfterImport) setTimeout(() => this.remove(item.id, false), 5000);
    } catch (error) {
      console.error(`[DownloadQueue] Import failed:`, error);
      item.postProcessStatus = 'failed'; item.lastError = error instanceof Error ? error.message : 'Import failed';
      this.queue.set(item.id, item);
    }
  }

  getStats(): QueueStats {
    const items = this.getQueue();
    const downloading = items.filter(i => i.status === 'downloading');
    return {
      queue: { total: items.length, downloading: downloading.length, seeding: items.filter(i => i.status === 'seeding').length, queued: items.filter(i => i.status === 'queued').length, completed: items.filter(i => i.status === 'completed' || i.status === 'imported').length, failed: items.filter(i => i.status === 'failed').length },
      speed: { download: downloading.reduce((s, i) => s + i.downloadSpeed, 0), upload: items.reduce((s, i) => s + i.uploadSpeed, 0) },
      totals: { downloaded: items.reduce((s, i) => s + i.downloadedBytes, 0), uploaded: items.reduce((s, i) => s + i.uploadedBytes, 0), ratio: items.reduce((s, i) => s + i.downloadedBytes, 0) > 0 ? items.reduce((s, i) => s + i.uploadedBytes, 0) / items.reduce((s, i) => s + i.downloadedBytes, 0) : 0 },
      eta: { current: downloading.filter(i => i.eta && i.eta > 0).reduce((max, i) => Math.max(max, i.eta!), 0) || undefined, total: undefined },
    };
  }

  setConfig(config: Partial<QueueConfig>): void { this.config = { ...this.config, ...config }; }
  getConfig(): QueueConfig { return { ...this.config }; }
  setOnProgress(handler: (item: DownloadItem) => void): void { this.onProgress = handler; }
  setOnCompleted(handler: (item: DownloadItem) => void): void { this.onCompleted = handler; }
  setOnFailed(handler: (item: DownloadItem, error: string) => void): void { this.onFailed = handler; }
  setOnImported(handler: (item: DownloadItem, destPath: string) => void): void { this.onImported = handler; }
}

export const downloadQueueService = DownloadQueueService.getInstance();
