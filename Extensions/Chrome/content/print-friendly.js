/**
 * Thea PrintFriendly Engine
 *
 * Inspired by: PrintFriendly for Chrome
 *
 * Features:
 * - Smart content extraction (article detection, readability)
 * - Click-to-delete any element (block-level deletion with hover preview)
 * - Text highlighting tool for study/reference
 * - Font size adjustment slider
 * - Image removal toggle
 * - Undo stack for all edits
 * - Save as PDF / Print / Screenshot
 * - Full-screen editing mode
 * - Word count and estimated read time
 * - RTL/non-Latin support
 */

(function() {
  'use strict';

  let printContainer = null;
  let undoStack = [];
  let currentTool = null; // 'delete' | 'highlight' | null
  let originalContent = null;

  // ============================================================================
  // Activation
  // ============================================================================

  function activate() {
    if (printContainer) return;

    // Save original scroll position
    const scrollPos = window.scrollY;

    // Extract main content
    const content = extractContent();
    originalContent = content.cloneNode(true);

    // Build print UI
    buildPrintUI(content);

    // Notify background
    chrome.runtime.sendMessage({ type: 'updateStats', data: { pagesCleaned: 1 } });
  }

  function deactivate() {
    if (printContainer) {
      printContainer.remove();
      printContainer = null;
      undoStack = [];
      currentTool = null;
    }
  }

  // ============================================================================
  // Content Extraction
  // ============================================================================

  function extractContent() {
    // Priority order for content detection
    const selectors = [
      'article[role="main"]', 'article', '[role="main"]',
      'main article', 'main', '.post-content', '.entry-content',
      '.article-content', '.article-body', '.story-body',
      '.content-body', '#content', '.content', '.post',
      '[itemprop="articleBody"]', '[data-article-body]'
    ];

    let source = null;
    for (const sel of selectors) {
      source = document.querySelector(sel);
      if (source && source.textContent.trim().length > 200) break;
    }

    if (!source) source = document.body;

    const content = source.cloneNode(true);

    // Remove clutter
    const removeSelectors = [
      'nav', 'aside', '.sidebar', '.ad', '.ads', '.advertisement',
      '.social-share', '.share-buttons', '.comments', '.comment-section',
      '.related-posts', '.recommended', '.newsletter', '.popup', '.modal',
      '.cookie-banner', '.cookie-consent', 'script', 'style', 'iframe',
      'noscript', '.promo', '.banner', '[data-ad]', '[data-advertisement]',
      '.footer-widgets', '.widget', 'button:not([type="submit"])',
      '[class*="newsletter"]', '[class*="subscribe"]', '[class*="popup"]',
      '[class*="overlay"]', '[class*="sticky"]', '.author-bio',
      '.breadcrumb', '.pagination', '.tags', '.categories',
      'header nav', 'footer'
    ];

    removeSelectors.forEach(sel => {
      content.querySelectorAll(sel).forEach(el => el.remove());
    });

    return content;
  }

  // ============================================================================
  // Print UI
  // ============================================================================

  function buildPrintUI(content) {
    printContainer = document.createElement('div');
    printContainer.id = 'thea-print-view';

    const wordCount = content.textContent.trim().split(/\s+/).filter(Boolean).length;
    const readTime = Math.max(1, Math.ceil(wordCount / 250));

    printContainer.innerHTML = `
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
        <h1 class="thea-pf-title">${escapeHtml(document.title)}</h1>
        <div class="thea-pf-source">${escapeHtml(window.location.hostname)} &middot; ${escapeHtml(new Date().toLocaleDateString())}</div>
        <div class="thea-pf-body" id="thea-pf-body"></div>
      </div>
    `;

    // Insert content
    printContainer.querySelector('#thea-pf-body').appendChild(content);

    document.body.appendChild(printContainer);

    // Setup interactions
    setupToolbar();
    setupDeleteTool();
    setupHighlightTool();
  }

  // ============================================================================
  // Toolbar Interactions
  // ============================================================================

  function setupToolbar() {
    const toolbar = printContainer.querySelector('#thea-pf-toolbar');

    toolbar.addEventListener('click', (e) => {
      const tool = e.target.closest('[data-tool]');
      const action = e.target.closest('[data-action]');

      if (tool) {
        handleTool(tool.dataset.tool);
      } else if (action) {
        handleAction(action.dataset.action);
      }
    });

    // Font size slider
    const fontSlider = printContainer.querySelector('#thea-pf-fontsize');
    fontSlider.addEventListener('input', (e) => {
      const body = printContainer.querySelector('#thea-pf-body');
      body.style.fontSize = `${e.target.value}px`;
    });
  }

  function handleTool(tool) {
    if (tool === 'undo') {
      performUndo();
      return;
    }

    if (tool === 'toggle-images') {
      toggleImages();
      return;
    }

    // Toggle tool selection
    if (currentTool === tool) {
      currentTool = null;
    } else {
      currentTool = tool;
    }

    // Update toolbar buttons
    printContainer.querySelectorAll('.thea-pf-tool[data-tool]').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.tool === currentTool);
    });

    // Update cursor
    const body = printContainer.querySelector('#thea-pf-body');
    body.classList.toggle('thea-pf-delete-mode', currentTool === 'delete');
    body.classList.toggle('thea-pf-highlight-mode', currentTool === 'highlight');
  }

  function handleAction(action) {
    switch (action) {
      case 'print':
        window.print();
        break;
      case 'pdf':
        window.print(); // Browser's Save as PDF
        break;
      case 'close':
        deactivate();
        break;
    }
  }

  // ============================================================================
  // Delete Tool (PrintFriendly block-level deletion with hover preview)
  // ============================================================================

  function setupDeleteTool() {
    const body = printContainer.querySelector('#thea-pf-body');
    let hoveredElement = null;

    body.addEventListener('mouseover', (e) => {
      if (currentTool !== 'delete') return;
      const target = findDeletableElement(e.target);
      if (target && target !== body) {
        if (hoveredElement) hoveredElement.classList.remove('thea-pf-delete-preview');
        target.classList.add('thea-pf-delete-preview');
        hoveredElement = target;
      }
    });

    body.addEventListener('mouseout', (e) => {
      if (hoveredElement) {
        hoveredElement.classList.remove('thea-pf-delete-preview');
        hoveredElement = null;
      }
    });

    body.addEventListener('click', (e) => {
      if (currentTool !== 'delete') return;
      e.preventDefault();
      e.stopPropagation();

      const target = findDeletableElement(e.target);
      if (target && target !== body) {
        // Save for undo
        undoStack.push({
          type: 'delete',
          element: target,
          parent: target.parentNode,
          nextSibling: target.nextSibling
        });
        target.remove();
        updateUndoButton();
      }
    });
  }

  function findDeletableElement(el) {
    // Walk up to find a meaningful block element
    const body = printContainer.querySelector('#thea-pf-body');
    let current = el;
    while (current && current !== body) {
      const display = getComputedStyle(current).display;
      if (display === 'block' || display === 'flex' || display === 'grid' ||
          display === 'table' || display === 'list-item' ||
          current.tagName === 'P' || current.tagName === 'DIV' ||
          current.tagName === 'SECTION' || current.tagName === 'FIGURE' ||
          current.tagName === 'BLOCKQUOTE' || current.tagName === 'UL' ||
          current.tagName === 'OL' || current.tagName === 'TABLE' ||
          current.tagName === 'IMG' || current.tagName === 'H1' ||
          current.tagName === 'H2' || current.tagName === 'H3' ||
          current.tagName === 'H4' || current.tagName === 'H5' ||
          current.tagName === 'H6' || current.tagName === 'PRE') {
        return current;
      }
      current = current.parentElement;
    }
    return el;
  }

  // ============================================================================
  // Highlight Tool
  // ============================================================================

  function setupHighlightTool() {
    const body = printContainer.querySelector('#thea-pf-body');

    body.addEventListener('mouseup', () => {
      if (currentTool !== 'highlight') return;

      const selection = window.getSelection();
      if (!selection.rangeCount || selection.isCollapsed) return;

      const range = selection.getRangeAt(0);
      if (!body.contains(range.commonAncestorContainer)) return;

      const mark = document.createElement('mark');
      mark.className = 'thea-pf-highlight';

      // Save for undo
      undoStack.push({
        type: 'highlight',
        range: range.cloneRange(),
        mark
      });

      try {
        range.surroundContents(mark);
      } catch (e) {
        // Complex selection spanning elements
        const fragment = range.extractContents();
        mark.appendChild(fragment);
        range.insertNode(mark);
      }

      selection.removeAllRanges();
      updateUndoButton();
    });
  }

  // ============================================================================
  // Undo System
  // ============================================================================

  function performUndo() {
    if (undoStack.length === 0) return;

    const action = undoStack.pop();

    switch (action.type) {
      case 'delete':
        // Restore deleted element
        if (action.nextSibling) {
          action.parent.insertBefore(action.element, action.nextSibling);
        } else {
          action.parent.appendChild(action.element);
        }
        break;

      case 'highlight':
        // Remove highlight
        const mark = action.mark;
        const parent = mark.parentNode;
        while (mark.firstChild) {
          parent.insertBefore(mark.firstChild, mark);
        }
        parent.removeChild(mark);
        parent.normalize();
        break;

      case 'images':
        // Re-show images
        printContainer.querySelectorAll('#thea-pf-body img').forEach(img => {
          img.style.display = '';
        });
        break;
    }

    updateUndoButton();
  }

  function updateUndoButton() {
    const undoBtn = printContainer.querySelector('#thea-pf-undo');
    if (undoBtn) {
      undoBtn.disabled = undoStack.length === 0;
    }
  }

  // ============================================================================
  // Image Toggle
  // ============================================================================

  function toggleImages() {
    const images = printContainer.querySelectorAll('#thea-pf-body img');
    const anyVisible = Array.from(images).some(img => img.style.display !== 'none');

    if (anyVisible) {
      undoStack.push({ type: 'images' });
      images.forEach(img => { img.style.display = 'none'; });
    } else {
      images.forEach(img => { img.style.display = ''; });
    }
    updateUndoButton();
  }

  // ============================================================================
  // Message Handling
  // ============================================================================

  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (!sender.id || sender.id !== chrome.runtime.id) {
      sendResponse({ success: false });
      return true;
    }

    if (message.type === 'activatePrintFriendly') {
      activate();
      sendResponse({ success: true });
    } else if (message.type === 'deactivatePrintFriendly') {
      deactivate();
      sendResponse({ success: true });
    }
    return true;
  });

  // ============================================================================
  // Utilities
  // ============================================================================

  function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text || '';
    return div.innerHTML;
  }

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
  // Auto-listen for activation
  // ============================================================================

  // Also handle the original cleanPage message
  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === 'cleanPage') {
      activate();
      sendResponse({ success: true });
      return true;
    }
  });

})();
