// Thea Chrome Extension - Service Worker (Manifest V3)
// Background script for managing extension state and features
//
// Safari-like integration with:
// - iCloud Passwords (via native messaging to access Keychain)
// - iCloud Hide My Email (via direct iCloud.com API - like Safari)

import icloudBridge from './icloud-bridge.js';
import icloudClient from './icloud-client.js';

// ============================================================================
// State Management
// ============================================================================

const defaultState = {
  // Feature toggles
  adBlockerEnabled: true,
  darkModeEnabled: false,
  privacyProtectionEnabled: true,
  passwordManagerEnabled: true,
  emailProtectionEnabled: true,
  printFriendlyEnabled: true,
  tabManagerEnabled: true,
  aiAssistantEnabled: true,

  // Dark mode settings
  darkModeTheme: 'midnight',
  darkModeFollowSystem: true,
  darkModeSitePreferences: {},

  // Stats
  stats: {
    adsBlocked: 0,
    trackersBlocked: 0,
    emailsProtected: 0,
    passwordsAutofilled: 0,
    pagesDarkened: 0,
    pagesCleaned: 0,
    dataSaved: 0
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

let state = { ...defaultState };

// Load state from storage
async function loadState() {
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
async function saveState() {
  try {
    await chrome.storage.local.set({ theaState: state });
  } catch (error) {
    console.error('Failed to save state:', error);
  }
}

// Initialize
loadState();

// ============================================================================
// Security Utilities
// ============================================================================

// SECURITY: Allowed state keys that can be updated from external sources
const ALLOWED_EXTERNAL_STATE_KEYS = new Set([
  'adBlockerEnabled',
  'darkModeEnabled',
  'privacyProtectionEnabled',
  'passwordManagerEnabled',
  'emailProtectionEnabled',
  'printFriendlyEnabled',
  'tabManagerEnabled',
  'aiAssistantEnabled',
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
function validateExternalState(newState) {
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

// ============================================================================
// Message Handling
// ============================================================================

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  handleMessage(message, sender).then(sendResponse);
  return true; // Keep channel open for async response
});

async function handleMessage(message, sender) {
  switch (message.type) {
    case 'getState':
      return { success: true, data: state };

    case 'setState':
      Object.assign(state, message.data);
      await saveState();
      // Notify all tabs of state change
      broadcastToTabs({ type: 'stateChanged', data: state });
      return { success: true };

    case 'getStats':
      return { success: true, data: state.stats };

    case 'updateStats':
      Object.assign(state.stats, message.data);
      await saveState();
      return { success: true };

    case 'toggleFeature':
      const { feature, enabled } = message.data;
      state[feature] = enabled;
      await saveState();
      broadcastToTabs({ type: 'featureToggled', data: { feature, enabled } });
      return { success: true };

    case 'getDarkModeCSS':
      const css = await generateDarkModeCSS(message.data.domain);
      return { success: true, data: { css } };

    case 'getBlockingDecision':
      const decision = await checkShouldBlock(message.data.url, message.data.type);
      return { success: true, data: decision };

    case 'generateEmailAlias':
      const alias = await generateEmailAlias(message.data.domain);
      return { success: true, data: alias };

    case 'getCredentials':
      const credentials = await getCredentialsForDomain(message.data.domain);
      return { success: true, data: credentials };

    case 'cleanPage':
      const cleaned = await cleanPageContent(message.data.html, message.data.url);
      return { success: true, data: cleaned };

    case 'askAI':
      const response = await askTheaAI(message.data.question, message.data.context);
      return { success: true, data: { response } };

    case 'syncWithApp':
      const syncResult = await syncWithTheaApp();
      return { success: true, data: syncResult };

    // ========================================
    // iCloud Integration Messages
    // ========================================

    case 'connectiCloud':
      return await handleiCloudConnect();

    case 'disconnectiCloud':
      return await handleiCloudDisconnect();

    case 'getiCloudStatus':
      return await handleGetiCloudStatus();

    case 'getiCloudCredentials':
      return await handleGetiCloudCredentials(message.data.domain);

    case 'saveiCloudCredential':
      return await handleSaveiCloudCredential(message.data);

    case 'generateiCloudPassword':
      return await handleGenerateiCloudPassword();

    case 'autofillCredential':
      return await handleAutofillCredential(message.data.domain);

    case 'createHideMyEmailAlias':
      return await handleCreateHideMyEmailAlias(message.data.domain, message.data.label);

    case 'getHideMyEmailAliases':
      return await handleGetHideMyEmailAliases();

    case 'autofillHideMyEmail':
      return await handleAutofillHideMyEmail(message.data.domain);

    case 'openPasswordManager':
      return await handleOpenPasswordManager();

    default:
      return { success: false, error: 'Unknown message type' };
  }
}

// Broadcast message to all tabs
async function broadcastToTabs(message) {
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
// Ad Blocking
// ============================================================================

// Known ad/tracker domains (subset for demonstration)
const blockList = new Set([
  'doubleclick.net',
  'googlesyndication.com',
  'googleadservices.com',
  'google-analytics.com',
  'facebook.net',
  'facebook.com/tr',
  'connect.facebook.net',
  'amazon-adsystem.com',
  'criteo.com',
  'taboola.com',
  'outbrain.com'
]);

async function checkShouldBlock(url, resourceType) {
  if (!state.adBlockerEnabled) {
    return { shouldBlock: false };
  }

  try {
    const urlObj = new URL(url);
    const host = urlObj.hostname;

    // Check whitelist
    if (state.whitelist.some(domain => host.endsWith(domain))) {
      return { shouldBlock: false };
    }

    // Check blocklist
    for (const blocked of blockList) {
      if (host.includes(blocked)) {
        state.stats.adsBlocked++;
        await saveState();
        return { shouldBlock: true, reason: 'ad-tracker' };
      }
    }

    return { shouldBlock: false };
  } catch (e) {
    return { shouldBlock: false };
  }
}

// ============================================================================
// Dark Mode
// ============================================================================

const darkThemes = {
  pure: {
    bg: '#000000',
    text: '#ffffff',
    link: '#4da6ff',
    border: '#333333'
  },
  midnight: {
    bg: '#1a1a2e',
    text: '#eaeaea',
    link: '#6b9fff',
    border: '#2d2d44'
  },
  warm: {
    bg: '#1f1b18',
    text: '#e8e4df',
    link: '#d4a574',
    border: '#3d3530'
  },
  nord: {
    bg: '#2e3440',
    text: '#eceff4',
    link: '#88c0d0',
    border: '#3b4252'
  },
  oled: {
    bg: '#000000',
    text: '#ffffff',
    link: '#4fc3f7',
    border: '#1a1a1a'
  }
};

async function generateDarkModeCSS(domain) {
  if (!state.darkModeEnabled) {
    return '';
  }

  // Check site preferences
  const sitePref = state.darkModeSitePreferences[domain];
  if (sitePref === 'never') {
    return '';
  }

  const themeName = sitePref?.theme || state.darkModeTheme;
  const theme = darkThemes[themeName] || darkThemes.midnight;

  return `
    :root {
      --thea-bg: ${theme.bg};
      --thea-text: ${theme.text};
      --thea-link: ${theme.link};
      --thea-border: ${theme.border};
    }

    html, body {
      background-color: var(--thea-bg) !important;
      color: var(--thea-text) !important;
    }

    * {
      border-color: var(--thea-border) !important;
    }

    a, a:link, a:visited {
      color: var(--thea-link) !important;
    }

    input, textarea, select, button {
      background-color: ${adjustBrightness(theme.bg, 0.1)} !important;
      color: var(--thea-text) !important;
      border-color: var(--thea-border) !important;
    }

    img {
      opacity: 0.9;
    }

    ::selection {
      background-color: var(--thea-link) !important;
      color: var(--thea-bg) !important;
    }
  `;
}

function adjustBrightness(hex, amount) {
  const num = parseInt(hex.replace('#', ''), 16);
  const r = Math.min(255, Math.max(0, (num >> 16) + amount * 255));
  const g = Math.min(255, Math.max(0, ((num >> 8) & 0x00FF) + amount * 255));
  const b = Math.min(255, Math.max(0, (num & 0x0000FF) + amount * 255));
  return `#${((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)}`;
}

// ============================================================================
// Email Protection (Legacy - for non-iCloud)
// ============================================================================

async function generateEmailAlias(domain) {
  if (!state.emailProtectionEnabled) {
    throw new Error('Email protection is disabled');
  }

  // Generate random alias
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  let localPart = '';
  for (let i = 0; i < 12; i++) {
    localPart += chars[Math.floor(Math.random() * chars.length)];
  }

  const alias = {
    id: crypto.randomUUID(),
    alias: `${localPart}@alias.thea.app`,
    domain: domain,
    createdAt: new Date().toISOString(),
    isEnabled: true,
    emailsReceived: 0,
    trackersBlocked: 0
  };

  state.emailAliases.push(alias);
  state.stats.emailsProtected++;
  await saveState();

  return alias;
}

// ============================================================================
// Password Manager (Interface to native app)
// ============================================================================

async function getCredentialsForDomain(domain) {
  if (!state.passwordManagerEnabled) {
    return [];
  }

  // This would communicate with the native Thea app
  // For now, return empty (credentials handled by native app)
  try {
    const response = await chrome.runtime.sendNativeMessage(
      'com.thea.app',
      { type: 'getCredentials', domain }
    );
    return response.credentials || [];
  } catch (e) {
    console.log('Native messaging not available, using stored credentials');
    return [];
  }
}

// ============================================================================
// Print Friendly
// ============================================================================

async function cleanPageContent(html, url) {
  if (!state.printFriendlyEnabled) {
    return { content: html };
  }

  // Remove common clutter elements
  const removeSelectors = [
    'nav', 'header', 'footer', 'aside',
    '.ad', '.ads', '.advertisement', '.sidebar',
    '.social-share', '.comments', '.related-posts',
    '[data-ad]', '[data-advertisement]', '.promo', '.banner'
  ].join(', ');

  // This is a simplified version - full implementation in content script
  let cleaned = html;

  // Remove script tags
  cleaned = cleaned.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');

  // Remove style tags
  cleaned = cleaned.replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, '');

  state.stats.pagesCleaned++;
  await saveState();

  return {
    content: cleaned,
    wordCount: cleaned.split(/\s+/).length,
    estimatedReadTime: Math.ceil(cleaned.split(/\s+/).length / 200)
  };
}

// ============================================================================
// AI Assistant
// ============================================================================

async function askTheaAI(question, context) {
  if (!state.aiAssistantEnabled) {
    return 'AI assistant is disabled';
  }

  // This would communicate with Thea's AI backend
  try {
    const response = await fetch('https://api.thea.app/v1/quick-prompt', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ question, context })
    });

    if (response.ok) {
      const data = await response.json();
      return data.response;
    }
  } catch (e) {
    console.error('AI request failed:', e);
  }

  return 'Unable to connect to Thea AI';
}

// ============================================================================
// App Synchronization
// ============================================================================

async function syncWithTheaApp() {
  try {
    // Try native messaging first
    const response = await chrome.runtime.sendNativeMessage(
      'com.thea.app',
      { type: 'sync', state }
    );

    if (response.success) {
      state.isConnectedToApp = true;
      state.lastSyncTime = new Date().toISOString();

      // Merge state from app
      if (response.state) {
        Object.assign(state, response.state);
      }

      await saveState();
      return { success: true, synced: true };
    }
  } catch (e) {
    console.log('Native messaging sync failed:', e);
  }

  // Try WebSocket connection to local app
  try {
    const ws = new WebSocket('ws://localhost:9876/extension');

    return new Promise((resolve, reject) => {
      ws.onopen = () => {
        ws.send(JSON.stringify({ type: 'sync', state }));
      };

      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          if (data.success) {
            state.isConnectedToApp = true;
            state.lastSyncTime = new Date().toISOString();
            // SECURITY: Validate and sanitize incoming state from WebSocket
            if (data.state) {
              const validatedState = validateExternalState(data.state);
              Object.assign(state, validatedState);
            }
            saveState();
            resolve({ success: true, synced: true });
          }
        } catch (parseError) {
          console.error('Failed to parse WebSocket message:', parseError);
          resolve({ success: false, synced: false, error: 'invalid message format' });
        }
        ws.close();
      };

      ws.onerror = () => {
        state.isConnectedToApp = false;
        resolve({ success: false, synced: false });
      };

      setTimeout(() => {
        ws.close();
        resolve({ success: false, synced: false, error: 'timeout' });
      }, 5000);
    });
  } catch (e) {
    state.isConnectedToApp = false;
    return { success: false, synced: false };
  }
}

// ============================================================================
// Context Menus
// ============================================================================

chrome.runtime.onInstalled.addListener(() => {
  // Create context menus
  chrome.contextMenus.create({
    id: 'thea-clean-page',
    title: 'Clean Page for Printing',
    contexts: ['page']
  });

  chrome.contextMenus.create({
    id: 'thea-generate-alias',
    title: 'Hide My Email',
    contexts: ['editable']
  });

  chrome.contextMenus.create({
    id: 'thea-ask-ai',
    title: 'Ask Thea AI',
    contexts: ['selection']
  });

  chrome.contextMenus.create({
    id: 'thea-save-password',
    title: 'Save Password',
    contexts: ['password']
  });
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  switch (info.menuItemId) {
    case 'thea-clean-page':
      chrome.tabs.sendMessage(tab.id, { type: 'cleanPage' });
      break;

    case 'thea-generate-alias':
      const url = new URL(tab.url);
      // Use iCloud Hide My Email if connected, otherwise fallback
      if (icloudClient.isAuthenticated) {
        const result = await handleAutofillHideMyEmail(url.hostname);
        if (result.success) {
          chrome.tabs.sendMessage(tab.id, {
            type: 'insertAlias',
            alias: result.data.email,
            source: 'iCloud Hide My Email'
          });
        }
      } else {
        const alias = await generateEmailAlias(url.hostname);
        chrome.tabs.sendMessage(tab.id, { type: 'insertAlias', alias: alias.alias });
      }
      break;

    case 'thea-ask-ai':
      const response = await askTheaAI(
        `Explain: ${info.selectionText}`,
        { url: tab.url, title: tab.title }
      );
      chrome.tabs.sendMessage(tab.id, { type: 'showAIResponse', response });
      break;

    case 'thea-save-password':
      chrome.tabs.sendMessage(tab.id, { type: 'savePassword' });
      break;
  }
});

// ============================================================================
// Keyboard Commands
// ============================================================================

chrome.commands.onCommand.addListener(async (command) => {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

  switch (command) {
    case 'toggle-dark-mode':
      state.darkModeEnabled = !state.darkModeEnabled;
      state.stats.pagesDarkened++;
      await saveState();
      chrome.tabs.sendMessage(tab.id, {
        type: 'toggleDarkMode',
        enabled: state.darkModeEnabled
      });
      break;

    case 'quick-prompt':
      chrome.tabs.sendMessage(tab.id, { type: 'showQuickPrompt' });
      break;

    case 'clean-page':
      chrome.tabs.sendMessage(tab.id, { type: 'cleanPage' });
      break;
  }
});

// ============================================================================
// Tab Management
// ============================================================================

chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
  if (changeInfo.status === 'complete' && tab.url) {
    // Inject protections
    try {
      const url = new URL(tab.url);
      const domain = url.hostname;

      // Get dark mode CSS if enabled
      if (state.darkModeEnabled) {
        const css = await generateDarkModeCSS(domain);
        if (css) {
          await chrome.scripting.insertCSS({
            target: { tabId },
            css
          });
        }
      }

      // Notify content script
      chrome.tabs.sendMessage(tabId, {
        type: 'pageLoaded',
        domain,
        state: {
          adBlockerEnabled: state.adBlockerEnabled,
          darkModeEnabled: state.darkModeEnabled,
          privacyProtectionEnabled: state.privacyProtectionEnabled,
          iCloudConnected: icloudClient.isAuthenticated
        }
      });
    } catch (e) {
      // Tab might not support messaging
    }
  }
});

// ============================================================================
// Alarms for periodic tasks
// ============================================================================

chrome.alarms.create('syncWithApp', { periodInMinutes: 5 });
chrome.alarms.create('updateStats', { periodInMinutes: 1 });
chrome.alarms.create('refreshiCloudAliases', { periodInMinutes: 30 });

chrome.alarms.onAlarm.addListener(async (alarm) => {
  switch (alarm.name) {
    case 'syncWithApp':
      await syncWithTheaApp();
      break;

    case 'updateStats':
      // Badge update
      const blocked = state.stats.adsBlocked + state.stats.trackersBlocked;
      if (blocked > 0) {
        chrome.action.setBadgeText({ text: formatNumber(blocked) });
        chrome.action.setBadgeBackgroundColor({ color: '#4CAF50' });
      }
      break;

    case 'refreshiCloudAliases':
      // Refresh Hide My Email aliases periodically
      if (icloudClient.isAuthenticated) {
        await icloudClient.getAliases().catch(err => {
          console.log('Failed to refresh aliases:', err.message);
        });
      }
      break;
  }
});

function formatNumber(num) {
  if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
  if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
  return num.toString();
}

// ============================================================================
// External Connections (from Thea app)
// ============================================================================

// SECURITY: Allowed origins for external connections
const ALLOWED_EXTERNAL_ORIGINS = new Set([
  'chrome-extension://', // Thea companion extension
  'https://thea.app',
  'https://www.thea.app',
  'http://localhost:3000',  // Local development
  'http://localhost:9876'   // Local WebSocket development
]);

/**
 * Validates external connection origin
 */
function isAllowedExternalOrigin(origin) {
  if (!origin) return false;
  return Array.from(ALLOWED_EXTERNAL_ORIGINS).some(allowed =>
    origin === allowed || origin.startsWith(allowed)
  );
}

chrome.runtime.onConnectExternal.addListener((port) => {
  const senderOrigin = port.sender?.origin || port.sender?.url || '';
  console.log('External connection attempt from:', senderOrigin);

  // SECURITY: Validate origin before accepting connection
  if (!isAllowedExternalOrigin(senderOrigin)) {
    console.warn('Rejected external connection from unauthorized origin:', senderOrigin);
    port.postMessage({ success: false, error: 'Unauthorized origin' });
    port.disconnect();
    return;
  }

  console.log('External connection accepted from:', senderOrigin);

  port.onMessage.addListener(async (message) => {
    switch (message.type) {
      case 'sync':
        // SECURITY: Validate and sanitize incoming state
        const validatedState = validateExternalState(message.state);
        Object.assign(state, validatedState);
        state.isConnectedToApp = true;
        state.lastSyncTime = new Date().toISOString();
        await saveState();
        port.postMessage({ success: true, state });
        break;

      case 'getState':
        port.postMessage({ success: true, state });
        break;

      case 'updateCredentials':
        // Password manager update from app
        port.postMessage({ success: true });
        break;

      default:
        port.postMessage({ success: false, error: 'Unknown message type' });
    }
  });
});

// ============================================================================
// iCloud Integration (Safari-like experience for Chrome/Brave)
// ============================================================================

/**
 * Connect to iCloud services
 * - Hide My Email: Uses direct iCloud.com API (like Safari)
 * - Passwords: Uses native messaging host (for Keychain access)
 */
async function handleiCloudConnect() {
  try {
    // Connect to iCloud via direct API (for Hide My Email)
    const icloudResult = await icloudClient.validateSession();

    // Connect via native messaging (for Passwords/Keychain)
    let nativeResult = { success: false };
    try {
      nativeResult = await icloudBridge.connect();
    } catch (e) {
      console.log('Native messaging not available:', e.message);
    }

    if (icloudResult.success || nativeResult.success) {
      state.iCloudHideMyEmailConnected = icloudResult.success && icloudResult.hasHideMyEmail;
      state.iCloudPasswordsConnected = nativeResult.success;
      state.iCloudAuthenticatedOnce = true;
      await saveState();

      return {
        success: true,
        data: {
          passwordsConnected: state.iCloudPasswordsConnected,
          hideMyEmailConnected: state.iCloudHideMyEmailConnected,
          userInfo: icloudResult.userInfo,
          message: state.iCloudHideMyEmailConnected
            ? 'Connected to iCloud. Hide My Email is ready!'
            : 'Partial connection. Please sign in to iCloud.com for Hide My Email.'
        }
      };
    } else {
      return {
        success: false,
        error: 'Not signed in to iCloud',
        requiresLogin: true,
        suggestion: 'Please sign in to iCloud.com in your browser to enable Hide My Email.'
      };
    }
  } catch (error) {
    return {
      success: false,
      error: error.message,
      suggestion: 'Please sign in to iCloud.com in your browser.'
    };
  }
}

/**
 * Disconnect from iCloud services
 */
async function handleiCloudDisconnect() {
  await icloudClient.disconnect();
  icloudBridge.disconnect();

  state.iCloudPasswordsConnected = false;
  state.iCloudHideMyEmailConnected = false;
  state.iCloudAuthenticatedOnce = false;
  await saveState();

  return { success: true, data: { disconnected: true } };
}

/**
 * Get current iCloud connection status
 */
async function handleGetiCloudStatus() {
  const icloudStatus = icloudClient.getStatus();
  const nativeStatus = await icloudBridge.getStatus();

  return {
    success: true,
    data: {
      connected: icloudStatus.isAuthenticated || nativeStatus.connected,
      hideMyEmailConnected: icloudStatus.isAuthenticated && icloudStatus.hasHideMyEmail,
      hideMyEmailAuthenticated: icloudStatus.isAuthenticated,
      passwordsConnected: nativeStatus.passwordsConnected || false,
      passwordsAuthenticated: nativeStatus.passwordsAuthenticated || false,
      userInfo: icloudStatus.userInfo,
      aliasCount: icloudStatus.aliasCount,
      lastSync: icloudStatus.lastSync,
      requiresReauth: !state.iCloudAuthenticatedOnce
    }
  };
}

/**
 * Get credentials from iCloud Keychain for a domain
 * Uses native messaging host to access Keychain
 */
async function handleGetiCloudCredentials(domain) {
  if (!state.iCloudPasswordsConnected) {
    // Try to connect first
    try {
      await icloudBridge.connect();
      state.iCloudPasswordsConnected = true;
    } catch (e) {
      return {
        success: false,
        error: 'iCloud Passwords not connected',
        suggestion: 'Install and configure the Thea native host for Keychain access.'
      };
    }
  }

  try {
    const credentials = await icloudBridge.getCredentials(domain);
    return {
      success: true,
      data: {
        credentials,
        source: 'iCloud Keychain',
        count: credentials.length
      }
    };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

/**
 * Save a credential to iCloud Keychain (Passwords.app)
 */
async function handleSaveiCloudCredential({ username, password, domain, notes }) {
  if (!state.iCloudPasswordsConnected) {
    return {
      success: false,
      error: 'iCloud Passwords not connected',
      suggestion: 'Install and configure the Thea native host for Keychain access.'
    };
  }

  try {
    await icloudBridge.saveCredential({ username, password, domain, notes });
    state.stats.passwordsAutofilled++;
    await saveState();

    return {
      success: true,
      data: {
        saved: true,
        message: 'Password saved to iCloud Keychain (Passwords.app)',
        synced: true
      }
    };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

/**
 * Generate a strong password (Apple format)
 * Uses native host to call SecCreateSharedWebCredentialPassword
 */
async function handleGenerateiCloudPassword() {
  try {
    const password = await icloudBridge.generatePassword();
    return {
      success: true,
      data: {
        password,
        format: 'Apple Strong Password'
      }
    };
  } catch (error) {
    // Fallback to local generation if native host unavailable
    const password = generateAppleStylePassword();
    return {
      success: true,
      data: {
        password,
        format: 'Apple Strong Password (Local)'
      }
    };
  }
}

/**
 * Generate Apple-style password locally (fallback)
 */
function generateAppleStylePassword() {
  const lowercase = 'abcdefghjkmnpqrstuvwxyz';
  const uppercase = 'ABCDEFGHJKMNPQRSTUVWXYZ';
  const digits = '23456789';

  function randomChar(charset) {
    return charset[Math.floor(Math.random() * charset.length)];
  }

  function generateGroup() {
    let group = '';
    group += randomChar(lowercase);
    group += randomChar(uppercase);
    group += randomChar(digits);

    const allChars = lowercase + uppercase + digits;
    for (let i = 0; i < 3; i++) {
      group += randomChar(allChars);
    }

    return group.split('').sort(() => Math.random() - 0.5).join('');
  }

  return `${generateGroup()}-${generateGroup()}-${generateGroup()}`;
}

/**
 * Autofill credential for a domain
 */
async function handleAutofillCredential(domain) {
  if (!state.iCloudPasswordsConnected) {
    return {
      success: false,
      error: 'iCloud Passwords not connected'
    };
  }

  try {
    const result = await icloudBridge.autofillCredential(domain);

    if (result.found) {
      state.stats.passwordsAutofilled++;
      await saveState();
    }

    return {
      success: true,
      data: result
    };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

/**
 * Create a new Hide My Email alias
 * Uses direct iCloud.com API (like Safari)
 * Returns a real @icloud.com address
 */
async function handleCreateHideMyEmailAlias(domain, label) {
  if (!icloudClient.isAuthenticated) {
    const result = await icloudClient.validateSession();
    if (!result.success) {
      return {
        success: false,
        error: 'Not signed in to iCloud',
        requiresLogin: true,
        suggestion: 'Please sign in to iCloud.com to use Hide My Email.'
      };
    }
  }

  try {
    const alias = await icloudClient.createAlias(domain, label);
    state.stats.emailsProtected++;
    state.iCloudHideMyEmailConnected = true;
    await saveState();

    return {
      success: true,
      data: {
        alias,
        email: alias.email,
        isNew: true,
        message: 'Hide My Email alias created and saved to iCloud',
        synced: true
      }
    };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      suggestion: error.message.includes('Authentication')
        ? 'Please sign in to iCloud.com'
        : undefined
    };
  }
}

/**
 * Get all Hide My Email aliases from iCloud
 */
async function handleGetHideMyEmailAliases() {
  if (!icloudClient.isAuthenticated) {
    const result = await icloudClient.validateSession();
    if (!result.success) {
      return {
        success: false,
        error: 'Not signed in to iCloud',
        requiresLogin: true
      };
    }
  }

  try {
    const aliases = await icloudClient.getAliases();
    return {
      success: true,
      data: {
        aliases,
        source: 'iCloud Hide My Email',
        count: aliases.length
      }
    };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

/**
 * Autofill Hide My Email (creates alias if needed)
 * Safari-like behavior: creates new alias for new domains
 */
async function handleAutofillHideMyEmail(domain) {
  if (!icloudClient.isAuthenticated) {
    const result = await icloudClient.validateSession();
    if (!result.success) {
      return {
        success: false,
        error: 'Not signed in to iCloud',
        requiresLogin: true,
        suggestion: 'Please sign in to iCloud.com to use Hide My Email.'
      };
    }
  }

  try {
    // Check if we already have an alias for this domain
    const existingAlias = icloudClient.getAliasForDomain(domain);

    if (existingAlias) {
      return {
        success: true,
        data: {
          email: existingAlias.email,
          isNew: false,
          source: 'iCloud Hide My Email'
        }
      };
    }

    // Create new alias for this domain
    const newAlias = await icloudClient.createAlias(domain);
    state.stats.emailsProtected++;
    await saveState();

    return {
      success: true,
      data: {
        email: newAlias.email,
        isNew: true,
        source: 'iCloud Hide My Email'
      }
    };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      suggestion: 'Please sign in to iCloud.com'
    };
  }
}

/**
 * Open the password manager (Passwords.app on macOS or settings)
 */
async function handleOpenPasswordManager() {
  // Try to open Passwords.app via native messaging
  try {
    await icloudBridge.sendRequest('openPasswordManager', {});
  } catch (e) {
    // Fallback: open iCloud settings in browser
    chrome.tabs.create({ url: 'https://www.icloud.com/passwords/' });
  }
  return { success: true };
}

// ============================================================================
// Event Listeners for iCloud
// ============================================================================

// iCloud Direct Client events (Hide My Email)
icloudClient.on('authenticated', (userInfo) => {
  console.log('iCloud authenticated:', userInfo?.firstName);
  state.iCloudHideMyEmailConnected = true;
  saveState();
  broadcastToTabs({ type: 'iCloudConnected', data: { hideMyEmail: true } });
});

icloudClient.on('disconnected', () => {
  console.log('iCloud disconnected');
  state.iCloudHideMyEmailConnected = false;
  saveState();
  broadcastToTabs({ type: 'iCloudDisconnected', data: { hideMyEmail: true } });
});

icloudClient.on('aliasCreated', (alias) => {
  console.log('Hide My Email alias created:', alias.email);
  broadcastToTabs({ type: 'aliasCreated', data: alias });
});

// iCloud Bridge events (Passwords/Keychain via native messaging)
icloudBridge.on('connected', (status) => {
  console.log('iCloud Keychain connected:', status);
  state.iCloudPasswordsConnected = status.passwordsConnected;
  saveState();
});

icloudBridge.on('disconnected', () => {
  console.log('iCloud Keychain disconnected');
  state.iCloudPasswordsConnected = false;
  saveState();
});

icloudBridge.on('credentialSaved', (data) => {
  console.log('Credential saved to Keychain:', data.domain);
  broadcastToTabs({ type: 'credentialSaved', data });
});

// ============================================================================
// Auto-connect on startup
// ============================================================================

loadState().then(async () => {
  // Auto-connect to iCloud if previously authenticated
  if (state.iCloudAuthenticatedOnce) {
    // Validate iCloud session (for Hide My Email)
    icloudClient.validateSession().then(result => {
      if (result.success) {
        state.iCloudHideMyEmailConnected = result.hasHideMyEmail;
        saveState();
        console.log('iCloud session restored for Hide My Email');
      }
    }).catch(err => {
      console.log('Failed to restore iCloud session:', err.message);
    });

    // Connect to native host (for Passwords)
    icloudBridge.connect().then(result => {
      if (result.success) {
        state.iCloudPasswordsConnected = result.status.passwordsConnected;
        saveState();
        console.log('Native host connected for Passwords');
      }
    }).catch(err => {
      console.log('Native host connection failed:', err.message);
    });
  }
});

console.log('Thea Extension Service Worker initialized with iCloud integration');
