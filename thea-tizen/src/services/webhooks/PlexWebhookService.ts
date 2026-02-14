/**
 * Plex Webhook Service
 *
 * Listens for Plex webhooks to detect what you're watching in real-time.
 * This enables:
 * - Automatic Trakt scrobbling
 * - "Continue Watching" awareness
 * - Duplicate download prevention
 * - Ambient lighting control (via Home Assistant)
 *
 * Webhooks are processed via Sync Bridge (Cloudflare Worker acts as webhook receiver)
 *
 * @see https://support.plex.tv/articles/115002267687-webhooks/
 */

import { secureConfigService } from '../config/SecureConfigService';

// Plex webhook event types
export type PlexWebhookEvent =
  | 'media.play'
  | 'media.pause'
  | 'media.resume'
  | 'media.stop'
  | 'media.scrobble' // 90%+ watched
  | 'media.rate'
  | 'library.on.deck'
  | 'library.new';

export interface PlexWebhookPayload {
  event: PlexWebhookEvent;
  user: boolean; // Is the webhook for the server owner
  owner: boolean;
  Account: {
    id: number;
    thumb: string;
    title: string; // Username
  };
  Server: {
    title: string;
    uuid: string;
  };
  Player: {
    local: boolean;
    publicAddress: string;
    title: string; // Device name
    uuid: string;
  };
  Metadata: {
    librarySectionType: 'movie' | 'show';
    ratingKey: string;
    key: string;
    parentRatingKey?: string; // For episodes
    grandparentRatingKey?: string; // For episodes (show ID)
    guid: string; // e.g., "plex://movie/5e163f7e96531500203bd53b"
    parentGuid?: string;
    grandparentGuid?: string;
    type: 'movie' | 'episode' | 'track';
    title: string;
    grandparentTitle?: string; // Show title for episodes
    parentTitle?: string; // Season for episodes
    parentIndex?: number; // Season number
    index?: number; // Episode number
    year?: number;
    duration?: number;
    viewOffset?: number; // Current playback position
    Guid?: Array<{ id: string }>; // External IDs (imdb, tmdb, tvdb)
  };
}

export interface WatchSession {
  id: string;
  mediaType: 'movie' | 'episode';
  title: string;
  showTitle?: string;
  season?: number;
  episode?: number;
  year?: number;
  externalIds: {
    imdb?: string;
    tmdb?: string;
    tvdb?: string;
  };
  startTime: Date;
  lastUpdate: Date;
  state: 'playing' | 'paused' | 'stopped';
  progress: number; // 0-100
  duration: number; // ms
  device: string;
  isScrobbled: boolean;
}

type WebhookListener = (payload: PlexWebhookPayload) => void;
type SessionListener = (session: WatchSession) => void;

class PlexWebhookService {
  private static instance: PlexWebhookService;
  private webhookListeners: Set<WebhookListener> = new Set();
  private sessionListeners: Set<SessionListener> = new Set();
  private activeSessions: Map<string, WatchSession> = new Map();
  private pollInterval: ReturnType<typeof setInterval> | null = null;
  private lastPollTime: number = 0;

  private constructor() {
    this.loadSessions();
  }

  static getInstance(): PlexWebhookService {
    if (!PlexWebhookService.instance) {
      PlexWebhookService.instance = new PlexWebhookService();
    }
    return PlexWebhookService.instance;
  }

  /**
   * Start polling for webhook events from Sync Bridge
   */
  start(intervalMs: number = 5000): void {
    if (this.pollInterval) return;

    console.log('PlexWebhookService: Starting webhook polling');
    this.pollInterval = setInterval(() => this.pollWebhooks(), intervalMs);
    this.pollWebhooks(); // Initial poll
  }

  /**
   * Stop polling
   */
  stop(): void {
    if (this.pollInterval) {
      clearInterval(this.pollInterval);
      this.pollInterval = null;
      console.log('PlexWebhookService: Stopped webhook polling');
    }
  }

  /**
   * Poll Sync Bridge for new webhook events
   */
  private async pollWebhooks(): Promise<void> {
    const syncConfig = secureConfigService.getSyncBridge();
    if (!syncConfig.url) return;

    try {
      const response = await fetch(
        `${syncConfig.url}/webhooks/plex?since=${this.lastPollTime}`,
        {
          headers: {
            'X-Device-Token': syncConfig.deviceToken,
          },
        }
      );

      if (!response.ok) return;

      const data = await response.json() as { events: PlexWebhookPayload[]; timestamp: number };
      this.lastPollTime = data.timestamp;

      for (const event of data.events || []) {
        this.processWebhook(event);
      }
    } catch (error) {
      console.warn('PlexWebhookService: Poll failed', error);
    }
  }

  /**
   * Process a webhook event
   */
  private processWebhook(payload: PlexWebhookPayload): void {
    console.log(`PlexWebhookService: Received ${payload.event}`, payload.Metadata?.title);

    // Notify raw webhook listeners
    for (const listener of this.webhookListeners) {
      try {
        listener(payload);
      } catch (error) {
        console.error('PlexWebhookService: Listener error', error);
      }
    }

    // Update session tracking
    this.updateSession(payload);
  }

  /**
   * Update session tracking based on webhook
   */
  private updateSession(payload: PlexWebhookPayload): void {
    const { event, Metadata, Player } = payload;
    if (!Metadata || !Player) return;

    const sessionId = `${Player.uuid}-${Metadata.ratingKey}`;

    // Extract external IDs
    const externalIds: WatchSession['externalIds'] = {};
    for (const guid of Metadata.Guid || []) {
      if (guid.id.startsWith('imdb://')) {
        externalIds.imdb = guid.id.replace('imdb://', '');
      } else if (guid.id.startsWith('tmdb://')) {
        externalIds.tmdb = guid.id.replace('tmdb://', '');
      } else if (guid.id.startsWith('tvdb://')) {
        externalIds.tvdb = guid.id.replace('tvdb://', '');
      }
    }

    let session = this.activeSessions.get(sessionId);

    if (event === 'media.play' || event === 'media.resume') {
      if (!session) {
        session = {
          id: sessionId,
          mediaType: Metadata.type === 'episode' ? 'episode' : 'movie',
          title: Metadata.type === 'episode'
            ? `${Metadata.grandparentTitle} S${Metadata.parentIndex}E${Metadata.index}`
            : Metadata.title,
          showTitle: Metadata.grandparentTitle,
          season: Metadata.parentIndex,
          episode: Metadata.index,
          year: Metadata.year,
          externalIds,
          startTime: new Date(),
          lastUpdate: new Date(),
          state: 'playing',
          progress: Metadata.duration
            ? Math.round(((Metadata.viewOffset || 0) / Metadata.duration) * 100)
            : 0,
          duration: Metadata.duration || 0,
          device: Player.title,
          isScrobbled: false,
        };
        this.activeSessions.set(sessionId, session);
      } else {
        session.state = 'playing';
        session.lastUpdate = new Date();
        session.progress = Metadata.duration
          ? Math.round(((Metadata.viewOffset || 0) / Metadata.duration) * 100)
          : session.progress;
      }
    } else if (event === 'media.pause') {
      if (session) {
        session.state = 'paused';
        session.lastUpdate = new Date();
      }
    } else if (event === 'media.stop') {
      if (session) {
        session.state = 'stopped';
        session.lastUpdate = new Date();
        // Keep session for a while before removing
        setTimeout(() => this.activeSessions.delete(sessionId), 60000);
      }
    } else if (event === 'media.scrobble') {
      if (session) {
        session.isScrobbled = true;
        session.progress = 100;
        session.lastUpdate = new Date();
      }
    }

    // Notify session listeners
    if (session) {
      this.saveSessions();
      for (const listener of this.sessionListeners) {
        try {
          listener(session);
        } catch (error) {
          console.error('PlexWebhookService: Session listener error', error);
        }
      }
    }
  }

  /**
   * Get active sessions
   */
  getActiveSessions(): WatchSession[] {
    return Array.from(this.activeSessions.values())
      .filter(s => s.state !== 'stopped');
  }

  /**
   * Get recently watched (scrobbled) items
   */
  getRecentlyWatched(): WatchSession[] {
    return Array.from(this.activeSessions.values())
      .filter(s => s.isScrobbled)
      .sort((a, b) => b.lastUpdate.getTime() - a.lastUpdate.getTime());
  }

  /**
   * Check if something is currently being watched
   */
  isWatching(tmdbId?: string, imdbId?: string): boolean {
    return Array.from(this.activeSessions.values()).some(s => {
      if (s.state === 'stopped') return false;
      if (tmdbId && s.externalIds.tmdb === tmdbId) return true;
      if (imdbId && s.externalIds.imdb === imdbId) return true;
      return false;
    });
  }

  /**
   * Subscribe to raw webhook events
   */
  onWebhook(listener: WebhookListener): () => void {
    this.webhookListeners.add(listener);
    return () => this.webhookListeners.delete(listener);
  }

  /**
   * Subscribe to session updates
   */
  onSession(listener: SessionListener): () => void {
    this.sessionListeners.add(listener);
    return () => this.sessionListeners.delete(listener);
  }

  /**
   * Persist sessions to localStorage
   */
  private saveSessions(): void {
    try {
      const sessions = Array.from(this.activeSessions.entries());
      localStorage.setItem('thea_plex_sessions', JSON.stringify(sessions));
    } catch { /* ignore */ }
  }

  /**
   * Load sessions from localStorage
   */
  private loadSessions(): void {
    try {
      const stored = localStorage.getItem('thea_plex_sessions');
      if (stored) {
        const sessions = JSON.parse(stored) as [string, WatchSession][];
        for (const [key, session] of sessions) {
          session.startTime = new Date(session.startTime);
          session.lastUpdate = new Date(session.lastUpdate);
          // Only restore recent sessions (last 24h)
          if (Date.now() - session.lastUpdate.getTime() < 24 * 60 * 60 * 1000) {
            this.activeSessions.set(key, session);
          }
        }
      }
    } catch { /* ignore */ }
  }
}

export const plexWebhookService = PlexWebhookService.getInstance();
