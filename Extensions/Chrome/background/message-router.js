// Thea Chrome Extension - Message Router
// Central message handler (switch/dispatch) + state/toggle/UI/config handlers

import { state, saveState, broadcastToTabs } from './state-manager.js';
import { generateDarkModeCSS } from './dark-mode-handler.js';
import { checkShouldBlock } from './ad-block-handler.js';
import {
  askTheaAI,
  syncWithTheaApp,
  getCredentialsForDomain,
  generateEmailAlias,
  cleanPageContent
} from './native-bridge.js';
import {
  handleiCloudConnect,
  handleiCloudDisconnect,
  handleGetiCloudStatus,
  handleGetiCloudCredentials,
  handleSaveiCloudCredential,
  handleGenerateiCloudPassword,
  handleAutofillCredential,
  handleCreateHideMyEmailAlias,
  handleGetHideMyEmailAliases,
  handleAutofillHideMyEmail,
  handleOpenPasswordManager,
  handleAddMemory,
  handleSearchMemory,
  handleListMemories,
  handleDeleteMemory,
  handleDeleteAllMemories,
  handleArchiveMemory,
  handleUpdateMemory,
  handleGetMemoryStats,
  handleExportMemories,
  handleImportMemories,
  handleCapturePageMemory,
  handleAnalyzeContent
} from './message-handlers.js';

// Re-export for service-worker.js (which imports handleAutofillHideMyEmail from here)
export { handleAutofillHideMyEmail };

// ============================================================================
// Main Message Handler
// ============================================================================

export async function handleMessage(message, sender) {
  switch (message.type) {
    // ========================================
    // State & Toggle Messages
    // ========================================

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

    case 'toggleFeature': {
      const { feature, enabled } = message.data;
      state[feature] = enabled;
      await saveState();
      broadcastToTabs({ type: 'featureToggled', data: { feature, enabled } });
      return { success: true };
    }

    // ========================================
    // Core Feature Messages
    // ========================================

    case 'getDarkModeCSS': {
      const css = await generateDarkModeCSS(message.data.domain);
      return { success: true, data: { css } };
    }

    case 'getBlockingDecision': {
      const decision = await checkShouldBlock(message.data.url, message.data.type);
      return { success: true, data: decision };
    }

    case 'generateEmailAlias': {
      const alias = await generateEmailAlias(message.data.domain);
      return { success: true, data: alias };
    }

    case 'getCredentials': {
      const credentials = await getCredentialsForDomain(message.data.domain);
      return { success: true, data: credentials };
    }

    case 'cleanPage': {
      const cleaned = await cleanPageContent(message.data.html, message.data.url);
      return { success: true, data: cleaned };
    }

    case 'askAI': {
      const response = await askTheaAI(message.data.question, message.data.context);
      return { success: true, data: { response } };
    }

    case 'syncWithApp': {
      const syncResult = await syncWithTheaApp();
      return { success: true, data: syncResult };
    }

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
