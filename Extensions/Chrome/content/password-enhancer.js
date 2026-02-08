/**
 * Thea Password Manager Enhancer - Logic Module
 *
 * Form detection, credential matching, passkey/WebAuthn,
 * TOTP field detection, password change detection, login success detection.
 *
 * Depends on: password-enhancer-ui.js (loaded before this file)
 */

(function() {
  'use strict';

  window.TheaModules = window.TheaModules || {};
  const UI = window.TheaModules.passwordUI;

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

  function detectFormType(form) {
    const html = (form.innerHTML + ' ' + form.action + ' ' + document.title).toLowerCase();
    const passwordFields = form.querySelectorAll('input[type="password"]');
    const visiblePasswordFields = [...passwordFields].filter(f => isVisible(f));
    const hasEmail = !!form.querySelector('input[type="email"], input[name*="email"]');
    const hasUsername = !!form.querySelector(
      'input[type="text"][name*="user"], input[type="text"][name*="name"], input[type="text"][id*="user"]'
    );

    // 2FA form
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
      const signupKeywords = ['sign up', 'signup', 'register', 'create account', 'join', 'get started'];
      if (signupKeywords.some(kw => html.includes(kw))) {
        return FORM_TYPES.SIGNUP;
      }
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
  // Password Generator
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
      return group.split('').sort(() => {
        const a = new Uint32Array(1);
        crypto.getRandomValues(a);
        return a[0] % 2 === 0 ? 1 : -1;
      }).join('');
    }

    return `${generateGroup()}${special}${generateGroup()}${special}${generateGroup()}`;
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

      const newPassword = passwordFields.length >= 3
        ? passwordFields[1].value
        : passwordFields[1].value;

      const usernameField = form.querySelector(
        'input[type="email"], input[type="text"][name*="user"], input[type="text"][name*="email"]'
      );
      const username = usernameField?.value || '';

      if (newPassword) {
        setTimeout(() => {
          UI.showPasswordUpdateBanner(username, newPassword);
        }, 1500);
      }
    }, true);
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
      UI.addTOTPButton(field);
    });
  }

  // ============================================================================
  // Passkey/WebAuthn Awareness
  // ============================================================================

  function setupPasskeyDetection() {
    if (window.PublicKeyCredential) {
      const originalCreate = navigator.credentials.create;
      if (originalCreate) {
        navigator.credentials.create = async function(...args) {
          const result = await originalCreate.apply(this, args);
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
      const usernameField = form.querySelector(
        'input[type="email"], input[type="text"][name*="user"], ' +
        'input[type="text"][name*="email"], input[type="text"][id*="user"]'
      );

      if (!passwordField?.value || !usernameField?.value) return;

      const credentials = {
        domain: window.location.hostname,
        username: usernameField.value,
        password: passwordField.value
      };

      setTimeout(() => {
        const errorIndicators = document.querySelectorAll(
          '.error, .alert-danger, [role="alert"], .login-error, .error-message'
        );
        const hasVisibleError = [...errorIndicators].some(
          el => isVisible(el) && el.textContent.trim().length > 0
        );

        if (!hasVisibleError) {
          showSavePasswordPrompt(credentials);
        }
      }, 2000);
    }, true);
  }

  function showSavePasswordPrompt(credentials) {
    chrome.runtime.sendMessage({
      type: 'getiCloudCredentials',
      data: { domain: credentials.domain }
    }).then(response => {
      if (response?.success) {
        const existing = response.data?.credentials || [];
        const alreadySaved = existing.some(c =>
          c.username === credentials.username && c.password === credentials.password
        );
        if (alreadySaved) return;
      }

      chrome.runtime.sendMessage({
        type: 'saveiCloudCredential',
        data: credentials
      }).then(result => {
        if (result?.success) {
          UI.showToast('Password saved to iCloud Keychain');
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
      if (formType === FORM_TYPES.SIGNUP || formType === FORM_TYPES.CHANGE_PASSWORD) {
        UI.addStrengthMeter(field);
        UI.addPasswordGeneratorButton(field, generateApplePassword);
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
