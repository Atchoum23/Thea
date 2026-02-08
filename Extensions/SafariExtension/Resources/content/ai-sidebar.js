(function() {
  'use strict';

  var UI = null;
  var Notify = null;
  var sidebar = null;
  var isOpen = false;
  var conversation = [];
  var currentModel = null;

  var SLASH_COMMANDS = {
    '/summarize': { description: 'Summarize this page', needsPage: true },
    '/explain': { description: 'Explain selected text or page', needsPage: true },
    '/translate': { description: 'Translate text (specify target language)', needsPage: false },
    '/code': { description: 'Help with code questions', needsPage: false },
    '/eli5': { description: 'Explain like I\'m five', needsPage: true },
    '/fix': { description: 'Fix grammar and writing', needsPage: false },
    '/action-items': { description: 'Extract action items from page', needsPage: true },
    '/research': { description: 'Deep research on a topic', needsPage: false },
    '/rewrite': { description: 'Rewrite text in a different style', needsPage: false },
    '/extract': { description: 'Extract structured data from page', needsPage: true },
    '/create': { description: 'Create content from page', needsPage: true }
  };

  function init() {
    UI = window.TheaModules.AISidebarUI;
    Notify = window.TheaModules.Notification;
    if (!UI) return;

    sidebar = UI.createSidebarContainer();

    browser.runtime.onMessage.addListener(function(message) {
      if (message.type === 'toggleAISidebar') {
        toggle();
      } else if (message.type === 'openSidebarWithQuery') {
        if (!isOpen) toggle();
        sendMessage(message.query);
      } else if (message.type === 'aiResponse') {
        handleAIResponse(message);
      }
    });
  }

  function toggle() {
    if (!sidebar) {
      sidebar = UI.createSidebarContainer();
    }
    isOpen = !isOpen;
    if (isOpen) {
      sidebar.classList.add('thea-open');
      var input = sidebar.querySelector('.thea-sidebar-input');
      if (input) setTimeout(function() { input.focus(); }, 350);
    } else {
      sidebar.classList.remove('thea-open');
    }
  }

  function sendMessage(text) {
    if (!text || !text.trim()) return;
    text = text.trim();

    if (text.startsWith('/')) {
      var parts = text.split(/\s+/);
      var cmd = parts[0].toLowerCase();
      var args = parts.slice(1).join(' ');
      if (SLASH_COMMANDS[cmd]) {
        handleSlashCommand(cmd, args);
        return;
      }
    }

    addMessage('user', text);
    UI.showTypingIndicator();

    var pageContext = getPageContext();
    browser.runtime.sendMessage({
      type: 'aiChatMessage',
      text: text,
      conversation: conversation.slice(-10),
      pageContext: {
        title: pageContext.title,
        url: pageContext.url,
        description: pageContext.description
      }
    }).catch(function(err) {
      UI.removeTypingIndicator();
      addMessage('assistant', 'Sorry, I encountered an error. Please try again.');
    });
  }

  function handleSlashCommand(command, args) {
    var def = SLASH_COMMANDS[command];
    if (!def) {
      addMessage('assistant', 'Unknown command: ' + command);
      return;
    }

    var displayText = command + (args ? ' ' + args : '');
    addMessage('user', displayText);

    if (command === '/create') {
      var messages = sidebar.querySelector('.thea-sidebar-messages');
      if (messages) {
        var menu = UI.createContentCreationMenu();
        messages.appendChild(menu);
        UI.scrollToBottom();
      }
      return;
    }

    UI.showTypingIndicator();

    var pageContext = def.needsPage ? getPageContext() : null;
    var prompt = buildSlashPrompt(command, args, pageContext);

    browser.runtime.sendMessage({
      type: 'aiChatMessage',
      text: prompt,
      conversation: [],
      pageContext: pageContext ? {
        title: pageContext.title,
        url: pageContext.url,
        content: pageContext.content ? pageContext.content.substring(0, 4000) : ''
      } : null,
      slashCommand: command
    }).catch(function() {
      UI.removeTypingIndicator();
      addMessage('assistant', 'Sorry, I could not process that command.');
    });
  }

  function buildSlashPrompt(command, args, context) {
    var contentSnippet = context && context.content ? context.content.substring(0, 3000) : '';
    var prompts = {
      '/summarize': 'Summarize the following page content concisely:\n\n' + contentSnippet,
      '/explain': args ?
        'Explain the following text clearly: ' + args :
        'Explain the main concepts of this page:\n\n' + contentSnippet,
      '/translate': 'Translate the following to ' + (args || 'English') + ':\n\n' + contentSnippet,
      '/code': 'Help with this coding question: ' + (args || contentSnippet),
      '/eli5': 'Explain the following like I am five years old:\n\n' + contentSnippet,
      '/fix': 'Fix the grammar and improve the writing of: ' + (args || contentSnippet),
      '/action-items': 'Extract all action items and tasks from:\n\n' + contentSnippet,
      '/research': 'Provide a comprehensive research overview on: ' + (args || contentSnippet),
      '/rewrite': 'Rewrite the following in a ' + (args || 'professional') + ' style:\n\n' + contentSnippet,
      '/extract': 'Extract structured data (names, dates, numbers, key facts) from:\n\n' + contentSnippet
    };
    return prompts[command] || args || contentSnippet;
  }

  function addMessage(role, content, model) {
    conversation.push({
      role: role,
      content: content,
      timestamp: Date.now(),
      model: model || null
    });

    var messages = sidebar ? sidebar.querySelector('.thea-sidebar-messages') : null;
    if (messages) {
      var bubble = UI.createMessageBubble(role, content, model);
      messages.appendChild(bubble);
      UI.scrollToBottom(messages);
    }

    var sessionMgr = window.TheaModules.SessionManager;
    if (sessionMgr) {
      sessionMgr.saveSession(window.location.hostname, conversation);
    }
  }

  function handleAIResponse(response) {
    UI.removeTypingIndicator();
    var content = response.content || response.text || 'No response received.';
    var model = response.model || null;
    addMessage('assistant', content, model);

    var messages = sidebar ? sidebar.querySelector('.thea-sidebar-messages') : null;
    if (messages) {
      var followUp = UI.createFollowUpPrompt();
      messages.appendChild(followUp);
      UI.scrollToBottom(messages);
    }
  }

  function handleFollowUp(question) {
    var lastAssistant = '';
    for (var i = conversation.length - 1; i >= 0; i--) {
      if (conversation[i].role === 'assistant') {
        lastAssistant = conversation[i].content;
        break;
      }
    }

    addMessage('user', question);
    UI.showTypingIndicator();

    browser.runtime.sendMessage({
      type: 'aiChatMessage',
      text: question,
      conversation: conversation.slice(-10),
      pageContext: {
        title: document.title,
        url: window.location.href
      },
      followUp: true,
      previousResponse: lastAssistant.substring(0, 2000)
    }).catch(function() {
      UI.removeTypingIndicator();
      addMessage('assistant', 'Sorry, I could not process the follow-up.');
    });
  }

  function handleDeepResearch(query) {
    addMessage('user', '/research ' + query);
    UI.showTypingIndicator();

    if (Notify) {
      Notify.showNotification('Deep Research', 'Researching: ' + query, 3000);
    }

    browser.runtime.sendMessage({
      type: 'deepResearch',
      query: query,
      pageContext: getPageContext()
    }).catch(function() {
      UI.removeTypingIndicator();
      addMessage('assistant', 'Research request failed. Please try again.');
    });
  }

  function handleContentCreation(template) {
    var pageContext = getPageContext();
    addMessage('user', '/create ' + template);
    UI.showTypingIndicator();

    var templatePrompts = {
      summary: 'Create a concise executive summary of this page content.',
      outline: 'Create a detailed outline from this page content.',
      blog_post: 'Create a blog post based on the content of this page.',
      email: 'Draft a professional email summarizing the key points of this page.',
      social: 'Create a social media post about this page content.',
      report: 'Create a structured report based on this page content.'
    };

    var prompt = templatePrompts[template] || 'Create content based on this page.';

    browser.runtime.sendMessage({
      type: 'aiChatMessage',
      text: prompt,
      conversation: [],
      pageContext: {
        title: pageContext.title,
        url: pageContext.url,
        content: pageContext.content ? pageContext.content.substring(0, 4000) : ''
      },
      slashCommand: '/create',
      template: template
    }).catch(function() {
      UI.removeTypingIndicator();
      addMessage('assistant', 'Content creation failed. Please try again.');
    });
  }

  function getPageContext() {
    var title = document.title || '';
    var url = window.location.href || '';
    var description = '';
    var metaDesc = document.querySelector('meta[name="description"]');
    if (metaDesc) description = metaDesc.getAttribute('content') || '';

    var content = '';
    var article = document.querySelector('article, [role="article"], main, #content');
    if (article) {
      content = article.textContent || '';
    } else {
      content = document.body.textContent || '';
    }
    content = content.replace(/\s+/g, ' ').trim().substring(0, 5000);

    var headings = [];
    document.querySelectorAll('h1, h2, h3').forEach(function(h) {
      headings.push({ tag: h.tagName, text: (h.textContent || '').trim() });
    });

    var structuredData = [];
    document.querySelectorAll('script[type="application/ld+json"]').forEach(function(s) {
      try {
        structuredData.push(JSON.parse(s.textContent));
      } catch (e) {}
    });

    var language = document.documentElement.lang || 'en';

    return {
      title: title,
      url: url,
      description: description,
      content: content,
      headings: headings.slice(0, 20),
      structuredData: structuredData.slice(0, 3),
      language: language
    };
  }

  function restoreSession() {
    var sessionMgr = window.TheaModules.SessionManager;
    if (!sessionMgr) return;

    sessionMgr.restoreSession(window.location.hostname).then(function(savedConversation) {
      if (savedConversation && savedConversation.length > 0) {
        conversation = savedConversation;
        var messages = sidebar ? sidebar.querySelector('.thea-sidebar-messages') : null;
        if (messages) {
          conversation.forEach(function(msg) {
            var bubble = UI.createMessageBubble(msg.role, msg.content, msg.model);
            messages.appendChild(bubble);
          });
          UI.scrollToBottom(messages);
        }
      }
    });
  }

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.AISidebar = {
    init: init,
    toggle: toggle,
    sendMessage: sendMessage,
    handleFollowUp: handleFollowUp,
    handleDeepResearch: handleDeepResearch,
    handleContentCreation: handleContentCreation,
    getPageContext: getPageContext,
    isOpen: function() { return isOpen; },
    getConversation: function() { return conversation.slice(); }
  };
})();
