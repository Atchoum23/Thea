// Thea Chrome Extension - Writing Assistant
// Emily-inspired real-time writing assistant with style learning

(function() {
  'use strict';

  let enabled = false;
  let activeField = null;
  let debounceTimer = null;
  let currentSuggestion = null;
  const DEBOUNCE_DELAY = 500;
  const MIN_TEXT_LENGTH = 20;

  const EDITABLE_SELECTORS = [
    'textarea',
    '[contenteditable="true"]',
    'input[type="text"]',
    'input[type="email"]',
    'input[type="search"]',
    '.ProseMirror',
    '.ql-editor',
    '.CodeMirror',
    '[role="textbox"]'
  ];

  // ── Initialization ──────────────────────────────────────────────────

  function init() {
    // Get state from background
    chrome.runtime.sendMessage({ type: 'getState' }, (response) => {
      if (response?.data?.writingAssistantEnabled) {
        enabled = true;
        scanForEditableFields();
        observeNewFields();
      }
    });

    // Listen for toggle
    chrome.runtime.onMessage.addListener((message) => {
      if (message.type === 'featureToggled' && message.data.feature === 'writingAssistantEnabled') {
        enabled = message.data.enabled;
        if (enabled) {
          scanForEditableFields();
          observeNewFields();
        } else {
          hideSuggestion();
          detachAllFields();
        }
      }
    });
  }

  // ── Field Detection ─────────────────────────────────────────────────

  function scanForEditableFields() {
    const selector = EDITABLE_SELECTORS.join(', ');
    document.querySelectorAll(selector).forEach(field => attachToField(field));
  }

  function observeNewFields() {
    const observer = new MutationObserver((mutations) => {
      if (!enabled) return;
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (node.nodeType !== Node.ELEMENT_NODE) continue;
          const selector = EDITABLE_SELECTORS.join(', ');
          if (node.matches && node.matches(selector)) {
            attachToField(node);
          }
          if (node.querySelectorAll) {
            node.querySelectorAll(selector).forEach(f => attachToField(f));
          }
        }
      }
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  // ── Field Attachment ────────────────────────────────────────────────

  function attachToField(field) {
    if (field._theaWritingAttached) return;
    field._theaWritingAttached = true;

    const inputHandler = () => {
      if (!enabled) return;
      clearTimeout(debounceTimer);
      activeField = field;

      debounceTimer = setTimeout(() => {
        const text = getFieldText(field);
        if (text.length >= MIN_TEXT_LENGTH) {
          analyzeText(text, field);
          scheduleStyleLearning(text);
        }
      }, DEBOUNCE_DELAY);
    };

    field.addEventListener('input', inputHandler);

    field.addEventListener('keydown', (e) => {
      if (e.key === 'Tab' && currentSuggestion) {
        e.preventDefault();
        acceptSuggestion();
      } else if (e.key === 'Escape' && currentSuggestion) {
        dismissSuggestion();
      }
    });

    field.addEventListener('blur', () => {
      setTimeout(hideSuggestion, 200);
    });
  }

  function detachAllFields() {
    // Fields will stop responding since enabled=false
    // The _theaWritingAttached flag prevents re-attachment until page reload
  }

  function getFieldText(field) {
    if (field.value !== undefined) return field.value;
    return field.textContent || field.innerText || '';
  }

  // ── AI Analysis ─────────────────────────────────────────────────────

  async function analyzeText(text, field) {
    try {
      const response = await chrome.runtime.sendMessage({
        type: 'rewriteText',
        data: {
          text: text.slice(-500), // Last 500 chars for context
          fullText: text,
          domain: window.location.hostname,
          fieldType: field.tagName.toLowerCase()
        }
      });

      if (response?.success && response?.data?.suggestion) {
        showSuggestion(field, response.data.suggestion);
      }
    } catch (e) {
      // Silently fail - writing assistant is non-critical
    }
  }

  // ── Suggestion Tooltip ──────────────────────────────────────────────

  function showSuggestion(field, suggestion) {
    hideSuggestion();
    currentSuggestion = suggestion;

    const caretPos = getCaretPosition(field);
    const rect = field.getBoundingClientRect();

    const tooltip = document.createElement('div');
    tooltip.id = 'thea-writing-suggestion';
    tooltip.innerHTML = `
      <div class="thea-suggestion-text">${escapeHtml(suggestion.text)}</div>
      ${suggestion.reason ? `<div class="thea-suggestion-reason">${escapeHtml(suggestion.reason)}</div>` : ''}
      <div class="thea-suggestion-actions">
        <button class="thea-accept" title="Accept (Tab)">Accept</button>
        <button class="thea-dismiss" title="Dismiss (Esc)">Dismiss</button>
      </div>
      <div class="thea-suggestion-hint">Tab to accept \u00B7 Esc to dismiss</div>
    `;

    // Position near caret or below field
    const x = caretPos ? caretPos.x : rect.left;
    const y = caretPos ? caretPos.y + 20 : rect.bottom + 8;

    tooltip.style.cssText = `
      position: fixed; z-index: 2147483647;
      left: ${Math.min(x, window.innerWidth - 340)}px;
      top: ${Math.min(y, window.innerHeight - 120)}px;
      background: #1C1C22; color: #F5F5F7; padding: 10px 14px;
      border-radius: 10px; font-size: 13px; max-width: 320px;
      box-shadow: 0 4px 16px rgba(0,0,0,0.3); border: 1px solid rgba(255,255,255,0.1);
      font-family: -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
      animation: theaFadeIn 0.15s ease-out;
    `;

    document.body.appendChild(tooltip);

    tooltip.querySelector('.thea-accept').addEventListener('click', acceptSuggestion);
    tooltip.querySelector('.thea-dismiss').addEventListener('click', dismissSuggestion);
  }

  function hideSuggestion() {
    const existing = document.getElementById('thea-writing-suggestion');
    if (existing) existing.remove();
    currentSuggestion = null;
  }

  // ── Suggestion Actions ──────────────────────────────────────────────

  function acceptSuggestion() {
    if (!currentSuggestion || !activeField) return;

    const suggestion = currentSuggestion;

    // Apply the suggestion
    if (suggestion.replacement) {
      // Full text replacement
      if (activeField.value !== undefined) {
        activeField.value = suggestion.replacement;
      } else {
        activeField.textContent = suggestion.replacement;
      }
    } else if (suggestion.append) {
      // Append completion
      if (activeField.value !== undefined) {
        activeField.value += suggestion.append;
      } else {
        activeField.textContent += suggestion.append;
      }
    }

    // Trigger input event so frameworks (React, Vue, etc.) pick up the change
    activeField.dispatchEvent(new Event('input', { bubbles: true }));

    // Report acceptance for style learning
    chrome.runtime.sendMessage({
      type: 'saveSuggestionFeedback',
      data: { accepted: true, suggestion: suggestion.text, domain: window.location.hostname }
    });

    hideSuggestion();
  }

  function dismissSuggestion() {
    if (currentSuggestion) {
      chrome.runtime.sendMessage({
        type: 'saveSuggestionFeedback',
        data: { accepted: false, suggestion: currentSuggestion.text, domain: window.location.hostname }
      });
    }
    hideSuggestion();
  }

  // ── Caret Position ──────────────────────────────────────────────────

  function getCaretPosition(field) {
    try {
      if (field.selectionStart !== undefined) {
        // textarea/input - approximate position from line count
        const rect = field.getBoundingClientRect();
        const computedStyle = getComputedStyle(field);
        const lineHeight = parseInt(computedStyle.lineHeight) || 20;
        const paddingTop = parseInt(computedStyle.paddingTop) || 0;
        const lines = field.value.substring(0, field.selectionStart).split('\n');
        return {
          x: rect.left + 10,
          y: rect.top + paddingTop + (lines.length * lineHeight)
        };
      }
      // contenteditable - use selection API
      const selection = window.getSelection();
      if (selection.rangeCount > 0) {
        const range = selection.getRangeAt(0);
        const rects = range.getClientRects();
        if (rects.length > 0) {
          return { x: rects[0].left, y: rects[0].bottom };
        }
      }
    } catch (e) {
      // Fall through to null
    }
    return null;
  }

  // ── Style Learning ──────────────────────────────────────────────────

  let learnTimer = null;

  function scheduleStyleLearning(text) {
    clearTimeout(learnTimer);
    learnTimer = setTimeout(() => {
      chrome.runtime.sendMessage({
        type: 'analyzeWritingStyle',
        data: { text, domain: window.location.hostname }
      });
    }, 30000); // Analyze every 30 seconds of active writing
  }

  // ── Utilities ───────────────────────────────────────────────────────

  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // ── Inject Styles ───────────────────────────────────────────────────

  if (!document.getElementById('thea-writing-styles')) {
    const style = document.createElement('style');
    style.id = 'thea-writing-styles';
    style.textContent = `
      @keyframes theaFadeIn {
        from { opacity: 0; transform: translateY(-4px); }
        to { opacity: 1; transform: translateY(0); }
      }
      #thea-writing-suggestion .thea-suggestion-text {
        margin-bottom: 6px;
        line-height: 1.4;
      }
      #thea-writing-suggestion .thea-suggestion-reason {
        color: #8E8E93;
        font-size: 11px;
        margin-bottom: 8px;
        font-style: italic;
      }
      #thea-writing-suggestion .thea-suggestion-actions {
        display: flex;
        gap: 8px;
      }
      #thea-writing-suggestion button {
        padding: 4px 12px;
        border-radius: 6px;
        border: none;
        cursor: pointer;
        font-size: 12px;
        font-family: inherit;
        transition: background 0.15s ease;
      }
      #thea-writing-suggestion .thea-accept {
        background: #0066FF;
        color: white;
      }
      #thea-writing-suggestion .thea-accept:hover {
        background: #0055DD;
      }
      #thea-writing-suggestion .thea-dismiss {
        background: rgba(255,255,255,0.1);
        color: #8E8E93;
      }
      #thea-writing-suggestion .thea-dismiss:hover {
        background: rgba(255,255,255,0.15);
      }
      #thea-writing-suggestion .thea-suggestion-hint {
        color: #636366;
        font-size: 10px;
        margin-top: 6px;
        text-align: center;
      }
    `;
    document.head.appendChild(style);
  }

  // ── Bootstrap ───────────────────────────────────────────────────────

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
