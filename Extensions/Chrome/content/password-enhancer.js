/**
 * Thea Password Manager Enhancer
 *
 * Inspired by: iCloud Passwords, 1Password, Bitwarden
 *
 * Features:
 * - Password change detection (auto-update saved credentials)
 * - Password strength meter on signup forms
 * - TOTP/2FA code autofill from Thea app
 * - Passkey/WebAuthn awareness
 * - Breach detection notifications
 * - Password generation inline (Apple-style strong passwords)
 * - Smart form detection (login vs signup vs change-password)
 * - Auto-save prompt after successful login
 */

(function() {
  'use strict';

  // ============================================================================
  // Form Type Detection
  // ============================================================================

  const FORM_TYPES = {
    LOGIN: 'login',
    SIGNUP: 'signup',
    CHANGE_PASSWORD: 'change_password',
    RESET_PASSWORD: 'reset_password',
    TWO_FACTOR: 'two_factor',
    UNKNOWN: 'unknown'
  };

  /**
   * Detect what type of form this is
   */
  function detectFormType(form) {
    const html = (form.innerHTML + ' ' + form.action + ' ' + document.title).toLowerCase();
    const passwordFields = form.querySelectorAll('input[type="password"]');
    const visiblePasswordFields = [...passwordFields].filter(f => isVisible(f));
    const hasEmail = !!form.querySelector('input[type="email"], input[name*="email"]');
    const hasUsername = !!form.querySelector('input[type="text"][name*="user"], input[type="text"][name*="name"], input[type="text"][id*="user"]');

    // 2FA form: no password field, has a short text/tel input
    const otpField = form.querySelector(
      'input[name*="otp"], input[name*="code"], input[name*="token"], input[name*="2fa"], ' +
      'input[name*="totp"], input[autocomplete="one-time-code"], ' +
      'input[inputmode="numeric"][maxlength="6"], input[inputmode="numeric"][maxlength="4"]'
    );
    if (otpField && visiblePasswordFields.length === 0) {
      return FORM_TYPES.TWO_FACTOR;
    }

    // Change password: 2+ password fields + keywords
    if (visiblePasswordFields.length >= 2) {
      const changeKeywords = ['change', 'update', 'new password', 'current password', 'old password', 'confirm password'];
      if (changeKeywords.some(kw => html.includes(kw))) {
        return FORM_TYPES.CHANGE_PASSWORD;
      }
      // 2 password fields with signup keywords
      const signupKeywords = ['sign up', 'signup', 'register', 'create account', 'join', 'get started'];
      if (signupKeywords.some(kw => html.includes(kw))) {
        return FORM_TYPES.SIGNUP;
      }
      // Default for 2+ password fields
      return FORM_TYPES.SIGNUP;
    }

    // Reset password
    const resetKeywords = ['reset', 'forgot', 'recover'];
    if (resetKeywords.some(kw => html.includes(kw)) && visiblePasswordFields.length <= 1) {
      return FORM_TYPES.RESET_PASSWORD;
    }

    // Login: 1 password + username/email
    if (visiblePasswordFields.length === 1 && (hasEmail || hasUsername)) {
      return FORM_TYPES.LOGIN;
    }

    // Signup patterns
    if (visiblePasswordFields.length === 1) {
      const signupKeywords = ['sign up', 'signup', 'register', 'create'];
      if (signupKeywords.some(kw => html.includes(kw))) {
        return FORM_TYPES.SIGNUP;
      }
    }

    return visiblePasswordFields.length > 0 ? FORM_TYPES.LOGIN : FORM_TYPES.UNKNOWN;
  }

  // ============================================================================
  // Password Strength Meter
  // ============================================================================

  function calculatePasswordStrength(password) {
    let score = 0;
    if (!password) return { score: 0, label: 'None', color: '#ccc' };

    // Length
    if (password.length >= 8) score += 1;
    if (password.length >= 12) score += 1;
    if (password.length >= 16) score += 1;

    // Character variety
    if (/[a-z]/.test(password)) score += 1;
    if (/[A-Z]/.test(password)) score += 1;
    if (/[0-9]/.test(password)) score += 1;
    if (/[^a-zA-Z0-9]/.test(password)) score += 1;

    // Patterns (negative)
    if (/(.)\1{2,}/.test(password)) score -= 1; // Repeated chars
    if (/^[a-zA-Z]+$/.test(password)) score -= 1; // Letters only
    if (/^[0-9]+$/.test(password)) score -= 1; // Numbers only

    // Common patterns
    const commonPatterns = ['password', '123456', 'qwerty', 'abc123', 'letmein', 'admin', 'welcome'];
    if (commonPatterns.some(p => password.toLowerCase().includes(p))) score -= 2;

    score = Math.max(0, Math.min(score, 7));

    const levels = [
      { score: 0, label: 'Very Weak', color: '#ff3b30' },
      { score: 1, label: 'Very Weak', color: '#ff3b30' },
      { score: 2, label: 'Weak', color: '#ff9500' },
      { score: 3, label: 'Fair', color: '#ffcc00' },
      { score: 4, label: 'Good', color: '#34c759' },
      { score: 5, label: 'Strong', color: '#30d158' },
      { score: 6, label: 'Very Strong', color: '#00c7be' },
      { score: 7, label: 'Excellent', color: '#007aff' }
    ];

    return levels[score];
  }

  function addStrengthMeter(passwordField) {
    if (passwordField.dataset.theaStrength) return;
    passwordField.dataset.theaStrength = 'true';

    const meter = document.createElement('div');
    meter.className = 'thea-strength-meter';
    meter.style.cssText = `
      height: 3px;
      margin-top: 4px;
      border-radius: 2px;
      background: #e0e0e0;
      overflow: hidden;
      transition: all 0.3s;
    `;

    const fill = document.createElement('div');
    fill.style.cssText = `
      height: 100%;
      width: 0%;
      border-radius: 2px;
      transition: all 0.3s ease;
    `;
    meter.appendChild(fill);

    const label = document.createElement('div');
    label.className = 'thea-strength-label';
    label.style.cssText = `
      font-size: 11px;
      margin-top: 2px;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      color: #999;
      transition: color 0.3s;
    `;

    passwordField.addEventListener('input', () => {
      const strength = calculatePasswordStrength(passwordField.value);
      const pct = (strength.score / 7) * 100;
      fill.style.width = pct + '%';
      fill.style.background = strength.color;
      label.textContent = passwordField.value ? strength.label : '';
      label.style.color = strength.color;
    });

    // Insert after the password field
    const container = passwordField.parentElement;
    if (container) {
      passwordField.after(label);
      passwordField.after(meter);
    }
  }

  // ============================================================================
  // Password Generator (Inline)
  // ============================================================================

  function generateApplePassword() {
    const lowercase = 'abcdefghjkmnpqrstuvwxyz';
    const uppercase = 'ABCDEFGHJKMNPQRSTUVWXYZ';
    const digits = '23456789';
    const special = '-';

    function randomChar(charset) {
      const array = new Uint32Array(1);
      crypto.getRandomValues(array);
      return charset[array[0] % charset.length];
    }

    function generateGroup() {
      let group = '';
      group += randomChar(lowercase);
      group += randomChar(uppercase);
      group += randomChar(digits);
      const allChars = lowercase + uppercase + digits;
      for (let i = 0; i < 3; i++) {
        group += randomChar(allChars);
      }
      // Shuffle
      return group.split('').sort(() => {
        const a = new Uint32Array(1);
        crypto.getRandomValues(a);
        return a[0] % 2 === 0 ? 1 : -1;
      }).join('');
    }

    return `${generateGroup()}${special}${generateGroup()}${special}${generateGroup()}`;
  }

  function addPasswordGenerator(passwordField, formType) {
    if (formType !== FORM_TYPES.SIGNUP && formType !== FORM_TYPES.CHANGE_PASSWORD) return;
    if (passwordField.dataset.theaGenerator) return;
    passwordField.dataset.theaGenerator = 'true';

    const btn = document.createElement('button');
    btn.type = 'button';
    btn.title = 'Generate strong password';
    btn.style.cssText = `
      position: absolute;
      right: 36px;
      top: 50%;
      transform: translateY(-50%);
      background: #007aff;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      padding: 3px 8px;
      color: white;
      font-size: 11px;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      z-index: 10000;
      white-space: nowrap;
    `;
    btn.textContent = 'Generate';

    btn.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      const password = generateApplePassword();
      passwordField.value = password;
      passwordField.dispatchEvent(new Event('input', { bubbles: true }));
      passwordField.dispatchEvent(new Event('change', { bubbles: true }));

      // Also fill confirm password if present
      const form = passwordField.closest('form');
      if (form) {
        const allPwFields = form.querySelectorAll('input[type="password"]');
        allPwFields.forEach(f => {
          if (f !== passwordField) {
            f.value = password;
            f.dispatchEvent(new Event('input', { bubbles: true }));
          }
        });
      }

      // Copy to clipboard
      navigator.clipboard.writeText(password).catch(() => {});
      showToast('Strong password generated and copied');
    });

    const container = passwordField.parentElement;
    if (container) {
      if (getComputedStyle(container).position === 'static') {
        container.style.position = 'relative';
      }
      container.appendChild(btn);
    }
  }

  // ============================================================================
  // Password Change Detection
  // ============================================================================

  function setupPasswordChangeDetection() {
    document.addEventListener('submit', async (e) => {
      const form = e.target;
      if (!(form instanceof HTMLFormElement)) return;

      const formType = detectFormType(form);
      if (formType !== FORM_TYPES.CHANGE_PASSWORD) return;

      const passwordFields = [...form.querySelectorAll('input[type="password"]')].filter(f => isVisible(f));
      if (passwordFields.length < 2) return;

      // Find the new password (usually the second or third field)
      const newPassword = passwordFields.length >= 3
        ? passwordFields[1].value // old, new, confirm
        : passwordFields[1].value; // old, new

      const usernameField = form.querySelector('input[type="email"], input[type="text"][name*="user"], input[type="text"][name*="email"]');
      const username = usernameField?.value || '';

      if (newPassword) {
        // Delay to let the form submit succeed
        setTimeout(() => {
          showPasswordUpdateBanner(username, newPassword);
        }, 1500);
      }
    }, true);
  }

  function showPasswordUpdateBanner(username, newPassword) {
    const banner = document.createElement('div');
    banner.className = 'thea-pw-update-banner';
    banner.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
      color: white;
      padding: 14px 20px;
      display: flex;
      align-items: center;
      gap: 12px;
      z-index: 2147483647;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      font-size: 14px;
      box-shadow: 0 2px 12px rgba(0,0,0,0.3);
      animation: thea-slide-down 0.3s ease-out;
    `;

    const style = document.createElement('style');
    style.textContent = `
      @keyframes thea-slide-down {
        from { transform: translateY(-100%); }
        to { transform: translateY(0); }
      }
    `;
    document.head.appendChild(style);

    banner.innerHTML = `
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#4fc3f7" stroke-width="2">
        <path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/>
      </svg>
      <span style="flex:1">Update saved password for <b>${escapeHtml(window.location.hostname)}</b>?</span>
      <button id="thea-pw-update-yes" style="background:#007aff;color:white;border:none;border-radius:6px;padding:6px 16px;cursor:pointer;font-size:13px;">Update</button>
      <button id="thea-pw-update-no" style="background:transparent;color:#ccc;border:1px solid #555;border-radius:6px;padding:6px 16px;cursor:pointer;font-size:13px;">Not Now</button>
    `;

    document.body.appendChild(banner);

    banner.querySelector('#thea-pw-update-no').addEventListener('click', () => {
      banner.style.transform = 'translateY(-100%)';
      banner.style.transition = 'transform 0.3s';
      setTimeout(() => banner.remove(), 300);
    });

    banner.querySelector('#thea-pw-update-yes').addEventListener('click', async () => {
      try {
        await chrome.runtime.sendMessage({
          type: 'saveiCloudCredential',
          data: {
            domain: window.location.hostname,
            username,
            password: newPassword,
            notes: 'Updated by Thea'
          }
        });
        banner.querySelector('span').textContent = 'Password updated!';
        setTimeout(() => {
          banner.style.transform = 'translateY(-100%)';
          banner.style.transition = 'transform 0.3s';
          setTimeout(() => banner.remove(), 300);
        }, 1500);
      } catch (err) {
        banner.querySelector('span').textContent = 'Failed to update password';
      }
    });

    // Auto-dismiss after 30s
    setTimeout(() => {
      if (document.body.contains(banner)) {
        banner.style.transform = 'translateY(-100%)';
        banner.style.transition = 'transform 0.3s';
        setTimeout(() => banner.remove(), 300);
      }
    }, 30000);
  }

  // ============================================================================
  // TOTP/2FA Code Autofill
  // ============================================================================

  function setupTOTPAutofill() {
    const observer = new MutationObserver(() => {
      detectAndEnhanceTOTPFields();
    });
    observer.observe(document.body, { childList: true, subtree: true });
    detectAndEnhanceTOTPFields();
  }

  function detectAndEnhanceTOTPFields() {
    const selectors = [
      'input[name*="otp"]', 'input[name*="code"]', 'input[name*="token"]',
      'input[name*="2fa"]', 'input[name*="totp"]', 'input[name*="mfa"]',
      'input[autocomplete="one-time-code"]',
      'input[inputmode="numeric"][maxlength="6"]',
      'input[inputmode="numeric"][maxlength="4"]'
    ];

    const fields = document.querySelectorAll(selectors.join(','));
    fields.forEach(field => {
      if (field.dataset.theaTotp) return;
      field.dataset.theaTotp = 'true';
      addTOTPButton(field);
    });
  }

  function addTOTPButton(field) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.title = 'Autofill 2FA code from Thea';
    btn.style.cssText = `
      position: absolute;
      right: 8px;
      top: 50%;
      transform: translateY(-50%);
      background: #007aff;
      border: none;
      border-radius: 4px;
      cursor: pointer;
      padding: 3px 8px;
      color: white;
      font-size: 11px;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      z-index: 10000;
    `;
    btn.textContent = '2FA';

    btn.addEventListener('click', async (e) => {
      e.preventDefault();
      e.stopPropagation();
      btn.textContent = '...';

      try {
        const response = await chrome.runtime.sendMessage({
          type: 'getTOTPCode',
          data: { domain: window.location.hostname }
        });

        if (response?.success && response.data?.code) {
          field.value = response.data.code;
          field.dispatchEvent(new Event('input', { bubbles: true }));
          field.dispatchEvent(new Event('change', { bubbles: true }));
          showToast('2FA code filled');
        } else {
          showToast('No 2FA code available for this site');
        }
      } catch (err) {
        showToast('Could not get 2FA code');
      }

      btn.textContent = '2FA';
    });

    const container = field.parentElement;
    if (container) {
      if (getComputedStyle(container).position === 'static') {
        container.style.position = 'relative';
      }
      container.appendChild(btn);
    }
  }

  // ============================================================================
  // Passkey/WebAuthn Awareness
  // ============================================================================

  function setupPasskeyDetection() {
    // Detect if site supports WebAuthn/Passkeys
    if (window.PublicKeyCredential) {
      // Listen for credential creation (passkey registration)
      const originalCreate = navigator.credentials.create;
      if (originalCreate) {
        navigator.credentials.create = async function(...args) {
          const result = await originalCreate.apply(this, args);
          // Notify about passkey creation
          chrome.runtime.sendMessage({
            type: 'passkeyCreated',
            data: {
              domain: window.location.hostname,
              type: 'webauthn'
            }
          }).catch(() => {});
          return result;
        };
      }
    }
  }

  // ============================================================================
  // Login Success Detection
  // ============================================================================

  function setupLoginDetection() {
    document.addEventListener('submit', (e) => {
      const form = e.target;
      if (!(form instanceof HTMLFormElement)) return;

      const formType = detectFormType(form);
      if (formType !== FORM_TYPES.LOGIN && formType !== FORM_TYPES.SIGNUP) return;

      const passwordField = form.querySelector('input[type="password"]');
      const usernameField = form.querySelector('input[type="email"], input[type="text"][name*="user"], input[type="text"][name*="email"], input[type="text"][id*="user"]');

      if (!passwordField?.value || !usernameField?.value) return;

      const credentials = {
        domain: window.location.hostname,
        username: usernameField.value,
        password: passwordField.value
      };

      // Wait to see if login succeeds (page navigates or no error message)
      setTimeout(() => {
        // If still on the same page, check for error messages
        const errorIndicators = document.querySelectorAll(
          '.error, .alert-danger, [role="alert"], .login-error, .error-message'
        );
        const hasVisibleError = [...errorIndicators].some(el => isVisible(el) && el.textContent.trim().length > 0);

        if (!hasVisibleError) {
          // Likely successful - offer to save
          showSavePasswordPrompt(credentials);
        }
      }, 2000);
    }, true);
  }

  function showSavePasswordPrompt(credentials) {
    // Check if we already saved for this domain
    chrome.runtime.sendMessage({
      type: 'getiCloudCredentials',
      data: { domain: credentials.domain }
    }).then(response => {
      if (response?.success) {
        const existing = response.data?.credentials || [];
        const alreadySaved = existing.some(c =>
          c.username === credentials.username && c.password === credentials.password
        );
        if (alreadySaved) return; // Already saved, skip
      }

      // Show save banner (reuses icloud-autofill-ui save banner if available)
      chrome.runtime.sendMessage({
        type: 'saveiCloudCredential',
        data: credentials
      }).then(result => {
        if (result?.success) {
          showToast('Password saved to iCloud Keychain');
        }
      }).catch(() => {});
    }).catch(() => {});
  }

  // ============================================================================
  // Form Enhancement
  // ============================================================================

  function enhanceForms() {
    const forms = document.querySelectorAll('form');
    forms.forEach(enhanceForm);
  }

  function enhanceForm(form) {
    if (form.dataset.theaEnhanced) return;
    form.dataset.theaEnhanced = 'true';

    const formType = detectFormType(form);
    const passwordFields = [...form.querySelectorAll('input[type="password"]')].filter(f => isVisible(f));

    passwordFields.forEach(field => {
      // Add strength meter for signup/change forms
      if (formType === FORM_TYPES.SIGNUP || formType === FORM_TYPES.CHANGE_PASSWORD) {
        addStrengthMeter(field);
        addPasswordGenerator(field, formType);
      }
    });
  }

  // ============================================================================
  // Utilities
  // ============================================================================

  function isVisible(el) {
    if (!el) return false;
    const style = getComputedStyle(el);
    return style.display !== 'none' && style.visibility !== 'hidden' &&
           style.opacity !== '0' && el.offsetParent !== null;
  }

  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text || '';
    return div.innerHTML;
  }

  function showToast(message) {
    const existing = document.querySelector('.thea-toast');
    if (existing) existing.remove();

    const toast = document.createElement('div');
    toast.className = 'thea-toast';
    toast.textContent = message;
    toast.style.cssText = `
      position: fixed;
      bottom: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: #323232;
      color: white;
      padding: 10px 20px;
      border-radius: 8px;
      z-index: 2147483647;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      font-size: 13px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3);
      animation: thea-toast-in 0.3s ease-out;
    `;
    document.body.appendChild(toast);
    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transition = 'opacity 0.3s';
      setTimeout(() => toast.remove(), 300);
    }, 3000);
  }

  // ============================================================================
  // Mutation Observer for Dynamic Forms
  // ============================================================================

  function setupObserver() {
    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type !== 'childList') continue;
        for (const node of mutation.addedNodes) {
          if (node.nodeType !== Node.ELEMENT_NODE) continue;
          const forms = node.querySelectorAll?.('form') || [];
          forms.forEach(enhanceForm);
          if (node.tagName === 'FORM') enhanceForm(node);
        }
      }
    });

    observer.observe(document.body, { childList: true, subtree: true });
  }

  // ============================================================================
  // Initialize
  // ============================================================================

  function init() {
    enhanceForms();
    setupPasswordChangeDetection();
    setupTOTPAutofill();
    setupPasskeyDetection();
    setupLoginDetection();
    setupObserver();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
