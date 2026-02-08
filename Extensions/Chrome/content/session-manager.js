// Thea Chrome Extension - Session Manager
// Emily-inspired session persistence for AI sidebar conversations

(function() {
  'use strict';

  const SESSION_STORAGE_KEY = 'thea_ai_sessions';
  const MAX_SESSIONS = 50;
  const MAX_MESSAGES_PER_SESSION = 100;
  const AUTO_SAVE_INTERVAL = 30000; // 30 seconds

  let sessions = {};
  let currentDomain = window.location.hostname;
  let loaded = false;

  // ── Initialization ──────────────────────────────────────────────────

  async function init() {
    await loadSessions();

    // Save on page unload
    window.addEventListener('beforeunload', () => {
      saveSessionsSync();
    });

    // Save periodically
    setInterval(() => {
      if (loaded) saveSessions();
    }, AUTO_SAVE_INTERVAL);
  }

  // ── Storage Operations ──────────────────────────────────────────────

  async function loadSessions() {
    try {
      const result = await chrome.storage.local.get(SESSION_STORAGE_KEY);
      sessions = result[SESSION_STORAGE_KEY] || {};
      loaded = true;
    } catch (e) {
      sessions = {};
      loaded = true;
    }
  }

  async function saveSessions() {
    try {
      // Prune old sessions if over limit
      const domains = Object.keys(sessions);
      if (domains.length > MAX_SESSIONS) {
        const sorted = domains.sort((a, b) =>
          (sessions[a].lastUpdated || 0) - (sessions[b].lastUpdated || 0)
        );
        const toRemove = sorted.slice(0, domains.length - MAX_SESSIONS);
        toRemove.forEach(d => delete sessions[d]);
      }

      await chrome.storage.local.set({ [SESSION_STORAGE_KEY]: sessions });
    } catch (e) {
      console.error('Thea SessionManager: Failed to save sessions:', e);
    }
  }

  function saveSessionsSync() {
    // Synchronous save attempt for beforeunload handler
    try {
      chrome.storage.local.set({ [SESSION_STORAGE_KEY]: sessions });
    } catch (e) {
      // Best effort - beforeunload has limited time
    }
  }

  // ── Session CRUD ────────────────────────────────────────────────────

  function saveSession(domain, conversation) {
    if (!domain || !conversation) return;

    // Trim conversation to max messages, keeping the most recent
    const messages = Array.isArray(conversation)
      ? conversation.slice(-MAX_MESSAGES_PER_SESSION)
      : [];

    sessions[domain] = {
      messages,
      lastUpdated: Date.now(),
      messageCount: messages.length
    };

    saveSessions();
  }

  function restoreSession(domain) {
    const session = sessions[domain || currentDomain];
    if (!session) return null;

    return {
      messages: session.messages || [],
      lastUpdated: session.lastUpdated,
      messageCount: session.messageCount
    };
  }

  function clearSession(domain) {
    delete sessions[domain || currentDomain];
    saveSessions();
  }

  function clearAllSessions() {
    sessions = {};
    saveSessions();
  }

  // ── Session Queries ─────────────────────────────────────────────────

  function getSessionList() {
    return Object.entries(sessions).map(([domain, data]) => ({
      domain,
      messageCount: data.messageCount || 0,
      lastUpdated: data.lastUpdated || 0
    })).sort((a, b) => b.lastUpdated - a.lastUpdated);
  }

  function hasSession(domain) {
    return !!(sessions[domain || currentDomain]?.messages?.length);
  }

  function getSessionCount() {
    return Object.keys(sessions).length;
  }

  function getStorageUsage() {
    try {
      const serialized = JSON.stringify(sessions);
      return {
        bytes: new Blob([serialized]).size,
        sessionCount: Object.keys(sessions).length,
        totalMessages: Object.values(sessions).reduce(
          (sum, s) => sum + (s.messageCount || 0), 0
        )
      };
    } catch (e) {
      return { bytes: 0, sessionCount: 0, totalMessages: 0 };
    }
  }

  // ── Bootstrap ───────────────────────────────────────────────────────

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // ── Expose Module ───────────────────────────────────────────────────

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.SessionManager = {
    init,
    saveSession,
    restoreSession,
    clearSession,
    clearAllSessions,
    getSessionList,
    hasSession,
    getSessionCount,
    getStorageUsage
  };
})();
