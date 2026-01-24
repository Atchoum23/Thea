/**
 * iCloud Autofill UI for Thea Chrome/Brave Extension
 *
 * Provides Safari-like autofill experience for:
 * - iCloud Passwords (Keychain)
 * - iCloud Hide My Email
 *
 * This creates native-feeling autofill dropdowns and prompts
 * that match Safari's UX as closely as possible.
 */

(function() {
  'use strict';

  // ============================================================================
  // Safari-like Autofill UI Constants
  // ============================================================================

  const STYLES = `
    /* Safari-like Autofill Popup */
    .thea-icloud-popup {
      position: absolute;
      background: #ffffff;
      border-radius: 10px;
      box-shadow: 0 4px 24px rgba(0, 0, 0, 0.15), 0 0 0 1px rgba(0, 0, 0, 0.05);
      z-index: 2147483647;
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', sans-serif;
      font-size: 13px;
      min-width: 280px;
      max-width: 360px;
      overflow: hidden;
      animation: thea-popup-appear 0.15s ease-out;
    }

    @keyframes thea-popup-appear {
      from {
        opacity: 0;
        transform: translateY(-8px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }

    /* Header with iCloud branding */
    .thea-icloud-popup-header {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 12px 14px;
      background: linear-gradient(180deg, #f8f8f8 0%, #f0f0f0 100%);
      border-bottom: 1px solid #e0e0e0;
    }

    .thea-icloud-popup-header svg {
      width: 20px;
      height: 20px;
      color: #007AFF;
    }

    .thea-icloud-popup-header span {
      font-weight: 500;
      color: #1d1d1f;
    }

    .thea-icloud-popup-header .thea-badge {
      margin-left: auto;
      font-size: 10px;
      padding: 2px 6px;
      background: #007AFF;
      color: white;
      border-radius: 10px;
      font-weight: 500;
    }

    /* Credential/Alias item */
    .thea-icloud-item {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 10px 14px;
      cursor: pointer;
      transition: background-color 0.1s ease;
    }

    .thea-icloud-item:hover,
    .thea-icloud-item:focus {
      background-color: #007AFF;
    }

    .thea-icloud-item:hover *,
    .thea-icloud-item:focus * {
      color: white !important;
    }

    .thea-icloud-item-icon {
      width: 32px;
      height: 32px;
      border-radius: 6px;
      background: #f0f0f0;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }

    .thea-icloud-item-icon svg {
      width: 18px;
      height: 18px;
      color: #8e8e93;
    }

    .thea-icloud-item:hover .thea-icloud-item-icon,
    .thea-icloud-item:focus .thea-icloud-item-icon {
      background: rgba(255, 255, 255, 0.2);
    }

    .thea-icloud-item:hover .thea-icloud-item-icon svg,
    .thea-icloud-item:focus .thea-icloud-item-icon svg {
      color: white;
    }

    .thea-icloud-item-content {
      flex: 1;
      min-width: 0;
    }

    .thea-icloud-item-title {
      font-weight: 500;
      color: #1d1d1f;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .thea-icloud-item-subtitle {
      font-size: 11px;
      color: #8e8e93;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      margin-top: 1px;
    }

    /* Footer actions */
    .thea-icloud-popup-footer {
      display: flex;
      align-items: center;
      padding: 8px 14px;
      background: #f8f8f8;
      border-top: 1px solid #e0e0e0;
      gap: 8px;
    }

    .thea-icloud-popup-footer button {
      flex: 1;
      padding: 6px 12px;
      border: none;
      border-radius: 6px;
      font-size: 12px;
      font-weight: 500;
      cursor: pointer;
      transition: background-color 0.1s ease;
    }

    .thea-icloud-popup-footer button.primary {
      background: #007AFF;
      color: white;
    }

    .thea-icloud-popup-footer button.primary:hover {
      background: #0062cc;
    }

    .thea-icloud-popup-footer button.secondary {
      background: #e5e5ea;
      color: #1d1d1f;
    }

    .thea-icloud-popup-footer button.secondary:hover {
      background: #d1d1d6;
    }

    /* Save Password Prompt (Safari-style banner) */
    .thea-save-password-banner {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      background: linear-gradient(180deg, #f8f8f8 0%, #f0f0f0 100%);
      border-bottom: 1px solid #d1d1d6;
      padding: 12px 16px;
      display: flex;
      align-items: center;
      gap: 12px;
      z-index: 2147483647;
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', sans-serif;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
      animation: thea-banner-slide 0.2s ease-out;
    }

    @keyframes thea-banner-slide {
      from {
        transform: translateY(-100%);
      }
      to {
        transform: translateY(0);
      }
    }

    .thea-save-password-banner-icon {
      width: 40px;
      height: 40px;
      background: linear-gradient(180deg, #007AFF 0%, #0056CC 100%);
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }

    .thea-save-password-banner-icon svg {
      width: 24px;
      height: 24px;
      color: white;
    }

    .thea-save-password-banner-content {
      flex: 1;
    }

    .thea-save-password-banner-title {
      font-weight: 600;
      font-size: 14px;
      color: #1d1d1f;
    }

    .thea-save-password-banner-subtitle {
      font-size: 12px;
      color: #8e8e93;
      margin-top: 2px;
    }

    .thea-save-password-banner-actions {
      display: flex;
      gap: 8px;
    }

    .thea-save-password-banner-actions button {
      padding: 8px 16px;
      border: none;
      border-radius: 6px;
      font-size: 13px;
      font-weight: 500;
      cursor: pointer;
    }

    .thea-save-password-banner-actions button.save {
      background: #007AFF;
      color: white;
    }

    .thea-save-password-banner-actions button.never {
      background: #e5e5ea;
      color: #1d1d1f;
    }

    /* Hide My Email Inline Button */
    .thea-hide-email-btn {
      position: absolute;
      right: 8px;
      top: 50%;
      transform: translateY(-50%);
      display: flex;
      align-items: center;
      gap: 4px;
      padding: 4px 8px;
      background: linear-gradient(180deg, #34C759 0%, #28a745 100%);
      border: none;
      border-radius: 4px;
      cursor: pointer;
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
      font-size: 11px;
      font-weight: 500;
      color: white;
      z-index: 10000;
      transition: transform 0.1s ease;
    }

    .thea-hide-email-btn:hover {
      transform: translateY(-50%) scale(1.02);
    }

    .thea-hide-email-btn svg {
      width: 14px;
      height: 14px;
    }

    /* Password Autofill Inline Button */
    .thea-password-btn {
      position: absolute;
      right: 8px;
      top: 50%;
      transform: translateY(-50%);
      display: flex;
      align-items: center;
      justify-content: center;
      width: 24px;
      height: 24px;
      background: none;
      border: none;
      cursor: pointer;
      z-index: 10000;
      padding: 0;
    }

    .thea-password-btn svg {
      width: 20px;
      height: 20px;
      color: #007AFF;
    }

    .thea-password-btn:hover svg {
      color: #0056cc;
    }

    /* Dark mode adjustments */
    @media (prefers-color-scheme: dark) {
      .thea-icloud-popup {
        background: #2c2c2e;
        box-shadow: 0 4px 24px rgba(0, 0, 0, 0.4), 0 0 0 1px rgba(255, 255, 255, 0.1);
      }

      .thea-icloud-popup-header {
        background: linear-gradient(180deg, #3a3a3c 0%, #2c2c2e 100%);
        border-color: #3a3a3c;
      }

      .thea-icloud-popup-header span {
        color: #f5f5f7;
      }

      .thea-icloud-item-icon {
        background: #3a3a3c;
      }

      .thea-icloud-item-title {
        color: #f5f5f7;
      }

      .thea-icloud-popup-footer {
        background: #1c1c1e;
        border-color: #3a3a3c;
      }
    }
  `;

  // ============================================================================
  // State
  // ============================================================================

  let currentPopup = null;
  let currentBanner = null;
  let iCloudConnected = false;

  // ============================================================================
  // Initialization
  // ============================================================================

  function init() {
    // Inject styles
    const styleEl = document.createElement('style');
    styleEl.id = 'thea-icloud-autofill-styles';
    styleEl.textContent = STYLES;
    document.head.appendChild(styleEl);

    // Check iCloud connection status
    checkiCloudStatus();

    // Setup input observers
    observeInputFields();

    // Listen for messages from background
    chrome.runtime.onMessage.addListener(handleMessage);
  }

  async function checkiCloudStatus() {
    try {
      const response = await chrome.runtime.sendMessage({ type: 'getiCloudStatus' });
      if (response.success) {
        iCloudConnected = response.data.connected;
      }
    } catch (e) {
      console.log('iCloud status check failed:', e);
    }
  }

  function handleMessage(message, sender, sendResponse) {
    // SECURITY: Verify message comes from our extension, not from web pages
    if (!sender.id || sender.id !== chrome.runtime.id) {
      console.warn('Thea: Rejected message from unauthorized sender');
      sendResponse({ success: false, error: 'Unauthorized sender' });
      return true;
    }

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
        showSaveConfirmation(message.data);
        sendResponse({ success: true });
        break;

      case 'aliasCreated':
        showAliasCreatedNotification(message.data);
        sendResponse({ success: true });
        break;

      default:
        sendResponse({ success: false, error: 'Unknown message type' });
    }
    return true;
  }

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
        enhanceEmailField(field);
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
    positionButtonInField(usernameField, btn);

    btn.addEventListener('click', async (e) => {
      e.preventDefault();
      e.stopPropagation();

      if (!iCloudConnected) {
        await connectToiCloud();
      }

      showPasswordPopup(usernameField, passwordField);
    });

    // Also trigger on focus
    usernameField.addEventListener('focus', async () => {
      if (iCloudConnected) {
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

  async function showPasswordPopup(usernameField, passwordField) {
    closeCurrentPopup();

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

      const popup = createCredentialPopup(credentials, usernameField, passwordField, domain);
      positionPopup(popup, usernameField);
      document.body.appendChild(popup);
      currentPopup = popup;

      // Close on click outside
      setTimeout(() => {
        document.addEventListener('click', closePopupHandler);
      }, 100);

    } catch (error) {
      console.error('Failed to get credentials:', error);
    }
  }

  function createCredentialPopup(credentials, usernameField, passwordField, domain) {
    const popup = document.createElement('div');
    popup.className = 'thea-icloud-popup';

    // Header
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

    // Credential items
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

    // Footer with "Suggest Password" option
    const footer = document.createElement('div');
    footer.className = 'thea-icloud-popup-footer';
    footer.innerHTML = `
      <button class="secondary" data-action="manage">Manage Passwords...</button>
      <button class="primary" data-action="suggest">Suggest Password</button>
    `;

    footer.querySelector('[data-action="suggest"]').addEventListener('click', async () => {
      const password = await suggestStrongPassword();
      if (password) {
        passwordField.value = password;
        passwordField.dispatchEvent(new Event('input', { bubbles: true }));
        closeCurrentPopup();
        showSavePasswordBanner(usernameField.value, password, domain);
      }
    });

    footer.querySelector('[data-action="manage"]').addEventListener('click', () => {
      // Open Thea settings or Passwords.app
      chrome.runtime.sendMessage({ type: 'openPasswordManager' });
      closeCurrentPopup();
    });

    popup.appendChild(footer);

    return popup;
  }

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
        No saved passwords for ${escapeHtml(domain)}
      </div>
      <div class="thea-icloud-popup-footer">
        <button class="primary" data-action="suggest" style="width: 100%;">Suggest Strong Password</button>
      </div>
    `;

    popup.querySelector('[data-action="suggest"]').addEventListener('click', async () => {
      const password = await suggestStrongPassword();
      if (password) {
        passwordField.value = password;
        passwordField.dispatchEvent(new Event('input', { bubbles: true }));
        closeCurrentPopup();
      }
    });

    positionPopup(popup, usernameField);
    document.body.appendChild(popup);
    currentPopup = popup;

    setTimeout(() => {
      document.addEventListener('click', closePopupHandler);
    }, 100);
  }

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

  function autofillCredential(credential, usernameField, passwordField) {
    // Fill username
    usernameField.value = credential.username;
    usernameField.dispatchEvent(new Event('input', { bubbles: true }));
    usernameField.dispatchEvent(new Event('change', { bubbles: true }));

    // Fill password
    passwordField.value = credential.password;
    passwordField.dispatchEvent(new Event('input', { bubbles: true }));
    passwordField.dispatchEvent(new Event('change', { bubbles: true }));

    // Notify background for stats
    chrome.runtime.sendMessage({
      type: 'updateStats',
      data: { passwordsAutofilled: 1 }
    });
  }

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
    positionButtonInField(emailField, btn);

    btn.addEventListener('click', async (e) => {
      e.preventDefault();
      e.stopPropagation();

      if (!iCloudConnected) {
        await connectToiCloud();
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

  async function showHideMyEmailPopup(emailField) {
    closeCurrentPopup();

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
          Your real email address will stay private from <strong>${escapeHtml(domain)}</strong>
        </div>
      </div>
      <div class="thea-icloud-popup-footer">
        <button class="secondary" data-action="cancel">Cancel</button>
        <button class="primary" data-action="create">Create Address</button>
      </div>
    `;

    popup.querySelector('[data-action="cancel"]').addEventListener('click', closeCurrentPopup);

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
          closeCurrentPopup();

          showAliasCreatedNotification({
            email: response.data.email,
            isNew: response.data.isNew
          });
        }
      } catch (e) {
        console.error('Failed to create alias:', e);
      }
    });

    positionPopup(popup, emailField);
    document.body.appendChild(popup);
    currentPopup = popup;

    setTimeout(() => {
      document.addEventListener('click', closePopupHandler);
    }, 100);
  }

  // ============================================================================
  // Save Password Banner (Safari-style)
  // ============================================================================

  function showSavePasswordBanner(username, password, domain) {
    closeSavePasswordBanner();

    const banner = document.createElement('div');
    banner.className = 'thea-save-password-banner';
    banner.innerHTML = `
      <div class="thea-save-password-banner-icon">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
          <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
        </svg>
      </div>
      <div class="thea-save-password-banner-content">
        <div class="thea-save-password-banner-title">Save this password in iCloud Keychain?</div>
        <div class="thea-save-password-banner-subtitle">
          ${escapeHtml(username || 'This password')} for ${escapeHtml(domain)}
        </div>
      </div>
      <div class="thea-save-password-banner-actions">
        <button class="never" data-action="never">Not Now</button>
        <button class="save" data-action="save">Save Password</button>
      </div>
    `;

    banner.querySelector('[data-action="never"]').addEventListener('click', closeSavePasswordBanner);

    banner.querySelector('[data-action="save"]').addEventListener('click', async () => {
      try {
        await chrome.runtime.sendMessage({
          type: 'saveiCloudCredential',
          data: { username, password, domain }
        });
        showNotification('Password saved to iCloud Keychain');
      } catch (e) {
        showNotification('Failed to save password');
      }
      closeSavePasswordBanner();
    });

    document.body.appendChild(banner);
    currentBanner = banner;

    // Auto-hide after 30 seconds
    setTimeout(closeSavePasswordBanner, 30000);
  }

  function closeSavePasswordBanner() {
    if (currentBanner) {
      currentBanner.remove();
      currentBanner = null;
    }
  }

  // ============================================================================
  // Connect to iCloud Prompt
  // ============================================================================

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
      closeCurrentPopup();
      await connectToiCloud();
    });

    positionPopup(popup, anchorElement);
    document.body.appendChild(popup);
    currentPopup = popup;

    setTimeout(() => {
      document.addEventListener('click', closePopupHandler);
    }, 100);
  }

  // ============================================================================
  // Notifications
  // ============================================================================

  function showAliasCreatedNotification(data) {
    showNotification(
      data.isNew
        ? `Created: ${data.email}`
        : `Using: ${data.email}`,
      'success'
    );
  }

  function showSaveConfirmation(data) {
    showNotification(`Password saved for ${data.domain}`, 'success');
  }

  function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.style.cssText = `
      position: fixed;
      bottom: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: ${type === 'success' ? '#34C759' : '#007AFF'};
      color: white;
      padding: 12px 24px;
      border-radius: 8px;
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
      font-size: 14px;
      font-weight: 500;
      z-index: 2147483647;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.2);
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
  // Utility Functions
  // ============================================================================

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

    // Adjust if off-screen
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

  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
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
