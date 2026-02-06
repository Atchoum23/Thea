/**
 * Example Secrets Configuration
 *
 * Copy this file to secrets.ts and fill in your actual values.
 * DO NOT commit secrets.ts to version control!
 *
 * These credentials can also be configured via the app's Settings UI.
 */

export const SECRETS = {
  // TMDB (The Movie Database) - for streaming availability
  // Get your API key at: https://www.themoviedb.org/settings/api
  TMDB_API_KEY: '',
  TMDB_ACCESS_TOKEN: '', // Recommended: Use access token for better rate limits

  // NordVPN - for SmartDNS and proxy
  // Get service credentials at: https://my.nordaccount.com/dashboard/nordvpn/manual-configuration
  // NOTE: These are SERVICE credentials, different from your login email/password!
  NORDVPN_SERVICE_USERNAME: '',
  NORDVPN_SERVICE_PASSWORD: '',
  // Optional: Access token for API calls (generate at same URL)
  NORDVPN_ACCESS_TOKEN: '',

  // Trakt - for watchlist and tracking
  // Create an app at: https://trakt.tv/oauth/applications
  TRAKT_CLIENT_ID: '',
  TRAKT_CLIENT_SECRET: '',

  // Sync Bridge - Cloudflare Worker URL
  // Deploy your own or use the default
  SYNC_BRIDGE_URL: 'https://thea-sync.your-worker.workers.dev',
};
