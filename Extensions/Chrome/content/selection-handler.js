// Thea Chrome Extension - Selection Handler Module
// Text selection popup with action buttons for AI operations

(function() {
  'use strict';

  window.TheaModules = window.TheaModules || {};

  // ============================================================================
  // Selection Popup Styles (injected once)
  // ============================================================================

  function injectSelectionStyles() {
    if (document.getElementById('thea-selection-styles')) return;

    const style = document.createElement('style');
    style.id = 'thea-selection-styles';
    style.textContent = `
      .thea-selection-actions {
        position: absolute;
        z-index: 2147483647;
        display: flex;
        gap: 2px;
        padding: 4px;
        background: #1a1a2e;
        border-radius: 8px;
        box-shadow: 0 4px 16px rgba(0,0,0,0.3);
        border: 1px solid rgba(255,255,255,0.1);
        transform: translateX(-50%);
        animation: thea-sel-fade-in 0.1s ease-out;
      }
      @keyframes thea-sel-fade-in {
        from { opacity: 0; transform: translateX(-50%) translateY(4px); }
        to { opacity: 1; transform: translateX(-50%) translateY(0); }
      }
      .thea-selection-actions button {
        background: transparent;
        border: none;
        color: #a0aec0;
        cursor: pointer;
        padding: 6px 8px;
        border-radius: 6px;
        transition: all 0.1s;
      }
      .thea-selection-actions button:hover {
        background: rgba(233,69,96,0.2);
        color: #e94560;
      }
    `;
    document.head.appendChild(style);
  }

  // ============================================================================
  // Selection Popup
  // ============================================================================

  function showSelectionPopup(selection, event) {
    removeSelectionPopup();

    const text = selection.toString().trim();
    if (text.length < 5) return;

    const popup = document.createElement('div');
    popup.className = 'thea-selection-actions';
    popup.innerHTML = `
      <button data-action="explain" title="Explain">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 015.83 1c0 2-3 3-3 3"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
      </button>
      <button data-action="summarize" title="Summarize">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="17" y1="10" x2="3" y2="10"/><line x1="21" y1="6" x2="3" y2="6"/><line x1="21" y1="14" x2="3" y2="14"/><line x1="17" y1="18" x2="3" y2="18"/></svg>
      </button>
      <button data-action="translate" title="Translate">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 8l6 6M4 14l6-6 2-3M2 5h12M7 2h1"/><path d="M11 21l5-10 5 10M14.5 17.5h5"/></svg>
      </button>
      <button data-action="ask" title="Ask Thea">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#e94560" stroke-width="2"><path d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z"/></svg>
      </button>
    `;

    // Position near selection
    const range = selection.getRangeAt(0);
    const rect = range.getBoundingClientRect();
    popup.style.top = `${rect.top + window.scrollY - 44}px`;
    popup.style.left = `${rect.left + window.scrollX + (rect.width / 2)}px`;

    popup.addEventListener('click', (e) => {
      const btn = e.target.closest('button');
      if (!btn) return;

      const action = btn.dataset.action;
      const sidebar = window.TheaModules.sidebar;

      // Open sidebar if available
      if (sidebar && sidebar.openSidebar) {
        sidebar.openSidebar();
      }

      switch (action) {
        case 'explain':
          if (sidebar && sidebar.executeSlashCommand) {
            sidebar.executeSlashCommand('/explain');
          }
          break;
        case 'summarize':
          if (sidebar && sidebar.executeSlashCommand) {
            sidebar.executeSlashCommand('/summarize');
          }
          break;
        case 'translate':
          if (sidebar && sidebar.executeSlashCommand) {
            sidebar.executeSlashCommand('/translate');
          }
          break;
        case 'ask':
          if (sidebar && sidebar.getSidebarElement) {
            const sidebarEl = sidebar.getSidebarElement();
            if (sidebarEl) {
              const input = sidebarEl.querySelector('#thea-sidebar-input');
              if (input) {
                input.value = text.substring(0, 500);
                input.focus();
              }
            }
          }
          break;
      }

      removeSelectionPopup();
    });

    document.body.appendChild(popup);

    // Remove on click outside
    setTimeout(() => {
      document.addEventListener('mousedown', removeSelectionPopup, { once: true });
    }, 100);
  }

  function removeSelectionPopup() {
    document.querySelectorAll('.thea-selection-actions').forEach(p => p.remove());
  }

  // ============================================================================
  // Selection Listener Setup
  // ============================================================================

  function setupSelectionListener() {
    injectSelectionStyles();

    document.addEventListener('mouseup', (e) => {
      // Don't show if sidebar is target
      const sidebar = window.TheaModules.sidebar;
      if (sidebar && sidebar.getSidebarElement) {
        const sidebarEl = sidebar.getSidebarElement();
        if (sidebarEl?.contains(e.target)) return;
      }

      const selection = window.getSelection();
      if (!selection || selection.isCollapsed || !selection.toString().trim()) return;

      showSelectionPopup(selection, e);
    });
  }

  // ============================================================================
  // Export to shared namespace
  // ============================================================================

  window.TheaModules.selection = {
    setupSelectionListener,
    showSelectionPopup,
    removeSelectionPopup
  };

})();
