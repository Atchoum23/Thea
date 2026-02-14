(function() {
  'use strict';

  var Notify = null;
  var popup = null;
  var enabled = false;
  var mouseDownTarget = null;
  var POPUP_ID = 'thea-selection-popup';

  var ACTIONS = [
    { id: 'ask', label: 'Ask', icon: '\uD83D\uDCAC' },
    { id: 'summarize', label: 'Summarize', icon: '\uD83D\uDCDD' },
    { id: 'translate', label: 'Translate', icon: '\uD83C\uDF0D' },
    { id: 'save', label: 'Save', icon: '\uD83D\uDCBE' },
    { id: 'rewrite', label: 'Rewrite', icon: '\u270D\uFE0F' }
  ];

  function init() {
    Notify = window.TheaModules.Notification;
    enabled = true;
    injectStyles();

    document.addEventListener('mousedown', function(e) {
      mouseDownTarget = e.target;
      if (popup && !popup.contains(e.target)) {
        hideSelectionPopup();
      }
    });

    document.addEventListener('mouseup', function(e) {
      if (!enabled) return;
      if (popup && popup.contains(e.target)) return;
      if (e.target.closest('#thea-ai-sidebar')) return;
      if (e.target.closest('[class*="thea-"]')) return;

      setTimeout(function() {
        var selection = window.getSelection();
        if (!selection || selection.isCollapsed) return;

        var text = selection.toString().trim();
        if (text.length < 3 || text.length > 10000) return;

        var range = selection.getRangeAt(0);
        var rect = range.getBoundingClientRect();
        showSelectionPopup(rect.left + rect.width / 2, rect.top, text);
      }, 10);
    });

    document.addEventListener('keydown', function(e) {
      if (e.key === 'Escape' && popup) {
        hideSelectionPopup();
      }
    });
  }

  function injectStyles() {
    if (document.getElementById('thea-selection-styles')) return;
    var style = document.createElement('style');
    style.id = 'thea-selection-styles';
    style.textContent = [
      '#' + POPUP_ID + ' {',
      '  position: fixed; z-index: 2147483643;',
      '  background: #1e1e2e; border: 1px solid #313244; border-radius: 10px;',
      '  padding: 6px; box-shadow: 0 8px 24px rgba(0,0,0,0.4);',
      '  display: flex; gap: 2px; align-items: center;',
      '  opacity: 0; transform: translateY(4px);',
      '  transition: opacity 0.2s ease, transform 0.2s ease;',
      '}',
      '#' + POPUP_ID + '.thea-visible {',
      '  opacity: 1; transform: translateY(0);',
      '}',
      '#' + POPUP_ID + ' button {',
      '  background: none; border: none; cursor: pointer;',
      '  padding: 6px 10px; border-radius: 6px; font-size: 12px;',
      '  color: #cdd6f4; font-family: -apple-system, sans-serif;',
      '  display: flex; align-items: center; gap: 4px;',
      '  transition: background 0.15s ease; white-space: nowrap;',
      '}',
      '#' + POPUP_ID + ' button:hover {',
      '  background: #313244; color: #fff;',
      '}',
      '#' + POPUP_ID + ' .thea-sel-icon { font-size: 14px; }',
      '#' + POPUP_ID + '::after {',
      '  content: ""; position: absolute; bottom: -6px; left: 50%; transform: translateX(-50%);',
      '  width: 12px; height: 6px;',
      '  background: #1e1e2e; clip-path: polygon(0 0, 100% 0, 50% 100%);',
      '}',
      '#' + POPUP_ID + '.thea-below::after {',
      '  top: -6px; bottom: auto;',
      '  clip-path: polygon(50% 0, 0 100%, 100% 100%);',
      '}'
    ].join('\n');
    document.head.appendChild(style);
  }

  function showSelectionPopup(x, y, text) {
    hideSelectionPopup();

    popup = document.createElement('div');
    popup.id = POPUP_ID;

    ACTIONS.forEach(function(action) {
      var btn = document.createElement('button');
      btn.title = action.label;
      btn.innerHTML = '<span class="thea-sel-icon">' + action.icon + '</span>' +
        '<span>' + action.label + '</span>';
      btn.addEventListener('click', function(e) {
        e.preventDefault();
        e.stopPropagation();
        handleAction(action.id, text);
        hideSelectionPopup();
      });
      popup.appendChild(btn);
    });

    document.body.appendChild(popup);

    var popupRect = popup.getBoundingClientRect();
    var popupWidth = popupRect.width;
    var popupHeight = popupRect.height;

    var left = x - popupWidth / 2;
    var top = y - popupHeight - 12;
    var below = false;

    if (top < 8) {
      top = y + 24;
      below = true;
    }
    if (left < 8) left = 8;
    if (left + popupWidth > window.innerWidth - 8) {
      left = window.innerWidth - popupWidth - 8;
    }

    popup.style.left = left + 'px';
    popup.style.top = top + 'px';
    if (below) popup.classList.add('thea-below');

    requestAnimationFrame(function() {
      if (popup) popup.classList.add('thea-visible');
    });
  }

  function hideSelectionPopup() {
    if (popup) {
      popup.classList.remove('thea-visible');
      var ref = popup;
      setTimeout(function() {
        if (ref && ref.parentNode) ref.parentNode.removeChild(ref);
      }, 200);
      popup = null;
    }
  }

  function handleAction(action, text) {
    switch (action) {
      case 'ask':
        var sidebar = window.TheaModules.AISidebar;
        if (sidebar) {
          if (!sidebar.isOpen()) sidebar.toggle();
          sidebar.sendMessage('Explain this: "' + text.substring(0, 500) + '"');
        }
        break;

      case 'summarize':
        if (Notify) Notify.showLoading('Summarizing...');
        browser.runtime.sendMessage({
          type: 'quickAction',
          action: 'summarize',
          text: text.substring(0, 3000)
        }).then(function(response) {
          if (Notify) Notify.hideLoading();
          if (response && response.result) {
            if (Notify) Notify.showResult('Summary', response.result);
          }
        }).catch(function() {
          if (Notify) {
            Notify.hideLoading();
            Notify.showNotification('Error', 'Failed to summarize text', 3000);
          }
        });
        break;

      case 'translate':
        if (Notify) Notify.showLoading('Translating...');
        browser.runtime.sendMessage({
          type: 'quickAction',
          action: 'translate',
          text: text.substring(0, 3000)
        }).then(function(response) {
          if (Notify) Notify.hideLoading();
          if (response && response.result) {
            if (Notify) Notify.showResult('Translation', response.result);
          }
        }).catch(function() {
          if (Notify) {
            Notify.hideLoading();
            Notify.showNotification('Error', 'Failed to translate text', 3000);
          }
        });
        break;

      case 'save':
        browser.runtime.sendMessage({
          type: 'saveSnippet',
          text: text.substring(0, 5000),
          url: window.location.href,
          title: document.title
        }).then(function() {
          if (Notify) Notify.showNotification('Saved', 'Snippet saved to Thea', 2000);
        }).catch(function() {
          if (Notify) Notify.showNotification('Error', 'Failed to save snippet', 3000);
        });
        break;

      case 'rewrite':
        if (Notify) Notify.showLoading('Rewriting...');
        browser.runtime.sendMessage({
          type: 'quickAction',
          action: 'rewrite',
          text: text.substring(0, 3000)
        }).then(function(response) {
          if (Notify) Notify.hideLoading();
          if (response && response.result) {
            if (Notify) Notify.showResult('Rewritten', response.result);
          }
        }).catch(function() {
          if (Notify) {
            Notify.hideLoading();
            Notify.showNotification('Error', 'Failed to rewrite text', 3000);
          }
        });
        break;
    }
  }

  function destroy() {
    enabled = false;
    hideSelectionPopup();
  }

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.SelectionHandler = {
    init: init,
    destroy: destroy,
    isEnabled: function() { return enabled; }
  };
})();
