(function() {
  'use strict';

  var Notify = null;
  var enabled = false;
  var observer = null;
  var attachedFields = new WeakSet();
  var activeSuggestion = null;
  var debounceTimers = new WeakMap();
  var dismissedSuggestions = new Set();

  var DEBOUNCE_DELAY = 500;
  var MIN_TEXT_LENGTH = 20;
  var SUGGESTION_TOOLTIP_ID = 'thea-writing-suggestion';

  var EDITABLE_SELECTORS = [
    'textarea',
    '[contenteditable="true"]',
    '[contenteditable=""]',
    'input[type="text"]',
    'input[type="email"]',
    'input[type="search"]',
    '.ProseMirror',
    '.ql-editor',
    '.CodeMirror',
    '.tox-edit-area__iframe',
    '[role="textbox"]',
    '.DraftEditor-root',
    '.public-DraftEditor-content'
  ];

  function init() {
    Notify = window.TheaModules.Notification;
    enabled = true;
    scanForEditableFields();
    observeEditableFields();
    injectStyles();
  }

  function injectStyles() {
    if (document.getElementById('thea-writing-styles')) return;
    var style = document.createElement('style');
    style.id = 'thea-writing-styles';
    style.textContent = [
      '#' + SUGGESTION_TOOLTIP_ID + ' {',
      '  position: fixed; z-index: 2147483641;',
      '  background: #1e1e2e; border: 1px solid #313244; border-radius: 10px;',
      '  padding: 10px 14px; max-width: 340px; min-width: 200px;',
      '  box-shadow: 0 8px 24px rgba(0,0,0,0.35);',
      '  font-family: -apple-system, BlinkMacSystemFont, sans-serif;',
      '  opacity: 0; transform: translateY(4px); transition: opacity 0.2s, transform 0.2s;',
      '}',
      '#' + SUGGESTION_TOOLTIP_ID + '.thea-visible {',
      '  opacity: 1; transform: translateY(0);',
      '}',
      '.thea-suggestion-header {',
      '  display: flex; align-items: center; justify-content: space-between;',
      '  margin-bottom: 6px;',
      '}',
      '.thea-suggestion-label {',
      '  font-size: 11px; font-weight: 600; color: #667eea;',
      '  text-transform: uppercase; letter-spacing: 0.5px;',
      '}',
      '.thea-suggestion-dismiss {',
      '  background: none; border: none; color: #6c7086; cursor: pointer;',
      '  font-size: 14px; padding: 0 4px; line-height: 1;',
      '}',
      '.thea-suggestion-dismiss:hover { color: #cdd6f4; }',
      '.thea-suggestion-text {',
      '  color: #cdd6f4; font-size: 13px; line-height: 1.5; margin-bottom: 8px;',
      '}',
      '.thea-suggestion-original {',
      '  color: #f38ba8; text-decoration: line-through; font-size: 12px;',
      '  margin-bottom: 4px; opacity: 0.8;',
      '}',
      '.thea-suggestion-replacement {',
      '  color: #a6e3a1; font-size: 12px; margin-bottom: 8px;',
      '}',
      '.thea-suggestion-actions { display: flex; gap: 6px; }',
      '.thea-suggestion-btn {',
      '  padding: 4px 12px; border: none; border-radius: 6px; cursor: pointer;',
      '  font-size: 12px; font-weight: 600; transition: background 0.15s;',
      '}',
      '.thea-suggestion-accept {',
      '  background: linear-gradient(135deg, #667eea, #764ba2); color: #fff;',
      '}',
      '.thea-suggestion-accept:hover { opacity: 0.9; }',
      '.thea-suggestion-skip { background: #313244; color: #cdd6f4; }',
      '.thea-suggestion-skip:hover { background: #45475a; }',
      '',
      '.thea-suggestion-type {',
      '  display: inline-block; font-size: 10px; padding: 1px 6px;',
      '  border-radius: 4px; margin-left: 6px; font-weight: 500;',
      '}',
      '.thea-type-grammar { background: rgba(243, 139, 168, 0.2); color: #f38ba8; }',
      '.thea-type-style { background: rgba(137, 180, 250, 0.2); color: #89b4fa; }',
      '.thea-type-clarity { background: rgba(166, 227, 161, 0.2); color: #a6e3a1; }',
      '.thea-type-tone { background: rgba(203, 166, 247, 0.2); color: #cba6f7; }'
    ].join('\n');
    document.head.appendChild(style);
  }

  function scanForEditableFields() {
    var selector = EDITABLE_SELECTORS.join(', ');
    var fields = document.querySelectorAll(selector);
    fields.forEach(function(field) { attachToField(field); });
  }

  function observeEditableFields() {
    if (observer) observer.disconnect();
    observer = new MutationObserver(function(mutations) {
      if (!enabled) return;
      var shouldScan = false;
      for (var i = 0; i < mutations.length; i++) {
        if (mutations[i].addedNodes.length > 0) {
          shouldScan = true;
          break;
        }
      }
      if (shouldScan) scanForEditableFields();
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  function attachToField(field) {
    if (attachedFields.has(field)) return;
    if (field.closest('#thea-ai-sidebar')) return;
    if (field.closest('[class*="thea-"]')) return;
    attachedFields.add(field);

    var isContentEditable = field.isContentEditable ||
      field.getAttribute('contenteditable') === 'true' ||
      field.getAttribute('contenteditable') === '';

    var eventName = isContentEditable ? 'input' : 'input';

    field.addEventListener(eventName, function() {
      var existingTimer = debounceTimers.get(field);
      if (existingTimer) clearTimeout(existingTimer);

      var timer = setTimeout(function() {
        var text = isContentEditable ? field.textContent : field.value;
        if (text && text.length >= MIN_TEXT_LENGTH) {
          analyzeText(text, field);
        }
      }, DEBOUNCE_DELAY);

      debounceTimers.set(field, timer);
    });

    field.addEventListener('focus', function() {
      hideSuggestion();
    });
  }

  function analyzeText(text, field) {
    if (!enabled) return;

    var hash = simpleHash(text);
    if (dismissedSuggestions.has(hash)) return;

    browser.runtime.sendMessage({
      type: 'analyzeWriting',
      text: text.substring(0, 2000),
      domain: window.location.hostname,
      fieldType: field.tagName.toLowerCase()
    }).then(function(response) {
      if (response && response.suggestion) {
        showSuggestion(field, response.suggestion);
      }
    }).catch(function() {});
  }

  function showSuggestion(field, suggestion) {
    hideSuggestion();

    var tooltip = document.createElement('div');
    tooltip.id = SUGGESTION_TOOLTIP_ID;

    var typeClass = 'thea-type-' + (suggestion.type || 'style');
    var typeLabel = (suggestion.type || 'style').charAt(0).toUpperCase() + (suggestion.type || 'style').slice(1);

    var html = '<div class="thea-suggestion-header">' +
      '<span class="thea-suggestion-label">Suggestion' +
      '<span class="thea-suggestion-type ' + typeClass + '">' + typeLabel + '</span></span>' +
      '<button class="thea-suggestion-dismiss" aria-label="Dismiss">&times;</button></div>';

    html += '<div class="thea-suggestion-text">' + escapeHtml(suggestion.message || '') + '</div>';

    if (suggestion.original && suggestion.replacement) {
      html += '<div class="thea-suggestion-original">' + escapeHtml(suggestion.original) + '</div>';
      html += '<div class="thea-suggestion-replacement">' + escapeHtml(suggestion.replacement) + '</div>';
    }

    html += '<div class="thea-suggestion-actions">' +
      '<button class="thea-suggestion-btn thea-suggestion-accept">Accept</button>' +
      '<button class="thea-suggestion-btn thea-suggestion-skip">Skip</button></div>';

    tooltip.innerHTML = html;
    document.body.appendChild(tooltip);
    activeSuggestion = { tooltip: tooltip, field: field, suggestion: suggestion };

    positionTooltip(tooltip, field);
    requestAnimationFrame(function() { tooltip.classList.add('thea-visible'); });

    tooltip.querySelector('.thea-suggestion-dismiss').addEventListener('click', function() {
      dismissSuggestion();
    });

    tooltip.querySelector('.thea-suggestion-accept').addEventListener('click', function() {
      acceptSuggestion(suggestion);
    });

    tooltip.querySelector('.thea-suggestion-skip').addEventListener('click', function() {
      dismissSuggestion();
    });
  }

  function positionTooltip(tooltip, field) {
    var rect = field.getBoundingClientRect();
    var tooltipRect = tooltip.getBoundingClientRect();

    var top = rect.bottom + 8;
    var left = rect.left;

    if (top + tooltipRect.height > window.innerHeight) {
      top = rect.top - tooltipRect.height - 8;
    }
    if (left + tooltipRect.width > window.innerWidth) {
      left = window.innerWidth - tooltipRect.width - 16;
    }
    left = Math.max(16, left);

    tooltip.style.top = top + 'px';
    tooltip.style.left = left + 'px';
  }

  function hideSuggestion() {
    if (activeSuggestion && activeSuggestion.tooltip) {
      activeSuggestion.tooltip.classList.remove('thea-visible');
      var ref = activeSuggestion.tooltip;
      setTimeout(function() {
        if (ref.parentNode) ref.parentNode.removeChild(ref);
      }, 200);
    }
    activeSuggestion = null;
  }

  function acceptSuggestion(suggestion) {
    if (!activeSuggestion) return;
    var field = activeSuggestion.field;

    if (suggestion.original && suggestion.replacement) {
      var isContentEditable = field.isContentEditable;
      if (isContentEditable) {
        var html = field.innerHTML;
        field.innerHTML = html.replace(suggestion.original, suggestion.replacement);
        field.dispatchEvent(new Event('input', { bubbles: true }));
      } else {
        var value = field.value;
        var nativeSet = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value') ||
                        Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value');
        if (nativeSet && nativeSet.set) {
          nativeSet.set.call(field, value.replace(suggestion.original, suggestion.replacement));
        } else {
          field.value = value.replace(suggestion.original, suggestion.replacement);
        }
        field.dispatchEvent(new Event('input', { bubbles: true }));
        field.dispatchEvent(new Event('change', { bubbles: true }));
      }
    }

    hideSuggestion();

    browser.runtime.sendMessage({
      type: 'writingSuggestionAction',
      action: 'accepted',
      suggestion: suggestion
    }).catch(function() {});
  }

  function dismissSuggestion() {
    if (activeSuggestion) {
      var field = activeSuggestion.field;
      var text = field.isContentEditable ? field.textContent : field.value;
      var hash = simpleHash(text);
      dismissedSuggestions.add(hash);

      browser.runtime.sendMessage({
        type: 'writingSuggestionAction',
        action: 'dismissed',
        suggestion: activeSuggestion.suggestion
      }).catch(function() {});
    }
    hideSuggestion();
  }

  function learnFromText(text) {
    browser.runtime.sendMessage({
      type: 'learnWritingStyle',
      text: text.substring(0, 3000),
      domain: window.location.hostname
    }).catch(function() {});
  }

  function simpleHash(str) {
    var hash = 0;
    for (var i = 0; i < str.length; i++) {
      var char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return hash.toString(36);
  }

  function escapeHtml(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }

  function destroy() {
    enabled = false;
    hideSuggestion();
    if (observer) {
      observer.disconnect();
      observer = null;
    }
  }

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.WritingAssistant = {
    init: init,
    destroy: destroy,
    isEnabled: function() { return enabled; }
  };
})();
