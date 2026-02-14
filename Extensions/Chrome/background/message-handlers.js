// Thea Chrome Extension - Message Handlers
// Specialized handlers: iCloud, Memory, Passwords, Content Analysis

import { state, saveState } from './state-manager.js';
import {
  askTheaAI,
  generateAppleStylePassword
} from './native-bridge.js';
import icloudBridge from './icloud-bridge.js';
import icloudClient from './icloud-client.js';
import memorySystem from './memory-system.js';

// ============================================================================
// iCloud Integration Handlers
// ============================================================================

/**
 * Connect to iCloud services
 * - Hide My Email: Uses direct iCloud.com API (like Safari)
 * - Passwords: Uses native messaging host (for Keychain access)
 */
export async function handleiCloudConnect() {
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
export async function handleiCloudDisconnect() {
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
export async function handleGetiCloudStatus() {
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
 */
export async function handleGetiCloudCredentials(domain) {
  if (!state.iCloudPasswordsConnected) {
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
export async function handleSaveiCloudCredential({ username, password, domain, notes }) {
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
 */
export async function handleGenerateiCloudPassword() {
  try {
    const password = await icloudBridge.generatePassword();
    return { success: true, data: { password, format: 'Apple Strong Password' } };
  } catch (error) {
    const password = generateAppleStylePassword();
    return { success: true, data: { password, format: 'Apple Strong Password (Local)' } };
  }
}

/**
 * Autofill credential for a domain
 */
export async function handleAutofillCredential(domain) {
  if (!state.iCloudPasswordsConnected) {
    return { success: false, error: 'iCloud Passwords not connected' };
  }

  try {
    const result = await icloudBridge.autofillCredential(domain);
    if (result.found) {
      state.stats.passwordsAutofilled++;
      await saveState();
    }
    return { success: true, data: result };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

/**
 * Create a new Hide My Email alias
 * Uses direct iCloud.com API (like Safari)
 */
export async function handleCreateHideMyEmailAlias(domain, label) {
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
        alias, email: alias.email, isNew: true,
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
export async function handleGetHideMyEmailAliases() {
  if (!icloudClient.isAuthenticated) {
    const result = await icloudClient.validateSession();
    if (!result.success) {
      return { success: false, error: 'Not signed in to iCloud', requiresLogin: true };
    }
  }

  try {
    const aliases = await icloudClient.getAliases();
    return {
      success: true,
      data: { aliases, source: 'iCloud Hide My Email', count: aliases.length }
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
    const existingAlias = icloudClient.getAliasForDomain(domain);
    if (existingAlias) {
      return {
        success: true,
        data: { email: existingAlias.email, isNew: false, source: 'iCloud Hide My Email' }
      };
    }

    const newAlias = await icloudClient.createAlias(domain);
    state.stats.emailsProtected++;
    await saveState();
    return {
      success: true,
      data: { email: newAlias.email, isNew: true, source: 'iCloud Hide My Email' }
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
export async function handleOpenPasswordManager() {
  try {
    await icloudBridge.sendRequest('openPasswordManager', {});
  } catch (e) {
    chrome.tabs.create({ url: 'https://www.icloud.com/passwords/' });
  }
  return { success: true };
}

// ============================================================================
// Memory System Handlers
// ============================================================================

export async function handleAddMemory(data) {
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

export async function handleSearchMemory(data) {
  try {
    const results = await memorySystem.searchMemory(data.query, data.limit || 10);
    return { success: true, data: results };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

export async function handleListMemories(data) {
  try {
    const result = await memorySystem.listMemories(data || {});
    return { success: true, data: result };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

export async function handleDeleteMemory(data) {
  try {
    await memorySystem.deleteMemory(data.id);
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

export async function handleDeleteAllMemories() {
  try {
    await memorySystem.deleteAllMemories();
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

export async function handleArchiveMemory(data) {
  try {
    const memory = await memorySystem.archiveMemory(data.id);
    return { success: true, data: memory };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

export async function handleUpdateMemory(data) {
  try {
    const memory = await memorySystem.updateMemory(data.id, data.updates || data);
    return { success: true, data: memory };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

export async function handleGetMemoryStats() {
  try {
    const stats = await memorySystem.getStats();
    return { success: true, data: stats };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

export async function handleExportMemories() {
  try {
    const data = await memorySystem.exportMemories();
    return { success: true, data };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

export async function handleImportMemories(data) {
  try {
    const result = await memorySystem.importMemories(data);
    return { success: true, data: result };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

export async function handleCapturePageMemory(data) {
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

export async function handleAnalyzeContent(data, sender) {
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
