(function() {
  'use strict';

  var UI = null;
  var active = false;
  var deleteMode = false;
  var highlightMode = false;
  var undoStack = [];
  var originalBodyOverflow = '';
  var imagesVisible = true;
  var currentFontSize = 18;

  var ARTICLE_SELECTORS = [
    'article', '[role="article"]', 'main', '#content', '#main-content',
    '.article-body', '.post-content', '.entry-content', '.story-body',
    '.article-content', '.page-content', '.blog-post', '.post-body'
  ];

  var REMOVE_SELECTORS = [
    'nav', 'header:not(article header)', 'footer:not(article footer)',
    'aside', '.sidebar', '.comments', '#comments', '.social-share',
    '.share-buttons', '.related-posts', '.advertisement', '.ad',
    '[class*="ad-"]', '[class*="sponsor"]', '.newsletter-signup',
    'script', 'style', 'noscript', 'iframe:not([src*="youtube"]):not([src*="vimeo"])',
    '.cookie-banner', '[class*="cookie"]', '[class*="popup"]',
    '.breadcrumb', '.pagination', '.tags', '.author-bio'
  ];

  function init() {
    UI = window.TheaModules.PrintFriendlyUI;
    if (!UI) return;

    browser.runtime.onMessage.addListener(function(message) {
      if (message.type === 'activatePrintFriendly') {
        if (active) {
          deactivate();
        } else {
          activate();
        }
      }
    });
  }

  function activate() {
    if (active) return;
    active = true;
    UI = window.TheaModules.PrintFriendlyUI;
    if (!UI) return;

    originalBodyOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    var content = extractContent();
    UI.createReaderOverlay(content);
    UI.createReaderToolbar();

    undoStack = [];
    currentFontSize = 18;
    imagesVisible = true;
  }

  function deactivate() {
    if (!active) return;
    active = false;

    disableDeleteMode();
    disableHighlightMode();

    document.body.style.overflow = originalBodyOverflow;

    if (UI) {
      UI.removeOverlay();
      UI.removeToolbar();
    }
    undoStack = [];
  }

  function extractContent() {
    var articleEl = null;
    for (var i = 0; i < ARTICLE_SELECTORS.length; i++) {
      articleEl = document.querySelector(ARTICLE_SELECTORS[i]);
      if (articleEl) break;
    }

    if (!articleEl) {
      articleEl = findLargestContentBlock();
    }

    if (!articleEl) {
      articleEl = document.body;
    }

    var clone = articleEl.cloneNode(true);

    REMOVE_SELECTORS.forEach(function(sel) {
      var els = clone.querySelectorAll(sel);
      els.forEach(function(el) {
        if (el.parentNode) el.parentNode.removeChild(el);
      });
    });

    var title = document.querySelector('h1') || document.querySelector('title');
    var titleHtml = '';
    if (title) {
      titleHtml = '<h1>' + escapeHtml(title.textContent.trim()) + '</h1>';
    }

    var meta = '';
    var timeEl = document.querySelector('time, [class*="date"], [class*="published"]');
    var authorEl = document.querySelector('[class*="author"], [rel="author"], .byline');
    if (authorEl || timeEl) {
      meta = '<p style="color: #888; font-size: 14px; margin-bottom: 24px;">';
      if (authorEl) meta += escapeHtml(authorEl.textContent.trim());
      if (authorEl && timeEl) meta += ' &middot; ';
      if (timeEl) meta += escapeHtml(timeEl.textContent.trim());
      meta += '</p>';
    }

    return titleHtml + meta + clone.innerHTML;
  }

  function findLargestContentBlock() {
    var candidates = document.querySelectorAll('div, section');
    var best = null;
    var bestScore = 0;

    candidates.forEach(function(el) {
      var text = el.textContent || '';
      var wordCount = text.split(/\s+/).filter(Boolean).length;
      var pCount = el.querySelectorAll('p').length;
      var score = wordCount + (pCount * 50);

      if (el.querySelectorAll('nav, header, footer').length > 0) {
        score *= 0.3;
      }

      if (score > bestScore) {
        bestScore = score;
        best = el;
      }
    });

    return best;
  }

  function enableDeleteMode() {
    deleteMode = true;
    disableHighlightMode();

    var overlay = document.getElementById('thea-reader-overlay');
    if (!overlay) return;

    overlay.addEventListener('mouseover', onDeleteMouseOver, true);
    overlay.addEventListener('mouseout', onDeleteMouseOut, true);
    overlay.addEventListener('click', onDeleteClick, true);
  }

  function disableDeleteMode() {
    deleteMode = false;
    var overlay = document.getElementById('thea-reader-overlay');
    if (!overlay) return;

    overlay.removeEventListener('mouseover', onDeleteMouseOver, true);
    overlay.removeEventListener('mouseout', onDeleteMouseOut, true);
    overlay.removeEventListener('click', onDeleteClick, true);

    var highlighted = overlay.querySelectorAll('.thea-delete-highlight');
    highlighted.forEach(function(el) {
      el.classList.remove('thea-delete-highlight');
    });
  }

  function onDeleteMouseOver(e) {
    if (!deleteMode) return;
    var el = e.target;
    if (el.className && typeof el.className === 'string' && el.className.indexOf('thea-') !== -1) return;
    if (el.classList) UI.createDeleteHighlight(el);
  }

  function onDeleteMouseOut(e) {
    if (!deleteMode) return;
    var el = e.target;
    if (el.classList) UI.removeDeleteHighlight(el);
  }

  function onDeleteClick(e) {
    if (!deleteMode) return;
    e.preventDefault();
    e.stopPropagation();

    var el = e.target;
    if (el.className && typeof el.className === 'string' && el.className.indexOf('thea-') !== -1) return;
    deleteElement(el);
  }

  function enableHighlightMode() {
    highlightMode = true;
    disableDeleteMode();

    document.addEventListener('mouseup', onHighlightMouseUp);
  }

  function disableHighlightMode() {
    highlightMode = false;
    document.removeEventListener('mouseup', onHighlightMouseUp);
  }

  function onHighlightMouseUp() {
    if (!highlightMode) return;
    var selection = window.getSelection();
    if (!selection || selection.isCollapsed) return;

    var range = selection.getRangeAt(0);
    var overlay = document.getElementById('thea-reader-overlay');
    if (!overlay || !overlay.contains(range.commonAncestorContainer)) return;

    UI.createTextHighlight(range);
    selection.removeAllRanges();
  }

  function deleteElement(el) {
    if (!el || !el.parentNode) return;
    undoStack.push({
      element: el,
      parent: el.parentNode,
      nextSibling: el.nextSibling
    });
    el.parentNode.removeChild(el);

    updateWordCountFromContent();
  }

  function undo() {
    if (undoStack.length === 0) return;
    var entry = undoStack.pop();
    if (entry.nextSibling && entry.parent.contains(entry.nextSibling)) {
      entry.parent.insertBefore(entry.element, entry.nextSibling);
    } else {
      entry.parent.appendChild(entry.element);
    }
    updateWordCountFromContent();
  }

  function adjustFontSize(delta) {
    currentFontSize = Math.max(12, Math.min(32, currentFontSize + delta));
    var content = document.querySelector('#thea-reader-overlay .thea-reader-content');
    if (content) {
      content.style.fontSize = currentFontSize + 'px';
    }
  }

  function toggleImages() {
    imagesVisible = !imagesVisible;
    var content = document.querySelector('#thea-reader-overlay .thea-reader-content');
    if (!content) return;
    var imgs = content.querySelectorAll('img, figure, picture, video');
    imgs.forEach(function(img) {
      img.style.display = imagesVisible ? '' : 'none';
    });
  }

  function printPage() {
    var toolbar = document.getElementById('thea-reader-toolbar');
    if (toolbar) toolbar.style.display = 'none';
    window.print();
    setTimeout(function() {
      if (toolbar) toolbar.style.display = '';
    }, 500);
  }

  function updateWordCountFromContent() {
    var content = document.querySelector('#thea-reader-overlay .thea-reader-content');
    if (content) {
      var count = content.textContent.split(/\s+/).filter(Boolean).length;
      UI.updateWordCount(count);
    }
  }

  function escapeHtml(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.PrintFriendly = {
    init: init,
    activate: activate,
    deactivate: deactivate,
    enableDeleteMode: enableDeleteMode,
    disableDeleteMode: disableDeleteMode,
    enableHighlightMode: enableHighlightMode,
    disableHighlightMode: disableHighlightMode,
    deleteElement: deleteElement,
    undo: undo,
    adjustFontSize: adjustFontSize,
    toggleImages: toggleImages,
    printPage: printPage,
    isActive: function() { return active; }
  };
})();
