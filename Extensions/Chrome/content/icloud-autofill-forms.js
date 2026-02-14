/**
 * iCloud Autofill - Forms Module
 *
 * Input field detection, password field enhancement,
 * password button, password popup, no-credentials popup,
 * connect to iCloud prompt.
 *
 * Depends on: icloud-autofill-ui.js (loaded before this file)
 */

(function() {
  'use strict';

  window.TheaModules = window.TheaModules || {};
  const UI = window.TheaModules.icloudUI;

  // ============================================================================
  // Input Field Detection & Enhancement
  // ============================================================================

  function observeInputFields() {
    // Process existing fields
    processInputFields();

    // Watch for new fields
    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === 'childList') {
          mutation.addedNodes.forEach(node => {
            if (node.nodeType === Node.ELEMENT_NODE) {
              processInputFields(node);
            }
          });
        }
      }
    });

    observer.observe(document.body, { childList: true, subtree: true });
  }

  function processInputFields(root = document) {
    // Find password fields for iCloud Passwords
    const passwordFields = root.querySelectorAll('input[type="password"]');
    passwordFields.forEach(field => {
      if (!field.dataset.theaEnhanced) {
        enhancePasswordField(field);
      }
    });

    // Find email fields for Hide My Email
    const emailFields = root.querySelectorAll(
      'input[type="email"], input[name*="email"], input[autocomplete*="email"]'
    );
    emailFields.forEach(field => {
      if (!field.dataset.theaEnhanced) {
        const email = window.TheaModules.icloudEmail;
        if (email) {
          email.enhanceEmailField(field);
        }
      }
    });
  }

  // ============================================================================
  // Password Field Enhancement (iCloud Passwords)
  // ============================================================================

  function enhancePasswordField(passwordField) {
    passwordField.dataset.theaEnhanced = 'true';

    // Find associated username field
    const form = passwordField.closest('form');
    const usernameField = form?.querySelector(
      'input[type="text"], input[type="email"], input[autocomplete*="username"], input[autocomplete*="email"]'
    );

    if (!usernameField) return;

    // Add Safari-like key icon button
    const btn = createPasswordButton();
    UI.positionButtonInField(usernameField, btn);

    btn.addEventListener('click', async (e) => {
      e.preventDefault();
      e.stopPropagation();

      if (!UI.isConnected()) {
        await UI.connectToiCloud();
      }

      showPasswordPopup(usernameField, passwordField);
    });

    // Also trigger on focus
    usernameField.addEventListener('focus', async () => {
      if (UI.isConnected()) {
        showPasswordPopup(usernameField, passwordField);
      }
    });
  }

  function createPasswordButton() {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'thea-password-btn';
    btn.title = 'AutoFill from iCloud Keychain';
    btn.innerHTML = `
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
        <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
      </svg>
    `;
    return btn;
  }

  // ============================================================================
  // Password Popup
  // ============================================================================

  async function showPasswordPopup(usernameField, passwordField) {
    UI.closeCurrentPopup();

    const domain = window.location.hostname;

    try {
      const response = await chrome.runtime.sendMessage({
        type: 'getiCloudCredentials',
        data: { domain }
      });

      if (!response.success) {
        showConnectPrompt(usernameField);
        return;
      }

      const credentials = response.data.credentials || [];

      if (credentials.length === 0) {
        showNoCredentialsPopup(usernameField, passwordField, domain);
        return;
      }

      const popup = UI.createCredentialPopup(credentials, usernameField, passwordField, domain);
      UI.positionPopup(popup, usernameField);
      document.body.appendChild(popup);
      UI.setCurrentPopup(popup);

      // Close on click outside
      setTimeout(() => {
        document.addEventListener('click', UI.closePopupHandler);
      }, 100);

    } catch (error) {
      console.error('Failed to get credentials:', error);
    }
  }

  // ============================================================================
  // No Credentials Popup
  // ============================================================================

  function showNoCredentialsPopup(usernameField, passwordField, domain) {
    const popup = document.createElement('div');
    popup.className = 'thea-icloud-popup';

    popup.innerHTML = `
      <div class="thea-icloud-popup-header">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
          <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
        </svg>
        <span>Passwords</span>
        <span class="thea-badge">iCloud</span>
      </div>
      <div style="padding: 16px; text-align: center; color: #8e8e93; font-size: 13px;">
        No saved passwords for ${UI.escapeHtml(domain)}
      </div>
      <div class="thea-icloud-popup-footer">
        <button class="primary" data-action="suggest" style="width: 100%;">Suggest Strong Password</button>
      </div>
    `;

    popup.querySelector('[data-action="suggest"]').addEventListener('click', async () => {
      const password = await UI.suggestStrongPassword();
      if (password) {
        passwordField.value = password;
        passwordField.dispatchEvent(new Event('input', { bubbles: true }));
        UI.closeCurrentPopup();
      }
    });

    UI.positionPopup(popup, usernameField);
    document.body.appendChild(popup);
    UI.setCurrentPopup(popup);

    setTimeout(() => {
      document.addEventListener('click', UI.closePopupHandler);
    }, 100);
  }

  // ============================================================================
  // Connect to iCloud Prompt
  // ============================================================================

  function showConnectPrompt(anchorElement) {
    const popup = document.createElement('div');
    popup.className = 'thea-icloud-popup';

    popup.innerHTML = `
      <div class="thea-icloud-popup-header">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z"/>
        </svg>
        <span>Connect to iCloud</span>
      </div>
      <div style="padding: 16px; font-size: 13px; color: #1d1d1f;">
        Connect to iCloud to autofill passwords and use Hide My Email.
      </div>
      <div class="thea-icloud-popup-footer">
        <button class="primary" data-action="connect" style="width: 100%;">Connect Now</button>
      </div>
    `;

    popup.querySelector('[data-action="connect"]').addEventListener('click', async () => {
      UI.closeCurrentPopup();
      await UI.connectToiCloud();
    });

    UI.positionPopup(popup, anchorElement);
    document.body.appendChild(popup);
    UI.setCurrentPopup(popup);

    setTimeout(() => {
      document.addEventListener('click', UI.closePopupHandler);
    }, 100);
  }

  // ============================================================================
  // Export to shared namespace
  // ============================================================================

  window.TheaModules.icloudForms = {
    observeInputFields,
    processInputFields,
    enhancePasswordField,
    showPasswordPopup,
    showNoCredentialsPopup,
    showConnectPrompt
  };

})();
