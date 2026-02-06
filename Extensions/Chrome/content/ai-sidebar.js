/**
 * Thea AI Sidebar
 *
 * Inspired by: Sider for Chrome, Claude for Chrome
 *
 * Features:
 * - Persistent sidebar on any webpage
 * - Multi-model support (routes to Thea's orchestrator)
 * - Page-aware context (reads current page content)
 * - Selection-aware (explain/translate/summarize selected text)
 * - Chat with page content (ChatPDF-like for any page)
 * - YouTube video summarization
 * - Deep research mode (multi-source synthesis)
 * - Conversation history with search
 * - Slash commands (/summarize, /translate, /explain, /code)
 * - Streaming responses
 * - Copy/share responses
 * - Keyboard shortcut to open (Alt+Space)
 */

(function() {
  'use strict';

  let sidebarElement = null;
  let isOpen = false;
  let conversations = [];
  let currentConversation = [];
  let isStreaming = false;
  let pageContext = null;

  // ============================================================================
  // Slash Commands
  // ============================================================================

  const SLASH_COMMANDS = {
    '/summarize': { label: 'Summarize page', prompt: 'Summarize the following page content concisely:' },
    '/explain': { label: 'Explain selection', prompt: 'Explain the following in simple terms:' },
    '/translate': { label: 'Translate', prompt: 'Translate the following to English (or to the user\'s language if already English):' },
    '/code': { label: 'Explain code', prompt: 'Explain this code step by step:' },
    '/fix': { label: 'Fix writing', prompt: 'Fix any grammar, spelling, or style issues in:' },
    '/key-points': { label: 'Key points', prompt: 'Extract the key points from:' },
    '/eli5': { label: 'ELI5', prompt: 'Explain like I\'m 5:' },
    '/rewrite': { label: 'Rewrite', prompt: 'Rewrite the following more clearly and professionally:' },
    '/action-items': { label: 'Action items', prompt: 'Extract action items from:' },
    '/research': { label: 'Deep research', prompt: 'Research this topic thoroughly, citing sources:' }
  };

  // ============================================================================
  // Sidebar UI
  // ============================================================================

  function createSidebar() {
    if (sidebarElement) return;

    sidebarElement = document.createElement('div');
    sidebarElement.id = 'thea-ai-sidebar';
    sidebarElement.innerHTML = `
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

    document.body.appendChild(sidebarElement);
    setupSidebarEvents();
    loadPageContext();
  }

  // ============================================================================
  // Event Setup
  // ============================================================================

  function setupSidebarEvents() {
    const input = sidebarElement.querySelector('#thea-sidebar-input');
    const sendBtn = sidebarElement.querySelector('#thea-sidebar-send');

    // Send on Enter (Shift+Enter for newline)
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        sendMessage();
      }
    });

    // Auto-resize textarea
    input.addEventListener('input', () => {
      input.style.height = 'auto';
      input.style.height = Math.min(input.scrollHeight, 120) + 'px';
      handleSlashMenu(input.value);
    });

    sendBtn.addEventListener('click', sendMessage);

    // Header actions
    sidebarElement.querySelector('[data-action="close"]').addEventListener('click', toggleSidebar);
    sidebarElement.querySelector('[data-action="new-chat"]').addEventListener('click', newConversation);
    sidebarElement.querySelector('[data-action="history"]').addEventListener('click', showHistory);

    // Quick action chips
    sidebarElement.querySelectorAll('.thea-quick-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        executeSlashCommand(chip.dataset.cmd);
      });
    });
  }

  // ============================================================================
  // Slash Menu
  // ============================================================================

  function handleSlashMenu(value) {
    const menu = sidebarElement.querySelector('#thea-slash-menu');

    if (value.startsWith('/') && !value.includes(' ')) {
      const filter = value.toLowerCase();
      const matches = Object.entries(SLASH_COMMANDS).filter(([cmd]) =>
        cmd.startsWith(filter)
      );

      if (matches.length > 0) {
        menu.innerHTML = matches.map(([cmd, info]) => `
          <div class="thea-slash-item" data-cmd="${cmd}">
            <span class="thea-slash-cmd">${cmd}</span>
            <span class="thea-slash-desc">${info.label}</span>
          </div>
        `).join('');

        menu.style.display = 'block';

        menu.querySelectorAll('.thea-slash-item').forEach(item => {
          item.addEventListener('click', () => {
            executeSlashCommand(item.dataset.cmd);
            menu.style.display = 'none';
          });
        });
        return;
      }
    }

    menu.style.display = 'none';
  }

  function executeSlashCommand(cmd) {
    const command = SLASH_COMMANDS[cmd];
    if (!command) return;

    const selection = window.getSelection()?.toString()?.trim();
    const context = selection || pageContext?.content?.substring(0, 8000) || '';

    const fullPrompt = `${command.prompt}\n\n${context}`;
    sendMessageDirect(fullPrompt, cmd);

    const input = sidebarElement.querySelector('#thea-sidebar-input');
    input.value = '';
    input.style.height = 'auto';
  }

  // ============================================================================
  // Page Context
  // ============================================================================

  function loadPageContext() {
    const titleEl = sidebarElement.querySelector('#thea-sidebar-page-title');

    pageContext = {
      title: document.title,
      url: window.location.href,
      domain: window.location.hostname,
      content: extractPageText(),
      type: detectPageType()
    };

    titleEl.textContent = pageContext.title || pageContext.domain;

    // Update quick actions based on page type
    updateQuickActions(pageContext.type);
  }

  function extractPageText() {
    const article = document.querySelector('article') ||
                    document.querySelector('main') ||
                    document.querySelector('[role="main"]');
    const source = article || document.body;
    return source.innerText.substring(0, 15000);
  }

  function detectPageType() {
    const url = window.location.href;
    if (url.includes('youtube.com/watch') || url.includes('youtu.be/')) return 'youtube';
    if (url.includes('github.com')) return 'github';
    if (document.querySelector('article')) return 'article';
    if (document.querySelector('pre code')) return 'code';
    if (document.querySelector('.product') || document.querySelector('[itemprop="price"]')) return 'product';
    return 'general';
  }

  function updateQuickActions(pageType) {
    const quickContainer = sidebarElement.querySelector('#thea-sidebar-quick');
    let chips = [
      { cmd: '/summarize', label: 'Summarize' },
      { cmd: '/key-points', label: 'Key Points' },
      { cmd: '/action-items', label: 'Actions' },
      { cmd: '/explain', label: 'Explain' }
    ];

    if (pageType === 'youtube') {
      chips = [
        { cmd: '/summarize', label: 'Summarize Video' },
        { cmd: '/key-points', label: 'Key Points' },
        { cmd: '/action-items', label: 'Timestamps' }
      ];
    } else if (pageType === 'github') {
      chips = [
        { cmd: '/explain', label: 'Explain Code' },
        { cmd: '/code', label: 'Review' },
        { cmd: '/summarize', label: 'Summarize' }
      ];
    } else if (pageType === 'code') {
      chips = [
        { cmd: '/code', label: 'Explain Code' },
        { cmd: '/fix', label: 'Fix Issues' },
        { cmd: '/rewrite', label: 'Optimize' }
      ];
    }

    quickContainer.innerHTML = chips.map(c =>
      `<button class="thea-quick-chip" data-cmd="${c.cmd}">${c.label}</button>`
    ).join('');

    quickContainer.querySelectorAll('.thea-quick-chip').forEach(chip => {
      chip.addEventListener('click', () => executeSlashCommand(chip.dataset.cmd));
    });
  }

  // ============================================================================
  // Message Handling
  // ============================================================================

  async function sendMessage() {
    const input = sidebarElement.querySelector('#thea-sidebar-input');
    const text = input.value.trim();
    if (!text || isStreaming) return;

    input.value = '';
    input.style.height = 'auto';

    // Check for slash command
    const cmd = text.split(' ')[0];
    if (SLASH_COMMANDS[cmd]) {
      const rest = text.slice(cmd.length).trim();
      const selection = window.getSelection()?.toString()?.trim();
      const context = rest || selection || pageContext?.content?.substring(0, 8000) || '';
      sendMessageDirect(`${SLASH_COMMANDS[cmd].prompt}\n\n${context}`, cmd);
      return;
    }

    sendMessageDirect(text);
  }

  async function sendMessageDirect(text, label) {
    if (isStreaming) return;

    // Add user message
    addMessage('user', label || text.substring(0, 200));

    // Show loading
    const loadingId = addMessage('assistant', '', true);

    isStreaming = true;
    updateSendButton();

    try {
      const response = await chrome.runtime.sendMessage({
        type: 'askAI',
        data: {
          question: text,
          context: {
            url: pageContext?.url,
            title: pageContext?.title,
            content: pageContext?.content?.substring(0, 8000),
            selection: window.getSelection()?.toString()?.trim(),
            type: pageContext?.type
          }
        }
      });

      const answer = response?.data?.response || response?.data || 'Unable to get a response.';
      updateMessage(loadingId, typeof answer === 'string' ? answer : JSON.stringify(answer));

      currentConversation.push(
        { role: 'user', content: text },
        { role: 'assistant', content: answer }
      );
    } catch (e) {
      updateMessage(loadingId, 'Error: ' + e.message);
    }

    isStreaming = false;
    updateSendButton();
  }

  // ============================================================================
  // Message Rendering
  // ============================================================================

  function addMessage(role, content, isLoading = false) {
    const messagesEl = sidebarElement.querySelector('#thea-sidebar-messages');

    // Remove welcome message if present
    const welcome = messagesEl.querySelector('.thea-sidebar-welcome');
    if (welcome) welcome.remove();

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

    // Copy action
    const copyBtn = msgEl.querySelector('[data-action="copy"]');
    if (copyBtn) {
      copyBtn.addEventListener('click', () => {
        navigator.clipboard.writeText(msgEl.querySelector('.thea-sidebar-msg-content').textContent);
        copyBtn.innerHTML = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#38a169" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>';
        setTimeout(() => {
          copyBtn.innerHTML = '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>';
        }, 2000);
      });
    }

    messagesEl.appendChild(msgEl);
    messagesEl.scrollTop = messagesEl.scrollHeight;

    return id;
  }

  function updateMessage(id, content) {
    const msgEl = sidebarElement.querySelector(`#${id}`);
    if (!msgEl) return;

    const contentEl = msgEl.querySelector('.thea-sidebar-msg-content');
    contentEl.textContent = content;

    // Add copy action if not present
    if (!msgEl.querySelector('.thea-sidebar-msg-actions')) {
      const actionsEl = document.createElement('div');
      actionsEl.className = 'thea-sidebar-msg-actions';
      actionsEl.innerHTML = `
        <button class="thea-msg-action" data-action="copy" title="Copy">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>
        </button>
      `;
      actionsEl.querySelector('[data-action="copy"]').addEventListener('click', () => {
        navigator.clipboard.writeText(content);
      });
      msgEl.appendChild(actionsEl);
    }

    const messagesEl = sidebarElement.querySelector('#thea-sidebar-messages');
    messagesEl.scrollTop = messagesEl.scrollHeight;
  }

  function updateSendButton() {
    const btn = sidebarElement.querySelector('#thea-sidebar-send');
    btn.disabled = isStreaming;
    btn.style.opacity = isStreaming ? '0.5' : '1';
  }

  // ============================================================================
  // Conversation Management
  // ============================================================================

  function newConversation() {
    if (currentConversation.length > 0) {
      conversations.push({
        id: Date.now(),
        title: currentConversation[0]?.content?.substring(0, 50) || 'Untitled',
        messages: [...currentConversation],
        timestamp: new Date().toISOString(),
        url: window.location.href
      });
    }

    currentConversation = [];
    const messagesEl = sidebarElement.querySelector('#thea-sidebar-messages');
    messagesEl.innerHTML = `
      <div class="thea-sidebar-welcome">
        <p>Ask me anything about this page, or use a quick action above.</p>
        <p class="thea-sidebar-hint">Type <code>/</code> to see all commands</p>
      </div>
    `;
  }

  function showHistory() {
    // Simple history view
    const messagesEl = sidebarElement.querySelector('#thea-sidebar-messages');
    if (conversations.length === 0) {
      messagesEl.innerHTML = `
        <div class="thea-sidebar-welcome">
          <p>No previous conversations yet.</p>
        </div>
      `;
      return;
    }

    messagesEl.innerHTML = conversations.map(conv => `
      <div class="thea-sidebar-history-item" data-id="${conv.id}">
        <div class="thea-sidebar-history-title">${escapeHtml(conv.title)}</div>
        <div class="thea-sidebar-history-meta">${new Date(conv.timestamp).toLocaleDateString()} &middot; ${conv.messages.length} messages</div>
      </div>
    `).join('');

    messagesEl.querySelectorAll('.thea-sidebar-history-item').forEach(item => {
      item.addEventListener('click', () => {
        const conv = conversations.find(c => c.id === parseInt(item.dataset.id));
        if (conv) {
          currentConversation = [...conv.messages];
          messagesEl.innerHTML = '';
          conv.messages.forEach(msg => addMessage(msg.role, msg.content));
        }
      });
    });
  }

  // ============================================================================
  // Toggle Sidebar
  // ============================================================================

  function toggleSidebar() {
    if (isOpen) {
      closeSidebar();
    } else {
      openSidebar();
    }
  }

  function openSidebar() {
    if (!sidebarElement) createSidebar();
    sidebarElement.classList.add('thea-sidebar-open');
    isOpen = true;

    // Focus input
    setTimeout(() => {
      sidebarElement.querySelector('#thea-sidebar-input')?.focus();
    }, 300);
  }

  function closeSidebar() {
    if (sidebarElement) {
      sidebarElement.classList.remove('thea-sidebar-open');
    }
    isOpen = false;
  }

  // ============================================================================
  // Selection Popup (context-aware)
  // ============================================================================

  function setupSelectionListener() {
    document.addEventListener('mouseup', (e) => {
      // Don't show if sidebar is target
      if (sidebarElement?.contains(e.target)) return;

      const selection = window.getSelection();
      if (!selection || selection.isCollapsed || !selection.toString().trim()) return;

      showSelectionPopup(selection, e);
    });
  }

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
      openSidebar();

      switch (action) {
        case 'explain': executeSlashCommand('/explain'); break;
        case 'summarize': executeSlashCommand('/summarize'); break;
        case 'translate': executeSlashCommand('/translate'); break;
        case 'ask':
          const input = sidebarElement.querySelector('#thea-sidebar-input');
          input.value = text.substring(0, 500);
          input.focus();
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
  // Message Handling from Extension
  // ============================================================================

  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (!sender.id || sender.id !== chrome.runtime.id) {
      sendResponse({ success: false });
      return true;
    }

    switch (message.type) {
      case 'toggleAISidebar':
        toggleSidebar();
        sendResponse({ success: true });
        break;
      case 'showQuickPrompt':
        openSidebar();
        sendResponse({ success: true });
        break;
      case 'openSidebarWithQuery':
        openSidebar();
        setTimeout(() => {
          const input = sidebarElement.querySelector('#thea-sidebar-input');
          if (input) {
            input.value = message.query || '';
            input.focus();
          }
        }, 300);
        sendResponse({ success: true });
        break;
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

      /* Selection popup */
      .thea-selection-actions {
        position: absolute; z-index: 2147483647;
        display: flex; gap: 2px; padding: 4px;
        background: #1a1a2e; border-radius: 8px;
        box-shadow: 0 4px 16px rgba(0,0,0,0.3);
        border: 1px solid rgba(255,255,255,0.1);
        transform: translateX(-50%);
        animation: thea-fade-in 0.1s ease-out;
      }
      @keyframes thea-fade-in { from { opacity: 0; transform: translateX(-50%) translateY(4px); } to { opacity: 1; transform: translateX(-50%) translateY(0); } }
      .thea-selection-actions button {
        background: transparent; border: none; color: #a0aec0;
        cursor: pointer; padding: 6px 8px; border-radius: 6px;
        transition: all 0.1s;
      }
      .thea-selection-actions button:hover { background: rgba(233,69,96,0.2); color: #e94560; }

      /* Scrollbar */
      .thea-sidebar-messages::-webkit-scrollbar { width: 4px; }
      .thea-sidebar-messages::-webkit-scrollbar-track { background: transparent; }
      .thea-sidebar-messages::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); border-radius: 2px; }
    `;
  }

  // ============================================================================
  // Initialize
  // ============================================================================

  setupSelectionListener();

})();
