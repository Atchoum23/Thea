// Thea Chrome Extension - Message Router
// Central message handler (switch statement) + iCloud handlers + memory handlers

import { state, saveState, broadcastToTabs } from './state-manager.js';
import { generateDarkModeCSS } from './dark-mode-handler.js';
import { checkShouldBlock } from './ad-block-handler.js';
import {
  askTheaAI,
  syncWithTheaApp,
  getCredentialsForDomain,
  generateEmailAlias,
  cleanPageContent,
  generateAppleStylePassword
} from './native-bridge.js';
import icloudBridge from './icloud-bridge.js';
import icloudClient from './icloud-client.js';
import memorySystem from './memory-system.js';

// ============================================================================
// Main Message Handler
// ============================================================================

export async function handleMessage(message, sender) {
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

    // ========================================
    // Video Controller Messages
    // ========================================

    case 'getVideoConfig':
      return { success: true, data: state.videoConfig };

    case 'saveVideoConfig':
      state.videoConfig = { ...state.videoConfig, ...message.data };
      await saveState();
      return { success: true };

    // ========================================
    // Dark Mode Engine Messages
    // ========================================

    case 'getDarkModeConfig':
      return { success: true, data: state.darkModeConfig };

    case 'saveDarkModeConfig':
      state.darkModeConfig = { ...state.darkModeConfig, ...message.data };
      await saveState();
      return { success: true };

    // ========================================
    // Privacy Shield Messages
    // ========================================

    case 'getPrivacyConfig':
      return { success: true, data: state.privacyConfig };

    case 'savePrivacyConfig':
      state.privacyConfig = { ...state.privacyConfig, ...message.data };
      await saveState();
      return { success: true };

    // ========================================
    // Memory System Messages
    // ========================================

    case 'addMemory':
      return await handleAddMemory(message.data);

    case 'searchMemory':
      return await handleSearchMemory(message.data);

    case 'listMemories':
      return await handleListMemories(message.data);

    case 'deleteMemory':
      return await handleDeleteMemory(message.data);

    case 'deleteAllMemories':
      return await handleDeleteAllMemories();

    case 'archiveMemory':
      return await handleArchiveMemory(message.data);

    case 'updateMemory':
      return await handleUpdateMemory(message.data);

    case 'getMemoryStats':
      return await handleGetMemoryStats();

    case 'exportMemories':
      return await handleExportMemories();

    case 'importMemories':
      return await handleImportMemories(message.data);

    case 'saveToMemory':
      return await handleAddMemory(message.data);

    case 'capturePageMemory':
      return await handleCapturePageMemory(message.data);

    // ========================================
    // AI Sidebar Messages
    // ========================================

    case 'toggleAISidebar': {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (tab) {
        await chrome.tabs.sendMessage(tab.id, { type: 'toggleAISidebar' });
      }
      return { success: true };
    }

    // ========================================
    // Print-Friendly Messages
    // ========================================

    case 'activatePrintFriendly': {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (tab) {
        await chrome.tabs.sendMessage(tab.id, { type: 'activatePrintFriendly' });
      }
      return { success: true };
    }

    // ========================================
    // Status & Getters
    // ========================================

    case 'getStatus':
      return {
        success: true,
        data: {
          ...state,
          iCloudStatus: {
            passwordsConnected: state.iCloudPasswordsConnected,
            hideMyEmailConnected: state.iCloudHideMyEmailConnected
          }
        }
      };

    case 'getBlockedCount':
      return {
        success: true,
        data: {
          count: state.stats.adsBlocked + state.stats.trackersBlocked
        }
      };

    case 'analyzeContent':
      return await handleAnalyzeContent(message.data, sender);

    default:
      return { success: false, error: 'Unknown message type' };
  }
}

// ============================================================================
// iCloud Integration Handlers
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
export async function handleAutofillHideMyEmail(domain) {
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
// Memory System Handlers
// ============================================================================

async function handleAddMemory(data) {
  try {
    const memory = await memorySystem.addMemory(data.text || data.content, {
      type: data.type || 'semantic',
      source: data.source || 'user',
      url: data.url || '',
      title: data.title || '',
      tags: data.tags || []
    });
    state.stats.memoriesSaved++;
    await saveState();
    return { success: true, data: memory };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

async function handleSearchMemory(data) {
  try {
    const results = await memorySystem.searchMemory(data.query, data.limit || 10);
    return { success: true, data: results };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

async function handleListMemories(data) {
  try {
    const result = await memorySystem.listMemories(data || {});
    return { success: true, data: result };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

async function handleDeleteMemory(data) {
  try {
    await memorySystem.deleteMemory(data.id);
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

async function handleDeleteAllMemories() {
  try {
    await memorySystem.deleteAllMemories();
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

async function handleArchiveMemory(data) {
  try {
    const memory = await memorySystem.archiveMemory(data.id);
    return { success: true, data: memory };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

async function handleUpdateMemory(data) {
  try {
    const memory = await memorySystem.updateMemory(data.id, data.updates || data);
    return { success: true, data: memory };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

async function handleGetMemoryStats() {
  try {
    const stats = await memorySystem.getStats();
    return { success: true, data: stats };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

async function handleExportMemories() {
  try {
    const data = await memorySystem.exportMemories();
    return { success: true, data };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

async function handleImportMemories(data) {
  try {
    const result = await memorySystem.importMemories(data);
    return { success: true, data: result };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

async function handleCapturePageMemory(data) {
  try {
    const memory = await memorySystem.capturePageVisit(data);
    if (memory) {
      state.stats.memoriesSaved++;
      await saveState();
    }
    return { success: true, data: memory };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// ============================================================================
// Content Analysis (AI)
// ============================================================================

async function handleAnalyzeContent(data, sender) {
  try {
    const tab = sender.tab;
    const pageInfo = {
      url: tab?.url || data?.url || '',
      title: tab?.title || data?.title || '',
      content: data?.content || ''
    };

    const response = await askTheaAI(
      `Analyze and summarize the following page content:\n\n${pageInfo.content?.substring(0, 5000)}`,
      pageInfo
    );

    return { success: true, data: { response, pageInfo } };
  } catch (error) {
    return { success: false, error: error.message };
  }
}
