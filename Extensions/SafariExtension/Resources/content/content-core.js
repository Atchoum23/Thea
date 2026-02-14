(function() {
  'use strict';

  var state = {
    enabled: false,
    darkMode: false,
    darkModeTheme: 'midnight',
    videoController: false,
    cosmeticFilter: false,
    privacyShield: false,
    passwordEnhancer: false,
    printFriendly: false,
    aiSidebar: false,
    writingAssistant: false,
    selectionHandler: false
  };

  var modulesInitialized = {};

  function init() {
    getState().then(function(savedState) {
      if (savedState) {
        Object.keys(savedState).forEach(function(key) {
          if (state.hasOwnProperty(key)) {
            state[key] = savedState[key];
          }
        });
      }

      if (!state.enabled) return;

      initModules();
      setupMessageListener();
    }).catch(function() {
      setupMessageListener();
    });
  }

  function initModules() {
    var M = window.TheaModules;
    if (!M) return;

    // Session manager initializes first (needed by AI sidebar)
    safeInit('SessionManager', M.SessionManager);

    // Notification is available globally (loaded first, no conditional)
    modulesInitialized.Notification = true;

    // Dark mode
    if (state.darkMode && M.DarkModeEngine) {
      safeInit('DarkModeEngine', M.DarkModeEngine);
    }

    // Video controller
    if (state.videoController && M.VideoController) {
      safeInit('VideoController', M.VideoController);
    }

    // Cosmetic filter
    if (state.cosmeticFilter && M.CosmeticFilter) {
      safeInit('CosmeticFilter', M.CosmeticFilter);
    }

    // Privacy shield
    if (state.privacyShield && M.PrivacyShield) {
      M.PrivacyShield.init({
        autoCookieDecline: true,
        fingerprintProtection: true,
        trackingParamStrip: true,
        cnameDefense: false
      });
      modulesInitialized.PrivacyShield = true;
    }

    // Password enhancer
    if (state.passwordEnhancer && M.PasswordEnhancer) {
      safeInit('PasswordEnhancer', M.PasswordEnhancer);
    }

    // Print friendly (init registers message listener, does not activate)
    if (M.PrintFriendly) {
      safeInit('PrintFriendly', M.PrintFriendly);
    }

    // AI sidebar
    if (M.AISidebar) {
      safeInit('AISidebar', M.AISidebar);
    }

    // Writing assistant
    if (state.writingAssistant && M.WritingAssistant) {
      safeInit('WritingAssistant', M.WritingAssistant);
    }

    // Selection handler
    if (state.selectionHandler && M.SelectionHandler) {
      safeInit('SelectionHandler', M.SelectionHandler);
    }
  }

  function safeInit(name, module) {
    if (modulesInitialized[name]) return;
    try {
      module.init();
      modulesInitialized[name] = true;
    } catch (e) {
      console.warn('Thea: Failed to initialize ' + name, e);
    }
  }

  function setupMessageListener() {
    browser.runtime.onMessage.addListener(function(message, sender, sendResponse) {
      handleMessage(message, sendResponse);
      return true;
    });
  }

  function handleMessage(message) {
    var M = window.TheaModules;
    if (!M) return;

    switch (message.type) {
      case 'stateChanged':
        var newState = message.state || {};
        Object.keys(newState).forEach(function(key) {
          if (state.hasOwnProperty(key)) {
            state[key] = newState[key];
          }
        });
        if (state.enabled && !modulesInitialized.Core) {
          modulesInitialized.Core = true;
          initModules();
        }
        syncModuleStates();
        break;

      case 'featureToggled':
        var feature = message.feature;
        var featureEnabled = message.enabled;
        if (state.hasOwnProperty(feature)) {
          state[feature] = featureEnabled;
        }
        toggleModule(feature, featureEnabled);
        break;

      case 'darkModeToggle':
        if (M.DarkModeEngine) {
          if (!modulesInitialized.DarkModeEngine) safeInit('DarkModeEngine', M.DarkModeEngine);
          M.DarkModeEngine.toggleDarkMode(message.enabled);
        }
        break;

      case 'darkModeSetTheme':
        if (M.DarkModeEngine) {
          M.DarkModeEngine.setTheme(message.theme);
        }
        break;

      case 'toggleAISidebar':
        if (M.AISidebar) {
          if (!modulesInitialized.AISidebar) safeInit('AISidebar', M.AISidebar);
          M.AISidebar.toggle();
        }
        break;

      case 'activatePrintFriendly':
        if (M.PrintFriendly) {
          if (!modulesInitialized.PrintFriendly) safeInit('PrintFriendly', M.PrintFriendly);
          M.PrintFriendly.activate();
        }
        break;

      case 'toggleVideoController':
        if (M.VideoController) {
          if (!modulesInitialized.VideoController) {
            safeInit('VideoController', M.VideoController);
          }
        }
        break;

      case 'startElementPicker':
        if (M.CosmeticFilter) {
          if (!modulesInitialized.CosmeticFilter) safeInit('CosmeticFilter', M.CosmeticFilter);
          M.CosmeticFilter.startElementPicker();
        }
        break;

      case 'stopElementPicker':
        if (M.CosmeticFilter) {
          M.CosmeticFilter.stopElementPicker();
        }
        break;

      case 'showNotification':
        if (M.Notification) {
          M.Notification.showNotification(
            message.title || 'Thea',
            message.message || '',
            message.duration || 4000
          );
        }
        break;

      case 'showAIResponse':
        if (M.Notification) {
          M.Notification.showResult(
            message.title || 'AI Response',
            message.content || ''
          );
        }
        break;

      case 'openSidebarWithQuery':
        if (M.AISidebar) {
          if (!modulesInitialized.AISidebar) safeInit('AISidebar', M.AISidebar);
          if (!M.AISidebar.isOpen()) M.AISidebar.toggle();
          M.AISidebar.sendMessage(message.query);
        }
        break;

      case 'aiResponse':
        if (M.AISidebar) {
          // Handled by AISidebar's own listener
        }
        break;

      case 'pageLoaded':
        reapplyFeatures();
        break;

      case 'insertAlias':
        insertAliasIntoField(message.alias);
        break;

      case 'getPageData':
        var data = extractPageData();
        browser.runtime.sendMessage({
          type: 'pageDataResponse',
          data: data
        }).catch(function() {});
        break;

      case 'extractPageContent':
        var pageData = extractPageData();
        browser.runtime.sendMessage({
          type: 'pageContentResponse',
          data: pageData
        }).catch(function() {});
        break;

      default:
        break;
    }
  }

  function toggleModule(feature, featureEnabled) {
    var M = window.TheaModules;
    if (!M) return;

    switch (feature) {
      case 'darkMode':
        if (M.DarkModeEngine) {
          if (featureEnabled) {
            if (!modulesInitialized.DarkModeEngine) safeInit('DarkModeEngine', M.DarkModeEngine);
            M.DarkModeEngine.toggleDarkMode(true);
          } else {
            M.DarkModeEngine.toggleDarkMode(false);
          }
        }
        break;

      case 'videoController':
        if (featureEnabled && M.VideoController && !modulesInitialized.VideoController) {
          safeInit('VideoController', M.VideoController);
        }
        break;

      case 'cosmeticFilter':
        if (M.CosmeticFilter) {
          if (featureEnabled && !modulesInitialized.CosmeticFilter) {
            safeInit('CosmeticFilter', M.CosmeticFilter);
          } else if (!featureEnabled) {
            M.CosmeticFilter.removeRules();
          }
        }
        break;

      case 'passwordEnhancer':
        if (featureEnabled && M.PasswordEnhancer && !modulesInitialized.PasswordEnhancer) {
          safeInit('PasswordEnhancer', M.PasswordEnhancer);
        }
        break;

      case 'writingAssistant':
        if (M.WritingAssistant) {
          if (featureEnabled && !modulesInitialized.WritingAssistant) {
            safeInit('WritingAssistant', M.WritingAssistant);
          } else if (!featureEnabled && M.WritingAssistant.destroy) {
            M.WritingAssistant.destroy();
            modulesInitialized.WritingAssistant = false;
          }
        }
        break;

      case 'selectionHandler':
        if (M.SelectionHandler) {
          if (featureEnabled && !modulesInitialized.SelectionHandler) {
            safeInit('SelectionHandler', M.SelectionHandler);
          } else if (!featureEnabled && M.SelectionHandler.destroy) {
            M.SelectionHandler.destroy();
            modulesInitialized.SelectionHandler = false;
          }
        }
        break;
    }
  }

  function syncModuleStates() {
    var featureKeys = [
      'darkMode', 'videoController', 'cosmeticFilter', 'privacyShield',
      'passwordEnhancer', 'writingAssistant', 'selectionHandler'
    ];
    featureKeys.forEach(function(key) {
      toggleModule(key, state[key]);
    });
  }

  function reapplyFeatures() {
    var M = window.TheaModules;
    if (!M) return;

    if (state.darkMode && M.DarkModeEngine && modulesInitialized.DarkModeEngine) {
      M.DarkModeEngine.init();
    }
    if (state.cosmeticFilter && M.CosmeticFilter && modulesInitialized.CosmeticFilter) {
      M.CosmeticFilter.init();
    }
    if (state.privacyShield && M.PrivacyShield) {
      M.PrivacyShield.init({
        autoCookieDecline: true,
        fingerprintProtection: false,
        trackingParamStrip: true,
        cnameDefense: false
      });
    }
  }

  function extractPageData() {
    var title = document.title || '';
    var url = window.location.href || '';

    var description = '';
    var metaDesc = document.querySelector('meta[name="description"]');
    if (metaDesc) description = metaDesc.getAttribute('content') || '';

    var content = '';
    var article = document.querySelector('article, [role="article"], main, #content, .post-content');
    if (article) {
      content = article.textContent || '';
    } else {
      content = document.body.textContent || '';
    }
    content = content.replace(/\s+/g, ' ').trim().substring(0, 8000);

    var headings = [];
    document.querySelectorAll('h1, h2, h3, h4').forEach(function(h) {
      headings.push({
        tag: h.tagName.toLowerCase(),
        text: (h.textContent || '').trim().substring(0, 200)
      });
    });

    var structuredData = [];
    document.querySelectorAll('script[type="application/ld+json"]').forEach(function(s) {
      try {
        structuredData.push(JSON.parse(s.textContent));
      } catch (e) {}
    });

    var language = document.documentElement.lang || navigator.language || 'en';

    var images = [];
    document.querySelectorAll('img[src]').forEach(function(img) {
      if (img.naturalWidth > 100 && img.naturalHeight > 100) {
        images.push({
          src: img.src,
          alt: img.alt || '',
          width: img.naturalWidth,
          height: img.naturalHeight
        });
      }
    });

    var links = [];
    document.querySelectorAll('a[href]').forEach(function(a) {
      var href = a.href;
      if (href && !href.startsWith('javascript:') && !href.startsWith('#')) {
        links.push({
          href: href,
          text: (a.textContent || '').trim().substring(0, 100)
        });
      }
    });

    return {
      title: title,
      url: url,
      description: description,
      content: content,
      headings: headings.slice(0, 30),
      structuredData: structuredData.slice(0, 5),
      language: language,
      images: images.slice(0, 20),
      links: links.slice(0, 50)
    };
  }

  function getState() {
    return browser.runtime.sendMessage({ type: 'getState' })
      .then(function(response) {
        return response && response.state ? response.state : null;
      })
      .catch(function() { return null; });
  }

  function insertAliasIntoField(alias) {
    var active = document.activeElement;
    if (!active) return;

    if (active.tagName === 'INPUT' || active.tagName === 'TEXTAREA') {
      var start = active.selectionStart || 0;
      var end = active.selectionEnd || 0;
      var val = active.value;
      active.value = val.substring(0, start) + alias + val.substring(end);
      active.selectionStart = active.selectionEnd = start + alias.length;
      active.dispatchEvent(new Event('input', { bubbles: true }));
    } else if (active.isContentEditable) {
      document.execCommand('insertText', false, alias);
    }
  }

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.Core = {
    init: init,
    extractPageData: extractPageData,
    getState: getState
  };

  // Auto-init
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
