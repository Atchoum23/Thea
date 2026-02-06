/**
 * Thea Sync Bridge - Cloudflare Worker
 *
 * Provides:
 * 1. CloudKit bridge for iCloud sync with Tizen app
 * 2. qBittorrent proxy for torrent downloads
 * 3. Prowlarr proxy for torrent search
 * 4. Trakt calendar API proxy
 * 5. Remote settings and notifications sync
 */

import { Hono } from 'hono';
import { cors } from 'hono/cors';

interface Env {
  SESSIONS: KVNamespace;
  CLOUDKIT_CONTAINER: string;
  CLOUDKIT_API_TOKEN: string;
  CLOUDKIT_KEY_ID: string;
  // qBittorrent settings (handles 5000+ torrents, best community support)
  QBITTORRENT_URL: string;
  QBITTORRENT_USER: string;
  QBITTORRENT_PASS: string;
  // Prowlarr for torrent search
  PROWLARR_URL: string;
  PROWLARR_API_KEY: string;
}

const app = new Hono<{ Bindings: Env }>();

// CORS for Tizen app
app.use('*', cors({
  origin: '*',
  allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowHeaders: ['Content-Type', 'Authorization', 'X-Device-Token'],
}));

// Health check
app.get('/', (c) => {
  return c.json({
    service: 'Thea Sync Bridge',
    version: '1.0.0',
    status: 'healthy',
    endpoints: [
      '/auth/device',
      '/sync/conversations',
      '/sync/messages',
      '/torrents/search',
      '/torrents/download',
      '/trakt/calendar',
      '/vpn/status',
      '/vpn/connect',
      '/vpn/disconnect',
      '/settings/auto-download',
      '/downloads/history',
      '/notifications',
    ],
  });
});

// ============================================================
// DEVICE AUTHENTICATION
// ============================================================

app.post('/auth/device', async (c) => {
  const { deviceId, deviceName, deviceType } = await c.req.json();

  if (!deviceId || !deviceName) {
    return c.json({ error: 'Missing deviceId or deviceName' }, 400);
  }

  // Generate unique token
  const deviceToken = crypto.randomUUID();

  // Store in KV with 1 year expiry
  await c.env.SESSIONS.put(
    `device:${deviceToken}`,
    JSON.stringify({
      deviceId,
      deviceName,
      deviceType: deviceType || 'unknown',
      createdAt: Date.now(),
    }),
    { expirationTtl: 365 * 24 * 60 * 60 }
  );

  return c.json({
    deviceToken,
    expiresIn: 365 * 24 * 60 * 60,
  });
});

// Validate device token middleware
async function validateDevice(c: any, next: any) {
  const token = c.req.header('X-Device-Token');

  if (!token) {
    return c.json({ error: 'Missing device token' }, 401);
  }

  const device = await c.env.SESSIONS.get(`device:${token}`);
  if (!device) {
    return c.json({ error: 'Invalid or expired device token' }, 401);
  }

  c.set('device', JSON.parse(device));
  await next();
}

// ============================================================
// CLOUDKIT SYNC (Simplified - direct REST)
// ============================================================

app.get('/sync/conversations', validateDevice, async (c) => {
  const since = c.req.query('since');

  // In production, this would call CloudKit REST API
  // For now, return mock data structure
  return c.json({
    conversations: [],
    syncToken: Date.now().toString(),
    message: 'CloudKit integration requires API token setup',
  });
});

app.post('/sync/conversations', validateDevice, async (c) => {
  const { conversations } = await c.req.json();

  // Store in KV as fallback
  const device = c.get('device');
  await c.env.SESSIONS.put(
    `conversations:${device.deviceId}`,
    JSON.stringify(conversations),
    { expirationTtl: 30 * 24 * 60 * 60 }
  );

  return c.json({ success: true, synced: conversations.length });
});

app.get('/sync/conversations/:id/messages', validateDevice, async (c) => {
  const conversationId = c.req.param('id');

  return c.json({
    messages: [],
    conversationId,
  });
});

// ============================================================
// TORRENT SEARCH (via Prowlarr)
// ============================================================

app.get('/torrents/search', validateDevice, async (c) => {
  const query = c.req.query('q');
  const category = c.req.query('category') || 'all'; // movies, tv, all

  if (!query) {
    return c.json({ error: 'Missing search query' }, 400);
  }

  if (!c.env.PROWLARR_URL || !c.env.PROWLARR_API_KEY) {
    return c.json({
      error: 'Prowlarr not configured',
      message: 'Set PROWLARR_URL and PROWLARR_API_KEY secrets',
    }, 503);
  }

  try {
    // Map category to Prowlarr categories
    const categoryMap: Record<string, number[]> = {
      movies: [2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060],
      tv: [5000, 5010, 5020, 5030, 5040, 5045, 5050, 5060],
      all: [],
    };

    const categories = categoryMap[category] || [];
    const catParam = categories.length > 0 ? `&categories=${categories.join(',')}` : '';

    const response = await fetch(
      `${c.env.PROWLARR_URL}/api/v1/search?query=${encodeURIComponent(query)}${catParam}`,
      {
        headers: {
          'X-Api-Key': c.env.PROWLARR_API_KEY,
        },
      }
    );

    if (!response.ok) {
      throw new Error(`Prowlarr error: ${response.status}`);
    }

    const results = await response.json() as any[];

    // Format results for Thea
    const formatted = results.slice(0, 50).map((r: any) => ({
      id: r.guid,
      title: r.title,
      size: r.size,
      sizeFormatted: formatBytes(r.size),
      seeders: r.seeders,
      leechers: r.leechers,
      indexer: r.indexer,
      downloadUrl: r.downloadUrl,
      magnetUrl: r.magnetUrl,
      infoUrl: r.infoUrl,
      publishDate: r.publishDate,
      categories: r.categories,
    }));

    return c.json({
      query,
      category,
      count: formatted.length,
      results: formatted,
    });
  } catch (error) {
    return c.json({
      error: 'Search failed',
      message: error instanceof Error ? error.message : 'Unknown error',
    }, 500);
  }
});

// ============================================================
// TORRENT DOWNLOAD (supports qBittorrent or Transmission)
// ============================================================

// qBittorrent session cookie storage
let qbCookie: string | null = null;

async function qbLogin(env: Env): Promise<string> {
  const response = await fetch(`${env.QBITTORRENT_URL}/api/v2/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `username=${encodeURIComponent(env.QBITTORRENT_USER)}&password=${encodeURIComponent(env.QBITTORRENT_PASS)}`,
  });

  const cookie = response.headers.get('set-cookie');
  if (!cookie || !response.ok) {
    throw new Error('qBittorrent login failed');
  }
  qbCookie = cookie.split(';')[0];
  return qbCookie;
}

async function qbRequest(env: Env, endpoint: string, method = 'GET', body?: any): Promise<any> {
  if (!qbCookie) {
    await qbLogin(env);
  }

  const options: RequestInit = {
    method,
    headers: { 'Cookie': qbCookie! },
  };

  if (body) {
    if (body instanceof FormData) {
      options.body = body;
    } else {
      options.headers = { ...options.headers, 'Content-Type': 'application/x-www-form-urlencoded' };
      options.body = new URLSearchParams(body).toString();
    }
  }

  let response = await fetch(`${env.QBITTORRENT_URL}/api/v2/${endpoint}`, options);

  // Re-login if session expired
  if (response.status === 403) {
    await qbLogin(env);
    options.headers = { ...options.headers, 'Cookie': qbCookie! };
    response = await fetch(`${env.QBITTORRENT_URL}/api/v2/${endpoint}`, options);
  }

  return response;
}

app.post('/torrents/download', validateDevice, async (c) => {
  const { magnetUrl, downloadUrl, title, category, savePath } = await c.req.json();

  if (!magnetUrl && !downloadUrl) {
    return c.json({ error: 'Missing magnetUrl or downloadUrl' }, 400);
  }

  if (!c.env.QBITTORRENT_URL) {
    return c.json({
      error: 'qBittorrent not configured',
      message: 'Set QBITTORRENT_URL, QBITTORRENT_USER, and QBITTORRENT_PASS secrets',
    }, 503);
  }

  const torrentUrl = magnetUrl || downloadUrl;

  try {
    const params: Record<string, string> = { urls: torrentUrl };
    if (category) params.category = category;
    if (savePath) params.savepath = savePath;

    const response = await qbRequest(c.env, 'torrents/add', 'POST', params);

    if (!response.ok) {
      const text = await response.text();
      throw new Error(text || 'Failed to add torrent');
    }

    return c.json({
      success: true,
      client: 'qbittorrent',
      torrent: { name: title, category, savePath },
      message: 'Torrent added to qBittorrent',
    });
  } catch (error) {
    return c.json({
      error: 'qBittorrent download failed',
      message: error instanceof Error ? error.message : 'Unknown error',
    }, 500);
  }
});

// Get download status from qBittorrent
app.get('/torrents/status', validateDevice, async (c) => {
  if (!c.env.QBITTORRENT_URL) {
    return c.json({ error: 'qBittorrent not configured' }, 503);
  }

  try {
    const filter = c.req.query('filter'); // all, downloading, completed, paused, active, inactive
    const category = c.req.query('category');

    let endpoint = 'torrents/info';
    const params: string[] = [];
    if (filter) params.push(`filter=${filter}`);
    if (category) params.push(`category=${category}`);
    if (params.length > 0) endpoint += '?' + params.join('&');

    const response = await qbRequest(c.env, endpoint);
    if (!response.ok) {
      throw new Error('Failed to get torrents');
    }

    const torrents = await response.json() as any[];

    return c.json({
      client: 'qbittorrent',
      count: torrents.length,
      torrents: torrents.map((t: any) => ({
        id: t.hash,
        name: t.name,
        status: t.state,
        progress: Math.round(t.progress * 100),
        eta: t.eta > 0 ? formatEta(t.eta) : null,
        downloadSpeed: formatBytes(t.dlspeed) + '/s',
        uploadSpeed: formatBytes(t.upspeed) + '/s',
        size: formatBytes(t.total_size),
        downloaded: formatBytes(t.downloaded),
        uploaded: formatBytes(t.uploaded),
        ratio: t.ratio.toFixed(2),
        category: t.category,
        savePath: t.save_path,
        addedOn: new Date(t.added_on * 1000).toISOString(),
        completedOn: t.completion_on > 0 ? new Date(t.completion_on * 1000).toISOString() : null,
      })),
    });
  } catch (error) {
    return c.json({
      error: 'Failed to get qBittorrent status',
      message: error instanceof Error ? error.message : 'Unknown error',
    }, 500);
  }
});

// Pause/resume/delete torrents
app.post('/torrents/action', validateDevice, async (c) => {
  const { action, hashes } = await c.req.json();

  if (!c.env.QBITTORRENT_URL) {
    return c.json({ error: 'qBittorrent not configured' }, 503);
  }

  if (!action || !hashes || !Array.isArray(hashes)) {
    return c.json({ error: 'Missing action or hashes' }, 400);
  }

  const validActions = ['pause', 'resume', 'delete', 'recheck', 'reannounce'];
  if (!validActions.includes(action)) {
    return c.json({ error: `Invalid action. Must be one of: ${validActions.join(', ')}` }, 400);
  }

  try {
    const hashStr = hashes.join('|');
    let endpoint: string;
    let params: Record<string, string> = { hashes: hashStr };

    switch (action) {
      case 'pause':
        endpoint = 'torrents/pause';
        break;
      case 'resume':
        endpoint = 'torrents/resume';
        break;
      case 'delete':
        endpoint = 'torrents/delete';
        params.deleteFiles = 'false'; // Don't delete files by default
        break;
      case 'recheck':
        endpoint = 'torrents/recheck';
        break;
      case 'reannounce':
        endpoint = 'torrents/reannounce';
        break;
      default:
        throw new Error('Unknown action');
    }

    const response = await qbRequest(c.env, endpoint, 'POST', params);

    if (!response.ok) {
      const text = await response.text();
      throw new Error(text || `Failed to ${action} torrents`);
    }

    return c.json({
      success: true,
      action,
      affectedHashes: hashes,
    });
  } catch (error) {
    return c.json({
      error: `Failed to ${action} torrents`,
      message: error instanceof Error ? error.message : 'Unknown error',
    }, 500);
  }
});

// ============================================================
// QBITTORRENT PROXY CONFIGURATION
// ============================================================

// Configure qBittorrent to use NordVPN SOCKS5 proxy
app.post('/torrents/configure-proxy', validateDevice, async (c) => {
  const { type, host, port, username, password, enabled = true } = await c.req.json();

  if (!c.env.QBITTORRENT_URL) {
    return c.json({ error: 'qBittorrent not configured' }, 503);
  }

  try {
    // qBittorrent proxy settings
    // Type: 0 = disabled, 1 = HTTP, 2 = SOCKS5, 3 = SOCKS5 w/auth
    const proxyType = enabled ? (username ? 3 : 2) : 0;

    const settings: Record<string, string> = {
      'proxy_type': proxyType.toString(),
      'proxy_ip': host || '',
      'proxy_port': (port || 1080).toString(),
      'proxy_username': username || '',
      'proxy_password': password || '',
      'proxy_peer_connections': 'true',
      'proxy_torrents_only': 'false', // Apply to all connections
    };

    const response = await qbRequest(c.env, 'app/setPreferences', 'POST', {
      json: JSON.stringify(settings),
    });

    if (!response.ok) {
      throw new Error('Failed to configure proxy');
    }

    return c.json({
      success: true,
      message: enabled
        ? `Proxy configured: ${host}:${port}`
        : 'Proxy disabled',
    });
  } catch (error) {
    return c.json({
      error: 'Failed to configure proxy',
      message: error instanceof Error ? error.message : 'Unknown error',
    }, 500);
  }
});

// Get current qBittorrent proxy settings
app.get('/torrents/proxy-status', validateDevice, async (c) => {
  if (!c.env.QBITTORRENT_URL) {
    return c.json({ error: 'qBittorrent not configured' }, 503);
  }

  try {
    const response = await qbRequest(c.env, 'app/preferences');
    if (!response.ok) {
      throw new Error('Failed to get preferences');
    }

    const prefs = await response.json() as any;

    const proxyTypes = ['disabled', 'http', 'socks5', 'socks5_auth'];

    return c.json({
      enabled: prefs.proxy_type > 0,
      type: proxyTypes[prefs.proxy_type] || 'unknown',
      host: prefs.proxy_ip,
      port: prefs.proxy_port,
      hasAuth: prefs.proxy_type === 3,
      peerConnections: prefs.proxy_peer_connections,
      torrentsOnly: prefs.proxy_torrents_only,
    });
  } catch (error) {
    return c.json({
      error: 'Failed to get proxy status',
      message: error instanceof Error ? error.message : 'Unknown error',
    }, 500);
  }
});

// ============================================================
// VPN CONTROLLER
// (Relay commands to NordVPN running on Mac/NAS/Router)
// ============================================================

// VPN controller state (stored in KV)
interface VPNControllerState {
  type: 'mac' | 'nas' | 'router' | 'smartdns';
  endpoint?: string;
  lastHeartbeat: number;
  connected: boolean;
  server?: string;
  country?: string;
  countryCode?: string;
  ip?: string;
}

// Get VPN status
app.get('/vpn/status', validateDevice, async (c) => {
  const state = await c.env.SESSIONS.get('vpn:state');

  if (!state) {
    return c.json({
      configured: false,
      connected: false,
      message: 'VPN controller not registered. Run the VPN controller on your Mac or configure your router.',
    });
  }

  const vpnState: VPNControllerState = JSON.parse(state);

  // Check if controller is still alive (heartbeat within last 5 minutes)
  const isAlive = Date.now() - vpnState.lastHeartbeat < 5 * 60 * 1000;

  return c.json({
    configured: true,
    controllerAlive: isAlive,
    controllerType: vpnState.type,
    connected: vpnState.connected,
    server: vpnState.server,
    country: vpnState.country,
    countryCode: vpnState.countryCode,
    ip: vpnState.ip,
    lastUpdate: new Date(vpnState.lastHeartbeat).toISOString(),
  });
});

// Connect to VPN (sends command to controller)
app.post('/vpn/connect', validateDevice, async (c) => {
  const { country, countryCode, server, protocol, reason } = await c.req.json();
  const device = c.get('device');

  if (!country && !countryCode && !server) {
    return c.json({ error: 'Must specify country, countryCode, or server' }, 400);
  }

  // Store connection request for controller to pick up
  const requestId = `vpn_connect_${Date.now()}`;
  await c.env.SESSIONS.put(
    'vpn:pending_command',
    JSON.stringify({
      id: requestId,
      command: 'connect',
      country,
      countryCode,
      server,
      protocol: protocol || 'nordlynx',
      requestedBy: device.deviceName,
      reason,
      timestamp: Date.now(),
    }),
    { expirationTtl: 5 * 60 } // 5 minute timeout
  );

  // Wait for controller response (poll for up to 30 seconds)
  const startTime = Date.now();
  while (Date.now() - startTime < 30000) {
    await new Promise(resolve => setTimeout(resolve, 1000));

    const result = await c.env.SESSIONS.get(`vpn:result:${requestId}`);
    if (result) {
      await c.env.SESSIONS.delete(`vpn:result:${requestId}`);
      const parsed = JSON.parse(result);
      return c.json(parsed);
    }
  }

  return c.json({
    success: false,
    error: 'VPN controller did not respond. Ensure the controller is running on your Mac/NAS.',
  }, 504);
});

// Disconnect from VPN
app.post('/vpn/disconnect', validateDevice, async (c) => {
  const device = c.get('device');

  const requestId = `vpn_disconnect_${Date.now()}`;
  await c.env.SESSIONS.put(
    'vpn:pending_command',
    JSON.stringify({
      id: requestId,
      command: 'disconnect',
      requestedBy: device.deviceName,
      timestamp: Date.now(),
    }),
    { expirationTtl: 5 * 60 }
  );

  // Wait for controller response
  const startTime = Date.now();
  while (Date.now() - startTime < 15000) {
    await new Promise(resolve => setTimeout(resolve, 500));

    const result = await c.env.SESSIONS.get(`vpn:result:${requestId}`);
    if (result) {
      await c.env.SESSIONS.delete(`vpn:result:${requestId}`);
      return c.json(JSON.parse(result));
    }
  }

  return c.json({
    success: false,
    error: 'VPN controller did not respond',
  }, 504);
});

// Controller heartbeat and command polling (called by Mac/NAS controller)
app.post('/vpn/controller/heartbeat', async (c) => {
  const {
    controllerType,
    controllerSecret,
    connected,
    server,
    country,
    countryCode,
    ip,
  } = await c.req.json();

  // Simple auth for controller (would be more secure in production)
  const expectedSecret = c.env.SESSIONS ? await c.env.SESSIONS.get('vpn:controller_secret') : null;
  if (expectedSecret && controllerSecret !== expectedSecret) {
    return c.json({ error: 'Invalid controller secret' }, 401);
  }

  // Update VPN state
  await c.env.SESSIONS.put(
    'vpn:state',
    JSON.stringify({
      type: controllerType,
      lastHeartbeat: Date.now(),
      connected,
      server,
      country,
      countryCode,
      ip,
    }),
    { expirationTtl: 24 * 60 * 60 }
  );

  // Check for pending commands
  const pendingCommand = await c.env.SESSIONS.get('vpn:pending_command');
  if (pendingCommand) {
    await c.env.SESSIONS.delete('vpn:pending_command');
    return c.json({
      hasCommand: true,
      command: JSON.parse(pendingCommand),
    });
  }

  return c.json({ hasCommand: false });
});

// Controller reports command result
app.post('/vpn/controller/result', async (c) => {
  const { requestId, success, error, state } = await c.req.json();

  await c.env.SESSIONS.put(
    `vpn:result:${requestId}`,
    JSON.stringify({ success, error, state }),
    { expirationTtl: 60 }
  );

  // Update VPN state if provided
  if (state) {
    const currentState = await c.env.SESSIONS.get('vpn:state');
    if (currentState) {
      const parsed = JSON.parse(currentState);
      await c.env.SESSIONS.put(
        'vpn:state',
        JSON.stringify({
          ...parsed,
          ...state,
          lastHeartbeat: Date.now(),
        }),
        { expirationTtl: 24 * 60 * 60 }
      );
    }
  }

  return c.json({ success: true });
});

// Get available VPN countries (proxies NordVPN API)
app.get('/vpn/countries', async (c) => {
  try {
    const response = await fetch('https://api.nordvpn.com/v1/servers/countries');
    if (!response.ok) {
      throw new Error('Failed to fetch countries');
    }

    const countries = await response.json() as any[];
    return c.json({
      countries: countries.map((c: any) => ({
        id: c.id,
        code: c.code?.toLowerCase(),
        name: c.name,
        serverCount: c.server_count || 0,
      })),
    });
  } catch (error) {
    return c.json({
      error: 'Failed to fetch VPN countries',
      message: error instanceof Error ? error.message : 'Unknown error',
    }, 500);
  }
});

// Get recommended server for a country
app.get('/vpn/servers', async (c) => {
  const countryCode = c.req.query('country');
  const limit = parseInt(c.req.query('limit') || '5');

  if (!countryCode) {
    return c.json({ error: 'Missing country parameter' }, 400);
  }

  try {
    const response = await fetch(
      `https://api.nordvpn.com/v1/servers/recommendations?filters[country_id]=${countryCode}&limit=${limit}`
    );

    if (!response.ok) {
      throw new Error('Failed to fetch servers');
    }

    const servers = await response.json() as any[];
    return c.json({
      servers: servers.map((s: any) => ({
        id: s.id,
        name: s.name,
        hostname: s.hostname,
        load: s.load,
        country: s.locations?.[0]?.country?.name,
        city: s.locations?.[0]?.country?.city?.name,
        technologies: s.technologies?.map((t: any) => t.name),
      })),
    });
  } catch (error) {
    return c.json({
      error: 'Failed to fetch VPN servers',
      message: error instanceof Error ? error.message : 'Unknown error',
    }, 500);
  }
});

// ============================================================
// TRAKT CALENDAR
// ============================================================

app.get('/trakt/calendar', async (c) => {
  const accessToken = c.req.header('Authorization')?.replace('Bearer ', '');
  const clientId = c.req.header('trakt-api-key');
  const days = parseInt(c.req.query('days') || '7');
  const type = c.req.query('type') || 'all'; // shows, movies, all

  if (!accessToken || !clientId) {
    return c.json({ error: 'Missing Trakt authentication' }, 401);
  }

  try {
    const today = new Date().toISOString().split('T')[0];
    const headers = {
      'Authorization': `Bearer ${accessToken}`,
      'trakt-api-key': clientId,
      'trakt-api-version': '2',
      'Content-Type': 'application/json',
    };

    const results: any = { shows: [], movies: [] };

    // Get new episodes from shows in progress
    if (type === 'all' || type === 'shows') {
      const showsResponse = await fetch(
        `https://api.trakt.tv/calendars/my/shows/${today}/${days}`,
        { headers }
      );

      if (showsResponse.ok) {
        results.shows = await showsResponse.json();
      }
    }

    // Get movies from calendar
    if (type === 'all' || type === 'movies') {
      const moviesResponse = await fetch(
        `https://api.trakt.tv/calendars/my/movies/${today}/${days}`,
        { headers }
      );

      if (moviesResponse.ok) {
        results.movies = await moviesResponse.json();
      }
    }

    // Also get watchlist items (new releases)
    const watchlistShows = await fetch(
      'https://api.trakt.tv/users/me/watchlist/shows',
      { headers }
    );
    const watchlistMovies = await fetch(
      'https://api.trakt.tv/users/me/watchlist/movies',
      { headers }
    );

    return c.json({
      calendar: {
        startDate: today,
        days,
        shows: results.shows,
        movies: results.movies,
      },
      watchlist: {
        shows: watchlistShows.ok ? await watchlistShows.json() : [],
        movies: watchlistMovies.ok ? await watchlistMovies.json() : [],
      },
    });
  } catch (error) {
    return c.json({
      error: 'Failed to fetch calendar',
      message: error instanceof Error ? error.message : 'Unknown error',
    }, 500);
  }
});

// ============================================================
// LIFE MONITORING SYNC
// ============================================================

// Receive life events from Tizen TV
app.post('/sync/life-events', validateDevice, async (c) => {
  const { events, deviceInfo } = await c.req.json();
  const device = c.get('device');

  if (!events || !Array.isArray(events)) {
    return c.json({ error: 'Missing or invalid events array' }, 400);
  }

  // Store events in KV for other devices to sync
  const eventKey = `life-events:${device.deviceId}:${Date.now()}`;
  await c.env.SESSIONS.put(
    eventKey,
    JSON.stringify({
      events,
      deviceInfo: deviceInfo || device,
      timestamp: Date.now(),
    }),
    { expirationTtl: 7 * 24 * 60 * 60 } // 7 days
  );

  // Also store to CloudKit if configured
  if (c.env.CLOUDKIT_API_TOKEN && c.env.CLOUDKIT_CONTAINER) {
    try {
      await syncToCloudKit(c.env, events, device);
    } catch (error) {
      console.error('CloudKit sync failed:', error);
    }
  }

  return c.json({
    success: true,
    synced: events.length,
    syncToken: eventKey,
  });
});

// Get life events from other devices
app.get('/sync/life-events', validateDevice, async (c) => {
  const since = c.req.query('since');
  const device = c.get('device');

  // List all event keys (excluding current device)
  const keys = await c.env.SESSIONS.list({ prefix: 'life-events:' });

  const events: any[] = [];
  for (const key of keys.keys) {
    // Skip events from the requesting device
    if (key.name.startsWith(`life-events:${device.deviceId}`)) {
      continue;
    }

    const data = await c.env.SESSIONS.get(key.name);
    if (data) {
      const parsed = JSON.parse(data);
      // Filter by since timestamp
      if (!since || parsed.timestamp > parseInt(since)) {
        events.push(...parsed.events.map((e: any) => ({
          ...e,
          sourceDevice: parsed.deviceInfo,
        })));
      }
    }
  }

  return c.json({
    events: events.slice(0, 500), // Limit response size
    syncToken: Date.now().toString(),
  });
});

// Sync health data
app.post('/sync/health', validateDevice, async (c) => {
  const { healthData, date } = await c.req.json();
  const device = c.get('device');

  if (!healthData) {
    return c.json({ error: 'Missing health data' }, 400);
  }

  const healthKey = `health:${device.deviceId}:${date || new Date().toISOString().split('T')[0]}`;
  await c.env.SESSIONS.put(
    healthKey,
    JSON.stringify({
      ...healthData,
      deviceId: device.deviceId,
      deviceType: device.deviceType,
      syncedAt: Date.now(),
    }),
    { expirationTtl: 365 * 24 * 60 * 60 } // 1 year
  );

  return c.json({ success: true, key: healthKey });
});

// Get aggregated health data
app.get('/sync/health', validateDevice, async (c) => {
  const date = c.req.query('date') || new Date().toISOString().split('T')[0];
  const days = parseInt(c.req.query('days') || '7');

  const healthData: any[] = [];
  const startDate = new Date(date);

  for (let i = 0; i < days; i++) {
    const checkDate = new Date(startDate);
    checkDate.setDate(checkDate.getDate() - i);
    const dateStr = checkDate.toISOString().split('T')[0];

    // Get all health entries for this date
    const keys = await c.env.SESSIONS.list({ prefix: `health:` });
    for (const key of keys.keys) {
      if (key.name.includes(`:${dateStr}`)) {
        const data = await c.env.SESSIONS.get(key.name);
        if (data) {
          healthData.push(JSON.parse(data));
        }
      }
    }
  }

  return c.json({
    date,
    days,
    entries: healthData,
  });
});

// Sync social interactions
app.post('/sync/interactions', validateDevice, async (c) => {
  const { interactions, contacts } = await c.req.json();
  const device = c.get('device');

  const interactionKey = `interactions:${device.deviceId}:${Date.now()}`;
  await c.env.SESSIONS.put(
    interactionKey,
    JSON.stringify({
      interactions: interactions || [],
      contacts: contacts || [],
      deviceId: device.deviceId,
      syncedAt: Date.now(),
    }),
    { expirationTtl: 30 * 24 * 60 * 60 } // 30 days
  );

  return c.json({ success: true, synced: interactions?.length || 0 });
});

// Get interactions from all devices
app.get('/sync/interactions', validateDevice, async (c) => {
  const since = c.req.query('since');

  const keys = await c.env.SESSIONS.list({ prefix: 'interactions:' });
  const allInteractions: any[] = [];
  const allContacts: any[] = [];

  for (const key of keys.keys) {
    const data = await c.env.SESSIONS.get(key.name);
    if (data) {
      const parsed = JSON.parse(data);
      if (!since || parsed.syncedAt > parseInt(since)) {
        allInteractions.push(...(parsed.interactions || []));
        allContacts.push(...(parsed.contacts || []));
      }
    }
  }

  // Deduplicate contacts by id
  const uniqueContacts = Array.from(
    new Map(allContacts.map(c => [c.id, c])).values()
  );

  return c.json({
    interactions: allInteractions.slice(0, 500),
    contacts: uniqueContacts.slice(0, 200),
    syncToken: Date.now().toString(),
  });
});

// Sync app usage
app.post('/sync/app-usage', validateDevice, async (c) => {
  const { usage, date } = await c.req.json();
  const device = c.get('device');

  const usageKey = `app-usage:${device.deviceId}:${date || new Date().toISOString().split('T')[0]}`;
  await c.env.SESSIONS.put(
    usageKey,
    JSON.stringify({
      usage,
      deviceId: device.deviceId,
      deviceType: device.deviceType,
      syncedAt: Date.now(),
    }),
    { expirationTtl: 90 * 24 * 60 * 60 } // 90 days
  );

  return c.json({ success: true });
});

// ============================================================
// REMOTE SETTINGS & NOTIFICATIONS
// (Access Thea-Tizen settings from Mac/iPhone/iPad)
// ============================================================

// ============================================================
// APP CONFIGURATION SYNC
// (Syncs non-sensitive settings across devices)
// ============================================================

// Get app configuration (preferences only - no secrets)
app.get('/settings/app-config', validateDevice, async (c) => {
  const config = await c.env.SESSIONS.get('settings:app-config');

  if (!config) {
    return c.json({
      user: {
        country: 'US',
        preferredLanguages: ['en'],
        preferredQuality: '1080p',
        avoidAds: true,
      },
      nordvpn: {
        smartDNSEnabled: false,
        selectedProxyCountry: 'us',
      },
    });
  }

  return c.json(JSON.parse(config));
});

// Save app configuration (preferences only - no secrets)
app.post('/settings/app-config', validateDevice, async (c) => {
  const { config } = await c.req.json();
  const device = c.get('device');

  // Only sync non-sensitive data
  const safeConfig = {
    user: config?.user,
    nordvpn: {
      smartDNSEnabled: config?.nordvpn?.smartDNSEnabled,
      selectedProxyCountry: config?.nordvpn?.selectedProxyCountry,
    },
    updatedBy: device.deviceId,
    updatedAt: Date.now(),
  };

  await c.env.SESSIONS.put(
    'settings:app-config',
    JSON.stringify(safeConfig),
    { expirationTtl: 365 * 24 * 60 * 60 }
  );

  // Notify other devices of settings change
  await c.env.SESSIONS.put(
    `notification:settings:${Date.now()}`,
    JSON.stringify({
      type: 'settings_changed',
      category: 'app-config',
      changedBy: device.deviceName,
      timestamp: Date.now(),
    }),
    { expirationTtl: 7 * 24 * 60 * 60 }
  );

  return c.json({ success: true });
});

// Store/retrieve auto-download settings
app.get('/settings/auto-download', validateDevice, async (c) => {
  const settings = await c.env.SESSIONS.get('settings:auto-download');

  if (!settings) {
    // Return default settings
    return c.json({
      enabled: false,
      checkIntervalMinutes: 30,
      retryIntervalMinutes: 60,
      maxRetries: 0,
      preferredAudioLanguages: ['en'],
      requiredAudioLanguages: [],
      preferredSubtitleLanguages: ['en'],
      downloadSubtitles: true,
      checkStreamingFirst: true,
      downloadIfDelayed: true,
      downloadIfAdsOnly: false,
      downloadIfLowQuality: true,
      downloadIfMissingLanguage: true,
      minQuality: '1080p',
      preferredQuality: '2160p',
      maxSizeGB: 15,
      categories: ['tv', 'movies'],
    });
  }

  return c.json(JSON.parse(settings));
});

app.post('/settings/auto-download', validateDevice, async (c) => {
  const settings = await c.req.json();
  const device = c.get('device');

  await c.env.SESSIONS.put(
    'settings:auto-download',
    JSON.stringify({
      ...settings,
      updatedBy: device.deviceId,
      updatedAt: Date.now(),
    }),
    { expirationTtl: 365 * 24 * 60 * 60 }
  );

  // Notify other devices of settings change
  await c.env.SESSIONS.put(
    `notification:settings:${Date.now()}`,
    JSON.stringify({
      type: 'settings_changed',
      category: 'auto-download',
      changedBy: device.deviceName,
      timestamp: Date.now(),
    }),
    { expirationTtl: 7 * 24 * 60 * 60 }
  );

  return c.json({ success: true });
});

// Store/retrieve streaming accounts
app.get('/settings/streaming-accounts', validateDevice, async (c) => {
  const accounts = await c.env.SESSIONS.get('settings:streaming-accounts');
  return c.json(accounts ? JSON.parse(accounts) : { accounts: [] });
});

app.post('/settings/streaming-accounts', validateDevice, async (c) => {
  const { accounts } = await c.req.json();
  const device = c.get('device');

  await c.env.SESSIONS.put(
    'settings:streaming-accounts',
    JSON.stringify({
      accounts,
      updatedBy: device.deviceId,
      updatedAt: Date.now(),
    }),
    { expirationTtl: 365 * 24 * 60 * 60 }
  );

  return c.json({ success: true });
});

// Get download history and queue
app.get('/downloads/history', validateDevice, async (c) => {
  const limit = parseInt(c.req.query('limit') || '50');
  const status = c.req.query('status'); // completed, failed, waiting, downloading

  const keys = await c.env.SESSIONS.list({ prefix: 'download:' });
  const downloads: any[] = [];

  for (const key of keys.keys.slice(0, 100)) {
    const data = await c.env.SESSIONS.get(key.name);
    if (data) {
      const download = JSON.parse(data);
      if (!status || download.status === status) {
        downloads.push(download);
      }
    }
  }

  // Sort by timestamp descending
  downloads.sort((a, b) => b.timestamp - a.timestamp);

  return c.json({
    count: downloads.length,
    downloads: downloads.slice(0, limit),
  });
});

// Record a download event
app.post('/downloads/record', validateDevice, async (c) => {
  const { item, status, error, torrentInfo } = await c.req.json();
  const device = c.get('device');

  const downloadId = `download:${item.type}:${item.traktId}:${Date.now()}`;

  await c.env.SESSIONS.put(
    downloadId,
    JSON.stringify({
      id: downloadId,
      item,
      status,
      error,
      torrentInfo,
      deviceId: device.deviceId,
      deviceName: device.deviceName,
      timestamp: Date.now(),
    }),
    { expirationTtl: 90 * 24 * 60 * 60 }
  );

  // Create notification for other devices
  if (status === 'completed' || status === 'failed') {
    await c.env.SESSIONS.put(
      `notification:download:${Date.now()}`,
      JSON.stringify({
        type: status === 'completed' ? 'download_complete' : 'download_failed',
        item,
        error,
        deviceName: device.deviceName,
        timestamp: Date.now(),
      }),
      { expirationTtl: 7 * 24 * 60 * 60 }
    );
  }

  return c.json({ success: true, downloadId });
});

// Get pending notifications for a device
app.get('/notifications', validateDevice, async (c) => {
  const since = c.req.query('since');
  const device = c.get('device');

  const keys = await c.env.SESSIONS.list({ prefix: 'notification:' });
  const notifications: any[] = [];

  for (const key of keys.keys) {
    const data = await c.env.SESSIONS.get(key.name);
    if (data) {
      const notification = JSON.parse(data);
      // Filter by timestamp and exclude self-notifications
      if ((!since || notification.timestamp > parseInt(since)) &&
          notification.deviceId !== device.deviceId) {
        notifications.push({
          ...notification,
          key: key.name,
        });
      }
    }
  }

  // Sort by timestamp ascending (oldest first)
  notifications.sort((a, b) => a.timestamp - b.timestamp);

  return c.json({
    count: notifications.length,
    notifications: notifications.slice(0, 100),
    syncToken: Date.now().toString(),
  });
});

// Mark notifications as read
app.post('/notifications/read', validateDevice, async (c) => {
  const { keys } = await c.req.json();

  if (!keys || !Array.isArray(keys)) {
    return c.json({ error: 'Missing keys array' }, 400);
  }

  // We don't actually delete, just acknowledge
  // Notifications auto-expire after 7 days
  return c.json({ success: true, acknowledged: keys.length });
});

// Send a push notification to all devices
app.post('/notifications/push', validateDevice, async (c) => {
  const { type, title, message, data } = await c.req.json();
  const device = c.get('device');

  if (!type || !title) {
    return c.json({ error: 'Missing type or title' }, 400);
  }

  await c.env.SESSIONS.put(
    `notification:push:${Date.now()}`,
    JSON.stringify({
      type,
      title,
      message,
      data,
      deviceId: device.deviceId,
      deviceName: device.deviceName,
      timestamp: Date.now(),
    }),
    { expirationTtl: 7 * 24 * 60 * 60 }
  );

  return c.json({ success: true });
});

// Get list of connected devices
app.get('/devices', validateDevice, async (c) => {
  const keys = await c.env.SESSIONS.list({ prefix: 'device:' });
  const devices: any[] = [];

  for (const key of keys.keys) {
    const data = await c.env.SESSIONS.get(key.name);
    if (data) {
      const device = JSON.parse(data);
      devices.push({
        ...device,
        token: key.name.replace('device:', '').substring(0, 8) + '...',
      });
    }
  }

  return c.json({
    count: devices.length,
    devices: devices.sort((a, b) => b.createdAt - a.createdAt),
  });
});

// CloudKit sync helper
async function syncToCloudKit(env: Env, events: any[], device: any) {
  const records = events.map(event => ({
    recordType: 'LifeEvent',
    fields: {
      eventId: { value: event.id },
      eventType: { value: event.type },
      timestamp: { value: new Date(event.timestamp).getTime() },
      sourceDeviceId: { value: device.deviceId },
      sourceDeviceName: { value: device.deviceName },
      data: { value: JSON.stringify(event.data || {}) },
    },
  }));

  // CloudKit REST API endpoint
  const cloudKitUrl = `https://api.apple-cloudkit.com/database/1/${env.CLOUDKIT_CONTAINER}/development/private/records/modify`;

  await fetch(cloudKitUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Apple-CloudKit-Request-KeyID': env.CLOUDKIT_KEY_ID,
      'X-Apple-CloudKit-Request-ISO8601Date': new Date().toISOString(),
      'Authorization': `Bearer ${env.CLOUDKIT_API_TOKEN}`,
    },
    body: JSON.stringify({
      operations: records.map(record => ({
        operationType: 'create',
        record,
      })),
    }),
  });
}

// ============================================================
// HELPERS
// ============================================================

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function formatEta(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ${Math.floor((seconds % 3600) / 60)}m`;
  return `${Math.floor(seconds / 86400)}d`;
}

export default app;
