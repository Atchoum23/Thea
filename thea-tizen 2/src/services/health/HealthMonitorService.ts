/**
 * Health Monitor Service
 *
 * Monitors all Thea services and external dependencies for:
 * - Connection status (Plex, Sync Bridge, APIs)
 * - Service health (response times, error rates)
 * - Automatic recovery (retries, reconnection)
 * - User notifications when issues are detected
 *
 * Provides self-healing capabilities to ensure reliability.
 */

import { secureConfigService } from '../config/SecureConfigService';

export interface ServiceHealth {
  id: string;
  name: string;
  status: 'healthy' | 'degraded' | 'unhealthy' | 'unknown';
  lastCheck: Date;
  lastSuccess: Date | null;
  responseTimeMs: number | null;
  errorCount: number;
  consecutiveFailures: number;
  lastError: string | null;
  isRecovering: boolean;
}

export interface HealthSummary {
  overallStatus: 'healthy' | 'degraded' | 'unhealthy';
  services: ServiceHealth[];
  lastFullCheck: Date;
  uptime: number; // seconds since app start
}

type HealthChangeListener = (summary: HealthSummary) => void;
type AlertListener = (alert: { service: string; message: string; severity: 'warning' | 'error' }) => void;

interface HealthCheckConfig {
  id: string;
  name: string;
  check: () => Promise<{ ok: boolean; responseTime: number; error?: string }>;
  interval: number; // ms
  timeout: number; // ms
  criticalFor: string[]; // Features that depend on this service
  autoRecover?: () => Promise<boolean>;
}

class HealthMonitorService {
  private static instance: HealthMonitorService;

  private healthStates: Map<string, ServiceHealth> = new Map();
  private checkConfigs: Map<string, HealthCheckConfig> = new Map();
  private checkIntervals: Map<string, ReturnType<typeof setInterval>> = new Map();
  private healthListeners: Set<HealthChangeListener> = new Set();
  private alertListeners: Set<AlertListener> = new Set();
  private startTime: Date = new Date();
  private isRunning = false;

  private constructor() {
    this.registerDefaultChecks();
  }

  static getInstance(): HealthMonitorService {
    if (!HealthMonitorService.instance) {
      HealthMonitorService.instance = new HealthMonitorService();
    }
    return HealthMonitorService.instance;
  }

  /**
   * Register default health checks
   */
  private registerDefaultChecks(): void {
    // Sync Bridge health check
    this.registerCheck({
      id: 'sync-bridge',
      name: 'Sync Bridge',
      interval: 30000, // 30s
      timeout: 5000,
      criticalFor: ['downloads', 'cross-device-sync', 'notifications'],
      check: async () => {
        const start = Date.now();
        const config = secureConfigService.getSyncBridge();
        if (!config.url) {
          return { ok: false, responseTime: 0, error: 'Not configured' };
        }
        try {
          const response = await fetch(`${config.url}/health`, {
            signal: AbortSignal.timeout(5000),
          });
          return {
            ok: response.ok,
            responseTime: Date.now() - start,
            error: response.ok ? undefined : `HTTP ${response.status}`,
          };
        } catch (error) {
          return {
            ok: false,
            responseTime: Date.now() - start,
            error: error instanceof Error ? error.message : 'Unknown error',
          };
        }
      },
      autoRecover: async () => {
        // Try to re-establish connection
        const config = secureConfigService.getSyncBridge();
        if (!config.url) return false;
        try {
          const response = await fetch(`${config.url}/health`);
          return response.ok;
        } catch {
          return false;
        }
      },
    });

    // Plex health check
    this.registerCheck({
      id: 'plex',
      name: 'Plex Media Server',
      interval: 60000, // 1min
      timeout: 10000,
      criticalFor: ['library-check', 'watch-detection', 'scrobbling'],
      check: async () => {
        const start = Date.now();
        const config = secureConfigService.getPlex();
        if (!config.serverUrl || !config.token) {
          return { ok: false, responseTime: 0, error: 'Not configured' };
        }
        try {
          const response = await fetch(`${config.serverUrl}/identity`, {
            headers: { 'X-Plex-Token': config.token },
            signal: AbortSignal.timeout(10000),
          });
          return {
            ok: response.ok,
            responseTime: Date.now() - start,
            error: response.ok ? undefined : `HTTP ${response.status}`,
          };
        } catch (error) {
          return {
            ok: false,
            responseTime: Date.now() - start,
            error: error instanceof Error ? error.message : 'Unknown error',
          };
        }
      },
    });

    // TMDB health check
    this.registerCheck({
      id: 'tmdb',
      name: 'TMDB API',
      interval: 120000, // 2min
      timeout: 5000,
      criticalFor: ['streaming-availability', 'metadata', 'search'],
      check: async () => {
        const start = Date.now();
        const config = secureConfigService.getTMDB();
        if (!config.apiKey && !config.accessToken) {
          return { ok: false, responseTime: 0, error: 'Not configured' };
        }
        try {
          const headers: Record<string, string> = { Accept: 'application/json' };
          let url = 'https://api.themoviedb.org/3/configuration';
          if (config.accessToken) {
            headers['Authorization'] = `Bearer ${config.accessToken}`;
          } else {
            url += `?api_key=${config.apiKey}`;
          }
          const response = await fetch(url, {
            headers,
            signal: AbortSignal.timeout(5000),
          });
          return {
            ok: response.ok,
            responseTime: Date.now() - start,
            error: response.ok ? undefined : `HTTP ${response.status}`,
          };
        } catch (error) {
          return {
            ok: false,
            responseTime: Date.now() - start,
            error: error instanceof Error ? error.message : 'Unknown error',
          };
        }
      },
    });

    // Trakt health check
    this.registerCheck({
      id: 'trakt',
      name: 'Trakt.tv',
      interval: 120000, // 2min
      timeout: 5000,
      criticalFor: ['episode-tracking', 'calendar', 'recommendations'],
      check: async () => {
        const start = Date.now();
        const config = secureConfigService.getTrakt();
        if (!config.clientId) {
          return { ok: false, responseTime: 0, error: 'Not configured' };
        }
        try {
          const response = await fetch('https://api.trakt.tv/users/settings', {
            headers: {
              'Content-Type': 'application/json',
              'trakt-api-key': config.clientId,
              'trakt-api-version': '2',
              ...(config.accessToken ? { 'Authorization': `Bearer ${config.accessToken}` } : {}),
            },
            signal: AbortSignal.timeout(5000),
          });
          // 401 just means not authenticated yet, API is still healthy
          return {
            ok: response.ok || response.status === 401,
            responseTime: Date.now() - start,
            error: response.ok || response.status === 401 ? undefined : `HTTP ${response.status}`,
          };
        } catch (error) {
          return {
            ok: false,
            responseTime: Date.now() - start,
            error: error instanceof Error ? error.message : 'Unknown error',
          };
        }
      },
    });

    // SmartDNS / IP check
    this.registerCheck({
      id: 'smartdns',
      name: 'SmartDNS',
      interval: 300000, // 5min
      timeout: 10000,
      criticalFor: ['geo-unblocking', 'streaming'],
      check: async () => {
        const start = Date.now();
        const config = secureConfigService.getNordVPN();
        if (!config.smartDNSActivatedIP) {
          return { ok: false, responseTime: 0, error: 'Not configured' };
        }
        try {
          const response = await fetch('https://ipv4.icanhazip.com/', {
            signal: AbortSignal.timeout(10000),
          });
          if (!response.ok) {
            return { ok: false, responseTime: Date.now() - start, error: 'IP check failed' };
          }
          const currentIP = (await response.text()).trim();
          const matches = currentIP === config.smartDNSActivatedIP;
          return {
            ok: matches,
            responseTime: Date.now() - start,
            error: matches ? undefined : `IP changed: ${currentIP} (expected: ${config.smartDNSActivatedIP})`,
          };
        } catch (error) {
          return {
            ok: false,
            responseTime: Date.now() - start,
            error: error instanceof Error ? error.message : 'Unknown error',
          };
        }
      },
    });

    // Network connectivity check
    this.registerCheck({
      id: 'network',
      name: 'Internet',
      interval: 30000, // 30s
      timeout: 5000,
      criticalFor: ['all'],
      check: async () => {
        const start = Date.now();
        try {
          // Use multiple endpoints for redundancy
          const endpoints = [
            'https://www.google.com/generate_204',
            'https://connectivity-check.ubuntu.com/',
          ];
          for (const url of endpoints) {
            try {
              const response = await fetch(url, {
                method: 'HEAD',
                signal: AbortSignal.timeout(3000),
              });
              if (response.ok || response.status === 204) {
                return { ok: true, responseTime: Date.now() - start };
              }
            } catch {
              continue;
            }
          }
          return { ok: false, responseTime: Date.now() - start, error: 'No connectivity' };
        } catch (error) {
          return {
            ok: false,
            responseTime: Date.now() - start,
            error: error instanceof Error ? error.message : 'Unknown error',
          };
        }
      },
    });
  }

  /**
   * Register a health check
   */
  registerCheck(config: HealthCheckConfig): void {
    this.checkConfigs.set(config.id, config);
    this.healthStates.set(config.id, {
      id: config.id,
      name: config.name,
      status: 'unknown',
      lastCheck: new Date(),
      lastSuccess: null,
      responseTimeMs: null,
      errorCount: 0,
      consecutiveFailures: 0,
      lastError: null,
      isRecovering: false,
    });
  }

  /**
   * Start health monitoring
   */
  start(): void {
    if (this.isRunning) return;
    this.isRunning = true;
    this.startTime = new Date();

    console.log('HealthMonitorService: Starting health monitoring');

    for (const [id, config] of this.checkConfigs) {
      // Run initial check
      this.runCheck(id);

      // Schedule periodic checks
      const interval = setInterval(() => this.runCheck(id), config.interval);
      this.checkIntervals.set(id, interval);
    }
  }

  /**
   * Stop health monitoring
   */
  stop(): void {
    this.isRunning = false;
    for (const interval of this.checkIntervals.values()) {
      clearInterval(interval);
    }
    this.checkIntervals.clear();
    console.log('HealthMonitorService: Stopped health monitoring');
  }

  /**
   * Run a health check
   */
  private async runCheck(id: string): Promise<void> {
    const config = this.checkConfigs.get(id);
    const state = this.healthStates.get(id);
    if (!config || !state) return;

    try {
      const result = await config.check();
      state.lastCheck = new Date();
      state.responseTimeMs = result.responseTime;

      if (result.ok) {
        state.lastSuccess = new Date();
        state.consecutiveFailures = 0;
        state.lastError = null;
        state.status = 'healthy';
        state.isRecovering = false;
      } else {
        state.errorCount++;
        state.consecutiveFailures++;
        state.lastError = result.error || 'Unknown error';

        // Determine status based on failure count
        if (state.consecutiveFailures >= 3) {
          state.status = 'unhealthy';
          this.notifyAlert({
            service: config.name,
            message: `Service is unreachable: ${state.lastError}`,
            severity: 'error',
          });

          // Attempt auto-recovery
          if (config.autoRecover && !state.isRecovering) {
            state.isRecovering = true;
            console.log(`HealthMonitorService: Attempting recovery for ${config.name}`);
            const recovered = await config.autoRecover();
            if (recovered) {
              console.log(`HealthMonitorService: ${config.name} recovered`);
              state.status = 'healthy';
              state.consecutiveFailures = 0;
            }
            state.isRecovering = false;
          }
        } else if (state.consecutiveFailures >= 1) {
          state.status = 'degraded';
          if (state.consecutiveFailures === 1) {
            this.notifyAlert({
              service: config.name,
              message: `Service experiencing issues: ${state.lastError}`,
              severity: 'warning',
            });
          }
        }
      }

      this.healthStates.set(id, state);
      this.notifyHealthChange();
    } catch (error) {
      console.error(`HealthMonitorService: Check failed for ${id}`, error);
    }
  }

  /**
   * Force immediate check of all services
   */
  async checkAll(): Promise<HealthSummary> {
    await Promise.all(
      Array.from(this.checkConfigs.keys()).map(id => this.runCheck(id))
    );
    return this.getSummary();
  }

  /**
   * Get health summary
   */
  getSummary(): HealthSummary {
    const services = Array.from(this.healthStates.values());
    const unhealthyCount = services.filter(s => s.status === 'unhealthy').length;
    const degradedCount = services.filter(s => s.status === 'degraded').length;

    let overallStatus: HealthSummary['overallStatus'] = 'healthy';
    if (unhealthyCount > 0) {
      overallStatus = 'unhealthy';
    } else if (degradedCount > 0) {
      overallStatus = 'degraded';
    }

    return {
      overallStatus,
      services,
      lastFullCheck: new Date(),
      uptime: Math.floor((Date.now() - this.startTime.getTime()) / 1000),
    };
  }

  /**
   * Get status of a specific service
   */
  getServiceHealth(id: string): ServiceHealth | undefined {
    return this.healthStates.get(id);
  }

  /**
   * Check if a feature's dependencies are healthy
   */
  isFeatureAvailable(feature: string): boolean {
    for (const [id, config] of this.checkConfigs) {
      if (config.criticalFor.includes(feature) || config.criticalFor.includes('all')) {
        const state = this.healthStates.get(id);
        if (state?.status === 'unhealthy') {
          return false;
        }
      }
    }
    return true;
  }

  /**
   * Notify health change listeners
   */
  private notifyHealthChange(): void {
    const summary = this.getSummary();
    for (const listener of this.healthListeners) {
      try {
        listener(summary);
      } catch (error) {
        console.error('HealthMonitorService: Listener error', error);
      }
    }
  }

  /**
   * Notify alert listeners
   */
  private notifyAlert(alert: { service: string; message: string; severity: 'warning' | 'error' }): void {
    for (const listener of this.alertListeners) {
      try {
        listener(alert);
      } catch (error) {
        console.error('HealthMonitorService: Alert listener error', error);
      }
    }
  }

  // Subscription methods
  onHealthChange(listener: HealthChangeListener): () => void {
    this.healthListeners.add(listener);
    return () => this.healthListeners.delete(listener);
  }

  onAlert(listener: AlertListener): () => void {
    this.alertListeners.add(listener);
    return () => this.alertListeners.delete(listener);
  }
}

export const healthMonitorService = HealthMonitorService.getInstance();
