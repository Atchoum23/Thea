(function() {
  'use strict';

  var THEA_GRADIENT = 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)';
  var UI_Z_INDEX = 2147483635;
  var activeElements = [];

  function injectStyles() {
    if (document.getElementById('thea-password-ui-styles')) return;
    var style = document.createElement('style');
    style.id = 'thea-password-ui-styles';
    style.textContent = [
      '.thea-autofill-dropdown {',
      '  position: absolute; z-index: ' + UI_Z_INDEX + ';',
      '  background: #1e1e2e; border: 1px solid #313244; border-radius: 10px;',
      '  box-shadow: 0 8px 32px rgba(0,0,0,0.4); min-width: 280px; max-width: 360px;',
      '  font-family: -apple-system, BlinkMacSystemFont, sans-serif; overflow: hidden;',
      '}',
      '.thea-autofill-header {',
      '  padding: 10px 14px; font-size: 11px; font-weight: 600;',
      '  color: #6c7086; text-transform: uppercase; letter-spacing: 0.5px;',
      '  border-bottom: 1px solid #313244;',
      '  background: ' + THEA_GRADIENT + '; -webkit-background-clip: text; -webkit-text-fill-color: transparent;',
      '}',
      '.thea-autofill-item {',
      '  padding: 10px 14px; cursor: pointer; display: flex; align-items: center; gap: 10px;',
      '  transition: background 0.15s ease; border-bottom: 1px solid #2a2a3c;',
      '}',
      '.thea-autofill-item:last-child { border-bottom: none; }',
      '.thea-autofill-item:hover { background: #313244; }',
      '.thea-autofill-icon {',
      '  width: 32px; height: 32px; border-radius: 8px; background: #313244;',
      '  display: flex; align-items: center; justify-content: center;',
      '  font-size: 16px; flex-shrink: 0;',
      '}',
      '.thea-autofill-info { flex: 1; min-width: 0; }',
      '.thea-autofill-username { color: #cdd6f4; font-size: 14px; font-weight: 500; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }',
      '.thea-autofill-domain { color: #6c7086; font-size: 12px; }',
      '',
      '.thea-strength-meter {',
      '  margin-top: 4px; height: 4px; border-radius: 2px; background: #313244;',
      '  overflow: hidden; transition: all 0.3s ease;',
      '}',
      '.thea-strength-bar { height: 100%; border-radius: 2px; transition: width 0.3s ease, background 0.3s ease; }',
      '.thea-strength-label { font-size: 11px; margin-top: 2px; font-family: -apple-system, sans-serif; }',
      '',
      '.thea-totp-display {',
      '  position: fixed; bottom: 100px; right: 20px; z-index: ' + UI_Z_INDEX + ';',
      '  background: #1e1e2e; border: 1px solid #313244; border-radius: 12px;',
      '  padding: 16px 24px; box-shadow: 0 8px 32px rgba(0,0,0,0.4);',
      '  font-family: -apple-system, sans-serif; text-align: center;',
      '}',
      '.thea-totp-code { font-size: 32px; font-weight: 700; letter-spacing: 6px; color: #cdd6f4; margin-bottom: 8px; cursor: pointer; }',
      '.thea-totp-timer { font-size: 13px; color: #6c7086; }',
      '.thea-totp-progress { width: 100%; height: 3px; background: #313244; border-radius: 2px; margin-top: 8px; overflow: hidden; }',
      '.thea-totp-progress-bar { height: 100%; background: ' + THEA_GRADIENT + '; transition: width 1s linear; }',
      '',
      '.thea-passkey-prompt {',
      '  position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%);',
      '  z-index: ' + (UI_Z_INDEX + 1) + '; background: #1e1e2e; border-radius: 16px;',
      '  padding: 28px 32px; box-shadow: 0 20px 60px rgba(0,0,0,0.6);',
      '  font-family: -apple-system, sans-serif; text-align: center; min-width: 300px;',
      '}',
      '.thea-passkey-icon { font-size: 48px; margin-bottom: 16px; }',
      '.thea-passkey-title { font-size: 18px; font-weight: 600; color: #cdd6f4; margin-bottom: 8px; }',
      '.thea-passkey-domain { font-size: 14px; color: #6c7086; margin-bottom: 20px; }',
      '.thea-passkey-btn {',
      '  padding: 10px 24px; border: none; border-radius: 8px; cursor: pointer;',
      '  font-size: 14px; font-weight: 600; margin: 0 6px;',
      '}',
      '.thea-passkey-btn-primary { background: ' + THEA_GRADIENT + '; color: #fff; }',
      '.thea-passkey-btn-secondary { background: #313244; color: #cdd6f4; }',
      '',
      '.thea-pw-change-banner {',
      '  position: fixed; top: 16px; left: 50%; transform: translateX(-50%);',
      '  z-index: ' + UI_Z_INDEX + '; background: #1e1e2e; border: 1px solid #313244;',
      '  border-radius: 12px; padding: 12px 20px; box-shadow: 0 8px 32px rgba(0,0,0,0.4);',
      '  font-family: -apple-system, sans-serif; display: flex; align-items: center; gap: 12px;',
      '}',
      '.thea-pw-change-text { color: #cdd6f4; font-size: 14px; }',
      '.thea-pw-change-btn { padding: 6px 16px; border: none; border-radius: 6px; cursor: pointer; font-size: 13px; font-weight: 600; }',
      '',
      '.thea-generate-btn {',
      '  position: absolute; right: 4px; top: 50%; transform: translateY(-50%);',
      '  z-index: ' + UI_Z_INDEX + '; background: none; border: none;',
      '  cursor: pointer; font-size: 18px; padding: 4px 8px; border-radius: 4px;',
      '  color: #667eea; transition: background 0.15s ease;',
      '}',
      '.thea-generate-btn:hover { background: rgba(102, 126, 234, 0.15); }'
    ].join('\n');
    document.head.appendChild(style);
  }

  function createAutofillDropdown(field, credentials) {
    injectStyles();
    removeAllUI();

    var rect = field.getBoundingClientRect();
    var dropdown = document.createElement('div');
    dropdown.className = 'thea-autofill-dropdown';
    dropdown.style.top = (rect.bottom + window.scrollY + 4) + 'px';
    dropdown.style.left = (rect.left + window.scrollX) + 'px';

    var header = document.createElement('div');
    header.className = 'thea-autofill-header';
    header.textContent = 'Thea Passwords';
    dropdown.appendChild(header);

    credentials.forEach(function(cred) {
      var item = document.createElement('div');
      item.className = 'thea-autofill-item';
      item.innerHTML =
        '<div class="thea-autofill-icon">\uD83D\uDD11</div>' +
        '<div class="thea-autofill-info">' +
        '  <div class="thea-autofill-username">' + escapeHtml(cred.username) + '</div>' +
        '  <div class="thea-autofill-domain">' + escapeHtml(cred.domain) + '</div>' +
        '</div>';
      item.addEventListener('click', function() {
        var enhancer = window.TheaModules.PasswordEnhancer;
        if (enhancer) enhancer.fillCredentials(cred.username, cred.password);
        removeAllUI();
      });
      dropdown.appendChild(item);
    });

    document.body.appendChild(dropdown);
    activeElements.push(dropdown);

    document.addEventListener('click', function handler(e) {
      if (!dropdown.contains(e.target) && e.target !== field) {
        removeAllUI();
        document.removeEventListener('click', handler);
      }
    });

    return dropdown;
  }

  function createStrengthMeter(passwordField) {
    injectStyles();
    var container = document.createElement('div');
    container.style.cssText = 'width: 100%; max-width: ' + passwordField.offsetWidth + 'px;';

    var meter = document.createElement('div');
    meter.className = 'thea-strength-meter';
    var bar = document.createElement('div');
    bar.className = 'thea-strength-bar';
    bar.style.width = '0%';
    meter.appendChild(bar);

    var label = document.createElement('div');
    label.className = 'thea-strength-label';

    container.appendChild(meter);
    container.appendChild(label);

    passwordField.parentNode.insertBefore(container, passwordField.nextSibling);
    activeElements.push(container);

    passwordField.addEventListener('input', function() {
      var strength = evaluateStrength(passwordField.value);
      bar.style.width = strength.percent + '%';
      bar.style.background = strength.color;
      label.textContent = strength.label;
      label.style.color = strength.color;
    });

    return container;
  }

  function evaluateStrength(password) {
    if (!password) return { percent: 0, color: '#6c7086', label: '' };
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;
    if (/[a-z]/.test(password) && /[A-Z]/.test(password)) score++;
    if (/\d/.test(password)) score++;
    if (/[^a-zA-Z0-9]/.test(password)) score++;
    if (password.length >= 20) score++;

    var levels = [
      { max: 2, percent: 20, color: '#f38ba8', label: 'Weak' },
      { max: 4, percent: 50, color: '#fab387', label: 'Fair' },
      { max: 5, percent: 75, color: '#a6e3a1', label: 'Good' },
      { max: Infinity, percent: 100, color: '#94e2d5', label: 'Strong' }
    ];
    for (var i = 0; i < levels.length; i++) {
      if (score <= levels[i].max) return levels[i];
    }
    return levels[levels.length - 1];
  }

  function createTOTPDisplay(code, timeRemaining) {
    injectStyles();
    var display = document.createElement('div');
    display.className = 'thea-totp-display';

    var codeEl = document.createElement('div');
    codeEl.className = 'thea-totp-code';
    codeEl.textContent = formatTOTP(code);
    codeEl.title = 'Click to copy';
    codeEl.addEventListener('click', function() {
      navigator.clipboard.writeText(code).then(function() {
        var notify = window.TheaModules.Notification;
        if (notify) notify.showNotification('Copied', 'TOTP code copied to clipboard', 2000);
      });
    });

    var timer = document.createElement('div');
    timer.className = 'thea-totp-timer';
    timer.textContent = timeRemaining + 's remaining';

    var progress = document.createElement('div');
    progress.className = 'thea-totp-progress';
    var progressBar = document.createElement('div');
    progressBar.className = 'thea-totp-progress-bar';
    progressBar.style.width = (timeRemaining / 30 * 100) + '%';
    progress.appendChild(progressBar);

    display.appendChild(codeEl);
    display.appendChild(timer);
    display.appendChild(progress);
    document.body.appendChild(display);
    activeElements.push(display);

    return display;
  }

  function createPasskeyPrompt(domain) {
    injectStyles();
    var prompt = document.createElement('div');
    prompt.className = 'thea-passkey-prompt';
    prompt.innerHTML =
      '<div class="thea-passkey-icon">\uD83D\uDD10</div>' +
      '<div class="thea-passkey-title">Sign in with Passkey</div>' +
      '<div class="thea-passkey-domain">' + escapeHtml(domain) + '</div>' +
      '<div>' +
      '  <button class="thea-passkey-btn thea-passkey-btn-primary" data-action="confirm">Continue</button>' +
      '  <button class="thea-passkey-btn thea-passkey-btn-secondary" data-action="cancel">Cancel</button>' +
      '</div>';
    document.body.appendChild(prompt);
    activeElements.push(prompt);
    return prompt;
  }

  function createPasswordChangeDetector() {
    injectStyles();
    var banner = document.createElement('div');
    banner.className = 'thea-pw-change-banner';
    banner.innerHTML =
      '<div class="thea-pw-change-text">Password changed. Update saved password?</div>' +
      '<button class="thea-pw-change-btn" style="background: ' + THEA_GRADIENT + '; color: #fff;" data-action="update">Update</button>' +
      '<button class="thea-pw-change-btn" style="background: #313244; color: #cdd6f4;" data-action="dismiss">Dismiss</button>';
    document.body.appendChild(banner);
    activeElements.push(banner);
    return banner;
  }

  function createGeneratePasswordButton(field) {
    injectStyles();
    var wrapper = field.parentElement;
    if (wrapper) wrapper.style.position = 'relative';

    var btn = document.createElement('button');
    btn.className = 'thea-generate-btn';
    btn.type = 'button';
    btn.textContent = '\uD83C\uDFB2';
    btn.title = 'Generate strong password';
    btn.addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      var enhancer = window.TheaModules.PasswordEnhancer;
      if (enhancer) enhancer.generatePassword();
    });

    if (wrapper) {
      wrapper.appendChild(btn);
    } else {
      field.insertAdjacentElement('afterend', btn);
    }
    activeElements.push(btn);
    return btn;
  }

  function removeAllUI() {
    activeElements.forEach(function(el) {
      if (el && el.parentNode) el.parentNode.removeChild(el);
    });
    activeElements = [];
  }

  function formatTOTP(code) {
    if (!code) return '';
    var s = String(code);
    if (s.length === 6) return s.slice(0, 3) + ' ' + s.slice(3);
    return s;
  }

  function escapeHtml(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.PasswordEnhancerUI = {
    createAutofillDropdown: createAutofillDropdown,
    createStrengthMeter: createStrengthMeter,
    createTOTPDisplay: createTOTPDisplay,
    createPasskeyPrompt: createPasskeyPrompt,
    createPasswordChangeDetector: createPasswordChangeDetector,
    createGeneratePasswordButton: createGeneratePasswordButton,
    removeAllUI: removeAllUI
  };
})();
