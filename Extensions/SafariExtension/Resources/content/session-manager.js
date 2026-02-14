(function() {
  'use strict';

  var SESSION_STORAGE_KEY = 'thea_ai_sessions';
  var SESSION_LIST_KEY = 'thea_ai_session_list';
  var MAX_SESSIONS = 50;
  var MAX_MESSAGES_PER_SESSION = 100;
  var initialized = false;

  function init() {
    if (initialized) return;
    initialized = true;

    window.addEventListener('beforeunload', function() {
      autoSaveCurrentSession();
    });

    pruneOldSessions();
  }

  function saveSession(domain, conversation) {
    if (!domain || !conversation || conversation.length === 0) return Promise.resolve();

    var trimmed = conversation.slice(-MAX_MESSAGES_PER_SESSION).map(function(msg) {
      return {
        role: msg.role,
        content: msg.content ? msg.content.substring(0, 5000) : '',
        timestamp: msg.timestamp || Date.now(),
        model: msg.model || null
      };
    });

    var sessionData = {};
    sessionData[SESSION_STORAGE_KEY + '_' + domain] = {
      domain: domain,
      conversation: trimmed,
      updatedAt: Date.now()
    };

    return browser.storage.local.set(sessionData).then(function() {
      return updateSessionList(domain);
    }).catch(function(err) {
      console.warn('Thea: Failed to save session', err);
    });
  }

  function restoreSession(domain) {
    if (!domain) return Promise.resolve(null);

    var key = SESSION_STORAGE_KEY + '_' + domain;
    return browser.storage.local.get([key]).then(function(data) {
      var session = data[key];
      if (session && session.conversation) {
        return session.conversation;
      }
      return null;
    }).catch(function() {
      return null;
    });
  }

  function clearSession(domain) {
    if (!domain) return Promise.resolve();

    var key = SESSION_STORAGE_KEY + '_' + domain;
    return browser.storage.local.remove([key]).then(function() {
      return removeFromSessionList(domain);
    }).catch(function() {});
  }

  function clearAllSessions() {
    return getSessionList().then(function(sessions) {
      var keys = sessions.map(function(s) {
        return SESSION_STORAGE_KEY + '_' + s.domain;
      });
      keys.push(SESSION_LIST_KEY);
      return browser.storage.local.remove(keys);
    }).catch(function() {});
  }

  function getSessionList() {
    return browser.storage.local.get([SESSION_LIST_KEY]).then(function(data) {
      var list = data[SESSION_LIST_KEY] || [];
      list.sort(function(a, b) { return (b.updatedAt || 0) - (a.updatedAt || 0); });
      return list;
    }).catch(function() { return []; });
  }

  function updateSessionList(domain) {
    return browser.storage.local.get([SESSION_LIST_KEY]).then(function(data) {
      var list = data[SESSION_LIST_KEY] || [];
      var existing = list.findIndex(function(s) { return s.domain === domain; });

      var entry = {
        domain: domain,
        updatedAt: Date.now()
      };

      if (existing > -1) {
        list[existing] = entry;
      } else {
        list.push(entry);
      }

      list.sort(function(a, b) { return (b.updatedAt || 0) - (a.updatedAt || 0); });

      if (list.length > MAX_SESSIONS) {
        var removed = list.splice(MAX_SESSIONS);
        var keysToRemove = removed.map(function(s) {
          return SESSION_STORAGE_KEY + '_' + s.domain;
        });
        browser.storage.local.remove(keysToRemove).catch(function() {});
      }

      var update = {};
      update[SESSION_LIST_KEY] = list;
      return browser.storage.local.set(update);
    }).catch(function() {});
  }

  function removeFromSessionList(domain) {
    return browser.storage.local.get([SESSION_LIST_KEY]).then(function(data) {
      var list = data[SESSION_LIST_KEY] || [];
      list = list.filter(function(s) { return s.domain !== domain; });
      var update = {};
      update[SESSION_LIST_KEY] = list;
      return browser.storage.local.set(update);
    }).catch(function() {});
  }

  function pruneOldSessions() {
    var thirtyDaysAgo = Date.now() - (30 * 24 * 60 * 60 * 1000);
    getSessionList().then(function(list) {
      var expired = list.filter(function(s) { return s.updatedAt < thirtyDaysAgo; });
      if (expired.length === 0) return;

      var keysToRemove = expired.map(function(s) {
        return SESSION_STORAGE_KEY + '_' + s.domain;
      });
      browser.storage.local.remove(keysToRemove).catch(function() {});

      var remaining = list.filter(function(s) { return s.updatedAt >= thirtyDaysAgo; });
      var update = {};
      update[SESSION_LIST_KEY] = remaining;
      browser.storage.local.set(update).catch(function() {});
    });
  }

  function autoSaveCurrentSession() {
    var sidebar = window.TheaModules.AISidebar;
    if (!sidebar) return;

    var conversation = sidebar.getConversation ? sidebar.getConversation() : [];
    if (conversation.length > 0) {
      saveSession(window.location.hostname, conversation);
    }
  }

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.SessionManager = {
    init: init,
    saveSession: saveSession,
    restoreSession: restoreSession,
    clearSession: clearSession,
    clearAllSessions: clearAllSessions,
    getSessionList: getSessionList
  };
})();
