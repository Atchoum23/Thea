(function() {
  'use strict';

  var THEA_GRADIENT = 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)';
  var SIDEBAR_ID = 'thea-ai-sidebar';
  var SIDEBAR_WIDTH = 380;

  function injectStyles() {
    if (document.getElementById('thea-sidebar-styles')) return;
    var style = document.createElement('style');
    style.id = 'thea-sidebar-styles';
    style.textContent = [
      '#' + SIDEBAR_ID + ' {',
      '  position: fixed; top: 0; right: 0; width: ' + SIDEBAR_WIDTH + 'px; height: 100vh;',
      '  z-index: 2147483642; background: #1e1e2e; border-left: 1px solid #313244;',
      '  box-shadow: -4px 0 24px rgba(0,0,0,0.3); display: flex; flex-direction: column;',
      '  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;',
      '  transform: translateX(100%); transition: transform 0.3s ease;',
      '}',
      '#' + SIDEBAR_ID + '.thea-open { transform: translateX(0); }',
      '',
      '.thea-sidebar-header {',
      '  padding: 14px 16px; display: flex; align-items: center; justify-content: space-between;',
      '  border-bottom: 1px solid #313244; flex-shrink: 0;',
      '}',
      '.thea-sidebar-title {',
      '  font-size: 15px; font-weight: 700;',
      '  background: ' + THEA_GRADIENT + '; -webkit-background-clip: text; -webkit-text-fill-color: transparent;',
      '}',
      '.thea-sidebar-close {',
      '  background: none; border: none; color: #6c7086; cursor: pointer;',
      '  font-size: 18px; padding: 4px 8px; border-radius: 4px;',
      '}',
      '.thea-sidebar-close:hover { color: #cdd6f4; background: #313244; }',
      '',
      '.thea-sidebar-messages {',
      '  flex: 1; overflow-y: auto; padding: 16px; display: flex; flex-direction: column; gap: 12px;',
      '}',
      '.thea-sidebar-messages::-webkit-scrollbar { width: 6px; }',
      '.thea-sidebar-messages::-webkit-scrollbar-track { background: transparent; }',
      '.thea-sidebar-messages::-webkit-scrollbar-thumb { background: #313244; border-radius: 3px; }',
      '',
      '.thea-msg {',
      '  padding: 10px 14px; border-radius: 12px; max-width: 90%; word-break: break-word;',
      '  font-size: 14px; line-height: 1.6;',
      '}',
      '.thea-msg-user {',
      '  background: ' + THEA_GRADIENT + '; color: #fff; align-self: flex-end; border-bottom-right-radius: 4px;',
      '}',
      '.thea-msg-assistant {',
      '  background: #313244; color: #cdd6f4; align-self: flex-start; border-bottom-left-radius: 4px;',
      '}',
      '.thea-msg-header {',
      '  display: flex; align-items: center; gap: 6px; margin-bottom: 6px; font-size: 11px; opacity: 0.7;',
      '}',
      '.thea-msg-avatar { width: 18px; height: 18px; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; font-size: 10px; }',
      '.thea-msg-model { font-size: 11px; opacity: 0.6; margin-top: 4px; }',
      '.thea-msg-copy {',
      '  float: right; background: none; border: none; color: #6c7086; cursor: pointer;',
      '  font-size: 12px; padding: 2px 6px; border-radius: 4px; opacity: 0; transition: opacity 0.2s;',
      '}',
      '.thea-msg:hover .thea-msg-copy { opacity: 1; }',
      '.thea-msg-copy:hover { color: #cdd6f4; background: rgba(255,255,255,0.1); }',
      '',
      '.thea-msg-content h1, .thea-msg-content h2, .thea-msg-content h3 { margin: 8px 0 4px; }',
      '.thea-msg-content h1 { font-size: 16px; }',
      '.thea-msg-content h2 { font-size: 15px; }',
      '.thea-msg-content h3 { font-size: 14px; }',
      '.thea-msg-content p { margin: 4px 0; }',
      '.thea-msg-content code { background: rgba(0,0,0,0.3); padding: 1px 5px; border-radius: 3px; font-family: "SF Mono", Menlo, monospace; font-size: 0.9em; }',
      '.thea-msg-content pre { background: rgba(0,0,0,0.3); padding: 10px; border-radius: 6px; overflow-x: auto; margin: 8px 0; }',
      '.thea-msg-content pre code { background: none; padding: 0; }',
      '.thea-msg-content ul, .thea-msg-content ol { padding-left: 20px; margin: 4px 0; }',
      '.thea-msg-content li { margin: 2px 0; }',
      '.thea-msg-content a { color: #89b4fa; text-decoration: underline; }',
      '.thea-msg-content strong { font-weight: 700; }',
      '.thea-msg-content em { font-style: italic; }',
      '.thea-msg-content blockquote { border-left: 3px solid #667eea; padding-left: 10px; margin: 6px 0; opacity: 0.8; }',
      '',
      '.thea-sidebar-input-area {',
      '  padding: 12px 16px; border-top: 1px solid #313244; flex-shrink: 0;',
      '}',
      '.thea-sidebar-input-row { display: flex; gap: 8px; }',
      '.thea-sidebar-input {',
      '  flex: 1; background: #313244; border: 1px solid #45475a; border-radius: 10px;',
      '  color: #cdd6f4; font-size: 14px; padding: 10px 14px; outline: none;',
      '  resize: none; font-family: inherit; min-height: 40px; max-height: 120px;',
      '}',
      '.thea-sidebar-input:focus { border-color: #667eea; }',
      '.thea-sidebar-input::placeholder { color: #6c7086; }',
      '.thea-sidebar-send {',
      '  background: ' + THEA_GRADIENT + '; border: none; color: #fff;',
      '  width: 40px; height: 40px; border-radius: 10px; cursor: pointer;',
      '  display: flex; align-items: center; justify-content: center; font-size: 18px;',
      '  flex-shrink: 0; align-self: flex-end;',
      '}',
      '.thea-sidebar-send:hover { opacity: 0.9; }',
      '.thea-sidebar-send:disabled { opacity: 0.4; cursor: not-allowed; }',
      '.thea-sidebar-hints {',
      '  margin-top: 6px; font-size: 11px; color: #6c7086;',
      '}',
      '.thea-sidebar-hints span { cursor: pointer; }',
      '.thea-sidebar-hints span:hover { color: #cdd6f4; }',
      '',
      '.thea-model-selector {',
      '  background: #313244; border: 1px solid #45475a; border-radius: 6px;',
      '  color: #cdd6f4; font-size: 12px; padding: 4px 8px; outline: none; cursor: pointer;',
      '}',
      '',
      '.thea-typing { display: flex; gap: 4px; align-items: center; padding: 10px 14px; }',
      '.thea-typing-dot {',
      '  width: 6px; height: 6px; border-radius: 50%; background: #6c7086;',
      '  animation: thea-typing-bounce 1.4s ease-in-out infinite;',
      '}',
      '.thea-typing-dot:nth-child(2) { animation-delay: 0.2s; }',
      '.thea-typing-dot:nth-child(3) { animation-delay: 0.4s; }',
      '@keyframes thea-typing-bounce { 0%, 60%, 100% { transform: translateY(0); } 30% { transform: translateY(-6px); } }',
      '',
      '.thea-followup-btn {',
      '  background: #313244; border: 1px solid #45475a; border-radius: 8px;',
      '  color: #cdd6f4; font-size: 13px; padding: 8px 14px; cursor: pointer;',
      '  text-align: left; width: 100%; transition: background 0.15s; margin-top: 4px;',
      '}',
      '.thea-followup-btn:hover { background: #45475a; }',
      '',
      '.thea-create-menu {',
      '  background: #313244; border-radius: 8px; padding: 8px; margin-top: 8px;',
      '}',
      '.thea-create-item {',
      '  padding: 6px 10px; border-radius: 6px; cursor: pointer; font-size: 13px; color: #cdd6f4;',
      '}',
      '.thea-create-item:hover { background: #45475a; }'
    ].join('\n');
    document.head.appendChild(style);
  }

  function createSidebarContainer() {
    injectStyles();
    var existing = document.getElementById(SIDEBAR_ID);
    if (existing) return existing;

    var sidebar = document.createElement('div');
    sidebar.id = SIDEBAR_ID;

    var header = document.createElement('div');
    header.className = 'thea-sidebar-header';
    header.innerHTML =
      '<span class="thea-sidebar-title">Thea AI</span>' +
      '<button class="thea-sidebar-close" aria-label="Close">&times;</button>';

    var messages = document.createElement('div');
    messages.className = 'thea-sidebar-messages';

    var inputArea = createInputArea();

    sidebar.appendChild(header);
    sidebar.appendChild(messages);
    sidebar.appendChild(inputArea);
    document.body.appendChild(sidebar);

    header.querySelector('.thea-sidebar-close').addEventListener('click', function() {
      var ai = window.TheaModules.AISidebar;
      if (ai) ai.toggle();
    });

    return sidebar;
  }

  function createMessageBubble(role, content, model) {
    var msg = document.createElement('div');
    msg.className = 'thea-msg thea-msg-' + role;

    var headerHtml = '';
    if (role === 'assistant') {
      headerHtml = '<div class="thea-msg-header">' +
        '<span class="thea-msg-avatar" style="background: ' + THEA_GRADIENT + ';">T</span>' +
        '<span>Thea</span></div>';
    }

    var copyBtn = '<button class="thea-msg-copy" title="Copy">Copy</button>';
    var renderedContent = role === 'assistant' ? renderMarkdown(content) : escapeHtml(content);

    msg.innerHTML = headerHtml +
      '<div class="thea-msg-content">' + copyBtn + renderedContent + '</div>' +
      (model ? '<div class="thea-msg-model">' + escapeHtml(model) + '</div>' : '');

    msg.querySelector('.thea-msg-copy').addEventListener('click', function() {
      navigator.clipboard.writeText(content).then(function() {
        var notify = window.TheaModules.Notification;
        if (notify) notify.showNotification('Copied', 'Message copied to clipboard', 1500);
      });
    });

    return msg;
  }

  function createModelSelector(models) {
    var select = document.createElement('select');
    select.className = 'thea-model-selector';
    models.forEach(function(m) {
      var option = document.createElement('option');
      option.value = m.id;
      option.textContent = m.name;
      select.appendChild(option);
    });
    return select;
  }

  function createInputArea() {
    var area = document.createElement('div');
    area.className = 'thea-sidebar-input-area';

    var row = document.createElement('div');
    row.className = 'thea-sidebar-input-row';

    var input = document.createElement('textarea');
    input.className = 'thea-sidebar-input';
    input.placeholder = 'Ask Thea anything...';
    input.rows = 1;

    var sendBtn = document.createElement('button');
    sendBtn.className = 'thea-sidebar-send';
    sendBtn.innerHTML = '\u2191';
    sendBtn.title = 'Send message';

    row.appendChild(input);
    row.appendChild(sendBtn);

    var hints = document.createElement('div');
    hints.className = 'thea-sidebar-hints';
    hints.innerHTML = [
      '<span data-cmd="/summarize">/summarize</span> ',
      '<span data-cmd="/explain">/explain</span> ',
      '<span data-cmd="/translate">/translate</span> ',
      '<span data-cmd="/code">/code</span> ',
      '<span data-cmd="/research">/research</span> ',
      '<span data-cmd="/create">/create</span>'
    ].join(' ');

    area.appendChild(row);
    area.appendChild(hints);

    input.addEventListener('input', function() {
      input.style.height = 'auto';
      input.style.height = Math.min(input.scrollHeight, 120) + 'px';
    });

    input.addEventListener('keydown', function(e) {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        var ai = window.TheaModules.AISidebar;
        if (ai && input.value.trim()) {
          ai.sendMessage(input.value.trim());
          input.value = '';
          input.style.height = 'auto';
        }
      }
    });

    sendBtn.addEventListener('click', function() {
      var ai = window.TheaModules.AISidebar;
      if (ai && input.value.trim()) {
        ai.sendMessage(input.value.trim());
        input.value = '';
        input.style.height = 'auto';
      }
    });

    hints.addEventListener('click', function(e) {
      var cmd = e.target.getAttribute('data-cmd');
      if (cmd) {
        input.value = cmd + ' ';
        input.focus();
      }
    });

    return area;
  }

  function createFollowUpPrompt() {
    var container = document.createElement('div');
    container.style.cssText = 'display: flex; flex-direction: column; gap: 4px; margin-top: 4px;';

    var suggestions = [
      'Tell me more about this',
      'Give me practical examples',
      'What are the alternatives?'
    ];

    suggestions.forEach(function(text) {
      var btn = document.createElement('button');
      btn.className = 'thea-followup-btn';
      btn.textContent = text;
      btn.addEventListener('click', function() {
        var ai = window.TheaModules.AISidebar;
        if (ai) ai.handleFollowUp(text);
        if (container.parentNode) container.parentNode.removeChild(container);
      });
      container.appendChild(btn);
    });

    return container;
  }

  function createContentCreationMenu() {
    var menu = document.createElement('div');
    menu.className = 'thea-create-menu';

    var templates = [
      { id: 'summary', label: 'Summary' },
      { id: 'outline', label: 'Outline' },
      { id: 'blog_post', label: 'Blog Post' },
      { id: 'email', label: 'Email Draft' },
      { id: 'social', label: 'Social Post' },
      { id: 'report', label: 'Report' }
    ];

    templates.forEach(function(t) {
      var item = document.createElement('div');
      item.className = 'thea-create-item';
      item.textContent = t.label;
      item.addEventListener('click', function() {
        var ai = window.TheaModules.AISidebar;
        if (ai) ai.handleContentCreation(t.id);
        if (menu.parentNode) menu.parentNode.removeChild(menu);
      });
      menu.appendChild(item);
    });

    return menu;
  }

  function renderMarkdown(text) {
    if (!text) return '';
    var html = escapeHtml(text);

    // Code blocks
    html = html.replace(/```(\w*)\n([\s\S]*?)```/g, function(_, lang, code) {
      return '<pre><code class="language-' + lang + '">' + code + '</code></pre>';
    });
    // Inline code
    html = html.replace(/`([^`]+)`/g, '<code>$1</code>');
    // Headers
    html = html.replace(/^### (.+)$/gm, '<h3>$1</h3>');
    html = html.replace(/^## (.+)$/gm, '<h2>$1</h2>');
    html = html.replace(/^# (.+)$/gm, '<h1>$1</h1>');
    // Bold + Italic
    html = html.replace(/\*\*\*(.+?)\*\*\*/g, '<strong><em>$1</em></strong>');
    html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    html = html.replace(/\*(.+?)\*/g, '<em>$1</em>');
    // Links
    html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');
    // Blockquotes
    html = html.replace(/^&gt; (.+)$/gm, '<blockquote>$1</blockquote>');
    // Unordered lists
    html = html.replace(/^[*-] (.+)$/gm, '<li>$1</li>');
    html = html.replace(/(<li>.*<\/li>\n?)+/g, '<ul>$&</ul>');
    // Ordered lists
    html = html.replace(/^\d+\. (.+)$/gm, '<li>$1</li>');
    // Paragraphs
    html = html.replace(/\n\n/g, '</p><p>');
    html = '<p>' + html + '</p>';
    // Line breaks
    html = html.replace(/\n/g, '<br>');
    // Clean up empty paragraphs
    html = html.replace(/<p><\/p>/g, '');

    return html;
  }

  function showTypingIndicator() {
    var messages = document.querySelector('#' + SIDEBAR_ID + ' .thea-sidebar-messages');
    if (!messages) return null;

    var indicator = document.createElement('div');
    indicator.className = 'thea-msg thea-msg-assistant thea-typing';
    indicator.id = 'thea-typing-indicator';
    indicator.innerHTML =
      '<div class="thea-typing-dot"></div>' +
      '<div class="thea-typing-dot"></div>' +
      '<div class="thea-typing-dot"></div>';
    messages.appendChild(indicator);
    scrollToBottom(messages);
    return indicator;
  }

  function removeTypingIndicator() {
    var indicator = document.getElementById('thea-typing-indicator');
    if (indicator && indicator.parentNode) {
      indicator.parentNode.removeChild(indicator);
    }
  }

  function scrollToBottom(container) {
    if (!container) {
      container = document.querySelector('#' + SIDEBAR_ID + ' .thea-sidebar-messages');
    }
    if (container) {
      container.scrollTop = container.scrollHeight;
    }
  }

  function escapeHtml(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.AISidebarUI = {
    createSidebarContainer: createSidebarContainer,
    createMessageBubble: createMessageBubble,
    createModelSelector: createModelSelector,
    createInputArea: createInputArea,
    createFollowUpPrompt: createFollowUpPrompt,
    createContentCreationMenu: createContentCreationMenu,
    renderMarkdown: renderMarkdown,
    showTypingIndicator: showTypingIndicator,
    removeTypingIndicator: removeTypingIndicator,
    scrollToBottom: scrollToBottom,
    SIDEBAR_ID: SIDEBAR_ID
  };
})();
