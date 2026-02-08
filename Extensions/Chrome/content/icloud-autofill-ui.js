/**
 * iCloud Autofill UI - Core Module
 *
 * Styles, state, init, message handling, credential popup,
 * autofill, popup utilities, iCloud connection state.
 *
 * Loaded first. Other iCloud modules depend on this.
 */

(function() {
  'use strict';

  window.TheaModules = window.TheaModules || {};

  // ============================================================================
  // Safari-like Autofill UI Styles (core popup + inline buttons + dark mode)
  // ============================================================================

  const STYLES = `
    .thea-icloud-popup {
      position: absolute;
      background: #ffffff;
      border-radius: 10px;
      box-shadow: 0 4px 24px rgba(0,0,0,0.15), 0 0 0 1px rgba(0,0,0,0.05);
      z-index: 2147483647;
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', sans-serif;
      font-size: 13px;
      min-width: 280px;
      max-width: 360px;
      overflow: hidden;
      animation: thea-popup-appear 0.15s ease-out;
    }
    @keyframes thea-popup-appear {
      from { opacity: 0; transform: translateY(-8px); }
      to { opacity: 1; transform: translateY(0); }
    }
    .thea-icloud-popup-header {
      display: flex; align-items: center; gap: 8px;
      padding: 12px 14px;
      background: linear-gradient(180deg, #f8f8f8 0%, #f0f0f0 100%);
      border-bottom: 1px solid #e0e0e0;
    }
    .thea-icloud-popup-header svg { width: 20px; height: 20px; color: #007AFF; }
    .thea-icloud-popup-header span { font-weight: 500; color: #1d1d1f; }
    .thea-icloud-popup-header .thea-badge {
      margin-left: auto; font-size: 10px; padding: 2px 6px;
      background: #007AFF; color: white; border-radius: 10px; font-weight: 500;
    }
    .thea-icloud-item {
      display: flex; align-items: center; gap: 12px;
      padding: 10px 14px; cursor: pointer;
      transition: background-color 0.1s ease;
    }
    .thea-icloud-item:hover, .thea-icloud-item:focus { background-color: #007AFF; }
    .thea-icloud-item:hover *, .thea-icloud-item:focus * { color: white !important; }
    .thea-icloud-item-icon {
      width: 32px; height: 32px; border-radius: 6px; background: #f0f0f0;
      display: flex; align-items: center; justify-content: center; flex-shrink: 0;
    }
    .thea-icloud-item-icon svg { width: 18px; height: 18px; color: #8e8e93; }
    .thea-icloud-item:hover .thea-icloud-item-icon,
    .thea-icloud-item:focus .thea-icloud-item-icon { background: rgba(255,255,255,0.2); }
    .thea-icloud-item:hover .thea-icloud-item-icon svg,
    .thea-icloud-item:focus .thea-icloud-item-icon svg { color: white; }
    .thea-icloud-item-content { flex: 1; min-width: 0; }
    .thea-icloud-item-title {
      font-weight: 500; color: #1d1d1f;
      white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
    }
    .thea-icloud-item-subtitle {
      font-size: 11px; color: #8e8e93;
      white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin-top: 1px;
    }
    .thea-icloud-popup-footer {
      display: flex; align-items: center; padding: 8px 14px;
      background: #f8f8f8; border-top: 1px solid #e0e0e0; gap: 8px;
    }
    .thea-icloud-popup-footer button {
      flex: 1; padding: 6px 12px; border: none; border-radius: 6px;
      font-size: 12px; font-weight: 500; cursor: pointer;
      transition: background-color 0.1s ease;
    }
    .thea-icloud-popup-footer button.primary { background: #007AFF; color: white; }
    .thea-icloud-popup-footer button.primary:hover { background: #0062cc; }
    .thea-icloud-popup-footer button.secondary { background: #e5e5ea; color: #1d1d1f; }
    .thea-icloud-popup-footer button.secondary:hover { background: #d1d1d6; }
    .thea-hide-email-btn {
      position: absolute; right: 8px; top: 50%; transform: translateY(-50%);
      display: flex; align-items: center; gap: 4px; padding: 4px 8px;
      background: linear-gradient(180deg, #34C759 0%, #28a745 100%);
      border: none; border-radius: 4px; cursor: pointer;
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
      font-size: 11px; font-weight: 500; color: white;
      z-index: 10000; transition: transform 0.1s ease;
    }
    .thea-hide-email-btn:hover { transform: translateY(-50%) scale(1.02); }
    .thea-hide-email-btn svg { width: 14px; height: 14px; }
    .thea-password-btn {
      position: absolute; right: 8px; top: 50%; transform: translateY(-50%);
      display: flex; align-items: center; justify-content: center;
      width: 24px; height: 24px; background: none; border: none;
      cursor: pointer; z-index: 10000; padding: 0;
    }
    .thea-password-btn svg { width: 20px; height: 20px; color: #007AFF; }
    .thea-password-btn:hover svg { color: #0056cc; }
    @media (prefers-color-scheme: dark) {
      .thea-icloud-popup {
        background: #2c2c2e;
        box-shadow: 0 4px 24px rgba(0,0,0,0.4), 0 0 0 1px rgba(255,255,255,0.1);
      }
      .thea-icloud-popup-header {
        background: linear-gradient(180deg, #3a3a3c 0%, #2c2c2e 100%);
        border-color: #3a3a3c;
      }
      .thea-icloud-popup-header span { color: #f5f5f7; }
      .thea-icloud-item-icon { background: #3a3a3c; }
      .thea-icloud-item-title { color: #f5f5f7; }
      .thea-icloud-popup-footer { background: #1c1c1e; border-color: #3a3a3c; }
    }
  `;

  // ============================================================================
  // State
  // ============================================================================

  let currentPopup = null;
  let iCloudConnected = false;

  // ============================================================================
  // Utilities
  // ============================================================================

  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  function positionButtonInField(input, btn) {
    const container = input.parentElement;
    if (container) {
      if (getComputedStyle(container).position === 'static') {
        container.style.position = 'relative';
      }
      container.appendChild(btn);
    }
  }

  function positionPopup(popup, anchorElement) {
    const rect = anchorElement.getBoundingClientRect();
    popup.style.position = 'fixed';
    popup.style.top = `${rect.bottom + 4}px`;
    popup.style.left = `${rect.left}px`;

    requestAnimationFrame(() => {
      const popupRect = popup.getBoundingClientRect();
      if (popupRect.right > window.innerWidth) {
        popup.style.left = `${window.innerWidth - popupRect.width - 10}px`;
      }
      if (popupRect.bottom > window.innerHeight) {
        popup.style.top = `${rect.top - popupRect.height - 4}px`;
      }
    });
  }

  function closeCurrentPopup() {
    if (currentPopup) {
      currentPopup.remove();
      currentPopup = null;
    }
    document.removeEventListener('click', closePopupHandler);
  }

  function closePopupHandler(e) {
    if (currentPopup && !currentPopup.contains(e.target)) {
      closeCurrentPopup();
    }
  }

  function setCurrentPopup(popup) {
    currentPopup = popup;
  }

  // ============================================================================
  // Credential Popup
  // ============================================================================

  function createCredentialPopup(credentials, usernameField, passwordField, domain) {
    const popup = document.createElement('div');
    popup.className = 'thea-icloud-popup';

    const header = document.createElement('div');
    header.className = 'thea-icloud-popup-header';
    header.innerHTML = `
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
        <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
      </svg>
      <span>Passwords</span>
      <span class="thea-badge">iCloud</span>
    `;
    popup.appendChild(header);

    credentials.forEach(cred => {
      const item = document.createElement('div');
      item.className = 'thea-icloud-item';
      item.tabIndex = 0;
      item.innerHTML = `
        <div class="thea-icloud-item-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
            <circle cx="12" cy="7" r="4"/>
          </svg>
        </div>
        <div class="thea-icloud-item-content">
          <div class="thea-icloud-item-title">${escapeHtml(cred.username)}</div>
          <div class="thea-icloud-item-subtitle">${escapeHtml(cred.domain)}</div>
        </div>
      `;

      item.addEventListener('click', () => {
        autofillCredential(cred, usernameField, passwordField);
        closeCurrentPopup();
      });
      item.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          autofillCredential(cred, usernameField, passwordField);
          closeCurrentPopup();
        }
      });
      popup.appendChild(item);
    });

    const footer = document.createElement('div');
    footer.className = 'thea-icloud-popup-footer';
    footer.innerHTML = `
      <button class="secondary" data-action="manage">Manage Passwords...</button>
      <button class="primary" data-action="suggest">Suggest Password</button>
    `;

    footer.querySelector('[data-action="suggest"]').addEventListener('click', async () => {
      const password = await suggestStrongPassword();
      if (password && passwordField) {
        passwordField.value = password;
        passwordField.dispatchEvent(new Event('input', { bubbles: true }));
        closeCurrentPopup();
        const totp = window.TheaModules.icloudTOTP;
        if (totp) {
          totp.showSavePasswordBanner(usernameField.value, password, domain);
        }
      }
    });

    footer.querySelector('[data-action="manage"]').addEventListener('click', () => {
      chrome.runtime.sendMessage({ type: 'openPasswordManager' });
      closeCurrentPopup();
    });

    popup.appendChild(footer);
    return popup;
  }

  // ============================================================================
  // Autofill Credential
  // ============================================================================

  function autofillCredential(credential, usernameField, passwordField) {
    usernameField.value = credential.username;
    usernameField.dispatchEvent(new Event('input', { bubbles: true }));
    usernameField.dispatchEvent(new Event('change', { bubbles: true }));

    passwordField.value = credential.password;
    passwordField.dispatchEvent(new Event('input', { bubbles: true }));
    passwordField.dispatchEvent(new Event('change', { bubbles: true }));

    chrome.runtime.sendMessage({
      type: 'updateStats',
      data: { passwordsAutofilled: 1 }
    });
  }

  // ============================================================================
  // Suggest Strong Password
  // ============================================================================

  async function suggestStrongPassword() {
    try {
      const response = await chrome.runtime.sendMessage({ type: 'generateiCloudPassword' });
      if (response.success) {
        return response.data.password;
      }
    } catch (e) {
      console.error('Failed to generate password:', e);
    }
    return null;
  }

  // ============================================================================
  // Notification
  // ============================================================================

  function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.style.cssText = `
      position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%);
      background: ${type === 'success' ? '#34C759' : '#007AFF'};
      color: white; padding: 12px 24px; border-radius: 8px;
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
      font-size: 14px; font-weight: 500; z-index: 2147483647;
      box-shadow: 0 4px 12px rgba(0,0,0,0.2);
      animation: thea-notification-appear 0.2s ease-out;
    `;
    notification.textContent = message;

    const style = document.createElement('style');
    style.textContent = `
      @keyframes thea-notification-appear {
        from { opacity: 0; transform: translate(-50%, 20px); }
        to { opacity: 1; transform: translate(-50%, 0); }
      }
    `;
    notification.appendChild(style);
    document.body.appendChild(notification);

    setTimeout(() => {
      notification.style.opacity = '0';
      notification.style.transition = 'opacity 0.3s';
      setTimeout(() => notification.remove(), 300);
    }, 3000);
  }

  // ============================================================================
  // iCloud Connection State
  // ============================================================================

  function isConnected() { return iCloudConnected; }

  function setConnected(value) { iCloudConnected = value; }

  async function connectToiCloud() {
    try {
      const response = await chrome.runtime.sendMessage({ type: 'connectiCloud' });
      if (response.success) {
        iCloudConnected = true;
        return true;
      }
    } catch (e) {
      console.error('Failed to connect to iCloud:', e);
    }
    return false;
  }

  // ============================================================================
  // Initialization
  // ============================================================================

  function init() {
    const styleEl = document.createElement('style');
    styleEl.id = 'thea-icloud-autofill-styles';
    styleEl.textContent = STYLES;
    document.head.appendChild(styleEl);

    checkiCloudStatus();

    const forms = window.TheaModules.icloudForms;
    if (forms) { forms.observeInputFields(); }

    chrome.runtime.onMessage.addListener(handleMessage);
  }

  async function checkiCloudStatus() {
    try {
      const response = await chrome.runtime.sendMessage({ type: 'getiCloudStatus' });
      if (response.success) { iCloudConnected = response.data.connected; }
    } catch (e) {
      console.log('iCloud status check failed:', e);
    }
  }

  function handleMessage(message, sender, sendResponse) {
    if (!sender.id || sender.id !== chrome.runtime.id) {
      console.warn('Thea: Rejected message from unauthorized sender');
      sendResponse({ success: false, error: 'Unauthorized sender' });
      return true;
    }

    const email = window.TheaModules.icloudEmail;

    switch (message.type) {
      case 'iCloudConnected':
        iCloudConnected = true;
        sendResponse({ success: true });
        break;
      case 'iCloudDisconnected':
        iCloudConnected = false;
        sendResponse({ success: true });
        break;
      case 'credentialSaved':
        if (email) email.showSaveConfirmation(message.data);
        sendResponse({ success: true });
        break;
      case 'aliasCreated':
        if (email) email.showAliasCreatedNotification(message.data);
        sendResponse({ success: true });
        break;
      default:
        sendResponse({ success: false, error: 'Unknown message type' });
    }
    return true;
  }

  // ============================================================================
  // Export to shared namespace
  // ============================================================================

  window.TheaModules.icloudUI = {
    escapeHtml,
    positionButtonInField,
    positionPopup,
    closeCurrentPopup,
    closePopupHandler,
    setCurrentPopup,
    createCredentialPopup,
    autofillCredential,
    suggestStrongPassword,
    showNotification,
    isConnected,
    setConnected,
    connectToiCloud
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
