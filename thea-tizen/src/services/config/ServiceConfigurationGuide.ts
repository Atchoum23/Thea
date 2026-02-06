/**
 * Service Configuration Guide
 *
 * Documents what each service needs to be configured and how users can set them up.
 * This serves as both documentation and a schema for the configuration UI.
 */

export interface ServiceConfig {
  id: string;
  name: string;
  description: string;
  status: 'configured' | 'partial' | 'not_configured';
  required: ConfigField[];
  optional: ConfigField[];
  setupMethod: 'automatic' | 'oauth' | 'manual' | 'hybrid';
  setupInstructions?: string[];
}

export interface ConfigField {
  key: string;
  label: string;
  type: 'text' | 'password' | 'url' | 'number' | 'boolean' | 'select' | 'multi-select';
  placeholder?: string;
  hint?: string;
  options?: { value: string; label: string }[];
  validation?: {
    required?: boolean;
    pattern?: string;
    min?: number;
    max?: number;
  };
}

/**
 * All configurable services in Thea
 */
export const SERVICE_CONFIGURATIONS: ServiceConfig[] = [
  // ============================================================
  // CORE AI SERVICES
  // ============================================================
  {
    id: 'openrouter',
    name: 'OpenRouter',
    description: 'Access to 100+ AI models through one API. Recommended as default provider.',
    status: 'not_configured',
    setupMethod: 'manual',
    required: [
      {
        key: 'apiKey',
        label: 'API Key',
        type: 'password',
        placeholder: 'sk-or-v1-...',
        hint: 'Get from openrouter.ai/keys',
        validation: { required: true, pattern: '^sk-or-' },
      },
    ],
    optional: [
      {
        key: 'defaultModel',
        label: 'Default Model',
        type: 'select',
        options: [
          { value: 'anthropic/claude-3.5-sonnet', label: 'Claude 3.5 Sonnet (Recommended)' },
          { value: 'anthropic/claude-3-opus', label: 'Claude 3 Opus' },
          { value: 'openai/gpt-4-turbo', label: 'GPT-4 Turbo' },
          { value: 'google/gemini-pro', label: 'Gemini Pro' },
        ],
      },
    ],
    setupInstructions: [
      'Go to openrouter.ai and create an account',
      'Navigate to Keys section',
      'Create a new API key',
      'Copy the key and paste it here',
    ],
  },
  {
    id: 'anthropic',
    name: 'Anthropic (Claude)',
    description: 'Direct access to Claude models. Better rate limits than OpenRouter.',
    status: 'not_configured',
    setupMethod: 'manual',
    required: [
      {
        key: 'apiKey',
        label: 'API Key',
        type: 'password',
        placeholder: 'sk-ant-...',
        hint: 'Get from console.anthropic.com',
        validation: { required: true, pattern: '^sk-ant-' },
      },
    ],
    optional: [
      {
        key: 'defaultModel',
        label: 'Default Model',
        type: 'select',
        options: [
          { value: 'claude-3-5-sonnet-20241022', label: 'Claude 3.5 Sonnet (Latest)' },
          { value: 'claude-3-opus-20240229', label: 'Claude 3 Opus' },
          { value: 'claude-3-haiku-20240307', label: 'Claude 3 Haiku (Fast)' },
        ],
      },
    ],
  },

  // ============================================================
  // MEDIA DISCOVERY
  // ============================================================
  {
    id: 'tmdb',
    name: 'TMDB',
    description: 'Movie and TV show metadata, posters, streaming availability.',
    status: 'configured', // Pre-configured with user's key
    setupMethod: 'manual',
    required: [
      {
        key: 'apiKey',
        label: 'API Key (v3)',
        type: 'password',
        hint: 'Get from themoviedb.org/settings/api',
        validation: { required: true },
      },
    ],
    optional: [
      {
        key: 'accessToken',
        label: 'Access Token (v4)',
        type: 'password',
        hint: 'For advanced API features',
      },
      {
        key: 'defaultRegion',
        label: 'Default Region',
        type: 'select',
        options: [
          { value: 'CH', label: 'Switzerland' },
          { value: 'FR', label: 'France' },
          { value: 'US', label: 'United States' },
          { value: 'DE', label: 'Germany' },
        ],
      },
    ],
  },
  {
    id: 'trakt',
    name: 'Trakt',
    description: 'Track what you watch, get recommendations, sync across devices.',
    status: 'not_configured',
    setupMethod: 'oauth',
    required: [
      {
        key: 'clientId',
        label: 'Client ID',
        type: 'text',
        hint: 'Create app at trakt.tv/oauth/applications',
        validation: { required: true },
      },
      {
        key: 'clientSecret',
        label: 'Client Secret',
        type: 'password',
        validation: { required: true },
      },
    ],
    optional: [],
    setupInstructions: [
      'Go to trakt.tv/oauth/applications',
      'Create a new application',
      'Set Redirect URI to: urn:ietf:wg:oauth:2.0:oob',
      'Copy Client ID and Secret here',
      'Click "Authenticate" to complete OAuth flow',
    ],
  },

  // ============================================================
  // LOCAL MEDIA
  // ============================================================
  {
    id: 'plex',
    name: 'Plex Media Server',
    description: 'Check your Plex library before downloading. Avoid duplicates.',
    status: 'not_configured',
    setupMethod: 'hybrid', // OAuth for token + manual for server
    required: [
      {
        key: 'serverUrl',
        label: 'Server URL',
        type: 'url',
        placeholder: 'http://192.168.1.100:32400',
        hint: 'Your Plex server address',
        validation: { required: true, pattern: '^https?://' },
      },
      {
        key: 'token',
        label: 'X-Plex-Token',
        type: 'password',
        hint: 'Find in Plex Web → ... → Get Info → View XML',
        validation: { required: true },
      },
    ],
    optional: [
      {
        key: 'serverName',
        label: 'Server Name',
        type: 'text',
        placeholder: 'MSM3U',
        hint: 'Friendly name for display',
      },
      {
        key: 'movieLibraries',
        label: 'Movie Libraries',
        type: 'multi-select',
        hint: 'Libraries to check for movies',
      },
      {
        key: 'tvLibraries',
        label: 'TV Libraries',
        type: 'multi-select',
        hint: 'Libraries to check for TV shows',
      },
    ],
    setupInstructions: [
      'Open Plex Web (app.plex.tv)',
      'Navigate to any media item',
      'Click ... → Get Info → View XML',
      'Copy X-Plex-Token from the URL',
      'Enter your server IP/hostname and port',
    ],
  },

  // ============================================================
  // DOWNLOAD AUTOMATION
  // ============================================================
  {
    id: 'syncBridge',
    name: 'Sync Bridge',
    description: 'Connect to your Mac for downloads, notifications, and iCloud sync.',
    status: 'not_configured',
    setupMethod: 'automatic',
    required: [
      {
        key: 'url',
        label: 'Bridge URL',
        type: 'url',
        placeholder: 'https://your-worker.workers.dev',
        hint: 'Cloudflare Worker URL or local Mac address',
        validation: { required: true },
      },
      {
        key: 'deviceToken',
        label: 'Device Token',
        type: 'password',
        hint: 'Generated automatically on first connection',
      },
    ],
    optional: [
      {
        key: 'autoSync',
        label: 'Auto Sync',
        type: 'boolean',
        hint: 'Automatically sync conversations and settings',
      },
      {
        key: 'syncIntervalMinutes',
        label: 'Sync Interval',
        type: 'number',
        hint: 'Minutes between syncs',
        validation: { min: 5, max: 60 },
      },
    ],
  },
  {
    id: 'prowlarr',
    name: 'Prowlarr',
    description: 'Unified torrent indexer search. Required for auto-downloads.',
    status: 'not_configured',
    setupMethod: 'manual',
    required: [
      {
        key: 'url',
        label: 'Prowlarr URL',
        type: 'url',
        placeholder: 'http://192.168.1.100:9696',
        validation: { required: true },
      },
      {
        key: 'apiKey',
        label: 'API Key',
        type: 'password',
        hint: 'Settings → General → API Key',
        validation: { required: true },
      },
    ],
    optional: [
      {
        key: 'preferredIndexers',
        label: 'Preferred Indexers',
        type: 'multi-select',
        hint: 'Prioritize certain indexers',
      },
    ],
  },
  {
    id: 'qbittorrent',
    name: 'qBittorrent',
    description: 'Download client for automated downloads.',
    status: 'not_configured',
    setupMethod: 'manual',
    required: [
      {
        key: 'url',
        label: 'qBittorrent URL',
        type: 'url',
        placeholder: 'http://192.168.1.100:8080',
        validation: { required: true },
      },
      {
        key: 'username',
        label: 'Username',
        type: 'text',
        validation: { required: true },
      },
      {
        key: 'password',
        label: 'Password',
        type: 'password',
        validation: { required: true },
      },
    ],
    optional: [
      {
        key: 'movieCategory',
        label: 'Movie Category',
        type: 'text',
        placeholder: 'movies',
      },
      {
        key: 'tvCategory',
        label: 'TV Category',
        type: 'text',
        placeholder: 'tv',
      },
      {
        key: 'savePath',
        label: 'Save Path',
        type: 'text',
        placeholder: '/downloads',
      },
    ],
  },

  // ============================================================
  // VPN & STREAMING
  // ============================================================
  {
    id: 'nordvpn',
    name: 'NordVPN SmartDNS',
    description: 'Access geo-restricted streaming content without VPN overhead.',
    status: 'configured', // Pre-configured with user's values
    setupMethod: 'hybrid',
    required: [
      {
        key: 'serviceUsername',
        label: 'Service Username',
        type: 'text',
        hint: 'From NordVPN Dashboard → Manual Setup',
        validation: { required: true },
      },
      {
        key: 'servicePassword',
        label: 'Service Password',
        type: 'password',
        validation: { required: true },
      },
    ],
    optional: [
      {
        key: 'smartDNSPrimary',
        label: 'Primary DNS',
        type: 'text',
        placeholder: '103.86.96.103',
        hint: 'Provided after SmartDNS activation',
      },
      {
        key: 'smartDNSSecondary',
        label: 'Secondary DNS',
        type: 'text',
        placeholder: '103.86.99.103',
      },
      {
        key: 'activatedIP',
        label: 'Activated IP',
        type: 'text',
        hint: 'Your public IP when SmartDNS was activated',
      },
    ],
    setupInstructions: [
      'Log into NordVPN Dashboard',
      'Go to Manual Setup → Service Credentials',
      'Copy username and password',
      'Go to SmartDNS → Activate',
      'Note the DNS servers provided',
      'Configure your TV DNS manually',
    ],
  },
  {
    id: 'streamingAccounts',
    name: 'Streaming Accounts',
    description: 'Configure which streaming services you have access to.',
    status: 'configured',
    setupMethod: 'manual',
    required: [],
    optional: [
      {
        key: 'netflix',
        label: 'Netflix Regions',
        type: 'multi-select',
        options: [
          { value: 'CH', label: 'Switzerland' },
          { value: 'FR', label: 'France' },
          { value: 'US', label: 'United States' },
          { value: 'RU', label: 'Russia' },
        ],
      },
      {
        key: 'amazonPrime',
        label: 'Prime Video Regions',
        type: 'multi-select',
        options: [
          { value: 'CH', label: 'Switzerland' },
          { value: 'FR', label: 'France' },
          { value: 'US', label: 'United States' },
          { value: 'RU', label: 'Russia' },
        ],
      },
      {
        key: 'appleTv',
        label: 'Apple TV+ Regions',
        type: 'multi-select',
        options: [
          { value: 'CH', label: 'Switzerland' },
          { value: 'FR', label: 'France' },
          { value: 'US', label: 'United States' },
          { value: 'RU', label: 'Russia' },
        ],
      },
      {
        key: 'canalPlus',
        label: 'Canal+',
        type: 'boolean',
      },
      {
        key: 'youtubePremium',
        label: 'YouTube Premium',
        type: 'boolean',
      },
      {
        key: 'swisscomBlue',
        label: 'Swisscom blue TV',
        type: 'boolean',
      },
    ],
  },

  // ============================================================
  // QUALITY PREFERENCES
  // ============================================================
  {
    id: 'qualityPrefs',
    name: 'Quality Preferences',
    description: 'Configure download quality based on TRaSH Guides recommendations.',
    status: 'configured',
    setupMethod: 'manual',
    required: [],
    optional: [
      {
        key: 'preferredResolution',
        label: 'Preferred Resolution',
        type: 'select',
        options: [
          { value: '2160p', label: '4K (2160p)' },
          { value: '1080p', label: 'Full HD (1080p)' },
          { value: '720p', label: 'HD (720p)' },
        ],
      },
      {
        key: 'maxSizeGB',
        label: 'Max File Size (GB)',
        type: 'number',
        validation: { min: 1, max: 100 },
      },
      {
        key: 'requireHDR',
        label: 'Require HDR for 4K',
        type: 'boolean',
      },
      {
        key: 'preferDolbyVision',
        label: 'Prefer Dolby Vision',
        type: 'boolean',
        hint: 'Must have HDR fallback for Samsung TVs',
      },
      {
        key: 'preferAtmos',
        label: 'Prefer Dolby Atmos',
        type: 'boolean',
      },
      {
        key: 'minSeeders',
        label: 'Minimum Seeders',
        type: 'number',
        validation: { min: 1, max: 100 },
      },
    ],
  },

  // ============================================================
  // AUTOMATION
  // ============================================================
  {
    id: 'episodeMonitor',
    name: 'Episode Monitor',
    description: 'Automatic episode tracking and downloading.',
    status: 'configured',
    setupMethod: 'manual',
    required: [],
    optional: [
      {
        key: 'enabled',
        label: 'Enable Monitoring',
        type: 'boolean',
      },
      {
        key: 'checkIntervalMinutes',
        label: 'Check Interval (minutes)',
        type: 'number',
        validation: { min: 15, max: 180 },
      },
      {
        key: 'autoDownload',
        label: 'Auto Download',
        type: 'boolean',
        hint: 'Download automatically when available',
      },
      {
        key: 'preferStreaming',
        label: 'Prefer Streaming',
        type: 'boolean',
        hint: 'Skip download if available on streaming',
      },
      {
        key: 'notifyOnAvailable',
        label: 'Notify When Available',
        type: 'boolean',
      },
      {
        key: 'notifyOnDownloaded',
        label: 'Notify When Downloaded',
        type: 'boolean',
      },
    ],
  },
  {
    id: 'releaseIntelligence',
    name: 'Release Intelligence',
    description: 'AI-powered download timing based on historical patterns.',
    status: 'configured',
    setupMethod: 'automatic',
    required: [],
    optional: [
      {
        key: 'learnFromHistory',
        label: 'Learn from History',
        type: 'boolean',
        hint: 'Improve timing based on past downloads',
      },
      {
        key: 'useNetworkDefaults',
        label: 'Use Network Defaults',
        type: 'boolean',
        hint: 'Netflix ~15min, Broadcast ~90min, Cable ~45min',
      },
      {
        key: 'waitForQuality',
        label: 'Wait for Preferred Quality',
        type: 'boolean',
        hint: 'Delay download to get better quality',
      },
      {
        key: 'maxWaitHours',
        label: 'Maximum Wait (hours)',
        type: 'number',
        validation: { min: 1, max: 24 },
      },
    ],
  },
];

/**
 * Get configuration status summary
 */
export function getConfigurationSummary(): {
  configured: number;
  partial: number;
  notConfigured: number;
  total: number;
} {
  const counts = {
    configured: 0,
    partial: 0,
    notConfigured: 0,
    total: SERVICE_CONFIGURATIONS.length,
  };

  for (const service of SERVICE_CONFIGURATIONS) {
    counts[service.status === 'configured' ? 'configured' :
           service.status === 'partial' ? 'partial' : 'notConfigured']++;
  }

  return counts;
}

/**
 * Get services that need configuration for a specific feature
 */
export function getRequiredServicesForFeature(feature: string): ServiceConfig[] {
  const featureRequirements: Record<string, string[]> = {
    'ai-chat': ['openrouter', 'anthropic'], // At least one
    'watch-tracking': ['trakt'],
    'episode-monitoring': ['trakt', 'syncBridge'],
    'auto-download': ['syncBridge', 'prowlarr', 'qbittorrent'],
    'plex-integration': ['plex'],
    'streaming-check': ['tmdb', 'streamingAccounts'],
    'smartdns': ['nordvpn'],
  };

  const requiredIds = featureRequirements[feature] || [];
  return SERVICE_CONFIGURATIONS.filter(s => requiredIds.includes(s.id));
}
