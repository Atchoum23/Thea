/**
 * Media Automation Service
 *
 * Orchestrates all media automation components:
 * - Release parsing and quality profiling
 * - Media library management
 * - Release monitoring (RSS/search)
 * - Download queue management
 * - Post-processing and import
 *
 * This is the main entry point for Thea's native media automation
 * capabilities, implementing the core functionality of Sonarr/Radarr.
 */

import { releaseParserService, ParsedRelease } from './ReleaseParserService';
import { qualityProfileService, QualityProfile } from './QualityProfileService';
import { mediaLibraryService, Movie, TVShow, MediaItem } from './MediaLibraryService';
import { releaseMonitorService, WantedItem, SearchResult, Indexer } from './ReleaseMonitorService';
import { downloadQueueService, DownloadItem, DownloadClient, QueueStats } from '../download/DownloadQueueService';

// ============================================================
// TYPES
// ============================================================

export interface AutomationConfig {
  // General
  enabled: boolean;
  autoSearchOnAdd: boolean;
  autoGrabBestMatch: boolean;

  // Quality
  defaultMovieProfileId: string;
  defaultTVProfileId: string;
  defaultAnimeProfileId: string;

  // Monitoring
  monitorNewEpisodes: boolean;
  monitorNewSeasons: boolean;
  monitorNewMovies: boolean;

  // Download
  preferTorrent: boolean;
  minSeeders: number;
  maxPendingDownloads: number;

  // Notifications
  notifyOnGrab: boolean;
  notifyOnDownload: boolean;
  notifyOnUpgrade: boolean;
  notifyOnHealth: boolean;
}

export interface AutomationStatus {
  enabled: boolean;
  started: boolean;
  lastCheck: Date | null;

  // Component statuses
  monitoring: {
    active: boolean;
    indexersTotal: number;
    indexersHealthy: number;
    wantedItems: number;
    lastRssSync: Date | null;
  };

  queue: QueueStats;

  library: {
    movies: number;
    tvShows: number;
    episodes: number;
    sizeOnDisk: number;
  };

  // Recent activity
  recentActivity: ActivityItem[];

  // Health checks
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
  wikiLink?: string;
  timestamp: Date;
}

export interface AddMediaResult {
  success: boolean;
  mediaId?: string;
  message: string;
  searchStarted: boolean;
}

export interface SearchMediaResult {
  success: boolean;
  results: SearchResult[];
  bestMatch?: SearchResult;
  message: string;
}

// ============================================================
// DEFAULT CONFIGURATION
// ============================================================

const DEFAULT_CONFIG: AutomationConfig = {
  enabled: true,
  autoSearchOnAdd: true,
  autoGrabBestMatch: false, // Require user confirmation by default

  defaultMovieProfileId: 'trash-4k-samsung',
  defaultTVProfileId: 'trash-1080p',
  defaultAnimeProfileId: 'anime',

  monitorNewEpisodes: true,
  monitorNewSeasons: true,
  monitorNewMovies: true,

  preferTorrent: true,
  minSeeders: 3,
  maxPendingDownloads: 10,

  notifyOnGrab: true,
  notifyOnDownload: true,
  notifyOnUpgrade: true,
  notifyOnHealth: true,
};

// ============================================================
// SERVICE
// ============================================================

class MediaAutomationService {
  private static instance: MediaAutomationService;

  private config: AutomationConfig = DEFAULT_CONFIG;
  private started: boolean = false;
  private lastCheck: Date | null = null;
  private activityLog: ActivityItem[] = [];
  private healthIssues: HealthIssue[] = [];

  // Notification handler
  private onNotification?: (activity: ActivityItem) => void;

  private constructor() {}

  static getInstance(): MediaAutomationService {
    if (!MediaAutomationService.instance) {
      MediaAutomationService.instance = new MediaAutomationService();
    }
    return MediaAutomationService.instance;
  }

  // ============================================================
  // LIFECYCLE
  // ============================================================

  /**
   * Start all automation services
   */
  start(): void {
    if (this.started) return;

    console.log('[MediaAutomation] Starting media automation service...');

    // Set up event handlers
    this.setupEventHandlers();

    // Start sub-services
    releaseMonitorService.start();
    downloadQueueService.start();

    this.started = true;
    this.lastCheck = new Date();

    this.logActivity({
      type: 'added',
      title: 'System',
      message: 'Media automation started',
      mediaType: 'movie',
    });

    console.log('[MediaAutomation] All services started');
  }

  /**
   * Stop all automation services
   */
  stop(): void {
    if (!this.started) return;

    console.log('[MediaAutomation] Stopping media automation service...');

    releaseMonitorService.stop();
    downloadQueueService.stop();

    this.started = false;

    console.log('[MediaAutomation] All services stopped');
  }

  /**
   * Set up event handlers between services
   */
  private setupEventHandlers(): void {
    // When a matching release is found
    releaseMonitorService.setOnReleaseFound((wanted, result) => {
      this.handleReleaseFound(wanted, result);
    });

    // When a release is ready for download
    releaseMonitorService.setOnDownloadReady((wanted, result) => {
      this.handleDownloadReady(wanted, result);
    });

    // Download progress
    downloadQueueService.setOnProgress((item) => {
      // Could update UI here
    });

    // Download completed
    downloadQueueService.setOnCompleted((item) => {
      this.handleDownloadCompleted(item);
    });

    // Download failed
    downloadQueueService.setOnFailed((item, error) => {
      this.handleDownloadFailed(item, error);
    });

    // Download imported
    downloadQueueService.setOnImported((item, destPath) => {
      this.handleDownloadImported(item, destPath);
    });
  }

  // ============================================================
  // EVENT HANDLERS
  // ============================================================

  private handleReleaseFound(wanted: WantedItem, result: SearchResult): void {
    console.log(`[MediaAutomation] Release found: ${result.title}`);

    this.logActivity({
      type: 'grabbed',
      title: wanted.title,
      message: `Found matching release: ${result.parsedRelease.resolution} ${result.parsedRelease.source}`,
      mediaType: wanted.type,
      quality: `${result.parsedRelease.resolution} ${result.parsedRelease.source}`,
    });

    // Auto-grab if configured
    if (this.config.autoGrabBestMatch) {
      this.grabRelease(wanted.id, result);
    }
  }

  private handleDownloadReady(wanted: WantedItem, result: SearchResult): void {
    console.log(`[MediaAutomation] Download ready: ${result.title}`);

    // Add to download queue
    const downloadItem = downloadQueueService.add(result, wanted);
    console.log(`[MediaAutomation] Added to queue: ${downloadItem.id}`);
  }

  private handleDownloadCompleted(item: DownloadItem): void {
    this.logActivity({
      type: 'downloaded',
      title: item.title,
      message: `Download completed (${this.formatBytes(item.size)})`,
      mediaType: item.wantedItem?.type || 'movie',
      quality: `${item.parsedRelease.resolution} ${item.parsedRelease.source}`,
    });
  }

  private handleDownloadFailed(item: DownloadItem, error: string): void {
    this.logActivity({
      type: 'failed',
      title: item.title,
      message: `Download failed: ${error}`,
      mediaType: item.wantedItem?.type || 'movie',
    });

    // Add health issue
    this.addHealthIssue({
      type: 'error',
      source: 'download_client',
      message: `Download failed for "${item.title}": ${error}`,
    });
  }

  private handleDownloadImported(item: DownloadItem, destPath: string): void {
    this.logActivity({
      type: 'imported',
      title: item.title,
      message: `Imported to library`,
      mediaType: item.wantedItem?.type || 'movie',
      quality: `${item.parsedRelease.resolution} ${item.parsedRelease.source}`,
    });
  }

  // ============================================================
  // MOVIE MANAGEMENT
  // ============================================================

  /**
   * Add a movie to the library and wanted list
   */
  async addMovie(options: {
    title: string;
    year: number;
    tmdbId?: number;
    imdbId?: string;
    qualityProfileId?: string;
    monitored?: boolean;
  }): Promise<AddMediaResult> {
    const profileId = options.qualityProfileId || this.config.defaultMovieProfileId;

    // Check if already exists
    if (options.imdbId && mediaLibraryService.getMovieByImdbId(options.imdbId)) {
      return { success: false, message: 'Movie already in library', searchStarted: false };
    }
    if (options.tmdbId && mediaLibraryService.getMovieByTmdbId(options.tmdbId)) {
      return { success: false, message: 'Movie already in library', searchStarted: false };
    }

    // Add to library
    const movie = mediaLibraryService.addMovie({
      title: options.title,
      year: options.year,
      tmdbId: options.tmdbId,
      imdbId: options.imdbId,
      status: 'released',
      monitored: options.monitored ?? true,
      hasFile: false,
      rootPath: mediaLibraryService.getRootPaths().movies,
      path: `${mediaLibraryService.getRootPaths().movies}/${mediaLibraryService.generateMovieFolderName(options)}`,
      qualityProfileId: profileId,
      minimumAvailability: 'released',
    });

    // Add to wanted list if monitored
    let searchStarted = false;
    if (movie.monitored) {
      releaseMonitorService.addWanted({
        type: 'movie',
        title: options.title,
        year: options.year,
        imdbId: options.imdbId,
        tmdbId: options.tmdbId,
        qualityProfileId: profileId,
        monitored: true,
      });

      if (this.config.autoSearchOnAdd) {
        searchStarted = true;
        // Search will be triggered by the wanted service
      }
    }

    this.logActivity({
      type: 'added',
      title: options.title,
      message: `Added to library${searchStarted ? ', searching...' : ''}`,
      mediaType: 'movie',
    });

    return {
      success: true,
      mediaId: movie.id,
      message: `Added "${options.title}" to library`,
      searchStarted,
    };
  }

  /**
   * Search for a movie manually
   */
  async searchMovie(movieId: string): Promise<SearchMediaResult> {
    const movie = mediaLibraryService.getMovie(movieId);
    if (!movie) {
      return { success: false, results: [], message: 'Movie not found' };
    }

    // Find the wanted item or create one
    const wantedItems = releaseMonitorService.getWantedItems();
    let wanted = wantedItems.find(w =>
      w.type === 'movie' &&
      (w.imdbId === movie.imdbId || w.tmdbId === movie.tmdbId)
    );

    if (!wanted) {
      wanted = releaseMonitorService.addWanted({
        type: 'movie',
        title: movie.title,
        year: movie.year,
        imdbId: movie.imdbId,
        tmdbId: movie.tmdbId,
        qualityProfileId: movie.qualityProfileId,
        monitored: movie.monitored,
      });
    }

    const results = await releaseMonitorService.searchForItem(wanted.id);

    return {
      success: results.length > 0,
      results,
      bestMatch: results[0],
      message: results.length > 0 ? `Found ${results.length} releases` : 'No releases found',
    };
  }

  // ============================================================
  // TV SHOW MANAGEMENT
  // ============================================================

  /**
   * Add a TV show to the library
   */
  async addTVShow(options: {
    title: string;
    year?: number;
    tvdbId?: number;
    imdbId?: string;
    qualityProfileId?: string;
    monitorStatus?: 'all' | 'future' | 'missing' | 'none';
    seasons?: { seasonNumber: number; monitored: boolean }[];
  }): Promise<AddMediaResult> {
    const profileId = options.qualityProfileId || this.config.defaultTVProfileId;

    // Check if already exists
    if (options.tvdbId && mediaLibraryService.getTVShowByTvdbId(options.tvdbId)) {
      return { success: false, message: 'TV show already in library', searchStarted: false };
    }

    // Add to library
    const show = mediaLibraryService.addTVShow({
      title: options.title,
      year: options.year,
      tvdbId: options.tvdbId,
      imdbId: options.imdbId,
      status: 'continuing',
      monitorStatus: options.monitorStatus || 'all',
      rootPath: mediaLibraryService.getRootPaths().tvShows,
      path: `${mediaLibraryService.getRootPaths().tvShows}/${mediaLibraryService.generateSeriesFolderName(options)}`,
      seasons: options.seasons?.map(s => ({
        seasonNumber: s.seasonNumber,
        monitored: s.monitored,
        episodes: [],
        statistics: { episodeCount: 0, episodeFileCount: 0, percentOfEpisodes: 0, sizeOnDisk: 0 },
      })) || [],
      qualityProfileId: profileId,
    });

    this.logActivity({
      type: 'added',
      title: options.title,
      message: `Added TV show to library`,
      mediaType: 'episode',
    });

    return {
      success: true,
      mediaId: show.id,
      message: `Added "${options.title}" to library`,
      searchStarted: false,
    };
  }

  /**
   * Search for a specific episode
   */
  async searchEpisode(showId: string, season: number, episode: number): Promise<SearchMediaResult> {
    const show = mediaLibraryService.getTVShow(showId);
    if (!show) {
      return { success: false, results: [], message: 'Show not found' };
    }

    // Add to wanted list
    const wanted = releaseMonitorService.addWanted({
      type: 'episode',
      title: show.title,
      season,
      episode,
      tvdbId: show.tvdbId,
      imdbId: show.imdbId,
      qualityProfileId: show.qualityProfileId,
      monitored: true,
    });

    const results = await releaseMonitorService.searchForItem(wanted.id);

    return {
      success: results.length > 0,
      results,
      bestMatch: results[0],
      message: results.length > 0 ? `Found ${results.length} releases` : 'No releases found',
    };
  }

  // ============================================================
  // RELEASE MANAGEMENT
  // ============================================================

  /**
   * Grab a specific release for download
   */
  async grabRelease(wantedId: string, result: SearchResult): Promise<boolean> {
    return releaseMonitorService.grabRelease(wantedId, result);
  }

  /**
   * Parse a release name
   */
  parseRelease(releaseName: string): ParsedRelease {
    return releaseParserService.parse(releaseName);
  }

  /**
   * Score a release against the active profile
   */
  scoreRelease(release: ParsedRelease, profileId?: string): number {
    const profile = profileId
      ? qualityProfileService.getProfile(profileId)
      : qualityProfileService.getActiveProfile();
    return qualityProfileService.scoreRelease(release, profile);
  }

  /**
   * Check if a release is acceptable for download
   */
  isAcceptable(release: ParsedRelease, profileId?: string): { acceptable: boolean; reason?: string } {
    const profile = profileId
      ? qualityProfileService.getProfile(profileId)
      : qualityProfileService.getActiveProfile();
    return qualityProfileService.isAcceptable(release, profile);
  }

  // ============================================================
  // INDEXER MANAGEMENT
  // ============================================================

  /**
   * Add an indexer
   */
  addIndexer(indexer: Omit<Indexer, 'id' | 'errorCount' | 'lastError'>): Indexer {
    return releaseMonitorService.addIndexer(indexer);
  }

  /**
   * Get all indexers
   */
  getIndexers(): Indexer[] {
    return releaseMonitorService.getIndexers();
  }

  /**
   * Test an indexer
   */
  async testIndexer(id: string): Promise<{ success: boolean; message: string }> {
    return releaseMonitorService.testIndexer(id);
  }

  // ============================================================
  // DOWNLOAD CLIENT MANAGEMENT
  // ============================================================

  /**
   * Add a download client
   */
  addDownloadClient(client: Omit<DownloadClient, 'id' | 'connected' | 'errorCount' | 'currentDownloads' | 'totalDownloading' | 'totalSeeding'>): DownloadClient {
    return downloadQueueService.addClient(client);
  }

  /**
   * Get all download clients
   */
  getDownloadClients(): DownloadClient[] {
    return downloadQueueService.getClients();
  }

  /**
   * Test a download client
   */
  async testDownloadClient(id: string): Promise<{ success: boolean; message: string }> {
    return downloadQueueService.testClient(id);
  }

  // ============================================================
  // QUEUE MANAGEMENT
  // ============================================================

  /**
   * Get the download queue
   */
  getQueue(): DownloadItem[] {
    return downloadQueueService.getSortedQueue();
  }

  /**
   * Get queue statistics
   */
  getQueueStats(): QueueStats {
    return downloadQueueService.getStats();
  }

  /**
   * Pause a download
   */
  pauseDownload(id: string): boolean {
    return downloadQueueService.pause(id);
  }

  /**
   * Resume a download
   */
  resumeDownload(id: string): boolean {
    return downloadQueueService.resume(id);
  }

  /**
   * Remove from queue
   */
  removeFromQueue(id: string, deleteFiles?: boolean): boolean {
    return downloadQueueService.remove(id, deleteFiles);
  }

  // ============================================================
  // STATUS & HEALTH
  // ============================================================

  /**
   * Get full automation status
   */
  getStatus(): AutomationStatus {
    const monitorStats = releaseMonitorService.getStats();
    const queueStats = downloadQueueService.getStats();
    const libraryStats = mediaLibraryService.getStats();

    return {
      enabled: this.config.enabled,
      started: this.started,
      lastCheck: this.lastCheck,

      monitoring: {
        active: this.started,
        indexersTotal: monitorStats.indexers.total,
        indexersHealthy: monitorStats.indexers.healthy,
        wantedItems: monitorStats.wanted.movies + monitorStats.wanted.episodes,
        lastRssSync: monitorStats.rss.lastRssSync || null,
      },

      queue: queueStats,

      library: {
        movies: libraryStats.movies.total,
        tvShows: libraryStats.tvShows.total,
        episodes: libraryStats.tvShows.episodesTotal,
        sizeOnDisk: libraryStats.movies.sizeOnDisk + libraryStats.tvShows.sizeOnDisk,
      },

      recentActivity: this.activityLog.slice(0, 20),
      healthIssues: this.healthIssues,
    };
  }

  /**
   * Run health check
   */
  runHealthCheck(): HealthIssue[] {
    this.healthIssues = [];

    // Check indexers
    const indexers = releaseMonitorService.getIndexers();
    const unhealthyIndexers = indexers.filter(i => i.enabled && i.errorCount > 0);
    for (const indexer of unhealthyIndexers) {
      this.addHealthIssue({
        type: 'warning',
        source: 'indexer',
        message: `Indexer "${indexer.name}" has errors: ${indexer.lastError}`,
      });
    }

    // Check download clients
    const clients = downloadQueueService.getClients();
    const disconnectedClients = clients.filter(c => c.enabled && !c.connected);
    for (const client of disconnectedClients) {
      this.addHealthIssue({
        type: 'error',
        source: 'download_client',
        message: `Download client "${client.name}" is disconnected`,
      });
    }

    // Check for failed downloads
    const failedDownloads = downloadQueueService.getQueue().filter(d => d.status === 'failed');
    if (failedDownloads.length > 0) {
      this.addHealthIssue({
        type: 'warning',
        source: 'download_client',
        message: `${failedDownloads.length} download(s) have failed`,
      });
    }

    // Check disk space (would need actual implementation)
    // ...

    return this.healthIssues;
  }

  // ============================================================
  // ACTIVITY LOG
  // ============================================================

  private logActivity(activity: Omit<ActivityItem, 'id' | 'timestamp'>): void {
    const item: ActivityItem = {
      ...activity,
      id: `activity-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      timestamp: new Date(),
    };

    this.activityLog.unshift(item);

    // Keep only last 100 entries
    if (this.activityLog.length > 100) {
      this.activityLog = this.activityLog.slice(0, 100);
    }

    // Notify if configured
    if (this.config.notifyOnGrab && activity.type === 'grabbed') {
      this.onNotification?.(item);
    }
    if (this.config.notifyOnDownload && activity.type === 'downloaded') {
      this.onNotification?.(item);
    }
    if (this.config.notifyOnUpgrade && activity.type === 'upgraded') {
      this.onNotification?.(item);
    }
  }

  private addHealthIssue(issue: Omit<HealthIssue, 'id' | 'timestamp'>): void {
    const healthIssue: HealthIssue = {
      ...issue,
      id: `health-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      timestamp: new Date(),
    };

    this.healthIssues.push(healthIssue);

    if (this.config.notifyOnHealth) {
      // Could trigger a notification here
    }
  }

  /**
   * Get recent activity
   */
  getActivityLog(limit: number = 20): ActivityItem[] {
    return this.activityLog.slice(0, limit);
  }

  // ============================================================
  // CONFIGURATION
  // ============================================================

  setConfig(config: Partial<AutomationConfig>): void {
    this.config = { ...this.config, ...config };
  }

  getConfig(): AutomationConfig {
    return { ...this.config };
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  setOnNotification(handler: (activity: ActivityItem) => void): void {
    this.onNotification = handler;
  }

  // ============================================================
  // UTILITIES
  // ============================================================

  private formatBytes(bytes: number): string {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
  }
}

export const mediaAutomationService = MediaAutomationService.getInstance();
