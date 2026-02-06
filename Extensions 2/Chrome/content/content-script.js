// Thea Chrome Extension - Content Script
// Runs on every page to apply protections and features

(function() {
  'use strict';

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
  let quickPromptElement = null;

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
    // Messages from web pages have sender.tab, extension messages have sender.id
    if (!sender.id || sender.id !== chrome.runtime.id) {
      console.warn('Thea: Rejected message from unauthorized sender');
      sendResponse({ success: false, error: 'Unauthorized sender' });
      return true;
    }

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
        showAIResponsePopup(message.response);
        sendResponse({ success: true });
        break;

      case 'showQuickPrompt':
        showQuickPrompt();
        sendResponse({ success: true });
        break;

      case 'savePassword':
        promptSavePassword();
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
    // Inject fingerprint protection
    injectFingerprintProtection();

    // Strip tracking params from links
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

  function setupPasswordAutofill() {
    // Find login forms
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
    // Check if button already exists
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

    button.addEventListener('click', async (e) => {
      e.preventDefault();
      e.stopPropagation();

      const response = await chrome.runtime.sendMessage({
        type: 'getCredentials',
        data: { domain: window.location.hostname }
      });

      if (response.success && response.data.length > 0) {
        showCredentialPicker(response.data, usernameField, passwordField);
      } else {
        showNotification('No saved credentials for this site');
      }
    });

    // Position relative container
    const container = usernameField.parentElement;
    if (container.style.position !== 'relative') {
      container.style.position = 'relative';
    }
    container.appendChild(button);
  }

  function showCredentialPicker(credentials, usernameField, passwordField) {
    // Remove existing picker
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

      item.addEventListener('mouseover', () => {
        item.style.background = '#f5f5f5';
      });
      item.addEventListener('mouseout', () => {
        item.style.background = 'none';
      });

      item.addEventListener('click', () => {
        usernameField.value = cred.username;
        passwordField.value = cred.password;

        // Trigger input events
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

    // Position picker
    const rect = usernameField.getBoundingClientRect();
    picker.style.top = `${rect.bottom + window.scrollY + 4}px`;
    picker.style.left = `${rect.left + window.scrollX}px`;

    document.body.appendChild(picker);

    // Close on click outside
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
    // Find email input fields
    const emailInputs = document.querySelectorAll(
      'input[type="email"], input[name*="email"], input[id*="email"], input[placeholder*="email"]'
    );

    emailInputs.forEach(input => {
      addEmailProtectionButton(input);
    });
  }

  function addEmailProtectionButton(input) {
    // Check if button already exists
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
          showNotification(`Email alias generated: ${response.data.alias}`);
        }
      } catch (e) {
        showNotification('Failed to generate alias');
      }

      button.disabled = false;
      button.innerHTML = `
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
          <polyline points="22,6 12,13 2,6"/>
        </svg>
      `;
    });

    // Position container
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
      showNotification(`Inserted alias: ${alias}`);
    }
  }

  // ============================================================================
  // Print Friendly
  // ============================================================================

  async function cleanPageForPrinting() {
    // Create print-friendly view
    const printContainer = document.createElement('div');
    printContainer.id = 'thea-print-friendly';

    // Get page content
    const article = document.querySelector('article') ||
                    document.querySelector('.post-content') ||
                    document.querySelector('.entry-content') ||
                    document.querySelector('main') ||
                    document.body;

    // Clone content
    const content = article.cloneNode(true);

    // Remove unwanted elements
    const removeSelectors = [
      'nav', 'header', 'footer', 'aside', '.sidebar',
      '.ad', '.ads', '.advertisement', '.social-share',
      '.comments', '.related-posts', 'script', 'style',
      'iframe', '.promo', '.banner'
    ];

    removeSelectors.forEach(selector => {
      content.querySelectorAll(selector).forEach(el => el.remove());
    });

    // Create print UI
    const printUI = document.createElement('div');
    printUI.innerHTML = `
      <style>
        #thea-print-friendly {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background: white;
          z-index: 999999;
          overflow-y: auto;
          padding: 20px;
        }
        #thea-print-friendly .toolbar {
          position: sticky;
          top: 0;
          background: #f5f5f5;
          padding: 16px;
          border-radius: 8px;
          margin-bottom: 20px;
          display: flex;
          gap: 12px;
          align-items: center;
        }
        #thea-print-friendly .toolbar button {
          padding: 8px 16px;
          border: none;
          border-radius: 4px;
          cursor: pointer;
          font-size: 14px;
        }
        #thea-print-friendly .toolbar button.primary {
          background: #2196F3;
          color: white;
        }
        #thea-print-friendly .toolbar button.secondary {
          background: #e0e0e0;
        }
        #thea-print-friendly .content {
          max-width: 800px;
          margin: 0 auto;
          line-height: 1.6;
          font-size: 16px;
        }
        #thea-print-friendly .content img {
          max-width: 100%;
          height: auto;
        }
        @media print {
          #thea-print-friendly .toolbar { display: none; }
        }
      </style>
      <div class="toolbar">
        <button class="primary" id="thea-print-btn">🖨️ Print</button>
        <button class="primary" id="thea-pdf-btn">📄 Save PDF</button>
        <button class="secondary" id="thea-close-btn">✕ Close</button>
        <span style="flex: 1;"></span>
        <label>
          Font Size:
          <input type="range" min="12" max="24" value="16" id="thea-font-size">
        </label>
      </div>
      <div class="content"></div>
    `;

    printUI.querySelector('.content').appendChild(content);
    printContainer.appendChild(printUI);
    document.body.appendChild(printContainer);

    // Event handlers
    document.getElementById('thea-print-btn').addEventListener('click', () => {
      window.print();
    });

    document.getElementById('thea-pdf-btn').addEventListener('click', () => {
      window.print(); // Browser's print to PDF
    });

    document.getElementById('thea-close-btn').addEventListener('click', () => {
      printContainer.remove();
    });

    document.getElementById('thea-font-size').addEventListener('input', (e) => {
      printUI.querySelector('.content').style.fontSize = e.target.value + 'px';
    });

    // Notify background
    chrome.runtime.sendMessage({
      type: 'updateStats',
      data: { pagesCleaned: 1 }
    });
  }

  // ============================================================================
  // Quick Prompt (AI Assistant)
  // ============================================================================

  function showQuickPrompt() {
    // Remove existing
    if (quickPromptElement) {
      quickPromptElement.remove();
    }

    quickPromptElement = document.createElement('div');
    quickPromptElement.id = 'thea-quick-prompt';
    quickPromptElement.innerHTML = `
      <style>
        #thea-quick-prompt {
          position: fixed;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          background: white;
          border-radius: 16px;
          box-shadow: 0 8px 32px rgba(0,0,0,0.3);
          width: 600px;
          max-width: 90vw;
          z-index: 1000000;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        #thea-quick-prompt .header {
          padding: 16px 20px;
          border-bottom: 1px solid #eee;
          display: flex;
          align-items: center;
          gap: 12px;
        }
        #thea-quick-prompt .header svg {
          color: #2196F3;
        }
        #thea-quick-prompt .header h3 {
          margin: 0;
          font-size: 16px;
          font-weight: 600;
        }
        #thea-quick-prompt .body {
          padding: 20px;
        }
        #thea-quick-prompt textarea {
          width: 100%;
          border: 1px solid #ddd;
          border-radius: 8px;
          padding: 12px;
          font-size: 15px;
          resize: none;
          font-family: inherit;
        }
        #thea-quick-prompt textarea:focus {
          outline: none;
          border-color: #2196F3;
        }
        #thea-quick-prompt .response {
          margin-top: 16px;
          padding: 16px;
          background: #f5f5f5;
          border-radius: 8px;
          display: none;
          max-height: 300px;
          overflow-y: auto;
        }
        #thea-quick-prompt .footer {
          padding: 12px 20px;
          border-top: 1px solid #eee;
          display: flex;
          justify-content: flex-end;
          gap: 8px;
        }
        #thea-quick-prompt button {
          padding: 8px 16px;
          border: none;
          border-radius: 6px;
          cursor: pointer;
          font-size: 14px;
        }
        #thea-quick-prompt button.primary {
          background: #2196F3;
          color: white;
        }
        #thea-quick-prompt button.secondary {
          background: #e0e0e0;
        }
        #thea-quick-prompt .overlay {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background: rgba(0,0,0,0.5);
          z-index: -1;
        }
      </style>
      <div class="overlay"></div>
      <div class="header">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z"/>
        </svg>
        <h3>Ask Thea</h3>
      </div>
      <div class="body">
        <textarea rows="3" placeholder="Ask anything about this page..."></textarea>
        <div class="response"></div>
      </div>
      <div class="footer">
        <button class="secondary" id="thea-prompt-close">Cancel</button>
        <button class="primary" id="thea-prompt-submit">Ask</button>
      </div>
    `;

    document.body.appendChild(quickPromptElement);

    const textarea = quickPromptElement.querySelector('textarea');
    const responseDiv = quickPromptElement.querySelector('.response');
    const submitBtn = quickPromptElement.querySelector('#thea-prompt-submit');
    const closeBtn = quickPromptElement.querySelector('#thea-prompt-close');
    const overlay = quickPromptElement.querySelector('.overlay');

    textarea.focus();

    submitBtn.addEventListener('click', async () => {
      const question = textarea.value.trim();
      if (!question) return;

      submitBtn.disabled = true;
      submitBtn.textContent = 'Thinking...';

      try {
        const response = await chrome.runtime.sendMessage({
          type: 'askAI',
          data: {
            question,
            context: {
              url: window.location.href,
              title: document.title,
              selection: window.getSelection()?.toString()
            }
          }
        });

        responseDiv.style.display = 'block';
        responseDiv.textContent = response.data.response;
      } catch (e) {
        responseDiv.style.display = 'block';
        responseDiv.textContent = 'Failed to get response';
      }

      submitBtn.disabled = false;
      submitBtn.textContent = 'Ask';
    });

    const close = () => quickPromptElement.remove();
    closeBtn.addEventListener('click', close);
    overlay.addEventListener('click', close);

    // Close on Escape
    document.addEventListener('keydown', function escHandler(e) {
      if (e.key === 'Escape') {
        close();
        document.removeEventListener('keydown', escHandler);
      }
    });
  }

  function showAIResponsePopup(response) {
    const popup = document.createElement('div');
    popup.style.cssText = `
      position: fixed;
      bottom: 20px;
      right: 20px;
      background: white;
      border-radius: 12px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.2);
      padding: 16px;
      max-width: 400px;
      z-index: 1000000;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    `;

    // SECURITY: Escape AI response to prevent XSS from malicious API responses
    popup.innerHTML = `
      <div style="display: flex; justify-content: space-between; margin-bottom: 12px;">
        <strong style="color: #2196F3;">Thea AI</strong>
        <button style="border: none; background: none; cursor: pointer; font-size: 16px;">✕</button>
      </div>
      <div style="line-height: 1.5; color: #333;">${escapeHtml(response)}</div>
    `;

    popup.querySelector('button').addEventListener('click', () => popup.remove());
    document.body.appendChild(popup);

    // Auto remove after 30 seconds
    setTimeout(() => popup.remove(), 30000);
  }

  // ============================================================================
  // Utilities
  // ============================================================================

  /**
   * Escapes HTML special characters to prevent XSS attacks.
   * SECURITY: Always use this when inserting user-generated or external content into HTML.
   * @param {string} text - The text to escape
   * @returns {string} - HTML-escaped text safe for innerHTML
   */
  function escapeHtml(text) {
    if (text == null) return '';
    const div = document.createElement('div');
    div.textContent = String(text);
    return div.innerHTML;
  }

  function showNotification(message) {
    const notification = document.createElement('div');
    notification.style.cssText = `
      position: fixed;
      bottom: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: #323232;
      color: white;
      padding: 12px 24px;
      border-radius: 8px;
      z-index: 1000000;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      font-size: 14px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    `;
    notification.textContent = message;
    document.body.appendChild(notification);

    setTimeout(() => {
      notification.style.opacity = '0';
      notification.style.transition = 'opacity 0.3s';
      setTimeout(() => notification.remove(), 300);
    }, 3000);
  }

  function promptSavePassword() {
    const passwordFields = document.querySelectorAll('input[type="password"]');
    if (passwordFields.length === 0) {
      showNotification('No password field found');
      return;
    }

    const form = passwordFields[0].closest('form');
    if (!form) return;

    const usernameField = form.querySelector('input[type="text"], input[type="email"]');
    if (!usernameField) return;

    const username = usernameField.value;
    const password = passwordFields[0].value;

    if (!username || !password) {
      showNotification('Please fill in credentials first');
      return;
    }

    // Show save dialog
    // SECURITY: Escape username and hostname to prevent XSS
    const dialog = document.createElement('div');
    dialog.innerHTML = `
      <div style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 999999; display: flex; align-items: center; justify-content: center;">
        <div style="background: white; border-radius: 12px; padding: 24px; width: 350px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
          <h3 style="margin: 0 0 16px;">Save Password?</h3>
          <p style="margin: 0 0 8px; color: #666;">Username: ${escapeHtml(username)}</p>
          <p style="margin: 0 0 16px; color: #666;">Site: ${escapeHtml(window.location.hostname)}</p>
          <div style="display: flex; gap: 8px; justify-content: flex-end;">
            <button id="thea-save-no" style="padding: 8px 16px; border: 1px solid #ddd; border-radius: 6px; background: white; cursor: pointer;">Not Now</button>
            <button id="thea-save-yes" style="padding: 8px 16px; border: none; border-radius: 6px; background: #2196F3; color: white; cursor: pointer;">Save</button>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(dialog);

    dialog.querySelector('#thea-save-no').addEventListener('click', () => dialog.remove());
    dialog.querySelector('#thea-save-yes').addEventListener('click', async () => {
      try {
        await chrome.runtime.sendMessage({
          type: 'saveCredential',
          data: {
            domain: window.location.hostname,
            username,
            password
          }
        });
        showNotification('Password saved!');
      } catch (e) {
        showNotification('Failed to save password');
      }
      dialog.remove();
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
              // Check for new forms
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

              // Check for new email inputs
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

    observer.observe(document.body, {
      childList: true,
      subtree: true
    });
  }

  function setupFormObserver() {
    // Watch for form submissions to prompt password save
    document.addEventListener('submit', (e) => {
      if (!state.passwordManagerEnabled) return;

      const form = e.target;
      const passwordField = form.querySelector('input[type="password"]');

      if (passwordField && passwordField.value) {
        // Delay to allow form processing
        setTimeout(promptSavePassword, 500);
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
