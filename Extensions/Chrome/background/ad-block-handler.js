// Thea Chrome Extension - Ad Block Handler
// Block list and ad/tracker decision logic

import { state, saveState } from './state-manager.js';

// ============================================================================
// Block List
// ============================================================================

// Known ad/tracker domains (subset for demonstration)
export const blockList = new Set([
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

// ============================================================================
// Blocking Decision
// ============================================================================

export async function checkShouldBlock(url, resourceType) {
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
