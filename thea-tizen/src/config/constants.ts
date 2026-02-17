/**
 * Application constants and configuration
 */

// API Endpoints
export const API_URLS = {
  // AI Providers
  ANTHROPIC: 'https://api.anthropic.com/v1',
  OPENAI: 'https://api.openai.com/v1',
  OPENROUTER: 'https://openrouter.ai/api/v1',
  GOOGLE: 'https://generativelanguage.googleapis.com/v1beta',

  // Trakt
  TRAKT: 'https://api.trakt.tv',
  TRAKT_OAUTH: 'https://trakt.tv/oauth',

  // Sync Bridge (Cloudflare Worker)
  SYNC_BRIDGE: 'https://thea-sync.workers.dev', // Update with your worker URL

  // Media APIs
  TMDB: 'https://api.themoviedb.org/3',
} as const;

// Shorthand exports for common URLs
export const SYNC_BRIDGE_URL = API_URLS.SYNC_BRIDGE;

// External API Keys (should be set via environment or settings)
// TMDB API key is free and can be public in client-side code
export const TMDB_API_KEY = ''; // Get from https://www.themoviedb.org/settings/api

// Trakt Configuration
export const TRAKT_CONFIG = {
  CLIENT_ID: '', // Set via settings or environment
  // Device auth poll interval (seconds)
  POLL_INTERVAL: 5,
  // Token expiry buffer (refresh 1 day before expiry)
  TOKEN_REFRESH_BUFFER: 86400000,
} as const;

// API Versions
export const API_VERSIONS = {
  ANTHROPIC: '2024-01-01',
  TRAKT: '2',
} as const;

// Default Models
export const DEFAULT_MODELS = {
  ANTHROPIC: 'claude-sonnet-4-20250514',
  OPENAI: 'gpt-4o',
  OPENROUTER: 'anthropic/claude-sonnet-4',
} as const;

// UI Configuration for 10-foot experience
export const TV_UI = {
  // Minimum text sizes (px)
  FONT_SIZE: {
    XS: 18,
    SM: 22,
    BASE: 26,
    LG: 32,
    XL: 40,
    XXL: 48,
    XXXL: 60,
  },
  // Minimum touch/focus targets (px)
  TARGET_SIZE: {
    MIN: 48,
    RECOMMENDED: 96,
  },
  // Screen margins (px)
  MARGIN: {
    SAFE_ZONE: 48,
    CONTENT: 32,
  },
  // Animation durations (ms)
  ANIMATION: {
    FAST: 100,
    NORMAL: 200,
    SLOW: 300,
  },
  // Focus scale factor
  FOCUS_SCALE: 1.05,
} as const;

// Streaming configuration
export const STREAM_CONFIG = {
  // UI update throttle (ms) - 20fps max for smooth TV rendering
  UI_THROTTLE: 50,
  // Connection timeout (ms)
  TIMEOUT: 30000,
  // Max retries on failure
  MAX_RETRIES: 3,
} as const;

// Storage keys
export const STORAGE_KEYS = {
  // Secure storage (encrypted)
  API_KEYS: {
    ANTHROPIC: 'thea_api_anthropic',
    OPENAI: 'thea_api_openai',
    OPENROUTER: 'thea_api_openrouter',
    GOOGLE: 'thea_api_google',
    TRAKT_ACCESS: 'thea_trakt_access',
    TRAKT_REFRESH: 'thea_trakt_refresh',
  },
  // Local storage
  SETTINGS: 'thea_settings',
  DEVICE_ID: 'thea_device_id',
  DEVICE_TOKEN: 'thea_device_token',
  LAST_SYNC: 'thea_last_sync',
  CONVERSATIONS: 'thea_conversations',
  MESSAGES: 'thea_messages',
} as const;

// IndexedDB configuration
export const IDB_CONFIG = {
  NAME: 'TheaDB',
  VERSION: 1,
  STORES: {
    CONVERSATIONS: 'conversations',
    MESSAGES: 'messages',
    SYNC_QUEUE: 'syncQueue',
  },
} as const;

// App metadata
export const APP_INFO = {
  NAME: 'THEA',
  VERSION: '1.0.0',
  PLATFORM: 'samsung-tizen',
  BUILD: import.meta.env.PROD ? 'release' : 'debug',
} as const;
