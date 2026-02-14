/**
 * Thea PrintFriendly Engine - UI Module
 *
 * Toolbar DOM construction, layout, styles.
 */

(function() {
  'use strict';

  window.TheaModules = window.TheaModules || {};

  // ============================================================================
  // Styles
  // ============================================================================

  function getPrintStyles() {
    return `
      #thea-print-view {
        position: fixed;
        top: 0; left: 0; right: 0; bottom: 0;
        background: #f8f8f8;
        z-index: 2147483647;
        overflow-y: auto;
        font-family: Georgia, 'Times New Roman', serif;
      }

      .thea-pf-toolbar {
        position: sticky; top: 0; z-index: 10;
        display: flex; align-items: center; justify-content: space-between;
        background: #fff; border-bottom: 1px solid #e0e0e0;
        padding: 8px 16px; gap: 12px;
        box-shadow: 0 1px 4px rgba(0,0,0,0.06);
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      }

      .thea-pf-toolbar-left { display: flex; align-items: center; gap: 12px; }
      .thea-pf-toolbar-center { display: flex; align-items: center; gap: 4px; flex: 1; justify-content: center; }
      .thea-pf-toolbar-right { display: flex; align-items: center; gap: 8px; }

      .thea-pf-logo { font-weight: 700; font-size: 15px; color: #e94560; }
      .thea-pf-meta { font-size: 12px; color: #999; }
      .thea-pf-separator { width: 1px; height: 20px; background: #e0e0e0; margin: 0 4px; }

      .thea-pf-tool {
        display: flex; align-items: center; gap: 4px;
        padding: 6px 10px; border: 1px solid transparent; border-radius: 6px;
        background: transparent; color: #555; cursor: pointer;
        font-size: 12px; font-weight: 500; white-space: nowrap;
        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
        transition: all 0.15s;
      }
      .thea-pf-tool:hover { background: #f0f0f0; color: #333; }
      .thea-pf-tool.active { background: #e94560; color: #fff; border-color: #e94560; }
      .thea-pf-tool:disabled { opacity: 0.4; cursor: default; }

      .thea-pf-font-control { display: flex; align-items: center; gap: 6px; color: #555; cursor: pointer; }
      .thea-pf-slider { width: 80px; height: 4px; accent-color: #e94560; cursor: pointer; }

      .thea-pf-action {
        display: flex; align-items: center; gap: 4px;
        padding: 6px 14px; border: 1px solid #e0e0e0; border-radius: 6px;
        background: #fff; color: #333; cursor: pointer;
        font-size: 12px; font-weight: 600; white-space: nowrap;
        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      }
      .thea-pf-action:hover { background: #f5f5f5; }
      .thea-pf-action.primary { background: #e94560; color: #fff; border-color: #e94560; }
      .thea-pf-action.primary:hover { background: #d13b54; }

      .thea-pf-close {
        background: none; border: none; cursor: pointer; padding: 6px;
        color: #999; border-radius: 6px;
      }
      .thea-pf-close:hover { background: #f0f0f0; color: #333; }

      /* Content Area */
      .thea-pf-content {
        max-width: 750px; margin: 0 auto; padding: 40px 24px 80px;
        background: #fff; min-height: calc(100vh - 50px);
        box-shadow: 0 0 20px rgba(0,0,0,0.05);
      }

      .thea-pf-title {
        font-size: 28px; font-weight: 700; line-height: 1.3;
        margin-bottom: 8px; color: #1a1a1a;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      }
      .thea-pf-source {
        font-size: 13px; color: #999; margin-bottom: 32px;
        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      }

      #thea-pf-body {
        font-size: 18px; line-height: 1.8; color: #333;
      }
      #thea-pf-body img { max-width: 100%; height: auto; border-radius: 4px; margin: 16px 0; }
      #thea-pf-body h1, #thea-pf-body h2, #thea-pf-body h3 {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        margin-top: 2em; margin-bottom: 0.5em;
      }
      #thea-pf-body p { margin-bottom: 1.2em; }
      #thea-pf-body a { color: #e94560; }
      #thea-pf-body blockquote {
        border-left: 3px solid #e94560; padding-left: 16px;
        margin: 1.5em 0; color: #666; font-style: italic;
      }
      #thea-pf-body pre, #thea-pf-body code {
        font-family: 'SF Mono', Menlo, monospace;
        background: #f5f5f5; border-radius: 4px;
      }
      #thea-pf-body pre { padding: 16px; overflow-x: auto; }
      #thea-pf-body code { padding: 2px 6px; font-size: 0.9em; }

      /* Delete mode */
      #thea-pf-body.thea-pf-delete-mode { cursor: crosshair; }
      .thea-pf-delete-preview {
        outline: 2px dashed #e94560 !important;
        outline-offset: 2px;
        background: rgba(233, 69, 96, 0.05) !important;
        cursor: pointer !important;
      }

      /* Highlight mode */
      #thea-pf-body.thea-pf-highlight-mode { cursor: text; }
      .thea-pf-highlight {
        background: #fff3cd !important;
        color: inherit !important;
        padding: 1px 0;
        border-radius: 2px;
      }

      /* Print styles */
      @media print {
        .thea-pf-toolbar { display: none !important; }
        #thea-print-view { position: static; }
        .thea-pf-content { box-shadow: none; max-width: 100%; padding: 0; }
        .thea-pf-delete-preview { outline: none !important; background: inherit !important; }
      }
    `;
  }

  // ============================================================================
  // DOM Construction
  // ============================================================================

  function buildPrintViewDOM(title, hostname, wordCount, readTime, currentTool) {
    const escapeHtml = window.TheaModules.escapeHtml || function(t) {
      const d = document.createElement('div'); d.textContent = t || ''; return d.innerHTML;
    };

    const container = document.createElement('div');
    container.id = 'thea-print-view';
    container.innerHTML = `
      <style>${getPrintStyles()}</style>
      <div class="thea-pf-toolbar" id="thea-pf-toolbar">
        <div class="thea-pf-toolbar-left">
          <span class="thea-pf-logo">Thea Reader</span>
          <span class="thea-pf-meta">${wordCount.toLocaleString()} words &middot; ${readTime} min read</span>
        </div>
        <div class="thea-pf-toolbar-center">
          <button class="thea-pf-tool ${currentTool === 'delete' ? 'active' : ''}" data-tool="delete" title="Click to remove elements">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 6h18M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/></svg>
            Delete
          </button>
          <button class="thea-pf-tool ${currentTool === 'highlight' ? 'active' : ''}" data-tool="highlight" title="Highlight text">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 20h9M16.5 3.5a2.12 2.12 0 013 3L7 19l-4 1 1-4z"/></svg>
            Highlight
          </button>
          <div class="thea-pf-separator"></div>
          <label class="thea-pf-font-control" title="Font size">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 7V4h16v3M9 20h6M12 4v16"/></svg>
            <input type="range" min="12" max="28" value="18" id="thea-pf-fontsize" class="thea-pf-slider">
          </label>
          <button class="thea-pf-tool" data-tool="toggle-images" title="Toggle images">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="8.5" cy="8.5" r="1.5"/><path d="M21 15l-5-5L5 21"/></svg>
            Images
          </button>
          <div class="thea-pf-separator"></div>
          <button class="thea-pf-tool" data-tool="undo" title="Undo last action" id="thea-pf-undo" disabled>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 10h11a5 5 0 010 10h-3M3 10l4-4M3 10l4 4"/></svg>
            Undo
          </button>
        </div>
        <div class="thea-pf-toolbar-right">
          <button class="thea-pf-action" data-action="print" title="Print">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 01-2-2v-5a2 2 0 012-2h16a2 2 0 012 2v5a2 2 0 01-2 2h-2"/><rect x="6" y="14" width="12" height="8"/></svg>
            Print
          </button>
          <button class="thea-pf-action primary" data-action="pdf" title="Save as PDF">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
            PDF
          </button>
          <button class="thea-pf-close" data-action="close" title="Close reader view">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
      </div>
      <div class="thea-pf-content" id="thea-pf-content">
        <h1 class="thea-pf-title">${escapeHtml(title)}</h1>
        <div class="thea-pf-source">${escapeHtml(hostname)} &middot; ${escapeHtml(new Date().toLocaleDateString())}</div>
        <div class="thea-pf-body" id="thea-pf-body"></div>
      </div>
    `;

    return container;
  }

  // ============================================================================
  // Export to shared namespace
  // ============================================================================

  window.TheaModules.printUI = {
    getPrintStyles,
    buildPrintViewDOM
  };

})();
