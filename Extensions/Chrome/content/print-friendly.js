/**
 * Thea PrintFriendly Engine - Logic Module
 *
 * Reader mode logic, click-to-delete, undo stack, clean print,
 * content extraction, highlight tool, image toggle.
 *
 * Depends on: print-friendly-ui.js (loaded before this file)
 */

(function() {
  'use strict';

  window.TheaModules = window.TheaModules || {};
  const UI = window.TheaModules.printUI;

  let printContainer = null;
  let undoStack = [];
  let currentTool = null; // 'delete' | 'highlight' | null
  let originalContent = null;

  // ============================================================================
  // Activation
  // ============================================================================

  function activate() {
    if (printContainer) return;

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
  // Build Print UI
  // ============================================================================

  function buildPrintUI(content) {
    const wordCount = content.textContent.trim().split(/\s+/).filter(Boolean).length;
    const readTime = Math.max(1, Math.ceil(wordCount / 250));

    printContainer = UI.buildPrintViewDOM(
      document.title,
      window.location.hostname,
      wordCount,
      readTime,
      currentTool
    );

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
        window.print();
        break;
      case 'close':
        deactivate();
        break;
    }
  }

  // ============================================================================
  // Delete Tool
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

      undoStack.push({
        type: 'highlight',
        range: range.cloneRange(),
        mark
      });

      try {
        range.surroundContents(mark);
      } catch (e) {
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
        if (action.nextSibling) {
          action.parent.insertBefore(action.element, action.nextSibling);
        } else {
          action.parent.appendChild(action.element);
        }
        break;

      case 'highlight':
        const mark = action.mark;
        const parent = mark.parentNode;
        while (mark.firstChild) {
          parent.insertBefore(mark.firstChild, mark);
        }
        parent.removeChild(mark);
        parent.normalize();
        break;

      case 'images':
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
    } else if (message.type === 'cleanPage') {
      activate();
      sendResponse({ success: true });
      return true;
    }
    return true;
  });

})();
