/**
 * NordVPN Proxy Service
 *
 * Since Samsung Tizen does NOT support native VPN apps and the VPN API
 * is only available to native applications (not web apps), we use
 * NordVPN's SOCKS5 proxy servers as an alternative.
 *
 * IMPORTANT LIMITATIONS:
 * 1. SOCKS5 proxy only works for apps that can be configured to use a proxy
 * 2. The Netflix/Disney+/Prime apps on Samsung TV CANNOT be proxied this way
 * 3. For streaming app geo-unblocking, you need either:
 *    - Router-level VPN
 *    - SmartDNS (which CAN be configured on the TV's network settings)
 *
 * This service is useful for:
 * - Routing Thea's own API calls through different countries
 * - Configuring qBittorrent proxy (already supported)
 * - Future: If Samsung allows system-wide proxy settings
 *
 * BEST SOLUTION FOR YOUR USE CASE:
 * Use NordVPN SmartDNS - it CAN be configured directly on Samsung TV
 * and works with streaming apps like Netflix, Prime, etc.
 *
 * AUTHENTICATION:
 * NordVPN uses Nord Account (OAuth 2.0 / OpenID Connect 1.0).
 * For this app, users can:
 * 1. Sign in via browser and get an access token
 * 2. Enter their service credentials manually from the NordVPN dashboard
 *
 * @see https://my.nordaccount.com/dashboard/nordvpn/manual-configuration
 */

import { SYNC_BRIDGE_URL } from '../../config/constants';
import { secureConfigService } from '../config/SecureConfigService';

export interface NordVPNCredentials {
  // Service credentials (different from login credentials!)
  username: string;
  password: string;
  // Optional: Access token for API calls
  accessToken?: string;
}

export interface ProxyServer {
  hostname: string;
  country: string;
  countryCode: string;
  city?: string;
  port: number;
  type: 'socks5' | 'http';
}

export interface SmartDNSConfig {
  primary: string;
  secondary: string;
  // Instructions for TV settings
  setupInstructions: string[];
}

// NordVPN SOCKS5 Proxy Servers
const NORDVPN_SOCKS5_SERVERS: ProxyServer[] = [
  // United States
  { hostname: 'us.socks.nordhold.net', country: 'United States', countryCode: 'us', port: 1080, type: 'socks5' },
  { hostname: 'atlanta.us.socks.nordhold.net', country: 'United States', countryCode: 'us', city: 'Atlanta', port: 1080, type: 'socks5' },
  { hostname: 'chicago.us.socks.nordhold.net', country: 'United States', countryCode: 'us', city: 'Chicago', port: 1080, type: 'socks5' },
  { hostname: 'dallas.us.socks.nordhold.net', country: 'United States', countryCode: 'us', city: 'Dallas', port: 1080, type: 'socks5' },
  { hostname: 'los-angeles.us.socks.nordhold.net', country: 'United States', countryCode: 'us', city: 'Los Angeles', port: 1080, type: 'socks5' },
  { hostname: 'new-york.us.socks.nordhold.net', country: 'United States', countryCode: 'us', city: 'New York', port: 1080, type: 'socks5' },
  { hostname: 'phoenix.us.socks.nordhold.net', country: 'United States', countryCode: 'us', city: 'Phoenix', port: 1080, type: 'socks5' },
  { hostname: 'san-francisco.us.socks.nordhold.net', country: 'United States', countryCode: 'us', city: 'San Francisco', port: 1080, type: 'socks5' },
  // Netherlands
  { hostname: 'nl.socks.nordhold.net', country: 'Netherlands', countryCode: 'nl', port: 1080, type: 'socks5' },
  { hostname: 'amsterdam.nl.socks.nordhold.net', country: 'Netherlands', countryCode: 'nl', city: 'Amsterdam', port: 1080, type: 'socks5' },
  // Sweden
  { hostname: 'se.socks.nordhold.net', country: 'Sweden', countryCode: 'se', port: 1080, type: 'socks5' },
  { hostname: 'stockholm.se.socks.nordhold.net', country: 'Sweden', countryCode: 'se', city: 'Stockholm', port: 1080, type: 'socks5' },
];

// Default NordVPN SmartDNS servers (user-specific ones are in SecureConfigService)
const DEFAULT_SMARTDNS: SmartDNSConfig = {
  primary: '103.86.96.100',
  secondary: '103.86.99.100',
  setupInstructions: [
    '1. On your Samsung TV, go to Settings > General > Network',
    '2. Select Network Status, then IP Settings',
    '3. Change DNS Setting from "Obtain automatically" to "Enter manually"',
    '4. Enter your Primary DNS (check Settings in app)',
    '5. Enter your Secondary DNS (check Settings in app)',
    '6. Press OK and restart your TV',
    '7. IMPORTANT: Go to my.nordaccount.com on your phone/computer',
    '8. Navigate to NordVPN > SmartDNS',
    '9. Click "Activate SmartDNS" - this whitelists your current IP',
    '10. Your IP changes? Re-activate SmartDNS to whitelist the new IP',
  ],
};

// Detailed SmartDNS activation guide
export const SMARTDNS_ACTIVATION_GUIDE = {
  title: 'Activate SmartDNS (Required)',
  description: 'SmartDNS requires your IP address to be whitelisted. Do this on your phone or computer:',
  steps: [
    {
      step: 1,
      title: 'Open NordAccount',
      description: 'Visit my.nordaccount.com and sign in',
      url: 'https://my.nordaccount.com',
    },
    {
      step: 2,
      title: 'Go to NordVPN Services',
      description: 'Click on "NordVPN" in the left sidebar',
      url: 'https://my.nordaccount.com/dashboard/nordvpn/',
    },
    {
      step: 3,
      title: 'Open SmartDNS Settings',
      description: 'Click on "SmartDNS" in the NordVPN section',
      url: 'https://my.nordaccount.com/dashboard/nordvpn/smartdns/',
    },
    {
      step: 4,
      title: 'Activate SmartDNS',
      description: 'Click the "Activate SmartDNS" button to whitelist your current IP address',
      important: true,
    },
    {
      step: 5,
      title: 'Verify Activation',
      description: 'You should see your IP address listed as "activated"',
    },
  ],
  troubleshooting: [
    {
      issue: 'Streaming apps still show wrong region',
      solution: 'Clear the app cache: Settings > Apps > [App Name] > Clear Cache, then restart the app',
    },
    {
      issue: 'SmartDNS stopped working',
      solution: 'Your IP address changed. Re-activate SmartDNS at my.nordaccount.com/dashboard/nordvpn/smartdns/',
    },
    {
      issue: 'DNS settings reset after TV restart',
      solution: 'Disable "Auto DNS" in your router settings, or set static DNS there instead',
    },
  ],
  supportedServices: [
    'Netflix (US, UK, and other regions)',
    'Disney+',
    'Amazon Prime Video',
    'BBC iPlayer',
    'Hulu',
    'HBO Max',
    'Paramount+',
    'Peacock',
    'And many more...',
  ],
};

class NordVPNProxyService {
  private static instance: NordVPNProxyService;
  private selectedServer: ProxyServer | null = null;

  private constructor() {
    this.loadSelectedServer();
    // Subscribe to config changes
    secureConfigService.subscribe(() => {
      // Config changed externally
    });
  }

  static getInstance(): NordVPNProxyService {
    if (!NordVPNProxyService.instance) {
      NordVPNProxyService.instance = new NordVPNProxyService();
    }
    return NordVPNProxyService.instance;
  }

  /**
   * Load selected server from localStorage (not credentials - those are in SecureConfigService)
   */
  private loadSelectedServer(): void {
    const saved = localStorage.getItem('thea_nordvpn_selected_server');
    if (saved) {
      this.selectedServer = JSON.parse(saved);
    }
  }

  /**
   * Save selected server to localStorage
   */
  private saveSelectedServer(): void {
    if (this.selectedServer) {
      localStorage.setItem('thea_nordvpn_selected_server', JSON.stringify(this.selectedServer));
    } else {
      localStorage.removeItem('thea_nordvpn_selected_server');
    }
  }

  /**
   * Get current NordVPN configuration from SecureConfigService
   */
  private getConfig() {
    return secureConfigService.getNordVPN();
  }

  /**
   * Check if NordVPN is configured
   */
  isConfigured(): boolean {
    return secureConfigService.isNordVPNConfigured();
  }

  /**
   * Configure NordVPN service credentials
   * These are found at: my.nordaccount.com/dashboard/nordvpn/manual-configuration
   */
  setCredentials(credentials: NordVPNCredentials): void {
    secureConfigService.setNordVPN({
      serviceUsername: credentials.username,
      servicePassword: credentials.password,
      accessToken: credentials.accessToken || '',
    });
  }

  /**
   * Get NordVPN service credentials from access token
   * API: https://api.nordvpn.com/v1/users/services/credentials
   */
  async fetchCredentialsWithToken(accessToken: string): Promise<NordVPNCredentials | null> {
    try {
      const response = await fetch('https://api.nordvpn.com/v1/users/services/credentials', {
        headers: {
          'Authorization': `Basic ${btoa(`token:${accessToken}`)}`,
        },
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch credentials: ${response.status}`);
      }

      const data = await response.json() as {
        username: string;
        password: string;
        nordlynx_private_key?: string;
      };

      const credentials: NordVPNCredentials = {
        username: data.username,
        password: data.password,
        accessToken,
      };

      // Save to SecureConfigService
      secureConfigService.setNordVPN({
        serviceUsername: data.username,
        servicePassword: data.password,
        accessToken,
      });

      return credentials;
    } catch (error) {
      console.error('Failed to fetch NordVPN credentials:', error);
      return null;
    }
  }

  /**
   * Get available SOCKS5 proxy servers
   */
  getProxyServers(): ProxyServer[] {
    return [...NORDVPN_SOCKS5_SERVERS];
  }

  /**
   * Get servers for a specific country
   */
  getServersForCountry(countryCode: string): ProxyServer[] {
    return NORDVPN_SOCKS5_SERVERS.filter(
      s => s.countryCode === countryCode.toLowerCase()
    );
  }

  /**
   * Get available countries
   */
  getAvailableCountries(): { code: string; name: string; serverCount: number }[] {
    const countries = new Map<string, { name: string; count: number }>();

    for (const server of NORDVPN_SOCKS5_SERVERS) {
      const existing = countries.get(server.countryCode);
      if (existing) {
        existing.count++;
      } else {
        countries.set(server.countryCode, { name: server.country, count: 1 });
      }
    }

    return Array.from(countries.entries()).map(([code, { name, count }]) => ({
      code,
      name,
      serverCount: count,
    }));
  }

  /**
   * Select a proxy server
   */
  selectServer(server: ProxyServer): void {
    this.selectedServer = server;
    this.saveSelectedServer();
    // Also update the selected country in SecureConfigService
    secureConfigService.setNordVPN({ selectedProxyCountry: server.countryCode });
  }

  /**
   * Get currently selected server
   */
  getSelectedServer(): ProxyServer | null {
    return this.selectedServer;
  }

  /**
   * Get proxy configuration for HTTP clients
   * Note: This works for Thea's own requests, NOT for Netflix/etc apps
   */
  getProxyConfig(): { host: string; port: number; auth?: { username: string; password: string } } | null {
    const config = this.getConfig();
    if (!this.selectedServer || !config.serviceUsername || !config.servicePassword) {
      return null;
    }

    return {
      host: this.selectedServer.hostname,
      port: this.selectedServer.port,
      auth: {
        username: config.serviceUsername,
        password: config.servicePassword,
      },
    };
  }

  /**
   * Get SmartDNS configuration
   * This is the RECOMMENDED solution for streaming app geo-unblocking
   * Returns user-specific DNS servers from SecureConfigService
   */
  getSmartDNSConfig(): SmartDNSConfig {
    const config = this.getConfig();
    return {
      primary: config.smartDNSPrimary || DEFAULT_SMARTDNS.primary,
      secondary: config.smartDNSSecondary || DEFAULT_SMARTDNS.secondary,
      setupInstructions: [
        '1. On your Samsung TV, go to Settings > General > Network',
        '2. Select Network Status, then IP Settings',
        '3. Change DNS Setting from "Obtain automatically" to "Enter manually"',
        `4. Enter Primary DNS: ${config.smartDNSPrimary || DEFAULT_SMARTDNS.primary}`,
        `5. Enter Secondary DNS: ${config.smartDNSSecondary || DEFAULT_SMARTDNS.secondary}`,
        '6. Press OK and restart your TV',
        config.smartDNSActivatedIP
          ? `Note: SmartDNS is activated for IP: ${config.smartDNSActivatedIP}`
          : 'Note: Activate SmartDNS at my.nordaccount.com/dashboard/nordvpn/smartdns',
      ],
    };
  }

  /**
   * Get activated IP address for SmartDNS
   */
  getSmartDNSActivatedIP(): string | null {
    return this.getConfig().smartDNSActivatedIP || null;
  }

  /**
   * Update SmartDNS configuration (after activation email from NordVPN)
   */
  setSmartDNSServers(primary: string, secondary: string, activatedIP?: string): void {
    secureConfigService.setNordVPN({
      smartDNSPrimary: primary,
      smartDNSSecondary: secondary,
      smartDNSActivatedIP: activatedIP || '',
      smartDNSEnabled: true,
    });
  }

  /**
   * Mark SmartDNS as enabled (user has configured it on TV)
   */
  setSmartDNSEnabled(enabled: boolean): void {
    secureConfigService.setNordVPN({ smartDNSEnabled: enabled });
  }

  /**
   * Check if SmartDNS is enabled
   */
  isSmartDNSEnabled(): boolean {
    return secureConfigService.isSmartDNSEnabled();
  }

  /**
   * Get the link to register IP for SmartDNS
   */
  getSmartDNSRegistrationUrl(): string {
    return 'https://my.nordaccount.com/dashboard/nordvpn/smartdns';
  }

  /**
   * Test proxy connection
   */
  async testProxyConnection(): Promise<{ success: boolean; ip?: string; country?: string; error?: string }> {
    const config = this.getConfig();
    if (!this.selectedServer || !config.serviceUsername || !config.servicePassword) {
      return { success: false, error: 'No server or credentials configured' };
    }

    try {
      // Route through sync-bridge which can test the proxy
      const response = await fetch(`${SYNC_BRIDGE_URL}/vpn/test-proxy`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          proxy: {
            host: this.selectedServer.hostname,
            port: this.selectedServer.port,
            username: config.serviceUsername,
            password: config.servicePassword,
          },
        }),
      });

      if (!response.ok) {
        throw new Error('Proxy test failed');
      }

      const result = await response.json() as { ip: string; country: string };
      return { success: true, ip: result.ip, country: result.country };
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  /**
   * Configure qBittorrent to use the selected proxy
   * This is done via the sync-bridge
   */
  async configureQBittorrentProxy(): Promise<{ success: boolean; error?: string }> {
    const config = this.getConfig();
    if (!this.selectedServer || !config.serviceUsername || !config.servicePassword) {
      return { success: false, error: 'No server or credentials configured' };
    }

    try {
      const syncConfig = secureConfigService.getSyncBridge();
      const response = await fetch(`${SYNC_BRIDGE_URL}/torrents/configure-proxy`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Device-Token': syncConfig.deviceToken || '',
        },
        body: JSON.stringify({
          type: 'socks5',
          host: this.selectedServer.hostname,
          port: this.selectedServer.port,
          username: config.serviceUsername,
          password: config.servicePassword,
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to configure proxy');
      }

      return { success: true };
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  /**
   * Get credentials as NordVPNCredentials interface for compatibility
   */
  getCredentials(): NordVPNCredentials | null {
    const config = this.getConfig();
    if (!config.serviceUsername || !config.servicePassword) {
      return null;
    }
    return {
      username: config.serviceUsername,
      password: config.servicePassword,
      accessToken: config.accessToken || undefined,
    };
  }
}

export const nordVPNProxyService = NordVPNProxyService.getInstance();
