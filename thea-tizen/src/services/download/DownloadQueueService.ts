/**
 * Download Queue Service
 *
 * Intelligent download queue with qBittorrent integration.
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
  priority: number;
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
  errorCount: number;
  lastError?: string;
  downloadPath: string;
  category?: string;
  priority: number;
  maxConcurrentDownloads: number;
  currentDownloads: number;
}

export interface QueueStats {
  queue: { total: number; downloading: number; seeding: number; queued: number; completed: number; failed: number };
  speed: { download: number; upload: number };
  totals: { downloaded: number; uploaded: number; ratio: number };
  eta: { current?: number; total?: number };
}

class DownloadQueueService {
  private static instance: DownloadQueueService;
  private queue: Map<string, DownloadItem> = new Map();
  private clients: Map<string, DownloadClient> = new Map();
  private maxConcurrent = 5;
  private checkTimer?: ReturnType<typeof setInterval>;
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
    this.checkTimer = setInterval(() => this.checkQueue(), 10 * 1000);
    this.checkQueue();
  }

  stop(): void {
    console.log('[DownloadQueue] Stopping...');
    if (this.checkTimer) { clearInterval(this.checkTimer); this.checkTimer = undefined; }
  }

  addClient(client: Omit<DownloadClient, 'id' | 'connected' | 'errorCount' | 'currentDownloads'>): DownloadClient {
    const id = `client-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const c: DownloadClient = { ...client, id, connected: false, errorCount: 0, currentDownloads: 0 };
    this.clients.set(id, c);
    console.log(`[DownloadQueue] Added client: ${client.name}`);
    this.testClient(id);
    return c;
  }

  removeClient(id: string): boolean { return this.clients.delete(id); }
  getClients(): DownloadClient[] { return Array.from(this.clients.values()); }

  async testClient(id: string): Promise<{ success: boolean; message: string }> {
    const client = this.clients.get(id);
    if (!client) return { success: false, message: 'Not found' };
    try {
      const protocol = client.useSSL ? 'https' : 'http';
      const baseUrl = `${protocol}://${client.host}:${client.port}`;
      if (client.type === 'qbittorrent') {
        if (client.username && client.password) {
          const login = await fetch(`${baseUrl}/api/v2/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: `username=${encodeURIComponent(client.username)}&password=${encodeURIComponent(client.password)}` });
          if (!login.ok) { client.connected = false; client.errorCount++; client.lastError = 'Login failed'; this.clients.set(id, client); return { success: false, message: 'Login failed' }; }
        }
        const res = await fetch(`${baseUrl}/api/v2/app/version`);
        if (!res.ok) { client.connected = false; client.errorCount++; this.clients.set(id, client); return { success: false, message: `API error: ${res.status}` }; }
        client.connected = true; client.errorCount = 0; client.lastError = undefined; this.clients.set(id, client);
        return { success: true, message: `Connected to qBittorrent ${await res.text()}` };
      }
      return { success: false, message: 'Unsupported client type' };
    } catch (e) {
      client.connected = false; client.errorCount++; client.lastError = e instanceof Error ? e.message : 'Error'; this.clients.set(id, client);
      return { success: false, message: client.lastError };
    }
  }

  add(result: SearchResult, wantedItem?: WantedItem, opts?: { priority?: number }): DownloadItem {
    const id = `dl-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    let source: DownloadItem['source'] = 'torrent';
    if (result.magnetUri) source = 'magnet';
    else if (result.link.includes('.nzb')) source = 'usenet';
    let priority = opts?.priority || 5;
    priority -= Math.floor(result.qualityScore / 2000);
    if (wantedItem?.type === 'episode') priority -= 2;
    priority = Math.max(1, Math.min(10, priority));
    const item: DownloadItem = {
      id, source, sourceUrl: result.link, magnetUri: result.magnetUri, infoHash: result.infoHash,
      title: result.title, size: result.size, parsedRelease: result.parsedRelease, qualityScore: result.qualityScore,
      wantedItemId: wantedItem?.id, wantedItem, status: 'queued', progress: 0, downloadedBytes: 0, uploadedBytes: 0,
      downloadSpeed: 0, uploadSpeed: 0, seeders: result.seeders, leechers: result.leechers,
      addedAt: new Date(), errorCount: 0, priority, clientId: '',
    };
    this.queue.set(id, item);
    console.log(`[DownloadQueue] Added: ${result.title} (P${priority})`);
    return item;
  }

  remove(id: string): boolean { return this.queue.delete(id); }
  getQueue(): DownloadItem[] { return Array.from(this.queue.values()); }
  getSortedQueue(): DownloadItem[] {
    const order: Record<DownloadItem['status'], number> = { downloading: 0, queued: 1, paused: 2, seeding: 3, importing: 4, completed: 5, imported: 6, warning: 7, failed: 8 };
    return this.getQueue().sort((a, b) => (order[a.status] - order[b.status]) || (a.priority - b.priority));
  }
  pause(id: string): boolean { const i = this.queue.get(id); if (!i || i.status !== 'downloading') return false; i.status = 'paused'; this.queue.set(id, i); return true; }
  resume(id: string): boolean { const i = this.queue.get(id); if (!i || i.status !== 'paused') return false; i.status = 'queued'; this.queue.set(id, i); return true; }
  retry(id: string): boolean { const i = this.queue.get(id); if (!i || i.status !== 'failed') return false; i.status = 'queued'; i.errorCount++; this.queue.set(id, i); return true; }

  private async checkQueue(): Promise<void> {
    const downloading = this.getQueue().filter(i => i.status === 'downloading');
    const queued = this.getQueue().filter(i => i.status === 'queued');
    const freeSlots = this.maxConcurrent - downloading.length;
    if (freeSlots > 0) {
      const toStart = queued.sort((a, b) => a.priority - b.priority).slice(0, freeSlots);
      for (const item of toStart) await this.startDownload(item);
    }
    for (const item of downloading) await this.updateProgress(item);
    for (const item of this.getQueue().filter(i => i.status === 'completed')) {
      await this.importDownload(item);
    }
  }

  private async startDownload(item: DownloadItem): Promise<void> {
    const client = this.getClients().filter(c => c.enabled && c.connected && c.currentDownloads < c.maxConcurrentDownloads).sort((a, b) => a.priority - b.priority)[0];
    if (!client) { console.warn(`[DownloadQueue] No client for: ${item.title}`); return; }
    console.log(`[DownloadQueue] Starting: ${item.title}`);
    try {
      const downloadId = await this.addToClient(client, item);
      item.status = 'downloading'; item.startedAt = new Date(); item.clientId = client.id; item.clientDownloadId = downloadId;
      client.currentDownloads++;
      this.queue.set(item.id, item); this.clients.set(client.id, client);
    } catch (e) {
      console.error('[DownloadQueue] Start failed:', e);
      item.status = 'failed'; item.errorCount++; item.lastError = e instanceof Error ? e.message : 'Error';
      this.queue.set(item.id, item); this.onFailed?.(item, item.lastError);
    }
  }

  private async addToClient(client: DownloadClient, item: DownloadItem): Promise<string> {
    if (client.type === 'qbittorrent') {
      const protocol = client.useSSL ? 'https' : 'http';
      const baseUrl = `${protocol}://${client.host}:${client.port}`;
      const form = new FormData();
      form.append('urls', item.magnetUri || item.sourceUrl);
      if (client.downloadPath) form.append('savepath', client.downloadPath);
      if (client.category) form.append('category', client.category);
      const res = await fetch(`${baseUrl}/api/v2/torrents/add`, { method: 'POST', body: form });
      if (!res.ok) throw new Error(`qBittorrent: ${res.status}`);
      return item.infoHash || `qb-${Date.now()}`;
    }
    throw new Error('Unsupported client');
  }

  private async updateProgress(item: DownloadItem): Promise<void> {
    const client = this.clients.get(item.clientId);
    if (!client || !item.clientDownloadId) return;
    try {
      if (client.type === 'qbittorrent') {
        const protocol = client.useSSL ? 'https' : 'http';
        const baseUrl = `${protocol}://${client.host}:${client.port}`;
        const res = await fetch(`${baseUrl}/api/v2/torrents/info?hashes=${item.clientDownloadId}`);
        if (!res.ok) return;
        const data = await res.json();
        if (!data || !data[0]) return;
        const t = data[0];
        item.progress = t.progress * 100; item.downloadedBytes = t.downloaded; item.uploadedBytes = t.uploaded;
        item.downloadSpeed = t.dlspeed; item.uploadSpeed = t.upspeed; item.eta = t.eta;
        item.seeders = t.num_seeds; item.leechers = t.num_leechs;
        if (item.progress >= 100) {
          item.status = 'completed'; item.completedAt = new Date(); client.currentDownloads--;
          console.log(`[DownloadQueue] Completed: ${item.title}`);
          this.onCompleted?.(item);
        }
        if (t.state.includes('UP')) item.status = 'seeding';
        this.queue.set(item.id, item); this.clients.set(client.id, client);
        this.onProgress?.(item);
      }
    } catch (e) { console.error('[DownloadQueue] Progress error:', e); }
  }

  private async importDownload(item: DownloadItem): Promise<void> {
    if (item.status !== 'completed') return;
    console.log(`[DownloadQueue] Importing: ${item.title}`);
    item.status = 'imported';
    this.queue.set(item.id, item);
    this.onImported?.(item, '/imported/path');
  }

  getStats(): QueueStats {
    const items = this.getQueue();
    const downloading = items.filter(i => i.status === 'downloading');
    const dl = downloading.reduce((s, i) => s + i.downloadSpeed, 0);
    const ul = items.reduce((s, i) => s + i.uploadSpeed, 0);
    const totalDl = items.reduce((s, i) => s + i.downloadedBytes, 0);
    const totalUl = items.reduce((s, i) => s + i.uploadedBytes, 0);
    return {
      queue: { total: items.length, downloading: downloading.length, seeding: items.filter(i => i.status === 'seeding').length, queued: items.filter(i => i.status === 'queued').length, completed: items.filter(i => ['completed', 'imported'].includes(i.status)).length, failed: items.filter(i => i.status === 'failed').length },
      speed: { download: dl, upload: ul },
      totals: { downloaded: totalDl, uploaded: totalUl, ratio: totalDl > 0 ? totalUl / totalDl : 0 },
      eta: { current: downloading.filter(i => i.eta && i.eta > 0).reduce((m, i) => Math.max(m, i.eta!), 0) || undefined },
    };
  }

  setOnProgress(h: (item: DownloadItem) => void): void { this.onProgress = h; }
  setOnCompleted(h: (item: DownloadItem) => void): void { this.onCompleted = h; }
  setOnFailed(h: (item: DownloadItem, error: string) => void): void { this.onFailed = h; }
  setOnImported(h: (item: DownloadItem, destPath: string) => void): void { this.onImported = h; }
}

export const downloadQueueService = DownloadQueueService.getInstance();
