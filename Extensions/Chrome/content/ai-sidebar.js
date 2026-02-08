/**
 * Thea AI Sidebar - Logic Module
 *
 * Panel logic, conversation management, markdown rendering,
 * deep research, slash commands, page context, message handling.
 *
 * Depends on: ai-sidebar-ui.js (loaded before this file)
 */

(function() {
  'use strict';

  window.TheaModules = window.TheaModules || {};
  const UI = window.TheaModules.sidebarUI;

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
  // Sidebar Creation
  // ============================================================================

  function createSidebar() {
    if (sidebarElement) return;

    sidebarElement = UI.buildSidebarDOM();
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
        UI.renderSlashMenu(menu, matches);

        menu.querySelectorAll('.thea-slash-item').forEach(item => {
          item.addEventListener('click', () => {
            executeSlashCommand(item.dataset.cmd);
            UI.hideSlashMenu(menu);
          });
        });
        return;
      }
    }

    UI.hideSlashMenu(menu);
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

    UI.updateQuickActionChips(quickContainer, chips, executeSlashCommand);
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

    const { element: msgEl, id } = UI.createMessageBubble(role, content, isLoading);

    // Copy action
    const copyBtn = msgEl.querySelector('[data-action="copy"]');
    if (copyBtn) {
      copyBtn.addEventListener('click', () => {
        navigator.clipboard.writeText(msgEl.querySelector('.thea-sidebar-msg-content').textContent);
        copyBtn.innerHTML = UI.getCheckIconSVG();
        setTimeout(() => {
          copyBtn.innerHTML = UI.getCopyIconSVG();
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
          ${UI.getCopyIconSVG()}
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
    const messagesEl = sidebarElement.querySelector('#thea-sidebar-messages');
    const escapeHtml = UI.escapeHtml;

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

  function getSidebarElement() {
    return sidebarElement;
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
  // Export to shared namespace (for selection-handler.js)
  // ============================================================================

  window.TheaModules.sidebar = {
    openSidebar,
    closeSidebar,
    toggleSidebar,
    executeSlashCommand,
    getSidebarElement
  };

  // ============================================================================
  // Initialize
  // ============================================================================

  // Setup selection listener if available
  if (window.TheaModules.selection && window.TheaModules.selection.setupSelectionListener) {
    window.TheaModules.selection.setupSelectionListener();
  }

})();
