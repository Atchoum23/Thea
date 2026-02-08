/**
 * iCloud Autofill TOTP & Password Utilities Module
 *
 * TOTP code display, passkey authentication prompts,
 * password change detection, strength meter,
 * and save-password banner (Safari-style).
 *
 * Depends on icloudUI (icloud-autofill-ui.js).
 */

(function() {
  'use strict';

  window.TheaModules = window.TheaModules || {};

  const ui = () => window.TheaModules.icloudUI;

  // ============================================================================
  // Styles (banner, TOTP, passkey, strength meter)
  // ============================================================================

  const TOTP_STYLES = `
    .thea-save-password-banner {
      position: fixed; top: 0; left: 0; right: 0;
      background: linear-gradient(180deg, #f8f8f8 0%, #f0f0f0 100%);
      border-bottom: 1px solid #d1d1d6; padding: 12px 16px;
      display: flex; align-items: center; gap: 12px; z-index: 2147483647;
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', sans-serif;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1); animation: thea-banner-slide 0.2s ease-out;
    }
    @keyframes thea-banner-slide { from { transform: translateY(-100%); } to { transform: translateY(0); } }
    .thea-save-password-banner-icon {
      width: 40px; height: 40px; background: linear-gradient(180deg, #007AFF 0%, #0056CC 100%);
      border-radius: 8px; display: flex; align-items: center; justify-content: center; flex-shrink: 0;
    }
    .thea-save-password-banner-icon svg { width: 24px; height: 24px; color: white; }
    .thea-save-password-banner-content { flex: 1; }
    .thea-save-password-banner-title { font-weight: 600; font-size: 14px; color: #1d1d1f; }
    .thea-save-password-banner-subtitle { font-size: 12px; color: #8e8e93; margin-top: 2px; }
    .thea-save-password-banner-actions { display: flex; gap: 8px; }
    .thea-save-password-banner-actions button {
      padding: 8px 16px; border: none; border-radius: 6px; font-size: 13px; font-weight: 500; cursor: pointer;
    }
    .thea-save-password-banner-actions button.save { background: #007AFF; color: white; }
    .thea-save-password-banner-actions button.never { background: #e5e5ea; color: #1d1d1f; }
    .thea-totp-display {
      position: fixed; bottom: 80px; right: 20px; background: #ffffff;
      border-radius: 12px; box-shadow: 0 4px 24px rgba(0,0,0,0.15), 0 0 0 1px rgba(0,0,0,0.05);
      z-index: 2147483647; padding: 16px 20px;
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
      animation: thea-popup-appear 0.15s ease-out; min-width: 220px;
    }
    .thea-totp-header { display: flex; align-items: center; gap: 8px; margin-bottom: 12px; }
    .thea-totp-header svg { width: 18px; height: 18px; color: #007AFF; }
    .thea-totp-header span { font-size: 12px; font-weight: 500; color: #8e8e93; }
    .thea-totp-code {
      font-size: 32px; font-weight: 700; letter-spacing: 6px; color: #1d1d1f;
      text-align: center; font-variant-numeric: tabular-nums;
    }
    .thea-totp-timer { display: flex; align-items: center; justify-content: center; gap: 6px; margin-top: 8px; }
    .thea-totp-timer-bar { flex: 1; height: 4px; background: #e5e5ea; border-radius: 2px; overflow: hidden; }
    .thea-totp-timer-fill { height: 100%; background: #007AFF; border-radius: 2px; transition: width 1s linear; }
    .thea-totp-timer-text { font-size: 11px; color: #8e8e93; min-width: 24px; text-align: right; }
    .thea-totp-copy {
      display: block; width: 100%; margin-top: 10px; padding: 6px; background: #f0f0f0;
      border: none; border-radius: 6px; font-size: 12px; font-weight: 500; color: #007AFF;
      cursor: pointer; text-align: center;
    }
    .thea-totp-copy:hover { background: #e5e5ea; }
    .thea-passkey-overlay {
      position: fixed; inset: 0; background: rgba(0,0,0,0.4); backdrop-filter: blur(4px);
      z-index: 2147483647; display: flex; align-items: center; justify-content: center;
      animation: thea-fade-in 0.15s ease-out;
    }
    @keyframes thea-fade-in { from { opacity: 0; } to { opacity: 1; } }
    .thea-passkey-dialog {
      background: #ffffff; border-radius: 14px; padding: 28px 24px;
      box-shadow: 0 8px 40px rgba(0,0,0,0.25);
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif;
      text-align: center; max-width: 340px; width: 90%;
    }
    .thea-passkey-icon {
      width: 56px; height: 56px; margin: 0 auto 16px;
      background: linear-gradient(180deg, #007AFF 0%, #0056CC 100%); border-radius: 14px;
      display: flex; align-items: center; justify-content: center;
    }
    .thea-passkey-icon svg { width: 28px; height: 28px; color: white; }
    .thea-passkey-title { font-size: 17px; font-weight: 600; color: #1d1d1f; margin-bottom: 6px; }
    .thea-passkey-subtitle { font-size: 13px; color: #8e8e93; margin-bottom: 20px; line-height: 1.4; }
    .thea-passkey-actions { display: flex; flex-direction: column; gap: 8px; }
    .thea-passkey-actions button {
      padding: 12px; border: none; border-radius: 10px; font-size: 15px; font-weight: 500; cursor: pointer;
    }
    .thea-passkey-actions button.primary { background: #007AFF; color: white; }
    .thea-passkey-actions button.secondary { background: #f0f0f0; color: #1d1d1f; }
    .thea-strength-meter { margin-top: 6px; font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif; }
    .thea-strength-bar { height: 4px; background: #e5e5ea; border-radius: 2px; overflow: hidden; margin-bottom: 4px; }
    .thea-strength-fill { height: 100%; border-radius: 2px; transition: width 0.3s ease, background 0.3s ease; }
    .thea-strength-label { font-size: 11px; font-weight: 500; }
    @media (prefers-color-scheme: dark) {
      .thea-save-password-banner { background: linear-gradient(180deg, #2c2c2e 0%, #1c1c1e 100%); border-color: #3a3a3c; }
      .thea-save-password-banner-title { color: #f5f5f7; }
      .thea-totp-display { background: #2c2c2e; }
      .thea-totp-code { color: #f5f5f7; }
      .thea-totp-copy { background: #3a3a3c; }
      .thea-passkey-dialog { background: #2c2c2e; }
      .thea-passkey-title { color: #f5f5f7; }
    }
  `;

  // ============================================================================
  // State
  // ============================================================================

  let currentBanner = null;
  let currentTOTPDisplay = null;
  let totpInterval = null;
  let passwordChangeObserver = null;

  // ============================================================================
  // Save Password Banner (Safari-style)
  // ============================================================================

  function showSavePasswordBanner(username, password, domain) {
    closeSavePasswordBanner();

    const escapeHtml = ui().escapeHtml;
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
        ui().showNotification('Password saved to iCloud Keychain');
      } catch (e) {
        ui().showNotification('Failed to save password');
      }
      closeSavePasswordBanner();
    });

    document.body.appendChild(banner);
    currentBanner = banner;
    setTimeout(closeSavePasswordBanner, 30000);
  }

  function closeSavePasswordBanner() {
    if (currentBanner) { currentBanner.remove(); currentBanner = null; }
  }

  // ============================================================================
  // TOTP Code Display
  // ============================================================================

  function showTOTPCode(code, remainingSeconds, totalSeconds) {
    closeTOTPDisplay();

    const formatted = code.length === 6 ? `${code.slice(0, 3)} ${code.slice(3)}` : code;
    const display = document.createElement('div');
    display.className = 'thea-totp-display';
    display.innerHTML = `
      <div class="thea-totp-header">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
        </svg>
        <span>Verification Code</span>
      </div>
      <div class="thea-totp-code">${formatted}</div>
      <div class="thea-totp-timer">
        <div class="thea-totp-timer-bar">
          <div class="thea-totp-timer-fill" style="width: ${(remainingSeconds / totalSeconds) * 100}%"></div>
        </div>
        <span class="thea-totp-timer-text">${remainingSeconds}s</span>
      </div>
      <button class="thea-totp-copy">Copy Code</button>
    `;

    display.querySelector('.thea-totp-copy').addEventListener('click', () => {
      navigator.clipboard.writeText(code).then(() => {
        const btn = display.querySelector('.thea-totp-copy');
        btn.textContent = 'Copied!';
        setTimeout(() => { btn.textContent = 'Copy Code'; }, 1500);
      });
    });

    document.body.appendChild(display);
    currentTOTPDisplay = display;

    let remaining = remainingSeconds;
    const fill = display.querySelector('.thea-totp-timer-fill');
    const text = display.querySelector('.thea-totp-timer-text');

    totpInterval = setInterval(() => {
      remaining -= 1;
      if (remaining <= 0) { closeTOTPDisplay(); refreshTOTPCode(); return; }
      fill.style.width = `${(remaining / totalSeconds) * 100}%`;
      text.textContent = `${remaining}s`;
      if (remaining <= 5) { fill.style.background = '#FF3B30'; }
    }, 1000);

    setTimeout(closeTOTPDisplay, (remainingSeconds + 2) * 1000);
  }

  function closeTOTPDisplay() {
    if (totpInterval) { clearInterval(totpInterval); totpInterval = null; }
    if (currentTOTPDisplay) { currentTOTPDisplay.remove(); currentTOTPDisplay = null; }
  }

  async function refreshTOTPCode() {
    try {
      const response = await chrome.runtime.sendMessage({
        type: 'getTOTPCode', data: { domain: window.location.hostname }
      });
      if (response.success && response.data) {
        showTOTPCode(response.data.code, response.data.remaining, response.data.period || 30);
      }
    } catch (e) {
      console.error('Failed to refresh TOTP code:', e);
    }
  }

  function autofillTOTPCode(code) {
    const selectors = [
      'input[autocomplete="one-time-code"]',
      'input[name*="otp"]', 'input[name*="totp"]', 'input[name*="code"]',
      'input[name*="token"]', 'input[name*="2fa"]', 'input[name*="mfa"]',
      'input[type="tel"][maxlength="6"]', 'input[type="number"][maxlength="6"]',
      'input[inputmode="numeric"][maxlength="6"]'
    ];

    let target = document.activeElement;
    if (!target || target.tagName !== 'INPUT') {
      for (const sel of selectors) { target = document.querySelector(sel); if (target) break; }
    }
    if (target) {
      target.value = code;
      target.dispatchEvent(new Event('input', { bubbles: true }));
      target.dispatchEvent(new Event('change', { bubbles: true }));
      ui().showNotification('Verification code filled', 'success');
    }
  }

  // ============================================================================
  // Passkey Authentication Prompt
  // ============================================================================

  function showPasskeyPrompt(domain, options = {}) {
    const overlay = document.createElement('div');
    overlay.className = 'thea-passkey-overlay';

    const displayName = options.displayName || domain;
    const verb = options.isRegistration ? 'Create' : 'Sign in with';

    overlay.innerHTML = `
      <div class="thea-passkey-dialog">
        <div class="thea-passkey-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 11c0 1.66-1.34 3-3 3s-3-1.34-3-3 1.34-3 3-3 3 1.34 3 3z"/>
            <path d="M9 14c-3.31 0-6 1.34-6 3v2h12v-2c0-1.66-2.69-3-6-3z"/>
            <path d="M17 8l2 2 4-4"/>
          </svg>
        </div>
        <div class="thea-passkey-title">${verb} a passkey</div>
        <div class="thea-passkey-subtitle">
          ${ui().escapeHtml(displayName)} supports passkeys for secure,
          passwordless sign-in using iCloud Keychain.
        </div>
        <div class="thea-passkey-actions">
          <button class="primary" data-action="continue">Continue with Passkey</button>
          <button class="secondary" data-action="cancel">Use Password Instead</button>
        </div>
      </div>
    `;

    overlay.querySelector('[data-action="continue"]').addEventListener('click', async () => {
      overlay.remove();
      try {
        await chrome.runtime.sendMessage({ type: 'authenticatePasskey', data: { domain, ...options } });
      } catch (e) {
        console.error('Passkey authentication failed:', e);
        ui().showNotification('Passkey authentication failed');
      }
    });

    overlay.querySelector('[data-action="cancel"]').addEventListener('click', () => overlay.remove());
    overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });

    document.body.appendChild(overlay);
    return overlay;
  }

  // ============================================================================
  // Password Change Detection
  // ============================================================================

  function observePasswordChanges() {
    if (passwordChangeObserver) return;

    passwordChangeObserver = new MutationObserver(() => detectPasswordChangeForm());
    passwordChangeObserver.observe(document.body, { childList: true, subtree: true });
    detectPasswordChangeForm();
  }

  function detectPasswordChangeForm() {
    const passwordInputs = document.querySelectorAll('input[type="password"]');
    if (passwordInputs.length < 2) return;

    const labels = Array.from(passwordInputs).map(input => {
      const label = input.labels?.[0]?.textContent?.toLowerCase() || '';
      const placeholder = (input.placeholder || '').toLowerCase();
      const name = (input.name || '').toLowerCase();
      return label + ' ' + placeholder + ' ' + name;
    });

    const hasCurrent = labels.some(l => l.includes('current') || l.includes('old') || l.includes('existing'));
    const hasNew = labels.some(l => l.includes('new') || l.includes('confirm') || l.includes('retype'));

    if (hasCurrent && hasNew) attachPasswordChangeListeners(passwordInputs);
  }

  function attachPasswordChangeListeners(inputs) {
    const newPwdInput = Array.from(inputs).find(input => {
      const combined = [
        input.labels?.[0]?.textContent, input.name, input.placeholder
      ].map(s => (s || '').toLowerCase()).join(' ');
      return combined.includes('new') && !combined.includes('confirm');
    });

    if (!newPwdInput || newPwdInput.dataset.theaStrengthAttached) return;
    newPwdInput.dataset.theaStrengthAttached = 'true';

    const meter = createStrengthMeter();
    newPwdInput.parentElement?.appendChild(meter);
    newPwdInput.addEventListener('input', () => updateStrengthMeter(meter, newPwdInput.value));

    const form = newPwdInput.closest('form');
    if (form) {
      form.addEventListener('submit', () => {
        const usernameField = form.querySelector(
          'input[type="email"], input[type="text"][autocomplete*="user"], input[name*="user"], input[name*="email"]'
        );
        if (newPwdInput.value) {
          setTimeout(() => {
            showSavePasswordBanner(usernameField?.value || '', newPwdInput.value, window.location.hostname);
          }, 500);
        }
      });
    }
  }

  // ============================================================================
  // Password Strength Meter
  // ============================================================================

  function createStrengthMeter() {
    const el = document.createElement('div');
    el.className = 'thea-strength-meter';
    el.innerHTML = `
      <div class="thea-strength-bar"><div class="thea-strength-fill" style="width:0%"></div></div>
      <span class="thea-strength-label"></span>
    `;
    return el;
  }

  function evaluateStrength(password) {
    let score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;
    if (/[a-z]/.test(password) && /[A-Z]/.test(password)) score++;
    if (/\d/.test(password)) score++;
    if (/[^a-zA-Z0-9]/.test(password)) score++;
    if (!/(.)\1{2,}/.test(password)) score++;
    if (!/^(123|abc|qwerty|password)/i.test(password)) score++;

    if (score <= 2) return { level: 'weak', percent: 25, color: '#FF3B30', label: 'Weak' };
    if (score <= 4) return { level: 'fair', percent: 50, color: '#FF9500', label: 'Fair' };
    if (score <= 6) return { level: 'good', percent: 75, color: '#34C759', label: 'Good' };
    return { level: 'strong', percent: 100, color: '#007AFF', label: 'Strong' };
  }

  function updateStrengthMeter(meter, password) {
    const fill = meter.querySelector('.thea-strength-fill');
    const label = meter.querySelector('.thea-strength-label');
    if (!password) { fill.style.width = '0%'; label.textContent = ''; return; }

    const result = evaluateStrength(password);
    fill.style.width = `${result.percent}%`;
    fill.style.background = result.color;
    label.textContent = result.label;
    label.style.color = result.color;
  }

  // ============================================================================
  // Initialization
  // ============================================================================

  function init() {
    const styleEl = document.createElement('style');
    styleEl.id = 'thea-icloud-totp-styles';
    styleEl.textContent = TOTP_STYLES;
    document.head.appendChild(styleEl);

    observePasswordChanges();

    chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
      if (!sender.id || sender.id !== chrome.runtime.id) return;
      switch (message.type) {
        case 'showTOTPCode':
          if (message.data) showTOTPCode(message.data.code, message.data.remaining, message.data.period || 30);
          sendResponse({ success: true });
          break;
        case 'autofillTOTP':
          if (message.data?.code) autofillTOTPCode(message.data.code);
          sendResponse({ success: true });
          break;
        case 'showPasskeyPrompt':
          showPasskeyPrompt(message.data?.domain || window.location.hostname, message.data || {});
          sendResponse({ success: true });
          break;
        default: return;
      }
      return true;
    });
  }

  // ============================================================================
  // Export to shared namespace
  // ============================================================================

  window.TheaModules.icloudTOTP = {
    showSavePasswordBanner,
    closeSavePasswordBanner,
    showTOTPCode,
    closeTOTPDisplay,
    autofillTOTPCode,
    showPasskeyPrompt,
    observePasswordChanges,
    evaluateStrength,
    createStrengthMeter,
    updateStrengthMeter
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
