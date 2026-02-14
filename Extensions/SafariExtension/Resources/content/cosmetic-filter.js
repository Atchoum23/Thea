(function() {
  'use strict';

  var STYLE_ID = 'thea-cosmetic-filter-styles';
  var CUSTOM_STYLE_ID = 'thea-cosmetic-filter-custom';
  var PICKER_CLASS = 'thea-element-picker-active';
  var enabled = false;
  var pickerActive = false;
  var pickerHighlight = null;
  var observer = null;

  function init() {
    var rules = window.TheaModules.CosmeticFilterRules;
    if (!rules) return;

    enabled = true;
    applyRules(rules.GENERIC_SELECTORS);
    applySiteSpecificRules();
    loadAndApplyCustomRules();
    observeDom();
  }

  function applyRules(selectors) {
    if (!selectors || selectors.length === 0) return;

    var existing = document.getElementById(STYLE_ID);
    var existingCSS = existing ? existing.textContent : '';

    var css = selectors.map(function(sel) {
      return sel + ' { display: none !important; visibility: hidden !important; height: 0 !important; overflow: hidden !important; }';
    }).join('\n');

    if (existing) {
      existing.textContent = existingCSS + '\n' + css;
    } else {
      var style = document.createElement('style');
      style.id = STYLE_ID;
      style.textContent = '/* Thea Cosmetic Filter */\n' + css;
      document.head.appendChild(style);
    }
  }

  function applySiteSpecificRules() {
    var rules = window.TheaModules.CosmeticFilterRules;
    if (!rules || !rules.SITE_SPECIFIC) return;

    var hostname = window.location.hostname;
    Object.keys(rules.SITE_SPECIFIC).forEach(function(domain) {
      if (hostname === domain || hostname.endsWith('.' + domain)) {
        applyRules(rules.SITE_SPECIFIC[domain]);
      }
    });
  }

  function removeRules() {
    var el = document.getElementById(STYLE_ID);
    if (el) el.parentNode.removeChild(el);
    var custom = document.getElementById(CUSTOM_STYLE_ID);
    if (custom) custom.parentNode.removeChild(custom);
    enabled = false;
  }

  function startElementPicker() {
    if (pickerActive) return;
    pickerActive = true;
    document.body.classList.add(PICKER_CLASS);

    injectPickerStyles();

    document.addEventListener('mouseover', onPickerMouseOver, true);
    document.addEventListener('mouseout', onPickerMouseOut, true);
    document.addEventListener('click', onPickerClick, true);
    document.addEventListener('keydown', onPickerKeydown, true);

    var notify = window.TheaModules.Notification;
    if (notify) {
      notify.showNotification(
        'Element Picker',
        'Click any element to hide it. Press Escape to cancel.',
        0
      );
    }
  }

  function stopElementPicker() {
    pickerActive = false;
    document.body.classList.remove(PICKER_CLASS);

    document.removeEventListener('mouseover', onPickerMouseOver, true);
    document.removeEventListener('mouseout', onPickerMouseOut, true);
    document.removeEventListener('click', onPickerClick, true);
    document.removeEventListener('keydown', onPickerKeydown, true);

    removeHighlight();

    var notify = window.TheaModules.Notification;
    if (notify) notify.hideAllNotifications();
  }

  function onPickerMouseOver(e) {
    if (!pickerActive) return;
    var el = e.target;
    if (el === document.body || el === document.documentElement) return;
    if (el.classList && (el.className.indexOf('thea-') !== -1)) return;

    removeHighlight();
    pickerHighlight = document.createElement('div');
    pickerHighlight.className = 'thea-picker-highlight';
    var rect = el.getBoundingClientRect();
    pickerHighlight.style.cssText = [
      'position: fixed',
      'top: ' + rect.top + 'px',
      'left: ' + rect.left + 'px',
      'width: ' + rect.width + 'px',
      'height: ' + rect.height + 'px',
      'z-index: 2147483645',
      'pointer-events: none',
      'border: 2px solid #ff4444',
      'background: rgba(255, 0, 0, 0.1)',
      'box-sizing: border-box',
      'transition: all 0.1s ease'
    ].join('; ');

    var label = document.createElement('div');
    label.className = 'thea-picker-label';
    label.textContent = generateSelector(el);
    label.style.cssText = [
      'position: absolute', 'bottom: -24px', 'left: 0',
      'background: #1e1e2e', 'color: #cdd6f4', 'font-size: 11px',
      'padding: 2px 8px', 'border-radius: 4px', 'white-space: nowrap',
      'font-family: monospace', 'max-width: 300px', 'overflow: hidden',
      'text-overflow: ellipsis'
    ].join('; ');
    pickerHighlight.appendChild(label);
    document.body.appendChild(pickerHighlight);
  }

  function onPickerMouseOut() {
    removeHighlight();
  }

  function onPickerClick(e) {
    if (!pickerActive) return;
    e.preventDefault();
    e.stopPropagation();

    var el = e.target;
    if (el.classList && (el.className.indexOf('thea-') !== -1)) return;

    var selector = generateSelector(el);
    var domain = window.location.hostname;

    addCustomRule(domain, selector);
    el.style.display = 'none';

    var notify = window.TheaModules.Notification;
    if (notify) {
      notify.showNotification('Element Hidden', 'Rule saved: ' + selector, 3000);
    }
  }

  function onPickerKeydown(e) {
    if (e.key === 'Escape') {
      stopElementPicker();
    }
  }

  function removeHighlight() {
    if (pickerHighlight && pickerHighlight.parentNode) {
      pickerHighlight.parentNode.removeChild(pickerHighlight);
    }
    pickerHighlight = null;
  }

  function generateSelector(el) {
    if (el.id) return '#' + CSS.escape(el.id);

    var selector = el.tagName.toLowerCase();
    if (el.classList.length > 0) {
      var classes = Array.from(el.classList)
        .filter(function(c) { return c.indexOf('thea-') === -1; })
        .slice(0, 3);
      if (classes.length > 0) {
        selector += '.' + classes.map(CSS.escape).join('.');
      }
    }

    var parent = el.parentElement;
    if (parent && parent !== document.body && parent !== document.documentElement) {
      var parentSel = parent.id ? '#' + CSS.escape(parent.id) : parent.tagName.toLowerCase();
      selector = parentSel + ' > ' + selector;
    }

    return selector;
  }

  function addCustomRule(domain, selector) {
    browser.storage.local.get(['cosmeticCustomRules']).then(function(data) {
      var rules = data.cosmeticCustomRules || {};
      if (!rules[domain]) rules[domain] = [];
      if (rules[domain].indexOf(selector) === -1) {
        rules[domain].push(selector);
      }
      browser.storage.local.set({ cosmeticCustomRules: rules });
      applyCustomRules(rules[domain]);
    }).catch(function() {});
  }

  function removeCustomRule(domain, selector) {
    browser.storage.local.get(['cosmeticCustomRules']).then(function(data) {
      var rules = data.cosmeticCustomRules || {};
      if (!rules[domain]) return;
      var idx = rules[domain].indexOf(selector);
      if (idx > -1) {
        rules[domain].splice(idx, 1);
        browser.storage.local.set({ cosmeticCustomRules: rules });
        reloadCustomRules(domain);
      }
    }).catch(function() {});
  }

  function getCustomRules(domain) {
    return browser.storage.local.get(['cosmeticCustomRules']).then(function(data) {
      var rules = data.cosmeticCustomRules || {};
      return rules[domain] || [];
    }).catch(function() { return []; });
  }

  function loadAndApplyCustomRules() {
    var domain = window.location.hostname;
    getCustomRules(domain).then(function(rules) {
      if (rules.length > 0) applyCustomRules(rules);
    });
  }

  function applyCustomRules(selectors) {
    var existing = document.getElementById(CUSTOM_STYLE_ID);
    if (existing) existing.parentNode.removeChild(existing);

    var css = selectors.map(function(sel) {
      return sel + ' { display: none !important; }';
    }).join('\n');

    var style = document.createElement('style');
    style.id = CUSTOM_STYLE_ID;
    style.textContent = '/* Thea Custom Cosmetic Rules */\n' + css;
    document.head.appendChild(style);
  }

  function reloadCustomRules(domain) {
    getCustomRules(domain).then(function(rules) {
      var existing = document.getElementById(CUSTOM_STYLE_ID);
      if (existing) existing.parentNode.removeChild(existing);
      if (rules.length > 0) applyCustomRules(rules);
    });
  }

  function observeDom() {
    if (observer) observer.disconnect();
    observer = new MutationObserver(function() {
      // Re-check: some sites re-inject ad elements after removal
      // The CSS rules handle this automatically since they persist
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  function injectPickerStyles() {
    if (document.getElementById('thea-picker-styles')) return;
    var style = document.createElement('style');
    style.id = 'thea-picker-styles';
    style.textContent = [
      '.' + PICKER_CLASS + ' { cursor: crosshair !important; }',
      '.' + PICKER_CLASS + ' * { cursor: crosshair !important; }'
    ].join('\n');
    document.head.appendChild(style);
  }

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.CosmeticFilter = {
    init: init,
    applyRules: applyRules,
    removeRules: removeRules,
    startElementPicker: startElementPicker,
    stopElementPicker: stopElementPicker,
    addCustomRule: addCustomRule,
    removeCustomRule: removeCustomRule,
    getCustomRules: getCustomRules,
    isEnabled: function() { return enabled; }
  };
})();
