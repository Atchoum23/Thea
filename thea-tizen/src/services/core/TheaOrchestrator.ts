/**
 * Thea Orchestrator
 *
 * Central coordinator that manages all autonomous services:
 * - Health monitoring with self-healing
 * - Plex webhook processing for watch detection
 * - Download monitoring with notifications
 * - Episode monitoring and auto-downloads
 * - Content prediction and pre-caching
 * - IP monitoring for SmartDNS
 *
 * This is the "brain" of Thea that makes it proactive and autonomous.
 */

import { healthMonitorService, HealthSummary } from '../health/HealthMonitorService';
import { plexWebhookService, WatchSession } from '../webhooks/PlexWebhookService';
import { downloadMonitorService, DownloadCompletion, DownloadProgress } from '../downloads/DownloadMonitorService';
import { episodeMonitorService } from '../automation/EpisodeMonitorService';
import { contentPredictionService, PredictedContent } from '../prediction/ContentPredictionService';
import { ipMonitorService, IPCheckResult } from '../vpn/IPMonitorService';
import { secureConfigService } from '../config/SecureConfigService';

export interface OrchestratorState {
  isRunning: boolean;
  startTime: Date | null;
  health: HealthSummary | null;
  activeDownloads: DownloadProgress[];
  currentlyWatching: WatchSession | null;
  predictions: PredictedContent[];
  ipStatus: IPCheckResult | null;
  lastActivity: Date;
  notifications: TheaNotification[];
}

export interface TheaNotification {
  id: string;
  type: 'info' | 'success' | 'warning' | 'error';
  title: string;
  message: string;
  timestamp: Date;
  read: boolean;
  action?: {
    label: string;
    callback: () => void;
  };
}

type StateChangeListener = (state: OrchestratorState) => void;
type NotificationListener = (notification: TheaNotification) => void;

class TheaOrchestrator {
  private static instance: TheaOrchestrator;

  private state: OrchestratorState = {
    isRunning: false,
    startTime: null,
    health: null,
    activeDownloads: [],
    currentlyWatching: null,
    predictions: [],
    ipStatus: null,
    lastActivity: new Date(),
    notifications: [],
  };

  private stateListeners: Set<StateChangeListener> = new Set();
  private notificationListeners: Set<NotificationListener> = new Set();
  private cleanupFunctions: Array<() => void> = [];

  private constructor() {}

  static getInstance(): TheaOrchestrator {
    if (!TheaOrchestrator.instance) {
      TheaOrchestrator.instance = new TheaOrchestrator();
    }
    return TheaOrchestrator.instance;
  }

  /**
   * Start all autonomous services
   */
  async start(): Promise<void> {
    if (this.state.isRunning) {
      console.log('TheaOrchestrator: Already running');
      return;
    }

    console.log('TheaOrchestrator: Starting autonomous services...');
    this.state.isRunning = true;
    this.state.startTime = new Date();

    // 1. Start health monitoring first
    healthMonitorService.start();
    this.cleanupFunctions.push(() => healthMonitorService.stop());

    const healthUnsub = healthMonitorService.onHealthChange(health => {
      this.state.health = health;
      this.notifyStateChange();

      // Show alert if overall health degrades
      if (health.overallStatus === 'unhealthy') {
        this.addNotification({
          type: 'error',
          title: 'Service Issues Detected',
          message: `Some services are experiencing problems. Check Settings → Health for details.`,
        });
      }
    });
    this.cleanupFunctions.push(healthUnsub);

    const alertUnsub = healthMonitorService.onAlert(alert => {
      this.addNotification({
        type: alert.severity === 'error' ? 'error' : 'warning',
        title: alert.service,
        message: alert.message,
      });
    });
    this.cleanupFunctions.push(alertUnsub);

    // 2. Start Plex webhook service
    const syncConfig = secureConfigService.getSyncBridge();
    if (syncConfig.url) {
      plexWebhookService.start();
      this.cleanupFunctions.push(() => plexWebhookService.stop());

      const sessionUnsub = plexWebhookService.onSession(session => {
        this.state.currentlyWatching = session.state === 'playing' ? session : null;
        this.state.lastActivity = new Date();
        this.notifyStateChange();

        // Record watch for prediction learning
        if (session.isScrobbled) {
          contentPredictionService.recordWatch({
            showId: session.showTitle,
            season: session.season,
            episode: session.episode,
          });
        }
      });
      this.cleanupFunctions.push(sessionUnsub);
    }

    // 3. Start download monitoring
    downloadMonitorService.start();
    this.cleanupFunctions.push(() => downloadMonitorService.stop());

    const progressUnsub = downloadMonitorService.onProgress(downloads => {
      this.state.activeDownloads = downloads;
      this.notifyStateChange();
    });
    this.cleanupFunctions.push(progressUnsub);

    const completionUnsub = downloadMonitorService.onCompletion(completion => {
      this.addNotification({
        type: 'success',
        title: 'Download Complete',
        message: completion.name,
        action: {
          label: 'View',
          callback: () => {
            // Navigate to downloaded content
            console.log('Navigate to:', completion.savePath);
          },
        },
      });
    });
    this.cleanupFunctions.push(completionUnsub);

    const errorUnsub = downloadMonitorService.onError(error => {
      this.addNotification({
        type: 'error',
        title: 'Download Error',
        message: `${error.name}: ${error.error}`,
      });
    });
    this.cleanupFunctions.push(errorUnsub);

    // 4. Start episode monitoring
    episodeMonitorService.start();
    this.cleanupFunctions.push(() => episodeMonitorService.stop());

    // 5. Start IP monitoring for SmartDNS
    const nordConfig = secureConfigService.getNordVPN();
    if (nordConfig.smartDNSActivatedIP) {
      ipMonitorService.startMonitoring();
      this.cleanupFunctions.push(() => ipMonitorService.stopMonitoring());

      const ipUnsub = ipMonitorService.onIPChange(alert => {
        // Update IP status from the alert
        this.state.ipStatus = {
          ip: alert.currentIP,
          country: '',
          countryCode: '',
          timestamp: alert.timestamp,
        };
        this.notifyStateChange();

        if (alert.smartDNSAffected) {
          this.addNotification({
            type: 'warning',
            title: 'IP Address Changed',
            message: `SmartDNS may need reactivation. New IP: ${alert.currentIP}`,
            action: {
              label: 'Reactivate',
              callback: () => {
                // Open NordVPN SmartDNS activation page
                window.open(alert.activationUrl, '_blank');
              },
            },
          });
        }
      });
      this.cleanupFunctions.push(ipUnsub);

      // Check IP immediately
      const ipResult = await ipMonitorService.checkIP();
      if (ipResult) {
        this.state.ipStatus = ipResult;
      }
    }

    // 6. Generate initial predictions
    this.refreshPredictions();

    // 7. Periodic prediction refresh (every 30 minutes)
    const predictionInterval = setInterval(() => this.refreshPredictions(), 30 * 60 * 1000);
    this.cleanupFunctions.push(() => clearInterval(predictionInterval));

    // 8. Initial health check
    const initialHealth = await healthMonitorService.checkAll();
    this.state.health = initialHealth;

    this.addNotification({
      type: 'info',
      title: 'Thea Started',
      message: 'All autonomous services are now running.',
    });

    this.notifyStateChange();
    console.log('TheaOrchestrator: All services started');
  }

  /**
   * Stop all services
   */
  stop(): void {
    console.log('TheaOrchestrator: Stopping services...');

    for (const cleanup of this.cleanupFunctions) {
      try {
        cleanup();
      } catch (error) {
        console.error('TheaOrchestrator: Cleanup error', error);
      }
    }
    this.cleanupFunctions = [];

    this.state.isRunning = false;
    this.notifyStateChange();

    console.log('TheaOrchestrator: All services stopped');
  }

  /**
   * Refresh content predictions
   */
  async refreshPredictions(): Promise<void> {
    try {
      const predictions = await contentPredictionService.generatePredictions(10);
      this.state.predictions = predictions;
      this.notifyStateChange();
    } catch (error) {
      console.warn('TheaOrchestrator: Failed to refresh predictions', error);
    }
  }

  /**
   * Add a notification
   */
  private addNotification(notification: Omit<TheaNotification, 'id' | 'timestamp' | 'read'>): void {
    const newNotification: TheaNotification = {
      ...notification,
      id: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      timestamp: new Date(),
      read: false,
    };

    this.state.notifications.unshift(newNotification);

    // Keep only last 50 notifications
    if (this.state.notifications.length > 50) {
      this.state.notifications = this.state.notifications.slice(0, 50);
    }

    // Notify listeners
    for (const listener of this.notificationListeners) {
      try {
        listener(newNotification);
      } catch (error) {
        console.error('TheaOrchestrator: Notification listener error', error);
      }
    }

    this.notifyStateChange();
  }

  /**
   * Mark notification as read
   */
  markNotificationRead(id: string): void {
    const notification = this.state.notifications.find(n => n.id === id);
    if (notification) {
      notification.read = true;
      this.notifyStateChange();
    }
  }

  /**
   * Mark all notifications as read
   */
  markAllNotificationsRead(): void {
    for (const notification of this.state.notifications) {
      notification.read = true;
    }
    this.notifyStateChange();
  }

  /**
   * Clear all notifications
   */
  clearNotifications(): void {
    this.state.notifications = [];
    this.notifyStateChange();
  }

  /**
   * Get current state
   */
  getState(): OrchestratorState {
    return { ...this.state };
  }

  /**
   * Get unread notification count
   */
  getUnreadCount(): number {
    return this.state.notifications.filter(n => !n.read).length;
  }

  /**
   * Subscribe to state changes
   */
  onStateChange(listener: StateChangeListener): () => void {
    this.stateListeners.add(listener);
    // Immediately call with current state
    listener(this.state);
    return () => this.stateListeners.delete(listener);
  }

  /**
   * Subscribe to new notifications
   */
  onNotification(listener: NotificationListener): () => void {
    this.notificationListeners.add(listener);
    return () => this.notificationListeners.delete(listener);
  }

  /**
   * Notify state change
   */
  private notifyStateChange(): void {
    for (const listener of this.stateListeners) {
      try {
        listener(this.state);
      } catch (error) {
        console.error('TheaOrchestrator: State listener error', error);
      }
    }
  }

  /**
   * Trigger manual episode check
   */
  async checkEpisodesNow(): Promise<void> {
    await episodeMonitorService.runCheck();
  }

  /**
   * Check if a feature is available based on health
   */
  isFeatureAvailable(feature: string): boolean {
    return healthMonitorService.isFeatureAvailable(feature);
  }
}

export const theaOrchestrator = TheaOrchestrator.getInstance();
