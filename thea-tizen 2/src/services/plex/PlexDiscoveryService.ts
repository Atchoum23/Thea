/**
 * Plex Server Discovery Service
 *
 * Discovers Plex Media Servers on the local network using:
 * 1. GDM (Good Day Mate) - Plex's multicast discovery protocol
 * 2. Plex.tv API - For servers linked to account
 * 3. Manual fallback - Direct IP/hostname
 *
 * GDM uses UDP multicast to 239.0.0.250 on ports 32410-32414.
 * Since Tizen web apps can't do UDP, we use Sync Bridge as a proxy.
 *
 * @see https://python-plexapi.readthedocs.io/en/latest/modules/gdm.html
 * @see https://support.plex.tv/articles/200430283-network/
 */

import { secureConfigService } from '../config/SecureConfigService';

// ============================================================
// TYPES
// ============================================================

export interface PlexServer {
  name: string;
  host: string;
  port: number;
  version: string;
  machineIdentifier: string;
  owned: boolean;
  local: boolean;
  sourceType: 'gdm' | 'plex.tv' | 'manual';
  lastSeen: Date;
  // Connection details
  uri: string;
  // Capabilities
  capabilities?: string[];
}

export interface PlexUser {
  id: number;
  uuid: string;
  username: string;
  email: string;
  thumb: string;
  authToken: string;
  subscription: {
    active: boolean;
    plan: string;
  };
}

export interface GDMResponse {
  name: string;
  host: string;
  port: number;
  machineIdentifier: string;
  version: string;
}

type DiscoveryListener = (servers: PlexServer[]) => void;

// ============================================================
// CONSTANTS
// ============================================================

const PLEX_TV_API = 'https://plex.tv';
const DISCOVERY_CACHE_KEY = 'thea_plex_servers';

// ============================================================
// SERVICE
// ============================================================

class PlexDiscoveryService {
  private static instance: PlexDiscoveryService;

  private servers: Map<string, PlexServer> = new Map();
  private discoveryListeners: Set<DiscoveryListener> = new Set();
  private isDiscovering = false;
  private lastDiscovery: Date | null = null;

  private constructor() {
    this.loadCachedServers();
  }

  static getInstance(): PlexDiscoveryService {
    if (!PlexDiscoveryService.instance) {
      PlexDiscoveryService.instance = new PlexDiscoveryService();
    }
    return PlexDiscoveryService.instance;
  }

  // ============================================================
  // DISCOVERY
  // ============================================================

  /**
   * Discover all available Plex servers
   */
  async discoverServers(): Promise<PlexServer[]> {
    if (this.isDiscovering) {
      return Array.from(this.servers.values());
    }

    this.isDiscovering = true;
    console.log('PlexDiscovery: Starting server discovery');

    try {
      // Run all discovery methods in parallel
      const [gdmServers, plexTvServers] = await Promise.all([
        this.discoverViaGDM().catch(() => []),
        this.discoverViaPlexTv().catch(() => []),
      ]);

      // Merge results (prefer local/GDM over plex.tv)
      for (const server of [...gdmServers, ...plexTvServers]) {
        const existing = this.servers.get(server.machineIdentifier);
        if (!existing || server.sourceType === 'gdm') {
          this.servers.set(server.machineIdentifier, server);
        }
      }

      // Add manually configured server if not already found
      const manualServer = await this.getManualServer();
      if (manualServer && !this.servers.has(manualServer.machineIdentifier)) {
        this.servers.set(manualServer.machineIdentifier, manualServer);
      }

      this.lastDiscovery = new Date();
      this.saveServers();
      this.notifyListeners();

      console.log(`PlexDiscovery: Found ${this.servers.size} servers`);
      return Array.from(this.servers.values());
    } finally {
      this.isDiscovering = false;
    }
  }

  /**
   * Discover servers via GDM (Good Day Mate) protocol
   * Requires Sync Bridge to perform UDP multicast
   */
  private async discoverViaGDM(): Promise<PlexServer[]> {
    const syncConfig = secureConfigService.getSyncBridge();
    if (!syncConfig.url) {
      console.log('PlexDiscovery: Sync Bridge not configured, skipping GDM');
      return [];
    }

    try {
      const response = await fetch(`${syncConfig.url}/plex/gdm-discover`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Device-Token': syncConfig.deviceToken,
        },
        body: JSON.stringify({ timeout: 5000 }),
      });

      if (!response.ok) {
        console.warn('PlexDiscovery: GDM discovery failed');
        return [];
      }

      const data = await response.json() as { servers: GDMResponse[] };
      return data.servers.map(s => this.gdmToServer(s));
    } catch (error) {
      console.warn('PlexDiscovery: GDM error', error);
      return [];
    }
  }

  /**
   * Discover servers via Plex.tv API
   * Requires Plex token
   */
  private async discoverViaPlexTv(): Promise<PlexServer[]> {
    const plexConfig = secureConfigService.getPlex();
    if (!plexConfig.token) {
      console.log('PlexDiscovery: No Plex token, skipping plex.tv discovery');
      return [];
    }

    try {
      const response = await fetch(`${PLEX_TV_API}/api/resources?includeHttps=1`, {
        headers: {
          'Accept': 'application/json',
          'X-Plex-Token': plexConfig.token,
          'X-Plex-Client-Identifier': 'thea-tizen',
          'X-Plex-Product': 'Thea',
          'X-Plex-Version': '1.0.0',
        },
      });

      if (!response.ok) {
        console.warn('PlexDiscovery: Plex.tv API error');
        return [];
      }

      const data = await response.json() as Array<{
        name: string;
        provides: string;
        owned: boolean;
        clientIdentifier: string;
        productVersion: string;
        connections: Array<{
          protocol: string;
          address: string;
          port: number;
          uri: string;
          local: boolean;
        }>;
      }>;

      const servers: PlexServer[] = [];

      for (const resource of data) {
        // Only include server resources
        if (!resource.provides.includes('server')) continue;

        // Prefer local connections
        const localConn = resource.connections.find(c => c.local);
        const conn = localConn || resource.connections[0];

        if (conn) {
          servers.push({
            name: resource.name,
            host: conn.address,
            port: conn.port,
            version: resource.productVersion,
            machineIdentifier: resource.clientIdentifier,
            owned: resource.owned,
            local: conn.local,
            sourceType: 'plex.tv',
            lastSeen: new Date(),
            uri: conn.uri,
          });
        }
      }

      return servers;
    } catch (error) {
      console.warn('PlexDiscovery: Plex.tv error', error);
      return [];
    }
  }

  /**
   * Get manually configured server
   */
  private async getManualServer(): Promise<PlexServer | null> {
    const config = secureConfigService.getPlex();
    if (!config.serverUrl || !config.token) {
      return null;
    }

    try {
      // Test connection and get server info
      const response = await fetch(`${config.serverUrl}/identity`, {
        headers: { 'X-Plex-Token': config.token },
      });

      if (!response.ok) return null;

      const data = await response.json() as {
        MediaContainer: {
          machineIdentifier: string;
          version: string;
        };
      };

      const url = new URL(config.serverUrl);

      return {
        name: config.serverName || 'Manual Server',
        host: url.hostname,
        port: parseInt(url.port) || 32400,
        version: data.MediaContainer.version,
        machineIdentifier: data.MediaContainer.machineIdentifier,
        owned: true,
        local: true,
        sourceType: 'manual',
        lastSeen: new Date(),
        uri: config.serverUrl,
      };
    } catch (error) {
      console.warn('PlexDiscovery: Manual server check failed', error);
      return null;
    }
  }

  /**
   * Convert GDM response to PlexServer
   */
  private gdmToServer(gdm: GDMResponse): PlexServer {
    return {
      name: gdm.name,
      host: gdm.host,
      port: gdm.port,
      version: gdm.version,
      machineIdentifier: gdm.machineIdentifier,
      owned: true, // GDM only discovers local servers
      local: true,
      sourceType: 'gdm',
      lastSeen: new Date(),
      uri: `http://${gdm.host}:${gdm.port}`,
    };
  }

  // ============================================================
  // PLEX.TV SIGN IN
  // ============================================================

  /**
   * Sign in to Plex.tv to get a token
   * Uses PIN-based authentication (similar to Trakt device flow)
   */
  async createPlexPin(): Promise<{
    id: number;
    code: string;
    authUrl: string;
    expiresAt: Date;
  }> {
    const response = await fetch(`${PLEX_TV_API}/api/v2/pins?strong=true`, {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Plex-Client-Identifier': 'thea-tizen',
        'X-Plex-Product': 'Thea',
        'X-Plex-Version': '1.0.0',
      },
    });

    if (!response.ok) {
      throw new Error('Failed to create Plex PIN');
    }

    const data = await response.json() as {
      id: number;
      code: string;
      expiresAt: string;
    };

    return {
      id: data.id,
      code: data.code,
      authUrl: `https://app.plex.tv/auth#?clientID=thea-tizen&code=${data.code}`,
      expiresAt: new Date(data.expiresAt),
    };
  }

  /**
   * Check if a PIN has been authorized
   */
  async checkPlexPin(pinId: number): Promise<{ authorized: boolean; token?: string }> {
    const response = await fetch(`${PLEX_TV_API}/api/v2/pins/${pinId}`, {
      headers: {
        'Accept': 'application/json',
        'X-Plex-Client-Identifier': 'thea-tizen',
        'X-Plex-Product': 'Thea',
        'X-Plex-Version': '1.0.0',
      },
    });

    if (!response.ok) {
      throw new Error('Failed to check PIN');
    }

    const data = await response.json() as {
      authToken: string | null;
    };

    if (data.authToken) {
      // Save the token
      secureConfigService.setPlex({ token: data.authToken });
      return { authorized: true, token: data.authToken };
    }

    return { authorized: false };
  }

  /**
   * Get current Plex user info
   */
  async getCurrentUser(): Promise<PlexUser | null> {
    const config = secureConfigService.getPlex();
    if (!config.token) return null;

    try {
      const response = await fetch(`${PLEX_TV_API}/api/v2/user`, {
        headers: {
          'Accept': 'application/json',
          'X-Plex-Token': config.token,
          'X-Plex-Client-Identifier': 'thea-tizen',
          'X-Plex-Product': 'Thea',
          'X-Plex-Version': '1.0.0',
        },
      });

      if (!response.ok) return null;

      return await response.json() as PlexUser;
    } catch (error) {
      console.warn('PlexDiscovery: Failed to get user', error);
      return null;
    }
  }

  // ============================================================
  // SERVER SELECTION
  // ============================================================

  /**
   * Get all discovered servers
   */
  getServers(): PlexServer[] {
    return Array.from(this.servers.values());
  }

  /**
   * Get a specific server
   */
  getServer(machineIdentifier: string): PlexServer | undefined {
    return this.servers.get(machineIdentifier);
  }

  /**
   * Get the best available server (prefer local, then owned)
   */
  getBestServer(): PlexServer | undefined {
    const servers = this.getServers();

    // Prefer local servers
    const local = servers.find(s => s.local && s.owned);
    if (local) return local;

    // Then any local
    const anyLocal = servers.find(s => s.local);
    if (anyLocal) return anyLocal;

    // Then owned remote
    const owned = servers.find(s => s.owned);
    if (owned) return owned;

    // Any server
    return servers[0];
  }

  /**
   * Select a server for use
   */
  async selectServer(machineIdentifier: string): Promise<boolean> {
    const server = this.servers.get(machineIdentifier);
    if (!server) return false;

    // Update config
    secureConfigService.setPlex({
      serverUrl: server.uri,
      serverName: server.name,
    });

    return true;
  }

  // ============================================================
  // PERSISTENCE
  // ============================================================

  private loadCachedServers(): void {
    try {
      const saved = localStorage.getItem(DISCOVERY_CACHE_KEY);
      if (saved) {
        const data = JSON.parse(saved) as Array<[string, PlexServer]>;
        for (const [id, server] of data) {
          server.lastSeen = new Date(server.lastSeen);
          this.servers.set(id, server);
        }
      }
    } catch (error) {
      console.warn('PlexDiscovery: Failed to load cache', error);
    }
  }

  private saveServers(): void {
    try {
      const data = Array.from(this.servers.entries());
      localStorage.setItem(DISCOVERY_CACHE_KEY, JSON.stringify(data));
    } catch (error) {
      console.warn('PlexDiscovery: Failed to save cache', error);
    }
  }

  // ============================================================
  // LISTENERS
  // ============================================================

  onServersChanged(listener: DiscoveryListener): () => void {
    this.discoveryListeners.add(listener);
    // Immediately call with current servers
    listener(Array.from(this.servers.values()));
    return () => this.discoveryListeners.delete(listener);
  }

  private notifyListeners(): void {
    const servers = Array.from(this.servers.values());
    for (const listener of this.discoveryListeners) {
      try {
        listener(servers);
      } catch (error) {
        console.error('PlexDiscovery: Listener error', error);
      }
    }
  }
}

export const plexDiscoveryService = PlexDiscoveryService.getInstance();
