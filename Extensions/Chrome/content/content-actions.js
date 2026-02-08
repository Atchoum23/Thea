// Thea Chrome Extension - Content Actions Module
// Password autofill, email protection, print-friendly page, DOM utilities
// Depends on content-core.js (loaded first) for state and TheaModules namespace

(function() {
  'use strict';

  window.TheaModules = window.TheaModules || {};

  // ============================================================================
  // Shared Utilities
  // ============================================================================

  const escapeHtml = window.TheaModules.escapeHtml || function(text) {
    if (text == null) return '';
    const div = document.createElement('div');
    div.textContent = String(text);
    return div.innerHTML;
  };

  // ============================================================================
  // Password Autofill
  // ============================================================================

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
  // Print Friendly
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
  // Register Action Handlers on TheaModules
  // ============================================================================

  window.TheaModules.setupPasswordAutofill = setupPasswordAutofill;
  window.TheaModules.addAutofillButton = addAutofillButton;
  window.TheaModules.setupEmailProtection = setupEmailProtection;
  window.TheaModules.addEmailProtectionButton = addEmailProtectionButton;
  window.TheaModules.insertEmailAlias = insertEmailAlias;
  window.TheaModules.cleanPageForPrinting = cleanPageForPrinting;

})();
