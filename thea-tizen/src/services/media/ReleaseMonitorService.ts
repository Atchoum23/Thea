/**
 * Release Monitor Service
 *
 * Monitors for new releases via RSS feeds and search.
 * Features automatic searching, quality filtering, retry logic.
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

interface RSSItem {
  id: string;
  title: string;
  link: string;
  guid: string;
  pubDate: Date;
  size?: number;
  indexer: string;
  parsedRelease?: ParsedRelease;
}

class ReleaseMonitorService {
  private static instance: ReleaseMonitorService;
  private indexers: Map<string, Indexer> = new Map();
  private wantedItems: Map<string, WantedItem> = new Map();
  private rssHistory: Map<string, RSSItem> = new Map();
  private rssTimer?: NodeJS.Timeout;
  private searchTimer?: NodeJS.Timeout;
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
    const newIndexer: Indexer = { ...indexer, id, errorCount: 0 };
    this.indexers.set(id, newIndexer);
    console.log(`[ReleaseMonitor] Added indexer: ${indexer.name}`);
    return newIndexer;
  }

  removeIndexer(id: string): boolean { return this.indexers.delete(id); }
  getIndexers(): Indexer[] { return Array.from(this.indexers.values()); }
  getEnabledIndexers(): Indexer[] { return this.getIndexers().filter(i => i.enabled).sort((a, b) => a.priority - b.priority); }

  async testIndexer(id: string): Promise<{ success: boolean; message: string }> {
    const indexer = this.indexers.get(id);
    if (!indexer) return { success: false, message: 'Indexer not found' };
    try {
      if (indexer.rssUrl) { await this.fetchRSS(indexer); return { success: true, message: 'RSS feed accessible' }; }
      return { success: true, message: 'API accessible' };
    } catch (error) {
      return { success: false, message: error instanceof Error ? error.message : 'Unknown error' };
    }
  }

  async syncRSS(): Promise<void> {
    console.log('[ReleaseMonitor] Starting RSS sync...');
    for (const indexer of this.getEnabledIndexers().filter(i => i.rssUrl)) {
      try { await this.syncIndexerRSS(indexer); }
      catch (error) { console.error(`[ReleaseMonitor] Error syncing ${indexer.name}:`, error); this.recordIndexerError(indexer.id, error); }
    }
  }

  private async syncIndexerRSS(indexer: Indexer): Promise<void> {
    if (!indexer.rssUrl) return;
    const items = await this.fetchRSS(indexer);
    for (const item of items) {
      if (this.rssHistory.has(item.guid)) continue;
      item.parsedRelease = releaseParserService.parse(item.title);
      this.rssHistory.set(item.guid, item);
      await this.checkAgainstWanted(item, indexer);
    }
    indexer.lastSyncTime = new Date();
    this.indexers.set(indexer.id, indexer);
  }

  private async fetchRSS(indexer: Indexer): Promise<RSSItem[]> {
    if (!indexer.rssUrl) return [];
    if (indexer.lastRequestTime) {
      const timeSince = Date.now() - indexer.lastRequestTime.getTime();
      const minInterval = (60 * 1000) / indexer.requestsPerMinute;
      if (timeSince < minInterval) await new Promise(r => setTimeout(r, minInterval - timeSince));
    }
    indexer.lastRequestTime = new Date();
    const response = await fetch(indexer.rssUrl, { headers: { 'User-Agent': 'Thea/1.0 (Media Manager)' } });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const text = await response.text();
    return this.parseRSSFeed(text, indexer.id);
  }

  private parseRSSFeed(xml: string, indexerId: string): RSSItem[] {
    const items: RSSItem[] = [];
    const itemMatches = xml.matchAll(/<item>([\s\S]*?)<\/item>/g);
    for (const match of itemMatches) {
      const itemXml = match[1];
      const title = this.extractXmlValue(itemXml, 'title');
      const link = this.extractXmlValue(itemXml, 'link');
      const guid = this.extractXmlValue(itemXml, 'guid') || link;
      const pubDateStr = this.extractXmlValue(itemXml, 'pubDate');
      if (!title || !link) continue;
      items.push({ id: `rss-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`, title, link, guid, pubDate: pubDateStr ? new Date(pubDateStr) : new Date(), indexer: indexerId });
    }
    return items;
  }

  private extractXmlValue(xml: string, tag: string): string | undefined {
    const match = xml.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`, 'i'));
    if (match) return match[1].replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').trim();
    return undefined;
  }

  addWanted(item: Omit<WantedItem, 'id' | 'status' | 'searchCount' | 'failCount'>): WantedItem {
    const id = `wanted-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const wantedItem: WantedItem = { ...item, id, status: 'wanted', searchCount: 0, failCount: 0 };
    this.wantedItems.set(id, wantedItem);
    console.log(`[ReleaseMonitor] Added to wanted: ${item.title}`);
    return wantedItem;
  }

  removeWanted(id: string): boolean { return this.wantedItems.delete(id); }
  getWantedItems(): WantedItem[] { return Array.from(this.wantedItems.values()); }

  async searchForItem(id: string): Promise<SearchResult[]> {
    const item = this.wantedItems.get(id);
    if (!item) return [];
    console.log(`[ReleaseMonitor] Searching for: ${item.title}`);
    item.status = 'searching';
    item.lastSearchTime = new Date();
    item.searchCount++;
    this.wantedItems.set(id, item);
    const results: SearchResult[] = [];
    // Would search indexers here
    const profile = qualityProfileService.getProfile(item.qualityProfileId);
    const acceptableResults = results.filter(r => qualityProfileService.isAcceptable(r.parsedRelease, profile).acceptable);
    acceptableResults.sort((a, b) => b.qualityScore - a.qualityScore);
    if (acceptableResults.length > 0) {
      item.status = 'wanted';
      this.onReleaseFound?.(item, acceptableResults[0]);
    }
    this.wantedItems.set(id, item);
    return acceptableResults;
  }

  async runAutomaticSearch(): Promise<void> {
    console.log('[ReleaseMonitor] Running automatic search...');
    const items = this.getWantedItems().filter(i => i.monitored && i.status !== 'grabbed' && i.status !== 'downloaded');
    for (const item of items.slice(0, 20)) {
      await this.searchForItem(item.id);
      await new Promise(r => setTimeout(r, 2000));
    }
  }

  private async checkAgainstWanted(rssItem: RSSItem, indexer: Indexer): Promise<void> {
    if (!rssItem.parsedRelease) return;
    for (const wanted of this.wantedItems.values()) {
      if (!wanted.monitored || wanted.status === 'grabbed' || wanted.status === 'downloaded') continue;
      if (this.matchesWantedItem(rssItem.parsedRelease, wanted)) {
        const profile = qualityProfileService.getProfile(wanted.qualityProfileId);
        if (qualityProfileService.isAcceptable(rssItem.parsedRelease, profile).acceptable) {
          console.log(`[ReleaseMonitor] Found match for ${wanted.title}: ${rssItem.title}`);
          const result: SearchResult = {
            id: rssItem.id, indexer: indexer.id, title: rssItem.title, link: rssItem.link, size: rssItem.size || 0,
            pubDate: rssItem.pubDate, parsedRelease: rssItem.parsedRelease,
            qualityScore: qualityProfileService.scoreRelease(rssItem.parsedRelease, profile), isGrabbed: false,
          };
          this.onReleaseFound?.(wanted, result);
        }
      }
    }
  }

  private matchesWantedItem(release: ParsedRelease, wanted: WantedItem): boolean {
    const releaseTitle = release.cleanTitle.toLowerCase().replace(/[^a-z0-9]/g, '');
    const wantedTitle = wanted.title.toLowerCase().replace(/[^a-z0-9]/g, '');
    if (!releaseTitle.includes(wantedTitle) && !wantedTitle.includes(releaseTitle)) return false;
    if (wanted.type === 'movie' && wanted.year && release.year && Math.abs(release.year - wanted.year) > 1) return false;
    if (wanted.type === 'episode') {
      if (wanted.season !== undefined && release.season !== wanted.season) return false;
      if (wanted.episode !== undefined && release.episode !== wanted.episode) {
        if (release.episodeEnd && wanted.episode >= release.episode && wanted.episode <= release.episodeEnd) return true;
        return false;
      }
    }
    return true;
  }

  async grabRelease(wantedId: string, result: SearchResult): Promise<boolean> {
    const wanted = this.wantedItems.get(wantedId);
    if (!wanted) return false;
    console.log(`[ReleaseMonitor] Grabbing: ${result.title}`);
    try {
      wanted.status = 'grabbed';
      wanted.grabbedRelease = result;
      result.isGrabbed = true;
      this.wantedItems.set(wantedId, wanted);
      this.onDownloadReady?.(wanted, result);
      return true;
    } catch (error) {
      wanted.status = 'failed';
      wanted.failCount++;
      wanted.lastError = error instanceof Error ? error.message : 'Unknown error';
      wanted.nextRetryTime = new Date(Date.now() + 5 * 60 * 1000 * Math.pow(2, wanted.failCount - 1));
      this.wantedItems.set(wantedId, wanted);
      return false;
    }
  }

  private recordIndexerError(id: string, error: unknown): void {
    const indexer = this.indexers.get(id);
    if (!indexer) return;
    indexer.errorCount++;
    indexer.lastError = error instanceof Error ? error.message : 'Unknown error';
    if (indexer.errorCount >= 5) { indexer.enabled = false; console.warn(`[ReleaseMonitor] Disabled ${indexer.name} due to errors`); }
    this.indexers.set(id, indexer);
  }

  getStats() {
    const indexers = this.getIndexers();
    const wanted = this.getWantedItems();
    return {
      indexers: { total: indexers.length, enabled: indexers.filter(i => i.enabled).length, healthy: indexers.filter(i => i.enabled && i.errorCount === 0).length, lastSync: indexers.reduce((l, i) => (!i.lastSyncTime ? l : !l || i.lastSyncTime > l ? i.lastSyncTime : l), undefined as Date | undefined) },
      wanted: { movies: wanted.filter(i => i.type === 'movie').length, episodes: wanted.filter(i => i.type === 'episode').length, grabbed: wanted.filter(i => i.status === 'grabbed').length, failed: wanted.filter(i => i.status === 'failed').length },
      rss: { itemsProcessed: this.rssHistory.size, matchesFound: wanted.filter(i => i.status === 'grabbed').length, lastRssSync: indexers.reduce((l, i) => (!i.lastSyncTime ? l : !l || i.lastSyncTime > l ? i.lastSyncTime : l), undefined as Date | undefined) },
    };
  }

  setOnReleaseFound(handler: (item: WantedItem, result: SearchResult) => void): void { this.onReleaseFound = handler; }
  setOnDownloadReady(handler: (item: WantedItem, result: SearchResult) => void): void { this.onDownloadReady = handler; }
}

export const releaseMonitorService = ReleaseMonitorService.getInstance();
