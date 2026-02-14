// Thea Chrome Extension - State Manager
// Manages extension state: defaults, persistence, broadcasting, and security validation

// ============================================================================
// Default State
// ============================================================================

export const defaultState = {
  // Feature toggles
  adBlockerEnabled: true,
  darkModeEnabled: false,
  privacyProtectionEnabled: true,
  passwordManagerEnabled: true,
  emailProtectionEnabled: true,
  printFriendlyEnabled: true,
  tabManagerEnabled: true,
  aiAssistantEnabled: true,
  videoControllerEnabled: true,
  memoryEnabled: true,

  // Dark mode settings
  darkModeConfig: {
    enabled: false,
    theme: 'midnight',
    followSystem: true,
    sitePrefs: {},
    customThemes: {},
    pausedUntil: null
  },

  // Video controller settings
  videoConfig: {
    enabled: true,
    defaultSpeed: 1.0,
    speedStep: 0.1,
    showOverlay: true,
    rememberSpeed: true,
    siteSpeedPrefs: {},
    autoSpeedRules: []
  },

  // Privacy config
  privacyConfig: {
    cookieAutoDecline: true,
    fingerprintProtection: true,
    referrerStripping: true,
    linkUnshimming: true,
    trackingParamRemoval: true,
    socialWidgetBlocking: false,
    webrtcProtection: false
  },

  // Stats
  stats: {
    adsBlocked: 0,
    trackersBlocked: 0,
    emailsProtected: 0,
    passwordsAutofilled: 0,
    pagesDarkened: 0,
    pagesCleaned: 0,
    dataSaved: 0,
    cookiesDeclined: 0,
    trackingParamsStripped: 0,
    memoriesSaved: 0
  },

  // Whitelist
  whitelist: [],

  // Email aliases
  emailAliases: [],

  // Connection to Thea app
  isConnectedToApp: false,
  lastSyncTime: null,

  // iCloud integration
  iCloudPasswordsConnected: false,
  iCloudHideMyEmailConnected: false,
  iCloudAuthenticatedOnce: false  // Once true, no re-auth needed
};

// ============================================================================
// State Instance
// ============================================================================

export let state = { ...defaultState };

// ============================================================================
// State Persistence
// ============================================================================

// Load state from storage
export async function loadState() {
  try {
    const stored = await chrome.storage.local.get('theaState');
    if (stored.theaState) {
      state = { ...defaultState, ...stored.theaState };
    }
  } catch (error) {
    console.error('Failed to load state:', error);
  }
}

// Save state to storage
export async function saveState() {
  try {
    await chrome.storage.local.set({ theaState: state });
  } catch (error) {
    console.error('Failed to save state:', error);
  }
}

// ============================================================================
// Broadcasting
// ============================================================================

// Broadcast message to all tabs
export async function broadcastToTabs(message) {
  const tabs = await chrome.tabs.query({});
  for (const tab of tabs) {
    try {
      await chrome.tabs.sendMessage(tab.id, message);
    } catch (e) {
      // Tab might not have content script
    }
  }
}

// ============================================================================
// Security Utilities
// ============================================================================

// SECURITY: Allowed state keys that can be updated from external sources
export const ALLOWED_EXTERNAL_STATE_KEYS = new Set([
  'adBlockerEnabled',
  'darkModeEnabled',
  'privacyProtectionEnabled',
  'passwordManagerEnabled',
  'emailProtectionEnabled',
  'printFriendlyEnabled',
  'tabManagerEnabled',
  'aiAssistantEnabled',
  'videoControllerEnabled',
  'memoryEnabled',
  'darkModeTheme',
  'darkModeFollowSystem',
  'whitelist'
]);

/**
 * Validates and sanitizes external state updates.
 * SECURITY: Only allows known keys to prevent arbitrary state injection.
 * @param {object} newState - The incoming state object
 * @returns {object} - Sanitized state with only allowed keys
 */
export function validateExternalState(newState) {
  if (!newState || typeof newState !== 'object') {
    return {};
  }
  const sanitized = {};
  for (const [key, value] of Object.entries(newState)) {
    if (ALLOWED_EXTERNAL_STATE_KEYS.has(key)) {
      // Validate value types for known keys
      if (key.endsWith('Enabled') && typeof value !== 'boolean') continue;
      if (key === 'whitelist' && !Array.isArray(value)) continue;
      if (key === 'darkModeTheme' && typeof value !== 'string') continue;
      sanitized[key] = value;
    }
  }
  return sanitized;
}
