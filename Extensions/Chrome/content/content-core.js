// Thea Chrome Extension - Content Core Module
// Core initialization, feature orchestration, state management, message listeners
// Action handlers (password, email, print) are in content-actions.js

(function() {
  'use strict';

  window.TheaModules = window.TheaModules || {};

  // ============================================================================
  // State
  // ============================================================================

  let state = {
    adBlockerEnabled: true,
    darkModeEnabled: false,
    privacyProtectionEnabled: true,
    passwordManagerEnabled: true,
    emailProtectionEnabled: true
  };

  let darkModeStyleElement = null;
  let adBlockStyleElement = null;

  // Expose state getter/setter for content-actions.js
  window.TheaModules.getState = function() { return state; };
  window.TheaModules.setState = function(newState) { state = newState; };

  // ============================================================================
  // Initialization
  // ============================================================================

  async function init() {
    // Get initial state from background
    try {
      const response = await chrome.runtime.sendMessage({ type: 'getState' });
      if (response.success) {
        state = response.data;
      }
    } catch (e) {
      console.log('Failed to get initial state');
    }

    // Apply initial protections
    applyProtections();

    // Setup observers
    setupMutationObserver();
    setupFormObserver();
  }

  // ============================================================================
  // Message Handling
  // ============================================================================

  // SECURITY: Allowed state keys to prevent arbitrary state injection
  const ALLOWED_STATE_KEYS = new Set([
    'adBlockerEnabled',
    'darkModeEnabled',
    'privacyProtectionEnabled',
    'passwordManagerEnabled',
    'emailProtectionEnabled'
  ]);

  // Expose for content-actions.js
  window.TheaModules.ALLOWED_STATE_KEYS = ALLOWED_STATE_KEYS;

  /**
   * Validates and sanitizes incoming state updates.
   * SECURITY: Only allows known boolean state keys to prevent injection attacks.
   * @param {object} newState - The incoming state object
   * @returns {object} - Sanitized state with only allowed keys
   */
  function validateState(newState) {
    if (!newState || typeof newState !== 'object') {
      return {};
    }
    const sanitized = {};
    for (const key of ALLOWED_STATE_KEYS) {
      if (key in newState && typeof newState[key] === 'boolean') {
        sanitized[key] = newState[key];
      }
    }
    return sanitized;
  }

  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    // SECURITY: Verify message comes from our extension, not from web pages
    if (!sender.id || sender.id !== chrome.runtime.id) {
      console.warn('Thea: Rejected message from unauthorized sender');
      sendResponse({ success: false, error: 'Unauthorized sender' });
      return true;
    }

    // Get shared functions from TheaModules
    const showNotification = window.TheaModules.showNotification;
    const showAIResponsePopup = window.TheaModules.showAIResponsePopup;
    const showQuickPrompt = window.TheaModules.showQuickPrompt;
    const promptSavePassword = window.TheaModules.promptSavePassword;
    const insertEmailAlias = window.TheaModules.insertEmailAlias;
    const cleanPageForPrinting = window.TheaModules.cleanPageForPrinting;

    switch (message.type) {
      case 'stateChanged':
        // SECURITY: Validate and sanitize state to prevent arbitrary injection
        const validatedState = validateState(message.data);
        state = { ...state, ...validatedState };
        applyProtections();
        sendResponse({ success: true });
        break;

      case 'featureToggled':
        // SECURITY: Validate feature name is in allowed list
        if (message.data && ALLOWED_STATE_KEYS.has(message.data.feature) &&
            typeof message.data.enabled === 'boolean') {
          state[message.data.feature] = message.data.enabled;
          applyProtections();
          sendResponse({ success: true });
        } else {
          sendResponse({ success: false, error: 'Invalid feature toggle' });
        }
        break;

      case 'pageLoaded':
        // SECURITY: Validate and sanitize state
        const validatedPageState = validateState(message.state);
        state = { ...state, ...validatedPageState };
        applyProtections();
        sendResponse({ success: true });
        break;

      case 'toggleDarkMode':
        state.darkModeEnabled = message.enabled;
        applyDarkMode();
        sendResponse({ success: true });
        break;

      case 'cleanPage':
        if (cleanPageForPrinting) cleanPageForPrinting();
        sendResponse({ success: true });
        break;

      case 'insertAlias':
        if (insertEmailAlias) insertEmailAlias(message.alias);
        sendResponse({ success: true });
        break;

      case 'showAIResponse':
        if (showAIResponsePopup) showAIResponsePopup(message.response);
        sendResponse({ success: true });
        break;

      case 'showQuickPrompt':
        if (showQuickPrompt) showQuickPrompt();
        sendResponse({ success: true });
        break;

      case 'savePassword':
        if (promptSavePassword) promptSavePassword();
        sendResponse({ success: true });
        break;

      default:
        sendResponse({ success: false, error: 'Unknown message type' });
    }
    return true;
  });

  // ============================================================================
  // Protection Application
  // ============================================================================

  function applyProtections() {
    // Ad blocking
    if (state.adBlockerEnabled) {
      applyAdBlocking();
    } else {
      removeAdBlocking();
    }

    // Dark mode
    if (state.darkModeEnabled) {
      applyDarkMode();
    } else {
      removeDarkMode();
    }

    // Privacy protection
    if (state.privacyProtectionEnabled) {
      applyPrivacyProtection();
    }

    // Password manager (delegated to content-actions.js)
    if (state.passwordManagerEnabled) {
      const setupPasswordAutofill = window.TheaModules.setupPasswordAutofill;
      if (setupPasswordAutofill) setupPasswordAutofill();
    }

    // Email protection (delegated to content-actions.js)
    if (state.emailProtectionEnabled) {
      const setupEmailProtection = window.TheaModules.setupEmailProtection;
      if (setupEmailProtection) setupEmailProtection();
    }
  }

  // ============================================================================
  // Ad Blocking
  // ============================================================================

  const adSelectors = [
    '.ad', '.ads', '.advertisement', '.ad-container', '.ad-wrapper',
    '[data-ad]', '[data-advertisement]', '[data-ad-slot]',
    '.sponsored', '.promo', '.promotional',
    'ins.adsbygoogle', '.adsbygoogle',
    '#google_ads_frame', '.google-ads',
    '.dfp-ad', '.ad-slot', '.ad-unit',
    '[id^="google_ads_"]', '[id^="div-gpt-ad"]',
    '.taboola', '.outbrain', '[data-outbrain-widget]',
    '.ad-banner', '.banner-ad', '.top-ad', '.bottom-ad',
    '.sidebar-ad', '.ad-sidebar',
    '.social-share', '.share-buttons'
  ];

  function applyAdBlocking() {
    if (adBlockStyleElement) return;

    const css = adSelectors.join(',\n') + ` {
      display: none !important;
      visibility: hidden !important;
      height: 0 !important;
      min-height: 0 !important;
      max-height: 0 !important;
      overflow: hidden !important;
    }`;

    adBlockStyleElement = document.createElement('style');
    adBlockStyleElement.id = 'thea-adblock-styles';
    adBlockStyleElement.textContent = css;
    document.head.appendChild(adBlockStyleElement);

    // Count blocked elements
    let blocked = 0;
    adSelectors.forEach(selector => {
      blocked += document.querySelectorAll(selector).length;
    });

    if (blocked > 0) {
      chrome.runtime.sendMessage({
        type: 'updateStats',
        data: { adsBlocked: blocked }
      });
    }
  }

  function removeAdBlocking() {
    if (adBlockStyleElement) {
      adBlockStyleElement.remove();
      adBlockStyleElement = null;
    }
  }

  // ============================================================================
  // Dark Mode
  // ============================================================================

  async function applyDarkMode() {
    const domain = window.location.hostname;

    try {
      const response = await chrome.runtime.sendMessage({
        type: 'getDarkModeCSS',
        data: { domain }
      });

      if (response.success && response.data.css) {
        if (darkModeStyleElement) {
          darkModeStyleElement.textContent = response.data.css;
        } else {
          darkModeStyleElement = document.createElement('style');
          darkModeStyleElement.id = 'thea-darkmode-styles';
          darkModeStyleElement.textContent = response.data.css;
          document.head.appendChild(darkModeStyleElement);
        }

        chrome.runtime.sendMessage({
          type: 'updateStats',
          data: { pagesDarkened: 1 }
        });
      }
    } catch (e) {
      console.error('Failed to apply dark mode:', e);
    }
  }

  function removeDarkMode() {
    if (darkModeStyleElement) {
      darkModeStyleElement.remove();
      darkModeStyleElement = null;
    }
  }

  // ============================================================================
  // Privacy Protection
  // ============================================================================

  function applyPrivacyProtection() {
    injectFingerprintProtection();
    stripTrackingFromLinks();
  }

  function injectFingerprintProtection() {
    const script = document.createElement('script');
    script.src = chrome.runtime.getURL('content/inject.js');
    script.onload = function() {
      this.remove();
    };
    (document.head || document.documentElement).appendChild(script);
  }

  function stripTrackingFromLinks() {
    const trackingParams = new Set([
      'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
      'fbclid', 'gclid', 'msclkid', 'mc_cid', 'mc_eid',
      '_hsenc', '_hsmi', 'trk', 'ref'
    ]);

    document.querySelectorAll('a[href]').forEach(link => {
      try {
        const url = new URL(link.href);
        let modified = false;

        trackingParams.forEach(param => {
          if (url.searchParams.has(param)) {
            url.searchParams.delete(param);
            modified = true;
          }
        });

        if (modified) {
          link.href = url.toString();
        }
      } catch (e) {
        // Invalid URL
      }
    });
  }

  // ============================================================================
  // Mutation Observer
  // ============================================================================

  function setupMutationObserver() {
    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === 'childList') {
          mutation.addedNodes.forEach(node => {
            if (node.nodeType === Node.ELEMENT_NODE) {
              if (state.passwordManagerEnabled) {
                const addAutofillButton = window.TheaModules.addAutofillButton;
                if (addAutofillButton) {
                  const forms = node.querySelectorAll?.('form') || [];
                  forms.forEach(form => {
                    const passwordField = form.querySelector('input[type="password"]');
                    const usernameField = form.querySelector('input[type="text"], input[type="email"]');
                    if (passwordField && usernameField) {
                      addAutofillButton(form, usernameField, passwordField);
                    }
                  });
                }
              }

              if (state.emailProtectionEnabled) {
                const addEmailProtectionButton = window.TheaModules.addEmailProtectionButton;
                if (addEmailProtectionButton) {
                  const emailInputs = node.querySelectorAll?.(
                    'input[type="email"], input[name*="email"]'
                  ) || [];
                  emailInputs.forEach(input => addEmailProtectionButton(input));
                }
              }
            }
          });
        }
      }
    });

    observer.observe(document.body, { childList: true, subtree: true });
  }

  function setupFormObserver() {
    document.addEventListener('submit', (e) => {
      if (!state.passwordManagerEnabled) return;
      const form = e.target;
      const passwordField = form.querySelector('input[type="password"]');
      if (passwordField && passwordField.value) {
        const promptSavePassword = window.TheaModules.promptSavePassword;
        if (promptSavePassword) setTimeout(promptSavePassword, 500);
      }
    }, true);
  }

  // ============================================================================
  // Initialize
  // ============================================================================

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
