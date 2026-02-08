// Thea Chrome Extension - Content Core Module
// Main init, state sync, message listener hub, protection application

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
        cleanPageForPrinting();
        sendResponse({ success: true });
        break;

      case 'insertAlias':
        insertEmailAlias(message.alias);
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

    // Password manager
    if (state.passwordManagerEnabled) {
      setupPasswordAutofill();
    }

    // Email protection
    if (state.emailProtectionEnabled) {
      setupEmailProtection();
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
  // Password Autofill
  // ============================================================================

  const escapeHtml = window.TheaModules.escapeHtml || function(text) {
    if (text == null) return '';
    const div = document.createElement('div');
    div.textContent = String(text);
    return div.innerHTML;
  };

  function setupPasswordAutofill() {
    const forms = document.querySelectorAll('form');
    forms.forEach(form => {
      const passwordField = form.querySelector('input[type="password"]');
      const usernameField = form.querySelector('input[type="text"], input[type="email"]');
      if (passwordField && usernameField) {
        addAutofillButton(form, usernameField, passwordField);
      }
    });
  }

  function addAutofillButton(form, usernameField, passwordField) {
    if (form.querySelector('.thea-autofill-btn')) return;

    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'thea-autofill-btn';
    button.innerHTML = `
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/>
      </svg>
    `;
    button.title = 'Autofill with Thea';
    button.style.cssText = `
      position: absolute;
      right: 8px;
      top: 50%;
      transform: translateY(-50%);
      background: none;
      border: none;
      cursor: pointer;
      padding: 4px;
      color: #666;
      z-index: 10000;
    `;

    const showNotification = window.TheaModules.showNotification;

    button.addEventListener('click', async (e) => {
      e.preventDefault();
      e.stopPropagation();

      const response = await chrome.runtime.sendMessage({
        type: 'getCredentials',
        data: { domain: window.location.hostname }
      });

      if (response.success && response.data.length > 0) {
        showCredentialPicker(response.data, usernameField, passwordField);
      } else if (showNotification) {
        showNotification('No saved credentials for this site');
      }
    });

    const container = usernameField.parentElement;
    if (container.style.position !== 'relative') {
      container.style.position = 'relative';
    }
    container.appendChild(button);
  }

  function showCredentialPicker(credentials, usernameField, passwordField) {
    const existing = document.querySelector('.thea-credential-picker');
    if (existing) existing.remove();

    const picker = document.createElement('div');
    picker.className = 'thea-credential-picker';
    picker.style.cssText = `
      position: absolute;
      background: white;
      border: 1px solid #ddd;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      padding: 8px 0;
      z-index: 100000;
      max-width: 300px;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    `;

    credentials.forEach(cred => {
      const item = document.createElement('div');
      item.style.cssText = `
        padding: 10px 16px;
        cursor: pointer;
        display: flex;
        align-items: center;
        gap: 12px;
      `;
      // SECURITY: Escape user-generated content to prevent XSS
      item.innerHTML = `
        <div style="flex: 1;">
          <div style="font-weight: 500; font-size: 14px;">${escapeHtml(cred.username)}</div>
          <div style="font-size: 12px; color: #666;">${escapeHtml(cred.domain)}</div>
        </div>
      `;

      item.addEventListener('mouseover', () => { item.style.background = '#f5f5f5'; });
      item.addEventListener('mouseout', () => { item.style.background = 'none'; });

      item.addEventListener('click', () => {
        usernameField.value = cred.username;
        passwordField.value = cred.password;
        usernameField.dispatchEvent(new Event('input', { bubbles: true }));
        passwordField.dispatchEvent(new Event('input', { bubbles: true }));
        picker.remove();

        chrome.runtime.sendMessage({
          type: 'updateStats',
          data: { passwordsAutofilled: 1 }
        });
      });

      picker.appendChild(item);
    });

    const rect = usernameField.getBoundingClientRect();
    picker.style.top = `${rect.bottom + window.scrollY + 4}px`;
    picker.style.left = `${rect.left + window.scrollX}px`;

    document.body.appendChild(picker);

    document.addEventListener('click', function closeHandler(e) {
      if (!picker.contains(e.target)) {
        picker.remove();
        document.removeEventListener('click', closeHandler);
      }
    });
  }

  // ============================================================================
  // Email Protection
  // ============================================================================

  function setupEmailProtection() {
    const emailInputs = document.querySelectorAll(
      'input[type="email"], input[name*="email"], input[id*="email"], input[placeholder*="email"]'
    );
    emailInputs.forEach(input => addEmailProtectionButton(input));
  }

  function addEmailProtectionButton(input) {
    if (input.parentElement?.querySelector('.thea-email-btn')) return;

    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'thea-email-btn';
    button.innerHTML = `
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
        <polyline points="22,6 12,13 2,6"/>
        <path d="M12 13v8" stroke-dasharray="2 2"/>
      </svg>
    `;
    button.title = 'Generate email alias';
    button.style.cssText = `
      position: absolute;
      right: 8px;
      top: 50%;
      transform: translateY(-50%);
      background: #4CAF50;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      padding: 4px 6px;
      color: white;
      z-index: 10000;
      font-size: 12px;
    `;

    const showNotification = window.TheaModules.showNotification;

    button.addEventListener('click', async (e) => {
      e.preventDefault();
      e.stopPropagation();
      button.disabled = true;
      button.innerHTML = '...';

      try {
        const response = await chrome.runtime.sendMessage({
          type: 'generateEmailAlias',
          data: { domain: window.location.hostname }
        });

        if (response.success) {
          input.value = response.data.alias;
          input.dispatchEvent(new Event('input', { bubbles: true }));
          if (showNotification) showNotification(`Email alias generated: ${response.data.alias}`);
        }
      } catch (e) {
        if (showNotification) showNotification('Failed to generate alias');
      }

      button.disabled = false;
      button.innerHTML = `
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
          <polyline points="22,6 12,13 2,6"/>
        </svg>
      `;
    });

    const container = input.parentElement;
    if (container && container.style.position !== 'relative') {
      container.style.position = 'relative';
    }
    container?.appendChild(button);
  }

  function insertEmailAlias(alias) {
    const activeElement = document.activeElement;
    if (activeElement && (activeElement.tagName === 'INPUT' || activeElement.tagName === 'TEXTAREA')) {
      activeElement.value = alias;
      activeElement.dispatchEvent(new Event('input', { bubbles: true }));
      const showNotification = window.TheaModules.showNotification;
      if (showNotification) showNotification(`Inserted alias: ${alias}`);
    }
  }

  // ============================================================================
  // Print Friendly (basic, delegates to print-friendly.js if loaded)
  // ============================================================================

  async function cleanPageForPrinting() {
    const printContainer = document.createElement('div');
    printContainer.id = 'thea-print-friendly';

    const article = document.querySelector('article') ||
                    document.querySelector('.post-content') ||
                    document.querySelector('.entry-content') ||
                    document.querySelector('main') ||
                    document.body;

    const content = article.cloneNode(true);

    const removeSelectors = [
      'nav', 'header', 'footer', 'aside', '.sidebar',
      '.ad', '.ads', '.advertisement', '.social-share',
      '.comments', '.related-posts', 'script', 'style',
      'iframe', '.promo', '.banner'
    ];

    removeSelectors.forEach(selector => {
      content.querySelectorAll(selector).forEach(el => el.remove());
    });

    const printUI = document.createElement('div');
    printUI.innerHTML = `
      <style>
        #thea-print-friendly {
          position: fixed; top: 0; left: 0; right: 0; bottom: 0;
          background: white; z-index: 999999; overflow-y: auto; padding: 20px;
        }
        #thea-print-friendly .toolbar {
          position: sticky; top: 0; background: #f5f5f5; padding: 16px;
          border-radius: 8px; margin-bottom: 20px;
          display: flex; gap: 12px; align-items: center;
        }
        #thea-print-friendly .toolbar button {
          padding: 8px 16px; border: none; border-radius: 4px;
          cursor: pointer; font-size: 14px;
        }
        #thea-print-friendly .toolbar button.primary { background: #2196F3; color: white; }
        #thea-print-friendly .toolbar button.secondary { background: #e0e0e0; }
        #thea-print-friendly .content {
          max-width: 800px; margin: 0 auto; line-height: 1.6; font-size: 16px;
        }
        #thea-print-friendly .content img { max-width: 100%; height: auto; }
        @media print { #thea-print-friendly .toolbar { display: none; } }
      </style>
      <div class="toolbar">
        <button class="primary" id="thea-print-btn">Print</button>
        <button class="primary" id="thea-pdf-btn">Save PDF</button>
        <button class="secondary" id="thea-close-btn">Close</button>
        <span style="flex: 1;"></span>
        <label>Font Size: <input type="range" min="12" max="24" value="16" id="thea-font-size"></label>
      </div>
      <div class="content"></div>
    `;

    printUI.querySelector('.content').appendChild(content);
    printContainer.appendChild(printUI);
    document.body.appendChild(printContainer);

    document.getElementById('thea-print-btn').addEventListener('click', () => window.print());
    document.getElementById('thea-pdf-btn').addEventListener('click', () => window.print());
    document.getElementById('thea-close-btn').addEventListener('click', () => printContainer.remove());
    document.getElementById('thea-font-size').addEventListener('input', (e) => {
      printUI.querySelector('.content').style.fontSize = e.target.value + 'px';
    });

    chrome.runtime.sendMessage({ type: 'updateStats', data: { pagesCleaned: 1 } });
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
                const forms = node.querySelectorAll?.('form') || [];
                forms.forEach(form => {
                  const passwordField = form.querySelector('input[type="password"]');
                  const usernameField = form.querySelector('input[type="text"], input[type="email"]');
                  if (passwordField && usernameField) {
                    addAutofillButton(form, usernameField, passwordField);
                  }
                });
              }

              if (state.emailProtectionEnabled) {
                const emailInputs = node.querySelectorAll?.(
                  'input[type="email"], input[name*="email"]'
                ) || [];
                emailInputs.forEach(input => addEmailProtectionButton(input));
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
