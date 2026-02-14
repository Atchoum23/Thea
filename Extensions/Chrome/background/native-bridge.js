// Thea Chrome Extension - Native Bridge
// Communication with Thea native app, email aliases, credentials, page cleaning, AI

import { state, saveState, validateExternalState } from './state-manager.js';

// ============================================================================
// AI Assistant
// ============================================================================

export async function askTheaAI(question, context) {
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

export async function syncWithTheaApp() {
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
// Password Manager (Interface to native app)
// ============================================================================

export async function getCredentialsForDomain(domain) {
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
// Email Protection (Legacy - for non-iCloud)
// ============================================================================

export async function generateEmailAlias(domain) {
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
// Print Friendly
// ============================================================================

export async function cleanPageContent(html, url) {
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
// Apple-Style Password Generation (Fallback)
// ============================================================================

export function generateAppleStylePassword() {
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
