/**
 * Secure Configuration Service
 *
 * Manages API keys and credentials with:
 * - Default values from secrets.ts (can be empty)
 * - User overrides stored in localStorage (encrypted in future)
 * - Sync to cloud via sync-bridge for cross-device access
 * - Validation and testing of credentials
 */

import { SECRETS } from '../../config/secrets';

export interface AppConfiguration {
  // TMDB
  tmdb: {
    apiKey: string;
    accessToken: string;
  };

  // NordVPN
  nordvpn: {
    serviceUsername: string;
    servicePassword: string;
    accessToken: string;
    smartDNSEnabled: boolean;
    selectedProxyCountry: string;
    // User-specific SmartDNS servers (assigned by NordVPN per IP)
    smartDNSPrimary: string;
    smartDNSSecondary: string;
    smartDNSActivatedIP: string;
  };

  // Trakt
  trakt: {
    clientId: string;
    clientSecret: string;
    accessToken: string;
    refreshToken: string;
  };

  // Plex Media Server
  plex: {
    serverUrl: string;
    token: string;
    serverName: string;
  };

  // Sync Bridge
  syncBridge: {
    url: string;
    deviceToken: string;
  };

  // User preferences
  user: {
    country: string;
    preferredLanguages: string[];
    preferredQuality: '720p' | '1080p' | '4K';
    avoidAds: boolean;
  };
}

const DEFAULT_CONFIG: AppConfiguration = {
  tmdb: {
    apiKey: SECRETS.TMDB_API_KEY || '',
    accessToken: SECRETS.TMDB_ACCESS_TOKEN || '',
  },
  nordvpn: {
    serviceUsername: SECRETS.NORDVPN_SERVICE_USERNAME || '',
    servicePassword: SECRETS.NORDVPN_SERVICE_PASSWORD || '',
    accessToken: SECRETS.NORDVPN_ACCESS_TOKEN || '',
    smartDNSEnabled: true, // Already activated
    selectedProxyCountry: 'us',
    // User-specific SmartDNS (from NordVPN email)
    smartDNSPrimary: SECRETS.SMARTDNS_PRIMARY || '103.86.96.103',
    smartDNSSecondary: SECRETS.SMARTDNS_SECONDARY || '103.86.99.103',
    smartDNSActivatedIP: SECRETS.SMARTDNS_ACTIVATED_IP || '',
  },
  trakt: {
    clientId: SECRETS.TRAKT_CLIENT_ID || '',
    clientSecret: SECRETS.TRAKT_CLIENT_SECRET || '',
    accessToken: '',
    refreshToken: '',
  },
  plex: {
    serverUrl: SECRETS.PLEX_SERVER_URL || '',
    token: SECRETS.PLEX_TOKEN || '',
    serverName: SECRETS.PLEX_SERVER_NAME || 'MSM3U',
  },
  syncBridge: {
    url: SECRETS.SYNC_BRIDGE_URL || '',
    deviceToken: '',
  },
  user: {
    country: SECRETS.USER_COUNTRY || 'CH', // Switzerland
    preferredLanguages: ['en', 'fr', 'de'], // Common Swiss languages
    preferredQuality: '1080p',
    avoidAds: true,
  },
};

const STORAGE_KEY = 'thea_secure_config';

class SecureConfigService {
  private static instance: SecureConfigService;
  private config: AppConfiguration;
  private listeners: Set<(config: AppConfiguration) => void> = new Set();

  private constructor() {
    this.config = this.loadConfig();
    this.detectCountry();
  }

  static getInstance(): SecureConfigService {
    if (!SecureConfigService.instance) {
      SecureConfigService.instance = new SecureConfigService();
    }
    return SecureConfigService.instance;
  }

  /**
   * Load configuration from localStorage, merged with defaults
   */
  private loadConfig(): AppConfiguration {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        return this.deepMerge(DEFAULT_CONFIG, parsed);
      }
    } catch (error) {
      console.warn('Failed to load config:', error);
    }
    return { ...DEFAULT_CONFIG };
  }

  /**
   * Deep merge two objects
   */
  private deepMerge<T extends Record<string, any>>(target: T, source: Partial<T>): T {
    const result = { ...target };
    for (const key of Object.keys(source) as (keyof T)[]) {
      if (source[key] !== undefined) {
        if (typeof source[key] === 'object' && !Array.isArray(source[key])) {
          result[key] = this.deepMerge(target[key] as any, source[key] as any);
        } else {
          result[key] = source[key] as T[keyof T];
        }
      }
    }
    return result;
  }

  /**
   * Save configuration to localStorage
   */
  private saveConfig(): void {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(this.config));
      this.notifyListeners();
    } catch (error) {
      console.error('Failed to save config:', error);
    }
  }

  /**
   * Notify all listeners of config changes
   */
  private notifyListeners(): void {
    for (const listener of this.listeners) {
      listener(this.config);
    }
  }

  /**
   * Auto-detect user's country
   */
  private async detectCountry(): Promise<void> {
    try {
      const response = await fetch('https://ipapi.co/json/');
      if (response.ok) {
        const data = await response.json() as { country_code: string };
        if (data.country_code && !this.config.user.country) {
          this.config.user.country = data.country_code.toUpperCase();
          this.saveConfig();
        }
      }
    } catch (error) {
      console.warn('Could not detect country:', error);
    }
  }

  // ============================================================
  // GETTERS
  // ============================================================

  get(): AppConfiguration {
    return { ...this.config };
  }

  getTMDB(): AppConfiguration['tmdb'] {
    return { ...this.config.tmdb };
  }

  getNordVPN(): AppConfiguration['nordvpn'] {
    return { ...this.config.nordvpn };
  }

  getTrakt(): AppConfiguration['trakt'] {
    return { ...this.config.trakt };
  }

  getSyncBridge(): AppConfiguration['syncBridge'] {
    return { ...this.config.syncBridge };
  }

  getPlex(): AppConfiguration['plex'] {
    return { ...this.config.plex };
  }

  getUser(): AppConfiguration['user'] {
    return { ...this.config.user };
  }

  // ============================================================
  // SETTERS
  // ============================================================

  setTMDB(tmdb: Partial<AppConfiguration['tmdb']>): void {
    this.config.tmdb = { ...this.config.tmdb, ...tmdb };
    this.saveConfig();
  }

  setNordVPN(nordvpn: Partial<AppConfiguration['nordvpn']>): void {
    this.config.nordvpn = { ...this.config.nordvpn, ...nordvpn };
    this.saveConfig();
  }

  setTrakt(trakt: Partial<AppConfiguration['trakt']>): void {
    this.config.trakt = { ...this.config.trakt, ...trakt };
    this.saveConfig();
  }

  setSyncBridge(syncBridge: Partial<AppConfiguration['syncBridge']>): void {
    this.config.syncBridge = { ...this.config.syncBridge, ...syncBridge };
    this.saveConfig();
  }

  setPlex(plex: Partial<AppConfiguration['plex']>): void {
    this.config.plex = { ...this.config.plex, ...plex };
    this.saveConfig();
  }

  setUser(user: Partial<AppConfiguration['user']>): void {
    this.config.user = { ...this.config.user, ...user };
    this.saveConfig();
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  /**
   * Test TMDB credentials
   */
  async testTMDB(): Promise<{ success: boolean; error?: string }> {
    const { accessToken, apiKey } = this.config.tmdb;

    if (!accessToken && !apiKey) {
      return { success: false, error: 'No TMDB credentials configured' };
    }

    try {
      const url = 'https://api.themoviedb.org/3/configuration';
      const headers: Record<string, string> = { Accept: 'application/json' };

      if (accessToken) {
        headers['Authorization'] = `Bearer ${accessToken}`;
      }

      const response = await fetch(
        accessToken ? url : `${url}?api_key=${apiKey}`,
        { headers }
      );

      if (response.ok) {
        return { success: true };
      }

      return { success: false, error: `API returned ${response.status}` };
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
    }
  }

  /**
   * Test NordVPN credentials
   */
  async testNordVPN(): Promise<{ success: boolean; error?: string }> {
    const { serviceUsername, servicePassword, accessToken } = this.config.nordvpn;

    if (!serviceUsername && !accessToken) {
      return { success: false, error: 'No NordVPN credentials configured' };
    }

    // If we have an access token, try to fetch credentials
    if (accessToken) {
      try {
        const response = await fetch('https://api.nordvpn.com/v1/users/services/credentials', {
          headers: {
            'Authorization': `Basic ${btoa(`token:${accessToken}`)}`,
          },
        });

        if (response.ok) {
          return { success: true };
        }

        return { success: false, error: 'Invalid access token' };
      } catch (error) {
        return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
      }
    }

    // For service credentials, we can't easily test without making a proxy connection
    // Just verify they're not empty
    if (serviceUsername && servicePassword) {
      return { success: true };
    }

    return { success: false, error: 'Incomplete credentials' };
  }

  // ============================================================
  // CONVENIENCE METHODS
  // ============================================================

  /**
   * Check if TMDB is configured
   */
  isTMDBConfigured(): boolean {
    return !!(this.config.tmdb.accessToken || this.config.tmdb.apiKey);
  }

  /**
   * Check if NordVPN is configured
   */
  isNordVPNConfigured(): boolean {
    return !!(
      this.config.nordvpn.serviceUsername &&
      this.config.nordvpn.servicePassword
    );
  }

  /**
   * Check if SmartDNS is enabled
   */
  isSmartDNSEnabled(): boolean {
    return this.config.nordvpn.smartDNSEnabled;
  }

  /**
   * Check if Trakt is configured
   */
  isTraktConfigured(): boolean {
    return !!(this.config.trakt.clientId && this.config.trakt.accessToken);
  }

  /**
   * Subscribe to configuration changes
   */
  subscribe(listener: (config: AppConfiguration) => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  /**
   * Reset to defaults
   */
  reset(): void {
    this.config = { ...DEFAULT_CONFIG };
    this.saveConfig();
  }

  /**
   * Export configuration (for backup)
   */
  export(): string {
    return JSON.stringify(this.config, null, 2);
  }

  /**
   * Import configuration (from backup)
   */
  import(json: string): boolean {
    try {
      const parsed = JSON.parse(json);
      this.config = this.deepMerge(DEFAULT_CONFIG, parsed);
      this.saveConfig();
      return true;
    } catch (error) {
      console.error('Failed to import config:', error);
      return false;
    }
  }

  /**
   * Sync configuration to cloud (via sync-bridge)
   */
  async syncToCloud(): Promise<boolean> {
    const { url, deviceToken } = this.config.syncBridge;

    if (!url || !deviceToken) {
      console.warn('Sync bridge not configured');
      return false;
    }

    try {
      const response = await fetch(`${url}/settings/app-config`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Device-Token': deviceToken,
        },
        body: JSON.stringify({
          config: {
            // Don't sync sensitive credentials, only preferences
            user: this.config.user,
            nordvpn: {
              smartDNSEnabled: this.config.nordvpn.smartDNSEnabled,
              selectedProxyCountry: this.config.nordvpn.selectedProxyCountry,
            },
          },
        }),
      });

      return response.ok;
    } catch (error) {
      console.error('Failed to sync config:', error);
      return false;
    }
  }

  /**
   * Fetch configuration from cloud
   */
  async syncFromCloud(): Promise<boolean> {
    const { url, deviceToken } = this.config.syncBridge;

    if (!url || !deviceToken) {
      return false;
    }

    try {
      const response = await fetch(`${url}/settings/app-config`, {
        headers: {
          'X-Device-Token': deviceToken,
        },
      });

      if (response.ok) {
        const data = await response.json() as { config: Partial<AppConfiguration> };
        if (data.config) {
          // Merge cloud config with local (local credentials take precedence)
          if (data.config.user) {
            this.config.user = { ...this.config.user, ...data.config.user };
          }
          this.saveConfig();
          return true;
        }
      }
    } catch (error) {
      console.error('Failed to fetch config from cloud:', error);
    }

    return false;
  }
}

export const secureConfigService = SecureConfigService.getInstance();
