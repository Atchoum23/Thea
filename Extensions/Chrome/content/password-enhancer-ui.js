/**
 * Thea Password Manager Enhancer - UI Module
 *
 * Autofill dropdown DOM, strength meter, TOTP code display,
 * password update banner, password generator button.
 */

(function() {
  'use strict';

  window.TheaModules = window.TheaModules || {};

  // ============================================================================
  // Utilities
  // ============================================================================

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
    if (/(.)\1{2,}/.test(password)) score -= 1;
    if (/^[a-zA-Z]+$/.test(password)) score -= 1;
    if (/^[0-9]+$/.test(password)) score -= 1;

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

    const container = passwordField.parentElement;
    if (container) {
      passwordField.after(label);
      passwordField.after(meter);
    }
  }

  // ============================================================================
  // Password Generator Button
  // ============================================================================

  function addPasswordGeneratorButton(passwordField, generateFn) {
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
      const password = generateFn();
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
  // TOTP Button
  // ============================================================================

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
  // Password Update Banner
  // ============================================================================

  function showPasswordUpdateBanner(username, newPassword) {
    const banner = document.createElement('div');
    banner.className = 'thea-pw-update-banner';
    banner.style.cssText = `
      position: fixed;
      top: 0; left: 0; right: 0;
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

    const dismissBanner = () => {
      banner.style.transform = 'translateY(-100%)';
      banner.style.transition = 'transform 0.3s';
      setTimeout(() => banner.remove(), 300);
    };

    banner.querySelector('#thea-pw-update-no').addEventListener('click', dismissBanner);

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
        setTimeout(dismissBanner, 1500);
      } catch (err) {
        banner.querySelector('span').textContent = 'Failed to update password';
      }
    });

    // Auto-dismiss after 30s
    setTimeout(() => {
      if (document.body.contains(banner)) dismissBanner();
    }, 30000);

    return banner;
  }

  // ============================================================================
  // Export to shared namespace
  // ============================================================================

  window.TheaModules.passwordUI = {
    escapeHtml,
    showToast,
    calculatePasswordStrength,
    addStrengthMeter,
    addPasswordGeneratorButton,
    addTOTPButton,
    showPasswordUpdateBanner
  };

})();
