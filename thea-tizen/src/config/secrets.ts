/**
 * Secrets Configuration
 *
 * This file contains API keys and credentials.
 * These can be overridden via the app's Settings UI.
 */

export const SECRETS = {
  // TMDB (The Movie Database) - for streaming availability
  TMDB_API_KEY: 'ffe4b4af19bfa7a817e966d2bc455685',
  TMDB_ACCESS_TOKEN: 'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJmZmU0YjRhZjE5YmZhN2E4MTdlOTY2ZDJiYzQ1NTY4NSIsIm5iZiI6MTc3MDI5NTg5OS4yMDEsInN1YiI6IjY5ODQ5MjViMjYyY2NjMmU0YzZlZWM2NiIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.JPg6TkHNXCXFtqPaS4G9zAyvMc6SDDMKLu3RPL9kq3g',

  // NordVPN - for SmartDNS and proxy
  NORDVPN_SERVICE_USERNAME: 'yRWJmDJCBPcYwDovcfbJn8oF',
  NORDVPN_SERVICE_PASSWORD: 'cB2dXbBRAm3U9biDFVZCcUMx',
  NORDVPN_ACCESS_TOKEN: '',

  // SmartDNS Configuration (user-specific, assigned by NordVPN)
  // Activated for IP: 85.5.146.251
  SMARTDNS_PRIMARY: '103.86.96.103',
  SMARTDNS_SECONDARY: '103.86.99.103',
  SMARTDNS_ACTIVATED_IP: '85.5.146.251',

  // User location
  USER_COUNTRY: 'CH', // Switzerland

  // Trakt - for watchlist and tracking
  TRAKT_CLIENT_ID: '',
  TRAKT_CLIENT_SECRET: '',

  // Plex Media Server
  PLEX_SERVER_URL: '', // e.g., 'http://192.168.1.100:32400'
  PLEX_TOKEN: '', // X-Plex-Token from Plex Web
  PLEX_SERVER_NAME: 'MSM3U',

  // Sync Bridge - Cloudflare Worker URL
  SYNC_BRIDGE_URL: '',
};

/**
 * User's Streaming Accounts Configuration
 *
 * TMDB Provider IDs reference:
 * - Netflix: 8
 * - Amazon Prime Video: 9, 10
 * - Disney+: 337
 * - Apple TV+: 350, 2
 * - Canal+: 381
 * - YouTube Premium: 192
 * - HBO Max / Max: 384, 1899
 * - Hulu: 15
 * - Paramount+: 531
 * - Peacock: 386
 */
export const STREAMING_ACCOUNTS = [
  // Netflix - available in CH, FR, US, RU
  {
    providerId: 8,
    providerName: 'Netflix',
    active: true,
    regions: ['CH', 'FR', 'US', 'RU'],
    notes: 'Multi-region account',
  },
  // Canal+ - France
  {
    providerId: 381,
    providerName: 'Canal+',
    active: true,
    regions: ['FR'],
    notes: 'French subscription',
  },
  // Amazon Prime Video - CH, FR, US, RU
  {
    providerId: 9,
    providerName: 'Amazon Prime Video',
    active: true,
    regions: ['CH', 'FR', 'US', 'RU'],
    notes: 'Multi-region Prime',
  },
  // YouTube Premium
  {
    providerId: 192,
    providerName: 'YouTube Premium',
    active: true,
    regions: ['CH', 'FR', 'US', 'RU'],
    notes: 'Global account',
  },
  // Apple TV+ - Swiss Apple account
  {
    providerId: 350,
    providerName: 'Apple TV+',
    active: true,
    regions: ['CH'],
    appleAccountRegion: 'CH',
    notes: 'Swiss Apple account',
  },
  // Apple accounts in other regions (for purchases/rentals)
  {
    providerId: 2,
    providerName: 'Apple iTunes',
    active: true,
    regions: ['CH', 'FR', 'US', 'RU'],
    notes: 'Multiple Apple accounts for purchases',
  },
  // Swisscom blue TV
  {
    providerId: 0, // Custom, not in TMDB
    providerName: 'Swisscom blue TV',
    active: true,
    regions: ['CH'],
    customProvider: true,
    notes: 'Swiss IPTV service',
  },
  // Plex Media Server (local)
  {
    providerId: 0, // Custom, local server
    providerName: 'Plex',
    active: true,
    regions: ['LOCAL'],
    customProvider: true,
    localServer: {
      name: 'MSM3U',
      type: 'mac',
      // Connection details managed by Plex
    },
    notes: 'Local Plex server on Mac (MSM3U)',
  },
];
