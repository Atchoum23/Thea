/**
 * iCloud Autofill - Email Module
 *
 * Hide My Email button, email field enhancement,
 * Hide My Email popup, alias notifications.
 *
 * Depends on: icloud-autofill-ui.js (loaded before this file)
 */

(function() {
  'use strict';

  window.TheaModules = window.TheaModules || {};
  const UI = window.TheaModules.icloudUI;

  // ============================================================================
  // Email Field Enhancement (Hide My Email)
  // ============================================================================

  function enhanceEmailField(emailField) {
    emailField.dataset.theaEnhanced = 'true';

    // Don't add button to password reset or login email fields
    const form = emailField.closest('form');
    if (form?.querySelector('input[type="password"]')) {
      return; // This is likely a login form
    }

    // Add Hide My Email button
    const btn = createHideEmailButton();
    UI.positionButtonInField(emailField, btn);

    btn.addEventListener('click', async (e) => {
      e.preventDefault();
      e.stopPropagation();

      if (!UI.isConnected()) {
        await UI.connectToiCloud();
      }

      showHideMyEmailPopup(emailField);
    });
  }

  function createHideEmailButton() {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'thea-hide-email-btn';
    btn.title = 'Hide My Email';
    btn.innerHTML = `
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
        <polyline points="22,6 12,13 2,6"/>
      </svg>
      Hide
    `;
    return btn;
  }

  // ============================================================================
  // Hide My Email Popup
  // ============================================================================

  async function showHideMyEmailPopup(emailField) {
    UI.closeCurrentPopup();

    const domain = window.location.hostname;

    const popup = document.createElement('div');
    popup.className = 'thea-icloud-popup';

    popup.innerHTML = `
      <div class="thea-icloud-popup-header" style="background: linear-gradient(180deg, #34C759 0%, #28a745 100%); border-color: #28a745;">
        <svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2">
          <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
          <polyline points="22,6 12,13 2,6"/>
        </svg>
        <span style="color: white;">Hide My Email</span>
        <span class="thea-badge" style="background: rgba(255,255,255,0.3);">iCloud+</span>
      </div>
      <div style="padding: 16px;">
        <div style="font-size: 13px; color: #1d1d1f; margin-bottom: 12px;">
          Create a unique, random @icloud.com address that forwards to your real inbox.
        </div>
        <div style="font-size: 12px; color: #8e8e93;">
          Your real email address will stay private from <strong>${UI.escapeHtml(domain)}</strong>
        </div>
      </div>
      <div class="thea-icloud-popup-footer">
        <button class="secondary" data-action="cancel">Cancel</button>
        <button class="primary" data-action="create">Create Address</button>
      </div>
    `;

    popup.querySelector('[data-action="cancel"]').addEventListener('click', UI.closeCurrentPopup);

    popup.querySelector('[data-action="create"]').addEventListener('click', async () => {
      try {
        const response = await chrome.runtime.sendMessage({
          type: 'autofillHideMyEmail',
          data: { domain }
        });

        if (response.success) {
          emailField.value = response.data.email;
          emailField.dispatchEvent(new Event('input', { bubbles: true }));
          emailField.dispatchEvent(new Event('change', { bubbles: true }));
          UI.closeCurrentPopup();

          showAliasCreatedNotification({
            email: response.data.email,
            isNew: response.data.isNew
          });
        }
      } catch (e) {
        console.error('Failed to create alias:', e);
      }
    });

    UI.positionPopup(popup, emailField);
    document.body.appendChild(popup);
    UI.setCurrentPopup(popup);

    setTimeout(() => {
      document.addEventListener('click', UI.closePopupHandler);
    }, 100);
  }

  // ============================================================================
  // Notifications
  // ============================================================================

  function showAliasCreatedNotification(data) {
    UI.showNotification(
      data.isNew
        ? `Created: ${data.email}`
        : `Using: ${data.email}`,
      'success'
    );
  }

  function showSaveConfirmation(data) {
    UI.showNotification(`Password saved for ${data.domain}`, 'success');
  }

  // ============================================================================
  // Export to shared namespace
  // ============================================================================

  window.TheaModules.icloudEmail = {
    enhanceEmailField,
    createHideEmailButton,
    showHideMyEmailPopup,
    showAliasCreatedNotification,
    showSaveConfirmation
  };

})();
