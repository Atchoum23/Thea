(function() {
  'use strict';

  var THEA_GRADIENT = 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)';
  var TOOLBAR_ID = 'thea-reader-toolbar';
  var OVERLAY_ID = 'thea-reader-overlay';
  var activeToolbar = null;
  var activeOverlay = null;

  function injectStyles() {
    if (document.getElementById('thea-print-friendly-styles')) return;
    var style = document.createElement('style');
    style.id = 'thea-print-friendly-styles';
    style.textContent = [
      '#' + TOOLBAR_ID + ' {',
      '  position: fixed; top: 16px; right: 16px; z-index: 2147483644;',
      '  background: #1e1e2e; border: 1px solid #313244; border-radius: 12px;',
      '  padding: 8px; box-shadow: 0 8px 32px rgba(0,0,0,0.4);',
      '  font-family: -apple-system, BlinkMacSystemFont, sans-serif;',
      '  display: flex; gap: 4px; align-items: center; flex-wrap: wrap; max-width: 480px;',
      '}',
      '#' + TOOLBAR_ID + ' button {',
      '  background: #313244; border: none; color: #cdd6f4; cursor: pointer;',
      '  padding: 6px 12px; border-radius: 6px; font-size: 13px;',
      '  transition: all 0.15s ease; white-space: nowrap;',
      '}',
      '#' + TOOLBAR_ID + ' button:hover { background: #45475a; color: #fff; }',
      '#' + TOOLBAR_ID + ' button.thea-active {',
      '  background: ' + THEA_GRADIENT + '; color: #fff;',
      '}',
      '#' + TOOLBAR_ID + ' .thea-divider {',
      '  width: 1px; height: 24px; background: #313244; margin: 0 4px;',
      '}',
      '#' + TOOLBAR_ID + ' .thea-word-count {',
      '  color: #6c7086; font-size: 11px; padding: 0 8px;',
      '}',
      '',
      '#' + OVERLAY_ID + ' {',
      '  position: fixed; top: 0; left: 0; width: 100%; height: 100%;',
      '  z-index: 2147483643; background: #fafafa; overflow-y: auto;',
      '}',
      '#' + OVERLAY_ID + ' .thea-reader-content {',
      '  max-width: 720px; margin: 80px auto 60px; padding: 0 24px;',
      '  font-family: Georgia, "Times New Roman", serif;',
      '  font-size: 18px; line-height: 1.8; color: #2c2c2c;',
      '}',
      '#' + OVERLAY_ID + ' .thea-reader-content h1 { font-size: 32px; line-height: 1.3; margin-bottom: 16px; font-family: -apple-system, sans-serif; }',
      '#' + OVERLAY_ID + ' .thea-reader-content h2 { font-size: 26px; line-height: 1.35; margin-top: 32px; font-family: -apple-system, sans-serif; }',
      '#' + OVERLAY_ID + ' .thea-reader-content h3 { font-size: 22px; line-height: 1.4; margin-top: 24px; font-family: -apple-system, sans-serif; }',
      '#' + OVERLAY_ID + ' .thea-reader-content p { margin-bottom: 18px; }',
      '#' + OVERLAY_ID + ' .thea-reader-content img { max-width: 100%; height: auto; border-radius: 8px; margin: 16px 0; }',
      '#' + OVERLAY_ID + ' .thea-reader-content blockquote {',
      '  border-left: 4px solid #667eea; padding-left: 20px; margin: 20px 0;',
      '  color: #555; font-style: italic;',
      '}',
      '#' + OVERLAY_ID + ' .thea-reader-content code {',
      '  background: #f0f0f0; padding: 2px 6px; border-radius: 4px;',
      '  font-family: "SF Mono", Menlo, monospace; font-size: 0.9em;',
      '}',
      '#' + OVERLAY_ID + ' .thea-reader-content pre { background: #282c34; color: #abb2bf; padding: 16px; border-radius: 8px; overflow-x: auto; }',
      '#' + OVERLAY_ID + ' .thea-reader-content pre code { background: none; color: inherit; padding: 0; }',
      '#' + OVERLAY_ID + ' .thea-reader-content a { color: #667eea; }',
      '#' + OVERLAY_ID + ' .thea-reader-content ul, #' + OVERLAY_ID + ' .thea-reader-content ol { margin-bottom: 18px; padding-left: 24px; }',
      '#' + OVERLAY_ID + ' .thea-reader-content li { margin-bottom: 6px; }',
      '',
      '.thea-delete-highlight { outline: 3px solid #f38ba8 !important; outline-offset: 2px; cursor: pointer !important; }',
      '.thea-text-highlight { background: #fde68a !important; border-radius: 2px; }',
      '',
      '@media print {',
      '  #' + TOOLBAR_ID + ' { display: none !important; }',
      '  #' + OVERLAY_ID + ' { position: static; background: white; }',
      '  #' + OVERLAY_ID + ' .thea-reader-content { margin: 0; max-width: 100%; font-size: 12pt; }',
      '}'
    ].join('\n');
    document.head.appendChild(style);
  }

  function createReaderToolbar() {
    injectStyles();
    if (activeToolbar) return activeToolbar;

    var toolbar = document.createElement('div');
    toolbar.id = TOOLBAR_ID;

    var buttons = [
      { label: 'A-', title: 'Decrease font size', action: 'fontMinus' },
      { label: 'A+', title: 'Increase font size', action: 'fontPlus' },
      { divider: true },
      { label: '\uD83D\uDDBC', title: 'Toggle images', action: 'toggleImages' },
      { label: '\uD83D\uDFA8', title: 'Highlight mode', action: 'highlight', toggle: true },
      { label: '\u2702', title: 'Delete mode', action: 'delete', toggle: true },
      { label: '\u21A9', title: 'Undo', action: 'undo' },
      { divider: true },
      { label: '\uD83D\uDCF7', title: 'Screenshot', action: 'screenshot' },
      { label: '\uD83D\uDDA8', title: 'Print', action: 'print' },
      { label: '\u2715', title: 'Close reader', action: 'close' }
    ];

    buttons.forEach(function(def) {
      if (def.divider) {
        var div = document.createElement('span');
        div.className = 'thea-divider';
        toolbar.appendChild(div);
        return;
      }
      var btn = document.createElement('button');
      btn.textContent = def.label;
      btn.title = def.title;
      btn.setAttribute('data-action', def.action);
      if (def.toggle) btn.setAttribute('data-toggle', 'true');
      toolbar.appendChild(btn);
    });

    var wordCount = document.createElement('span');
    wordCount.className = 'thea-word-count';
    wordCount.textContent = '0 words';
    toolbar.appendChild(wordCount);

    toolbar.addEventListener('click', function(e) {
      var btn = e.target.closest('button');
      if (!btn) return;
      var action = btn.getAttribute('data-action');
      var pf = window.TheaModules.PrintFriendly;
      if (!pf) return;

      if (btn.getAttribute('data-toggle') === 'true') {
        btn.classList.toggle('thea-active');
      }

      switch (action) {
        case 'fontMinus': pf.adjustFontSize(-2); break;
        case 'fontPlus': pf.adjustFontSize(2); break;
        case 'toggleImages': pf.toggleImages(); break;
        case 'highlight':
          if (btn.classList.contains('thea-active')) {
            pf.enableHighlightMode();
          } else {
            pf.disableHighlightMode();
          }
          break;
        case 'delete':
          if (btn.classList.contains('thea-active')) {
            pf.enableDeleteMode();
          } else {
            pf.disableDeleteMode();
          }
          break;
        case 'undo': pf.undo(); break;
        case 'screenshot': takeScreenshot(); break;
        case 'print': pf.printPage(); break;
        case 'close': pf.deactivate(); break;
      }
    });

    document.body.appendChild(toolbar);
    activeToolbar = toolbar;
    return toolbar;
  }

  function createReaderOverlay(content) {
    injectStyles();
    if (activeOverlay) {
      activeOverlay.querySelector('.thea-reader-content').innerHTML = content;
      return activeOverlay;
    }

    var overlay = document.createElement('div');
    overlay.id = OVERLAY_ID;
    var contentDiv = document.createElement('div');
    contentDiv.className = 'thea-reader-content';
    contentDiv.innerHTML = content;
    overlay.appendChild(contentDiv);
    document.body.appendChild(overlay);
    activeOverlay = overlay;

    var wordCount = contentDiv.textContent.split(/\s+/).filter(Boolean).length;
    updateWordCount(wordCount);

    return overlay;
  }

  function createDeleteHighlight(element) {
    element.classList.add('thea-delete-highlight');
  }

  function removeDeleteHighlight(element) {
    element.classList.remove('thea-delete-highlight');
  }

  function createTextHighlight(range) {
    var span = document.createElement('span');
    span.className = 'thea-text-highlight';
    try {
      range.surroundContents(span);
    } catch (e) {
      var fragment = range.extractContents();
      span.appendChild(fragment);
      range.insertNode(span);
    }
    return span;
  }

  function takeScreenshot() {
    var notify = window.TheaModules.Notification;
    if (notify) notify.showLoading('Taking screenshot...');

    var overlay = document.getElementById(OVERLAY_ID);
    if (!overlay) {
      if (notify) {
        notify.hideLoading();
        notify.showNotification('Screenshot', 'No reader view active', 3000);
      }
      return;
    }

    try {
      var content = overlay.querySelector('.thea-reader-content');
      var canvas = document.createElement('canvas');
      var scale = 2;
      canvas.width = content.scrollWidth * scale;
      canvas.height = Math.min(content.scrollHeight, 8000) * scale;
      var ctx = canvas.getContext('2d');
      ctx.scale(scale, scale);
      ctx.fillStyle = '#fafafa';
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      canvas.toBlob(function(blob) {
        if (notify) notify.hideLoading();
        if (blob) {
          var url = URL.createObjectURL(blob);
          var a = document.createElement('a');
          a.href = url;
          a.download = 'thea-reader-' + Date.now() + '.png';
          a.click();
          setTimeout(function() { URL.revokeObjectURL(url); }, 5000);
          if (notify) notify.showNotification('Screenshot', 'Screenshot saved', 3000);
        }
      }, 'image/png');
    } catch (e) {
      if (notify) {
        notify.hideLoading();
        notify.showNotification('Screenshot', 'Failed to take screenshot', 3000);
      }
    }
  }

  function updateWordCount(count) {
    var el = document.querySelector('#' + TOOLBAR_ID + ' .thea-word-count');
    if (el) {
      var readTime = Math.ceil(count / 200);
      el.textContent = count + ' words ~ ' + readTime + ' min';
    }
  }

  function removeToolbar() {
    if (activeToolbar && activeToolbar.parentNode) {
      activeToolbar.parentNode.removeChild(activeToolbar);
    }
    activeToolbar = null;
  }

  function removeOverlay() {
    if (activeOverlay && activeOverlay.parentNode) {
      activeOverlay.parentNode.removeChild(activeOverlay);
    }
    activeOverlay = null;
  }

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.PrintFriendlyUI = {
    createReaderToolbar: createReaderToolbar,
    createReaderOverlay: createReaderOverlay,
    createDeleteHighlight: createDeleteHighlight,
    removeDeleteHighlight: removeDeleteHighlight,
    createTextHighlight: createTextHighlight,
    takeScreenshot: takeScreenshot,
    updateWordCount: updateWordCount,
    removeToolbar: removeToolbar,
    removeOverlay: removeOverlay
  };
})();
