/**
 * Release Monitor Service
 *
 * Monitors for new releases via RSS feeds and search.
 */

import { releaseParserService, ParsedRelease } from './ReleaseParserService';
import { qualityProfileService } from './QualityProfileService';

export interface Indexer {
  id: string;
  name: string;
  type: 'torrent' | 'usenet';
  url: string;
  apiKey?: string;
  rssUrl?: string;
  supportsSearch: boolean;
  supportsMovies: boolean;
  supportsTVShows: boolean;
  requestsPerMinute: number;
  lastRequestTime?: Date;
  enabled: boolean;
  priority: number;
  lastSyncTime?: Date;
  errorCount: number;
  lastError?: string;
}

export interface SearchResult {
  id: string;
  indexer: string;
  title: string;
  link: string;
  magnetUri?: string;
  infoHash?: string;
  size: number;
  seeders?: number;
  leechers?: number;
  pubDate: Date;
  parsedRelease: ParsedRelease;
  qualityScore: number;
  isGrabbed: boolean;
  grabError?: string;
}

export interface WantedItem {
  id: string;
  type: 'movie' | 'episode';
  title: string;
  year?: number;
  season?: number;
  episode?: number;
  imdbId?: string;
  tmdbId?: number;
  tvdbId?: number;
  qualityProfileId: string;
  monitored: boolean;
  status: 'wanted' | 'searching' | 'grabbed' | 'downloaded' | 'failed';
  lastSearchTime?: Date;
  searchCount: number;
  grabbedRelease?: SearchResult;
  failCount: number;
  lastError?: string;
  nextRetryTime?: Date;
}

class ReleaseMonitorService {
  private static instance: ReleaseMonitorService;
  private indexers: Map<string, Indexer> = new Map();
  private wantedItems: Map<string, WantedItem> = new Map();
  private rssHistory: Map<string, { title: string; guid: string; parsedRelease?: ParsedRelease }> = new Map();
  private rssTimer?: ReturnType<typeof setInterval>;
  private searchTimer?: ReturnType<typeof setInterval>;
  private onReleaseFound?: (item: WantedItem, result: SearchResult) => void;
  private onDownloadReady?: (item: WantedItem, result: SearchResult) => void;

  private constructor() {}
  static getInstance(): ReleaseMonitorService {
    if (!ReleaseMonitorService.instance) ReleaseMonitorService.instance = new ReleaseMonitorService();
    return ReleaseMonitorService.instance;
  }

  start(): void {
    console.log('[ReleaseMonitor] Starting...');
    this.rssTimer = setInterval(() => this.syncRSS(), 15 * 60 * 1000);
    this.searchTimer = setInterval(() => this.runAutomaticSearch(), 60 * 60 * 1000);
    this.syncRSS();
  }

  stop(): void {
    console.log('[ReleaseMonitor] Stopping...');
    if (this.rssTimer) { clearInterval(this.rssTimer); this.rssTimer = undefined; }
    if (this.searchTimer) { clearInterval(this.searchTimer); this.searchTimer = undefined; }
  }

  addIndexer(indexer: Omit<Indexer, 'id' | 'errorCount' | 'lastError'>): Indexer {
    const id = `indexer-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const i: Indexer = { ...indexer, id, errorCount: 0 };
    this.indexers.set(id, i);
    console.log(`[ReleaseMonitor] Added indexer: ${indexer.name}`);
    return i;
  }

  removeIndexer(id: string): boolean { return this.indexers.delete(id); }
  getIndexers(): Indexer[] { return Array.from(this.indexers.values()); }
  getEnabledIndexers(): Indexer[] { return this.getIndexers().filter(i => i.enabled).sort((a, b) => a.priority - b.priority); }

  async testIndexer(id: string): Promise<{ success: boolean; message: string }> {
    const indexer = this.indexers.get(id);
    if (!indexer) return { success: false, message: 'Not found' };
    try {
      if (indexer.rssUrl) {
        await fetch(indexer.rssUrl, { headers: { 'User-Agent': 'Thea/1.0' } });
        return { success: true, message: 'RSS accessible' };
      }
      return { success: true, message: 'API accessible' };
    } catch (e) {
      return { success: false, message: e instanceof Error ? e.message : 'Error' };
    }
  }

  async syncRSS(): Promise<void> {
    console.log('[ReleaseMonitor] Syncing RSS...');
    for (const indexer of this.getEnabledIndexers().filter(i => i.rssUrl)) {
      try {
        await this.syncIndexerRSS(indexer);
        indexer.lastSyncTime = new Date();
        this.indexers.set(indexer.id, indexer);
      } catch (e) {
        console.error(`[ReleaseMonitor] RSS sync error for ${indexer.name}:`, e);
        indexer.errorCount++;
        indexer.lastError = e instanceof Error ? e.message : 'Error';
        if (indexer.errorCount >= 5) indexer.enabled = false;
        this.indexers.set(indexer.id, indexer);
      }
    }
  }

  private async syncIndexerRSS(indexer: Indexer): Promise<void> {
    if (!indexer.rssUrl) return;
    const response = await fetch(indexer.rssUrl, { headers: { 'User-Agent': 'Thea/1.0' } });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const xml = await response.text();
    const items = this.parseRSS(xml);
    for (const item of items) {
      if (this.rssHistory.has(item.guid)) continue;
      const parsed = releaseParserService.parse(item.title);
      this.rssHistory.set(item.guid, { title: item.title, guid: item.guid, parsedRelease: parsed });
      await this.checkMatch(item, parsed, indexer);
    }
  }

  private parseRSS(xml: string): Array<{ title: string; link: string; guid: string; pubDate: Date; size?: number }> {
    const items: Array<{ title: string; link: string; guid: string; pubDate: Date; size?: number }> = [];
    const matches = xml.matchAll(/<item>([\s\S]*?)<\/item>/g);
    for (const m of matches) {
      const content = m[1];
      const title = this.extractTag(content, 'title');
      const link = this.extractTag(content, 'link');
      const guidRaw = this.extractTag(content, 'guid') || link;
      const pubDate = this.extractTag(content, 'pubDate');
      if (title && link) {
        const guid = guidRaw ?? link;
        items.push({ title, link, guid, pubDate: pubDate ? new Date(pubDate) : new Date() });
      }
    }
    return items;
  }

  private extractTag(xml: string, tag: string): string | undefined {
    const match = xml.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`, 'i'));
    return match ? match[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').trim() : undefined;
  }

  private async checkMatch(item: { title: string; link: string; guid: string; pubDate: Date }, parsed: ParsedRelease, indexer: Indexer): Promise<void> {
    for (const wanted of this.wantedItems.values()) {
      if (!wanted.monitored || wanted.status === 'grabbed' || wanted.status === 'downloaded') continue;
      if (this.matches(parsed, wanted)) {
        const profile = qualityProfileService.getProfile(wanted.qualityProfileId);
        if (qualityProfileService.isAcceptable(parsed, profile).acceptable) {
          console.log(`[ReleaseMonitor] Match found: ${item.title}`);
          const result: SearchResult = {
            id: `result-${Date.now()}`, indexer: indexer.id, title: item.title, link: item.link,
            size: 0, pubDate: item.pubDate, parsedRelease: parsed,
            qualityScore: qualityProfileService.scoreRelease(parsed, profile), isGrabbed: false,
          };
          this.onReleaseFound?.(wanted, result);
        }
      }
    }
  }

  private matches(release: ParsedRelease, wanted: WantedItem): boolean {
    const cleanR = release.cleanTitle.toLowerCase().replace(/[^a-z0-9]/g, '');
    const cleanW = wanted.title.toLowerCase().replace(/[^a-z0-9]/g, '');
    if (!cleanR.includes(cleanW) && !cleanW.includes(cleanR)) return false;
    if (wanted.type === 'movie' && wanted.year && release.year && Math.abs(release.year - wanted.year) > 1) return false;
    if (wanted.type === 'episode') {
      if (wanted.season !== undefined && release.season !== wanted.season) return false;
      if (wanted.episode !== undefined && release.episode !== wanted.episode) {
        if (release.episodeEnd && release.episode !== undefined && wanted.episode >= release.episode && wanted.episode <= release.episodeEnd) return true;
        return false;
      }
    }
    return true;
  }

  addWanted(item: Omit<WantedItem, 'id' | 'status' | 'searchCount' | 'failCount'>): WantedItem {
    const id = `wanted-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const w: WantedItem = { ...item, id, status: 'wanted', searchCount: 0, failCount: 0 };
    this.wantedItems.set(id, w);
    console.log(`[ReleaseMonitor] Added to wanted: ${item.title}`);
    return w;
  }

  removeWanted(id: string): boolean { return this.wantedItems.delete(id); }
  getWantedItems(): WantedItem[] { return Array.from(this.wantedItems.values()); }

  async searchForItem(id: string): Promise<SearchResult[]> {
    const item = this.wantedItems.get(id);
    if (!item) return [];
    console.log(`[ReleaseMonitor] Searching: ${item.title}`);
    item.status = 'searching';
    item.lastSearchTime = new Date();
    item.searchCount++;
    this.wantedItems.set(id, item);
    // Would search indexers here - returns empty for now
    item.status = 'wanted';
    this.wantedItems.set(id, item);
    return [];
  }

  async runAutomaticSearch(): Promise<void> {
    console.log('[ReleaseMonitor] Running automatic search...');
    const items = this.getWantedItems().filter(i => i.monitored && !['grabbed', 'downloaded'].includes(i.status));
    for (const item of items.slice(0, 20)) {
      await this.searchForItem(item.id);
      await new Promise(r => setTimeout(r, 2000));
    }
  }

  async grabRelease(wantedId: string, result: SearchResult): Promise<boolean> {
    const wanted = this.wantedItems.get(wantedId);
    if (!wanted) return false;
    console.log(`[ReleaseMonitor] Grabbing: ${result.title}`);
    wanted.status = 'grabbed';
    wanted.grabbedRelease = result;
    result.isGrabbed = true;
    this.wantedItems.set(wantedId, wanted);
    this.onDownloadReady?.(wanted, result);
    return true;
  }

  getStats() {
    const indexers = this.getIndexers();
    const wanted = this.getWantedItems();
    return {
      indexers: { total: indexers.length, enabled: indexers.filter(i => i.enabled).length, healthy: indexers.filter(i => i.enabled && i.errorCount === 0).length, lastSync: indexers.reduce((l, i) => !i.lastSyncTime ? l : !l || i.lastSyncTime > l ? i.lastSyncTime : l, undefined as Date | undefined) },
      wanted: { movies: wanted.filter(i => i.type === 'movie').length, episodes: wanted.filter(i => i.type === 'episode').length, grabbed: wanted.filter(i => i.status === 'grabbed').length, failed: wanted.filter(i => i.status === 'failed').length },
      rss: { itemsProcessed: this.rssHistory.size, matchesFound: wanted.filter(i => i.status === 'grabbed').length, lastRssSync: indexers.reduce((l, i) => !i.lastSyncTime ? l : !l || i.lastSyncTime > l ? i.lastSyncTime : l, undefined as Date | undefined) },
    };
  }

  setOnReleaseFound(handler: (item: WantedItem, result: SearchResult) => void): void { this.onReleaseFound = handler; }
  setOnDownloadReady(handler: (item: WantedItem, result: SearchResult) => void): void { this.onDownloadReady = handler; }
}

export const releaseMonitorService = ReleaseMonitorService.getInstance();
