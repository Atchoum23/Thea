(function() {
  'use strict';

  var UI = null;
  var observer = null;
  var detectedForms = new WeakSet();
  var currentDomain = window.location.hostname;

  var LOGIN_FIELD_SELECTORS = [
    'input[type="password"]',
    'input[type="email"]',
    'input[name*="user"]', 'input[name*="login"]', 'input[name*="email"]',
    'input[id*="user"]', 'input[id*="login"]', 'input[id*="email"]',
    'input[autocomplete="username"]', 'input[autocomplete="email"]',
    'input[autocomplete="current-password"]', 'input[autocomplete="new-password"]'
  ];

  var SIGNUP_INDICATORS = [
    'input[autocomplete="new-password"]',
    'input[name*="confirm"]', 'input[name*="repeat"]', 'input[name*="verify"]',
    'input[id*="confirm"]', 'input[id*="repeat"]',
    'input[name*="register"]', 'input[name*="signup"]'
  ];

  var PASSWORD_CHANGE_INDICATORS = [
    'input[name*="old_password"]', 'input[name*="current_password"]',
    'input[name*="oldPassword"]', 'input[name*="currentPassword"]',
    'input[autocomplete="current-password"]'
  ];

  function init() {
    UI = window.TheaModules.PasswordEnhancerUI;
    if (!UI) return;

    scanForForms();
    observeForms();
  }

  function scanForForms() {
    var forms = document.querySelectorAll('form');
    forms.forEach(function(form) { analyzeForm(form); });

    var orphanPasswords = document.querySelectorAll('input[type="password"]');
    orphanPasswords.forEach(function(field) {
      var form = field.closest('form');
      if (!form) {
        attachToPasswordField(field);
      }
    });
  }

  function analyzeForm(form) {
    if (detectedForms.has(form)) return;
    detectedForms.add(form);

    var passwordFields = form.querySelectorAll('input[type="password"]');
    if (passwordFields.length === 0) return;

    if (isPasswordChangeForm(form)) {
      handlePasswordChangeForm(form, passwordFields);
    } else if (isSignupForm(form)) {
      handleSignupForm(form, passwordFields);
    } else {
      handleLoginForm(form, passwordFields);
    }
  }

  function isSignupForm(form) {
    for (var i = 0; i < SIGNUP_INDICATORS.length; i++) {
      if (form.querySelector(SIGNUP_INDICATORS[i])) return true;
    }
    var passwordFields = form.querySelectorAll('input[type="password"]');
    if (passwordFields.length >= 2) return true;
    var action = (form.action || '').toLowerCase();
    var id = (form.id || '').toLowerCase();
    return /register|signup|sign.up|create.account|join/.test(action + ' ' + id);
  }

  function isPasswordChangeForm(form) {
    for (var i = 0; i < PASSWORD_CHANGE_INDICATORS.length; i++) {
      if (form.querySelector(PASSWORD_CHANGE_INDICATORS[i])) return true;
    }
    var passwordFields = form.querySelectorAll('input[type="password"]');
    if (passwordFields.length >= 3) return true;
    return false;
  }

  function handleLoginForm(form, passwordFields) {
    var usernameField = detectUsernameField(form);
    var passwordField = passwordFields[0];

    if (usernameField) {
      usernameField.addEventListener('focus', function() {
        requestCredentials(currentDomain).then(function(credentials) {
          if (credentials && credentials.length > 0) {
            UI.createAutofillDropdown(usernameField, credentials);
          }
        });
      });
    }

    if (passwordField) {
      passwordField.addEventListener('focus', function() {
        if (!usernameField || !usernameField.value) {
          requestCredentials(currentDomain).then(function(credentials) {
            if (credentials && credentials.length > 0) {
              UI.createAutofillDropdown(passwordField, credentials);
            }
          });
        }
      });
    }

    form.addEventListener('submit', function() {
      var username = usernameField ? usernameField.value : '';
      var password = passwordField ? passwordField.value : '';
      if (username && password) {
        saveDetectedCredentials(currentDomain, username, password);
      }
    });
  }

  function handleSignupForm(form, passwordFields) {
    var passwordField = passwordFields[0];
    if (passwordField) {
      UI.createStrengthMeter(passwordField);
      UI.createGeneratePasswordButton(passwordField);
    }

    form.addEventListener('submit', function() {
      var usernameField = detectUsernameField(form);
      var username = usernameField ? usernameField.value : '';
      var password = passwordField ? passwordField.value : '';
      if (username && password) {
        saveDetectedCredentials(currentDomain, username, password);
      }
    });
  }

  function handlePasswordChangeForm(form, passwordFields) {
    var newPasswordField = null;
    for (var i = 0; i < passwordFields.length; i++) {
      var auto = passwordFields[i].getAttribute('autocomplete');
      var name = (passwordFields[i].name || '').toLowerCase();
      if (auto === 'new-password' || /new|change/.test(name)) {
        newPasswordField = passwordFields[i];
        break;
      }
    }
    if (!newPasswordField && passwordFields.length >= 2) {
      newPasswordField = passwordFields[1];
    }

    if (newPasswordField) {
      UI.createStrengthMeter(newPasswordField);
      UI.createGeneratePasswordButton(newPasswordField);
    }

    form.addEventListener('submit', function() {
      if (newPasswordField && newPasswordField.value) {
        var banner = UI.createPasswordChangeDetector();
        var updateBtn = banner.querySelector('[data-action="update"]');
        var dismissBtn = banner.querySelector('[data-action="dismiss"]');

        updateBtn.addEventListener('click', function() {
          browser.runtime.sendMessage({
            type: 'updateCredential',
            domain: currentDomain,
            password: newPasswordField.value
          }).catch(function() {});
          if (banner.parentNode) banner.parentNode.removeChild(banner);
        });

        dismissBtn.addEventListener('click', function() {
          if (banner.parentNode) banner.parentNode.removeChild(banner);
        });
      }
    });
  }

  function detectUsernameField(form) {
    var selectors = [
      'input[autocomplete="username"]',
      'input[autocomplete="email"]',
      'input[type="email"]',
      'input[name*="user"]', 'input[name*="login"]', 'input[name*="email"]',
      'input[id*="user"]', 'input[id*="login"]', 'input[id*="email"]',
      'input[type="text"]'
    ];
    for (var i = 0; i < selectors.length; i++) {
      var field = form.querySelector(selectors[i]);
      if (field && field.type !== 'password' && field.type !== 'hidden') {
        return field;
      }
    }
    return null;
  }

  function attachToPasswordField(field) {
    field.addEventListener('focus', function() {
      requestCredentials(currentDomain).then(function(credentials) {
        if (credentials && credentials.length > 0) {
          UI.createAutofillDropdown(field, credentials);
        }
      });
    });
    UI.createGeneratePasswordButton(field);
  }

  function fillCredentials(username, password) {
    var forms = document.querySelectorAll('form');
    for (var i = 0; i < forms.length; i++) {
      var usernameField = detectUsernameField(forms[i]);
      var passwordField = forms[i].querySelector('input[type="password"]');

      if (usernameField && username) {
        setFieldValue(usernameField, username);
      }
      if (passwordField && password) {
        setFieldValue(passwordField, password);
      }
      if (usernameField || passwordField) return;
    }

    var orphanPassword = document.querySelector('input[type="password"]');
    if (orphanPassword && password) {
      setFieldValue(orphanPassword, password);
    }
  }

  function setFieldValue(field, value) {
    var nativeInputValueSetter = Object.getOwnPropertyDescriptor(
      window.HTMLInputElement.prototype, 'value'
    ).set;
    nativeInputValueSetter.call(field, value);
    field.dispatchEvent(new Event('input', { bubbles: true }));
    field.dispatchEvent(new Event('change', { bubbles: true }));
  }

  function requestCredentials(domain) {
    return browser.runtime.sendMessage({
      type: 'getCredentials',
      domain: domain
    }).then(function(response) {
      return response && response.credentials ? response.credentials : [];
    }).catch(function() { return []; });
  }

  function saveDetectedCredentials(domain, username, password) {
    browser.runtime.sendMessage({
      type: 'saveCredential',
      domain: domain,
      username: username,
      password: password
    }).catch(function() {});
  }

  function generatePassword() {
    browser.runtime.sendMessage({
      type: 'generatePassword'
    }).then(function(response) {
      if (response && response.password) {
        var activeField = document.activeElement;
        if (activeField && activeField.type === 'password') {
          setFieldValue(activeField, response.password);
        }
        navigator.clipboard.writeText(response.password).then(function() {
          var notify = window.TheaModules.Notification;
          if (notify) notify.showNotification('Password Generated', 'Strong password generated and copied', 3000);
        });
      }
    }).catch(function() {});
  }

  function handlePasskeyAuth(domain) {
    var prompt = UI.createPasskeyPrompt(domain);
    var confirmBtn = prompt.querySelector('[data-action="confirm"]');
    var cancelBtn = prompt.querySelector('[data-action="cancel"]');

    confirmBtn.addEventListener('click', function() {
      browser.runtime.sendMessage({
        type: 'passkeyAuth',
        domain: domain
      }).catch(function() {});
      if (prompt.parentNode) prompt.parentNode.removeChild(prompt);
    });

    cancelBtn.addEventListener('click', function() {
      if (prompt.parentNode) prompt.parentNode.removeChild(prompt);
    });
  }

  function handleTOTP(domain) {
    browser.runtime.sendMessage({
      type: 'getTOTP',
      domain: domain
    }).then(function(response) {
      if (response && response.code) {
        UI.createTOTPDisplay(response.code, response.timeRemaining || 30);
      }
    }).catch(function() {});
  }

  function observeForms() {
    if (observer) observer.disconnect();
    observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(mutation) {
        mutation.addedNodes.forEach(function(node) {
          if (node.nodeType !== Node.ELEMENT_NODE) return;
          if (node.tagName === 'FORM') {
            analyzeForm(node);
          }
          var nested = node.querySelectorAll ? node.querySelectorAll('form') : [];
          nested.forEach(function(f) { analyzeForm(f); });
          var pwFields = node.querySelectorAll ? node.querySelectorAll('input[type="password"]') : [];
          pwFields.forEach(function(f) {
            if (!f.closest('form')) attachToPasswordField(f);
          });
        });
      });
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.PasswordEnhancer = {
    init: init,
    fillCredentials: fillCredentials,
    generatePassword: generatePassword,
    handlePasskeyAuth: handlePasskeyAuth,
    handleTOTP: handleTOTP
  };
})();
