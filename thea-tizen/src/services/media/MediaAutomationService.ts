/**
 * Media Automation Service
 *
 * Orchestrates all media automation - native Sonarr/Radarr replacement.
 */

import { releaseParserService, ParsedRelease } from './ReleaseParserService';
import { qualityProfileService } from './QualityProfileService';
import { mediaLibraryService } from './MediaLibraryService';
import { releaseMonitorService, SearchResult, Indexer } from './ReleaseMonitorService';

export interface AutomationConfig {
  enabled: boolean;
  autoSearchOnAdd: boolean;
  autoGrabBestMatch: boolean;
  defaultMovieProfileId: string;
  defaultTVProfileId: string;
  notifyOnGrab: boolean;
  notifyOnDownload: boolean;
  notifyOnHealth: boolean;
}

export interface AutomationStatus {
  enabled: boolean;
  started: boolean;
  lastCheck: Date | null;
  monitoring: { active: boolean; indexersTotal: number; indexersHealthy: number; wantedItems: number; lastRssSync: Date | null };
  library: { movies: number; tvShows: number; episodes: number; sizeOnDisk: number };
  recentActivity: ActivityItem[];
  healthIssues: HealthIssue[];
}

export interface ActivityItem {
  id: string;
  type: 'grabbed' | 'downloaded' | 'imported' | 'upgraded' | 'failed' | 'added' | 'removed';
  title: string;
  message: string;
  timestamp: Date;
  mediaType: 'movie' | 'episode';
  quality?: string;
}

export interface HealthIssue {
  id: string;
  type: 'warning' | 'error';
  source: 'indexer' | 'download_client' | 'disk_space' | 'library' | 'general';
  message: string;
  timestamp: Date;
}

const DEFAULT_CONFIG: AutomationConfig = {
  enabled: true,
  autoSearchOnAdd: true,
  autoGrabBestMatch: false,
  defaultMovieProfileId: 'trash-4k-samsung',
  defaultTVProfileId: 'trash-1080p',
  notifyOnGrab: true,
  notifyOnDownload: true,
  notifyOnHealth: true,
};

class MediaAutomationService {
  private static instance: MediaAutomationService;
  private config: AutomationConfig = DEFAULT_CONFIG;
  private started = false;
  private lastCheck: Date | null = null;
  private activityLog: ActivityItem[] = [];
  private healthIssues: HealthIssue[] = [];
  private onNotification?: (activity: ActivityItem) => void;

  private constructor() {}
  static getInstance(): MediaAutomationService {
    if (!MediaAutomationService.instance) MediaAutomationService.instance = new MediaAutomationService();
    return MediaAutomationService.instance;
  }

  start(): void {
    if (this.started) return;
    console.log('[MediaAutomation] Starting...');
    this.setupEventHandlers();
    releaseMonitorService.start();
    this.started = true;
    this.lastCheck = new Date();
    this.logActivity({ type: 'added', title: 'System', message: 'Media automation started', mediaType: 'movie' });
  }

  stop(): void {
    if (!this.started) return;
    console.log('[MediaAutomation] Stopping...');
    releaseMonitorService.stop();
    this.started = false;
  }

  private setupEventHandlers(): void {
    releaseMonitorService.setOnReleaseFound((wanted, result) => {
      this.logActivity({ type: 'grabbed', title: wanted.title, message: `Found: ${result.parsedRelease.resolution} ${result.parsedRelease.source}`, mediaType: wanted.type, quality: `${result.parsedRelease.resolution} ${result.parsedRelease.source}` });
      if (this.config.autoGrabBestMatch) this.grabRelease(wanted.id, result);
    });
    releaseMonitorService.setOnDownloadReady((wanted, result) => {
      console.log(`[MediaAutomation] Download ready: ${result.title}`);
    });
  }

  async addMovie(opts: { title: string; year: number; tmdbId?: number; imdbId?: string; qualityProfileId?: string; monitored?: boolean }): Promise<{ success: boolean; mediaId?: string; message: string; searchStarted: boolean }> {
    const profileId = opts.qualityProfileId || this.config.defaultMovieProfileId;
    if (opts.imdbId && mediaLibraryService.getMovieByImdbId(opts.imdbId)) return { success: false, message: 'Already exists', searchStarted: false };
    if (opts.tmdbId && mediaLibraryService.getMovieByTmdbId(opts.tmdbId)) return { success: false, message: 'Already exists', searchStarted: false };
    const movie = mediaLibraryService.addMovie({
      title: opts.title, year: opts.year, tmdbId: opts.tmdbId, imdbId: opts.imdbId,
      status: 'released', monitored: opts.monitored ?? true, hasFile: false,
      rootPath: mediaLibraryService.getRootPaths().movies,
      path: `${mediaLibraryService.getRootPaths().movies}/${mediaLibraryService.generateMovieFolderName(opts)}`,
      qualityProfileId: profileId, minimumAvailability: 'released',
    });
    let searchStarted = false;
    if (movie.monitored) {
      releaseMonitorService.addWanted({ type: 'movie', title: opts.title, year: opts.year, imdbId: opts.imdbId, tmdbId: opts.tmdbId, qualityProfileId: profileId, monitored: true });
      if (this.config.autoSearchOnAdd) searchStarted = true;
    }
    this.logActivity({ type: 'added', title: opts.title, message: `Added to library${searchStarted ? ', searching...' : ''}`, mediaType: 'movie' });
    return { success: true, mediaId: movie.id, message: `Added "${opts.title}"`, searchStarted };
  }

  async addTVShow(opts: { title: string; year?: number; tvdbId?: number; imdbId?: string; qualityProfileId?: string; monitorStatus?: 'all' | 'future' | 'missing' | 'none' }): Promise<{ success: boolean; mediaId?: string; message: string; searchStarted: boolean }> {
    const profileId = opts.qualityProfileId || this.config.defaultTVProfileId;
    if (opts.tvdbId && mediaLibraryService.getTVShowByTvdbId(opts.tvdbId)) return { success: false, message: 'Already exists', searchStarted: false };
    const show = mediaLibraryService.addTVShow({
      title: opts.title, year: opts.year, tvdbId: opts.tvdbId, imdbId: opts.imdbId,
      status: 'continuing', monitorStatus: opts.monitorStatus || 'all',
      rootPath: mediaLibraryService.getRootPaths().tvShows,
      path: `${mediaLibraryService.getRootPaths().tvShows}/${mediaLibraryService.generateSeriesFolderName(opts)}`,
      seasons: [], qualityProfileId: profileId,
    });
    this.logActivity({ type: 'added', title: opts.title, message: 'Added TV show', mediaType: 'episode' });
    return { success: true, mediaId: show.id, message: `Added "${opts.title}"`, searchStarted: false };
  }

  async searchMovie(movieId: string): Promise<{ success: boolean; results: SearchResult[]; bestMatch?: SearchResult; message: string }> {
    const movie = mediaLibraryService.getMovie(movieId);
    if (!movie) return { success: false, results: [], message: 'Not found' };
    const wanted = releaseMonitorService.addWanted({ type: 'movie', title: movie.title, year: movie.year, imdbId: movie.imdbId, tmdbId: movie.tmdbId, qualityProfileId: movie.qualityProfileId, monitored: movie.monitored });
    const results = await releaseMonitorService.searchForItem(wanted.id);
    return { success: results.length > 0, results, bestMatch: results[0], message: results.length > 0 ? `Found ${results.length} releases` : 'No releases found' };
  }

  async searchEpisode(showId: string, season: number, episode: number): Promise<{ success: boolean; results: SearchResult[]; bestMatch?: SearchResult; message: string }> {
    const show = mediaLibraryService.getTVShow(showId);
    if (!show) return { success: false, results: [], message: 'Not found' };
    const wanted = releaseMonitorService.addWanted({ type: 'episode', title: show.title, season, episode, tvdbId: show.tvdbId, imdbId: show.imdbId, qualityProfileId: show.qualityProfileId, monitored: true });
    const results = await releaseMonitorService.searchForItem(wanted.id);
    return { success: results.length > 0, results, bestMatch: results[0], message: results.length > 0 ? `Found ${results.length} releases` : 'No releases found' };
  }

  async grabRelease(wantedId: string, result: SearchResult): Promise<boolean> {
    return releaseMonitorService.grabRelease(wantedId, result);
  }

  parseRelease(name: string): ParsedRelease { return releaseParserService.parse(name); }
  scoreRelease(release: ParsedRelease, profileId?: string): number {
    const profile = profileId ? qualityProfileService.getProfile(profileId) : qualityProfileService.getActiveProfile();
    return qualityProfileService.scoreRelease(release, profile);
  }
  isAcceptable(release: ParsedRelease, profileId?: string): { acceptable: boolean; reason?: string } {
    const profile = profileId ? qualityProfileService.getProfile(profileId) : qualityProfileService.getActiveProfile();
    return qualityProfileService.isAcceptable(release, profile);
  }

  addIndexer(indexer: Omit<Indexer, 'id' | 'errorCount' | 'lastError'>): Indexer { return releaseMonitorService.addIndexer(indexer); }
  getIndexers(): Indexer[] { return releaseMonitorService.getIndexers(); }
  async testIndexer(id: string): Promise<{ success: boolean; message: string }> { return releaseMonitorService.testIndexer(id); }

  getStatus(): AutomationStatus {
    const monitorStats = releaseMonitorService.getStats();
    const libraryStats = mediaLibraryService.getStats();
    return {
      enabled: this.config.enabled,
      started: this.started,
      lastCheck: this.lastCheck,
      monitoring: { active: this.started, indexersTotal: monitorStats.indexers.total, indexersHealthy: monitorStats.indexers.healthy, wantedItems: monitorStats.wanted.movies + monitorStats.wanted.episodes, lastRssSync: monitorStats.rss.lastRssSync || null },
      library: { movies: libraryStats.movies.total, tvShows: libraryStats.tvShows.total, episodes: libraryStats.tvShows.episodesTotal, sizeOnDisk: libraryStats.movies.sizeOnDisk + libraryStats.tvShows.sizeOnDisk },
      recentActivity: this.activityLog.slice(0, 20),
      healthIssues: this.healthIssues,
    };
  }

  runHealthCheck(): HealthIssue[] {
    this.healthIssues = [];
    const indexers = releaseMonitorService.getIndexers();
    for (const i of indexers.filter(x => x.enabled && x.errorCount > 0)) {
      this.healthIssues.push({ id: `health-${Date.now()}`, type: 'warning', source: 'indexer', message: `Indexer "${i.name}" has errors: ${i.lastError}`, timestamp: new Date() });
    }
    return this.healthIssues;
  }

  private logActivity(activity: Omit<ActivityItem, 'id' | 'timestamp'>): void {
    const item: ActivityItem = { ...activity, id: `activity-${Date.now()}`, timestamp: new Date() };
    this.activityLog.unshift(item);
    if (this.activityLog.length > 100) this.activityLog = this.activityLog.slice(0, 100);
    if ((this.config.notifyOnGrab && activity.type === 'grabbed') || (this.config.notifyOnDownload && activity.type === 'downloaded')) {
      this.onNotification?.(item);
    }
  }

  getActivityLog(limit = 20): ActivityItem[] { return this.activityLog.slice(0, limit); }
  setConfig(config: Partial<AutomationConfig>): void { this.config = { ...this.config, ...config }; }
  getConfig(): AutomationConfig { return { ...this.config }; }
  setOnNotification(handler: (activity: ActivityItem) => void): void { this.onNotification = handler; }
}

export const mediaAutomationService = MediaAutomationService.getInstance();
