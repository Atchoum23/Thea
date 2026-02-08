/**
 * Thea AI Sidebar - UI Module
 *
 * DOM construction: sidebar container, header, message bubbles,
 * input area, model selector, and all sidebar styles.
 */

(function() {
  'use strict';

  window.TheaModules = window.TheaModules || {};

  // ============================================================================
  // Sidebar Styles
  // ============================================================================

  function getSidebarStyles() {
    return `
      #thea-ai-sidebar {
        position: fixed;
        top: 0; right: -420px; bottom: 0;
        width: 400px;
        z-index: 2147483646;
        transition: right 0.25s cubic-bezier(0.4, 0, 0.2, 1);
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      }
      #thea-ai-sidebar.thea-sidebar-open { right: 0; }

      .thea-sidebar-container {
        display: flex; flex-direction: column;
        height: 100%; background: #1a1a2e;
        border-left: 1px solid rgba(255,255,255,0.08);
        box-shadow: -4px 0 20px rgba(0,0,0,0.3);
      }

      .thea-sidebar-header {
        display: flex; align-items: center; justify-content: space-between;
        padding: 12px 16px; border-bottom: 1px solid rgba(255,255,255,0.08);
        background: #16213e;
      }
      .thea-sidebar-logo { display: flex; align-items: center; gap: 8px; font-weight: 700; font-size: 15px; color: #fff; }
      .thea-sidebar-actions { display: flex; gap: 4px; }
      .thea-sidebar-btn {
        background: transparent; border: none; color: #a0aec0; cursor: pointer;
        padding: 6px; border-radius: 6px; transition: all 0.15s;
      }
      .thea-sidebar-btn:hover { background: rgba(255,255,255,0.1); color: #fff; }

      .thea-sidebar-context {
        display: flex; align-items: center; gap: 8px;
        padding: 8px 16px; background: rgba(255,255,255,0.03);
        border-bottom: 1px solid rgba(255,255,255,0.05);
        font-size: 12px; color: #a0aec0;
        white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
      }

      .thea-sidebar-quick-actions {
        display: flex; gap: 6px; padding: 10px 16px; flex-wrap: wrap;
        border-bottom: 1px solid rgba(255,255,255,0.05);
      }
      .thea-quick-chip {
        padding: 5px 12px; border-radius: 16px; border: 1px solid rgba(255,255,255,0.12);
        background: transparent; color: #a0aec0; cursor: pointer;
        font-size: 12px; font-weight: 500; transition: all 0.15s;
        font-family: inherit;
      }
      .thea-quick-chip:hover { background: #e94560; color: #fff; border-color: #e94560; }

      .thea-sidebar-messages {
        flex: 1; overflow-y: auto; padding: 16px;
        display: flex; flex-direction: column; gap: 12px;
      }

      .thea-sidebar-welcome {
        text-align: center; color: #a0aec0; font-size: 14px;
        padding: 40px 20px; line-height: 1.6;
      }
      .thea-sidebar-welcome code { background: rgba(255,255,255,0.1); padding: 2px 6px; border-radius: 4px; font-size: 13px; }
      .thea-sidebar-hint { font-size: 12px; color: #666; margin-top: 8px; }

      .thea-sidebar-msg {
        max-width: 95%; animation: thea-msg-in 0.15s ease-out;
      }
      @keyframes thea-msg-in { from { opacity: 0; transform: translateY(4px); } }

      .thea-sidebar-msg-user {
        align-self: flex-end;
      }
      .thea-sidebar-msg-user .thea-sidebar-msg-content {
        background: #e94560; color: #fff; border-radius: 14px 14px 4px 14px;
        padding: 10px 14px; font-size: 14px; line-height: 1.5;
      }

      .thea-sidebar-msg-assistant .thea-sidebar-msg-content {
        background: #16213e; color: #eaeaea; border-radius: 14px 14px 14px 4px;
        padding: 10px 14px; font-size: 14px; line-height: 1.6;
        border: 1px solid rgba(255,255,255,0.06);
      }

      .thea-sidebar-msg-actions {
        display: flex; gap: 4px; margin-top: 4px; padding-left: 4px;
      }
      .thea-msg-action {
        background: transparent; border: none; color: #666; cursor: pointer;
        padding: 3px; border-radius: 4px;
      }
      .thea-msg-action:hover { color: #a0aec0; background: rgba(255,255,255,0.05); }

      .thea-sidebar-loading span {
        display: inline-block; width: 6px; height: 6px;
        border-radius: 50%; background: #a0aec0; margin: 0 2px;
        animation: thea-bounce 1.4s infinite both;
      }
      .thea-sidebar-loading span:nth-child(2) { animation-delay: 0.16s; }
      .thea-sidebar-loading span:nth-child(3) { animation-delay: 0.32s; }
      @keyframes thea-bounce {
        0%, 80%, 100% { transform: scale(0); }
        40% { transform: scale(1); }
      }

      .thea-sidebar-history-item {
        padding: 12px; border-radius: 8px; cursor: pointer;
        border: 1px solid rgba(255,255,255,0.06);
        transition: background 0.15s;
      }
      .thea-sidebar-history-item:hover { background: rgba(255,255,255,0.05); }
      .thea-sidebar-history-title { font-size: 14px; color: #eaeaea; font-weight: 500; margin-bottom: 4px; }
      .thea-sidebar-history-meta { font-size: 12px; color: #666; }

      .thea-sidebar-input-area {
        border-top: 1px solid rgba(255,255,255,0.08); padding: 12px 16px;
        background: #16213e; position: relative;
      }

      .thea-sidebar-slash-menu {
        position: absolute; bottom: 100%; left: 12px; right: 12px;
        background: #1a1a2e; border: 1px solid rgba(255,255,255,0.1);
        border-radius: 8px; overflow: hidden;
        box-shadow: 0 -4px 12px rgba(0,0,0,0.3);
      }
      .thea-slash-item {
        display: flex; align-items: center; gap: 12px;
        padding: 8px 12px; cursor: pointer; transition: background 0.1s;
      }
      .thea-slash-item:hover { background: rgba(233, 69, 96, 0.15); }
      .thea-slash-cmd { color: #e94560; font-weight: 600; font-size: 13px; font-family: monospace; }
      .thea-slash-desc { color: #a0aec0; font-size: 12px; }

      .thea-sidebar-input-row { display: flex; gap: 8px; align-items: flex-end; }
      #thea-sidebar-input {
        flex: 1; padding: 10px 14px; background: #0f3460; border: 1px solid rgba(255,255,255,0.1);
        border-radius: 12px; color: #eaeaea; font-size: 14px; resize: none;
        font-family: inherit; outline: none; min-height: 40px; max-height: 120px;
      }
      #thea-sidebar-input::placeholder { color: #666; }
      #thea-sidebar-input:focus { border-color: #e94560; }

      .thea-sidebar-send {
        background: #e94560; border: none; color: #fff; cursor: pointer;
        width: 38px; height: 38px; border-radius: 10px;
        display: flex; align-items: center; justify-content: center;
        transition: background 0.15s; flex-shrink: 0;
      }
      .thea-sidebar-send:hover { background: #ff6b6b; }

      .thea-sidebar-footer {
        text-align: center; font-size: 11px; color: #555; margin-top: 8px;
      }

      /* Scrollbar */
      .thea-sidebar-messages::-webkit-scrollbar { width: 4px; }
      .thea-sidebar-messages::-webkit-scrollbar-track { background: transparent; }
      .thea-sidebar-messages::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); border-radius: 2px; }
    `;
  }

  // ============================================================================
  // Sidebar DOM Construction
  // ============================================================================

  function buildSidebarDOM() {
    const el = document.createElement('div');
    el.id = 'thea-ai-sidebar';
    el.innerHTML = `
      <style>${getSidebarStyles()}</style>
      <div class="thea-sidebar-container">
        <div class="thea-sidebar-header">
          <div class="thea-sidebar-logo">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#e94560" stroke-width="2">
              <path d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z"/>
            </svg>
            <span>Thea AI</span>
          </div>
          <div class="thea-sidebar-actions">
            <button class="thea-sidebar-btn" data-action="new-chat" title="New conversation">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
            </button>
            <button class="thea-sidebar-btn" data-action="history" title="Chat history">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
            </button>
            <button class="thea-sidebar-btn" data-action="close" title="Close sidebar">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
            </button>
          </div>
        </div>

        <div class="thea-sidebar-context" id="thea-sidebar-context">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
          <span id="thea-sidebar-page-title">Loading page...</span>
        </div>

        <div class="thea-sidebar-quick-actions" id="thea-sidebar-quick">
          <button class="thea-quick-chip" data-cmd="/summarize">Summarize</button>
          <button class="thea-quick-chip" data-cmd="/key-points">Key Points</button>
          <button class="thea-quick-chip" data-cmd="/action-items">Actions</button>
          <button class="thea-quick-chip" data-cmd="/explain">Explain</button>
        </div>

        <div class="thea-sidebar-messages" id="thea-sidebar-messages">
          <div class="thea-sidebar-welcome">
            <p>Ask me anything about this page, or use a quick action above.</p>
            <p class="thea-sidebar-hint">Type <code>/</code> to see all commands</p>
          </div>
        </div>

        <div class="thea-sidebar-input-area">
          <div class="thea-sidebar-slash-menu" id="thea-slash-menu" style="display:none;"></div>
          <div class="thea-sidebar-input-row">
            <textarea id="thea-sidebar-input"
              placeholder="Ask about this page..."
              rows="1"
              autofocus></textarea>
            <button class="thea-sidebar-send" id="thea-sidebar-send" title="Send (Enter)">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/>
              </svg>
            </button>
          </div>
          <div class="thea-sidebar-footer">
            Powered by Thea &middot; <span id="thea-sidebar-model">Auto</span>
          </div>
        </div>
      </div>
    `;

    return el;
  }

  // ============================================================================
  // Message Bubble Rendering
  // ============================================================================

  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text || '';
    return div.innerHTML;
  }

  function createMessageBubble(role, content, isLoading) {
    const msgEl = document.createElement('div');
    const id = `msg-${Date.now()}`;
    msgEl.id = id;
    msgEl.className = `thea-sidebar-msg thea-sidebar-msg-${role}`;

    if (isLoading) {
      msgEl.innerHTML = `
        <div class="thea-sidebar-msg-content">
          <div class="thea-sidebar-loading">
            <span></span><span></span><span></span>
          </div>
        </div>
      `;
    } else {
      msgEl.innerHTML = `
        <div class="thea-sidebar-msg-content">${escapeHtml(content)}</div>
        ${role === 'assistant' ? `
          <div class="thea-sidebar-msg-actions">
            <button class="thea-msg-action" data-action="copy" title="Copy">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>
            </button>
          </div>
        ` : ''}
      `;
    }

    return { element: msgEl, id };
  }

  function getCopyIconSVG() {
    return '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>';
  }

  function getCheckIconSVG() {
    return '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#38a169" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>';
  }

  function buildCopyActionsHTML() {
    return `
      <div class="thea-sidebar-msg-actions">
        <button class="thea-msg-action" data-action="copy" title="Copy">
          ${getCopyIconSVG()}
        </button>
      </div>
    `;
  }

  // ============================================================================
  // Quick Action Chips
  // ============================================================================

  function updateQuickActionChips(container, chips, onChipClick) {
    container.innerHTML = chips.map(c =>
      `<button class="thea-quick-chip" data-cmd="${c.cmd}">${c.label}</button>`
    ).join('');

    container.querySelectorAll('.thea-quick-chip').forEach(chip => {
      chip.addEventListener('click', () => onChipClick(chip.dataset.cmd));
    });
  }

  // ============================================================================
  // Slash Menu
  // ============================================================================

  function renderSlashMenu(menu, matches) {
    menu.innerHTML = matches.map(([cmd, info]) => `
      <div class="thea-slash-item" data-cmd="${cmd}">
        <span class="thea-slash-cmd">${cmd}</span>
        <span class="thea-slash-desc">${info.label}</span>
      </div>
    `).join('');
    menu.style.display = 'block';
  }

  function hideSlashMenu(menu) {
    menu.style.display = 'none';
  }

  // ============================================================================
  // Export to shared namespace
  // ============================================================================

  window.TheaModules.sidebarUI = {
    buildSidebarDOM,
    createMessageBubble,
    escapeHtml,
    getCopyIconSVG,
    getCheckIconSVG,
    buildCopyActionsHTML,
    updateQuickActionChips,
    renderSlashMenu,
    hideSlashMenu
  };

})();
