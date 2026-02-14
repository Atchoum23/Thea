// Thea Chrome Extension - Service Worker (Manifest V3)
// Entry point: imports modules, registers chrome.* event listeners
//
// Safari-like integration with:
// - iCloud Passwords (via native messaging to access Keychain)
// - iCloud Hide My Email (via direct iCloud.com API - like Safari)

import { state, loadState, saveState, broadcastToTabs, validateExternalState } from './state-manager.js';
import { handleMessage, handleAutofillHideMyEmail } from './message-router.js';
import { generateEmailAlias, askTheaAI, syncWithTheaApp } from './native-bridge.js';
import icloudBridge from './icloud-bridge.js';
import icloudClient from './icloud-client.js';
import memorySystem from './memory-system.js';

// ============================================================================
// Initialize State
// ============================================================================

loadState();

// ============================================================================
// Message Handling
// ============================================================================

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  handleMessage(message, sender).then(sendResponse);
  return true; // Keep channel open for async response
});

// ============================================================================
// Context Menus
// ============================================================================

chrome.runtime.onInstalled.addListener(() => {
  // Create context menus
  chrome.contextMenus.create({
    id: 'thea-clean-page',
    title: 'Reader View (Print-Friendly)',
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
    id: 'thea-explain-ai',
    title: 'Explain with Thea',
    contexts: ['selection']
  });

  chrome.contextMenus.create({
    id: 'thea-summarize-ai',
    title: 'Summarize with Thea',
    contexts: ['selection']
  });

  chrome.contextMenus.create({
    id: 'thea-save-password',
    title: 'Save Password',
    contexts: ['password']
  });

  chrome.contextMenus.create({
    id: 'thea-save-memory',
    title: 'Save to Thea Memory',
    contexts: ['selection']
  });

  chrome.contextMenus.create({
    id: 'thea-open-sidebar',
    title: 'Open Thea AI Sidebar',
    contexts: ['page']
  });
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  switch (info.menuItemId) {
    case 'thea-clean-page':
      chrome.tabs.sendMessage(tab.id, { type: 'activatePrintFriendly' });
      break;

    case 'thea-generate-alias': {
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
    }

    case 'thea-ask-ai': {
      const response = await askTheaAI(
        `Explain: ${info.selectionText}`,
        { url: tab.url, title: tab.title }
      );
      chrome.tabs.sendMessage(tab.id, { type: 'showAIResponse', response });
      break;
    }

    case 'thea-explain-ai':
      chrome.tabs.sendMessage(tab.id, {
        type: 'openSidebarWithQuery',
        query: `/explain ${info.selectionText}`
      });
      break;

    case 'thea-summarize-ai':
      chrome.tabs.sendMessage(tab.id, {
        type: 'openSidebarWithQuery',
        query: `/summarize ${info.selectionText}`
      });
      break;

    case 'thea-save-password':
      chrome.tabs.sendMessage(tab.id, { type: 'savePassword' });
      break;

    case 'thea-save-memory':
      await handleMessage({
        type: 'addMemory',
        data: {
          text: info.selectionText,
          source: 'context-menu',
          url: tab.url,
          title: tab.title,
          type: 'semantic'
        }
      }, { tab });
      chrome.tabs.sendMessage(tab.id, {
        type: 'showNotification',
        message: 'Saved to Thea Memory'
      });
      break;

    case 'thea-open-sidebar':
      chrome.tabs.sendMessage(tab.id, { type: 'toggleAISidebar' });
      break;
  }
});

// ============================================================================
// Keyboard Commands
// ============================================================================

chrome.commands.onCommand.addListener(async (command) => {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab) return;

  switch (command) {
    case 'toggle-dark-mode':
      state.darkModeConfig.enabled = !state.darkModeConfig.enabled;
      state.darkModeEnabled = state.darkModeConfig.enabled;
      state.stats.pagesDarkened++;
      await saveState();
      chrome.tabs.sendMessage(tab.id, {
        type: 'darkModeToggle',
        enabled: state.darkModeConfig.enabled
      });
      break;

    case 'toggle-ai-sidebar':
      chrome.tabs.sendMessage(tab.id, { type: 'toggleAISidebar' });
      break;

    case 'clean-page':
      chrome.tabs.sendMessage(tab.id, { type: 'activatePrintFriendly' });
      break;

    case 'toggle-video-speed':
      chrome.tabs.sendMessage(tab.id, { type: 'toggleVideoController' });
      break;
  }
});

// ============================================================================
// Tab Management
// ============================================================================

chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
  if (changeInfo.status === 'complete' && tab.url) {
    try {
      const url = new URL(tab.url);
      const domain = url.hostname;

      // Notify content script with full state
      chrome.tabs.sendMessage(tabId, {
        type: 'pageLoaded',
        domain,
        state: {
          adBlockerEnabled: state.adBlockerEnabled,
          darkModeEnabled: state.darkModeConfig.enabled,
          privacyProtectionEnabled: state.privacyProtectionEnabled,
          videoControllerEnabled: state.videoControllerEnabled,
          memoryEnabled: state.memoryEnabled,
          iCloudConnected: icloudClient.isAuthenticated
        }
      }).catch(() => {});

      // Auto-capture page visit for memory (if enabled)
      if (state.memoryEnabled) {
        memorySystem.capturePageVisit({
          url: tab.url,
          title: tab.title,
          description: ''
        }).catch(() => {});
      }
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
chrome.alarms.create('pruneMemories', { periodInMinutes: 1440 }); // Daily

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

    case 'pruneMemories':
      // Clean up expired memories daily
      memorySystem.pruneExpired();
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

console.log('Thea Extension v2.0 Service Worker initialized (iCloud, Memory, AI Sidebar, Dark Mode Engine, Video Controller, Privacy Shield)');
