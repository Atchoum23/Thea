// Thea Web — Vanilla JS chat interface

(() => {
    'use strict';

    // State
    const state = {
        token: localStorage.getItem('thea_token') || '',
        conversations: [],
        currentConversationId: null,
        messages: [],
        isStreaming: false,
    };

    // API
    const API_BASE = '/api/v1';

    async function apiRequest(path, options = {}) {
        const headers = {
            'Content-Type': 'application/json',
            ...options.headers,
        };
        if (state.token) {
            headers['X-API-Key'] = state.token;
        }
        const res = await fetch(`${API_BASE}${path}`, { ...options, headers });
        if (res.status === 401) {
            logout();
            throw new Error('Unauthorized');
        }
        return res;
    }

    // DOM Elements
    const $ = (sel) => document.querySelector(sel);
    const authScreen = $('#auth-screen');
    const chatScreen = $('#chat-screen');
    const apiKeyInput = $('#api-key-input');
    const loginBtn = $('#login-btn');
    const logoutBtn = $('#logout-btn');
    const sidebar = $('#sidebar');
    const sidebarToggle = $('#sidebar-toggle');
    const newChatBtn = $('#new-chat-btn');
    const conversationList = $('#conversation-list');
    const messagesContainer = $('#messages-container');
    const welcomeMessage = $('#welcome-message');
    const messageInput = $('#message-input');
    const sendBtn = $('#send-btn');
    const chatTitle = $('#chat-title');

    // Auth
    function login() {
        const key = apiKeyInput.value.trim();
        if (!key) return;
        state.token = key;
        localStorage.setItem('thea_token', key);
        showChat();
    }

    function logout() {
        state.token = '';
        state.conversations = [];
        state.currentConversationId = null;
        state.messages = [];
        localStorage.removeItem('thea_token');
        showAuth();
    }

    function showAuth() {
        authScreen.classList.remove('hidden');
        chatScreen.classList.add('hidden');
    }

    function showChat() {
        authScreen.classList.add('hidden');
        chatScreen.classList.remove('hidden');
        loadConversations();
        messageInput.focus();
    }

    // Conversations
    async function loadConversations() {
        try {
            const res = await apiRequest('/chat/conversations');
            if (res.ok) {
                state.conversations = await res.json();
                renderConversations();
            }
        } catch {
            // Offline or server error — show empty list
        }
    }

    function renderConversations() {
        conversationList.innerHTML = '';
        for (const conv of state.conversations) {
            const el = document.createElement('div');
            el.className = 'conv-item' + (conv.id === state.currentConversationId ? ' active' : '');
            el.innerHTML = `
                <span class="conv-title">${escapeHtml(conv.title || 'Untitled')}</span>
                <span class="conv-preview">${escapeHtml(conv.lastMessage || '')}</span>
            `;
            el.addEventListener('click', () => selectConversation(conv.id));
            conversationList.appendChild(el);
        }
    }

    function selectConversation(id) {
        state.currentConversationId = id;
        renderConversations();
        loadMessages(id);
    }

    async function loadMessages(conversationId) {
        try {
            const res = await apiRequest(`/chat/conversations/${conversationId}`);
            if (res.ok) {
                const data = await res.json();
                state.messages = data.messages || [];
                chatTitle.textContent = data.title || 'Conversation';
                renderMessages();
            }
        } catch {
            // Offline
        }
    }

    function newConversation() {
        state.currentConversationId = null;
        state.messages = [];
        chatTitle.textContent = 'New Conversation';
        renderConversations();
        renderMessages();
        messageInput.focus();
    }

    // Messages
    function renderMessages() {
        // Remove welcome if there are messages
        if (state.messages.length > 0 && welcomeMessage) {
            welcomeMessage.style.display = 'none';
        } else if (welcomeMessage) {
            welcomeMessage.style.display = '';
        }

        // Clear existing messages (keep welcome)
        const existing = messagesContainer.querySelectorAll('.message');
        existing.forEach((el) => el.remove());

        for (const msg of state.messages) {
            appendMessageElement(msg.role, msg.content);
        }

        scrollToBottom();
    }

    function appendMessageElement(role, content, streaming = false) {
        const el = document.createElement('div');
        el.className = `message ${role}`;
        if (streaming) el.classList.add('streaming-cursor');
        el.innerHTML = `
            <div class="role">${role === 'user' ? 'You' : 'Thea'}</div>
            <div class="content">${formatContent(content)}</div>
        `;
        messagesContainer.appendChild(el);
        scrollToBottom();
        return el;
    }

    function updateStreamingMessage(el, content) {
        const contentDiv = el.querySelector('.content');
        if (contentDiv) {
            contentDiv.innerHTML = formatContent(content);
        }
        scrollToBottom();
    }

    function scrollToBottom() {
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }

    // Send Message
    async function sendMessage() {
        const text = messageInput.value.trim();
        if (!text || state.isStreaming) return;

        // Hide welcome
        if (welcomeMessage) welcomeMessage.style.display = 'none';

        // Add user message
        state.messages.push({ role: 'user', content: text });
        appendMessageElement('user', text);
        messageInput.value = '';
        autoResizeInput();
        sendBtn.disabled = true;
        state.isStreaming = true;

        // Create streaming assistant message
        const assistantEl = appendMessageElement('assistant', '', true);
        let fullContent = '';

        try {
            const res = await apiRequest('/chat/send', {
                method: 'POST',
                body: JSON.stringify({
                    message: text,
                    conversationId: state.currentConversationId,
                }),
            });

            if (!res.ok) {
                const err = await res.text();
                fullContent = `Error: ${res.status} — ${err}`;
                updateStreamingMessage(assistantEl, fullContent);
            } else {
                // Check if streaming (SSE) or JSON response
                const contentType = res.headers.get('content-type') || '';

                if (contentType.includes('text/event-stream')) {
                    // SSE streaming
                    const reader = res.body.getReader();
                    const decoder = new TextDecoder();
                    let buffer = '';

                    while (true) {
                        const { done, value } = await reader.read();
                        if (done) break;

                        buffer += decoder.decode(value, { stream: true });
                        const lines = buffer.split('\n');
                        buffer = lines.pop() || '';

                        for (const line of lines) {
                            if (line.startsWith('data: ')) {
                                const data = line.slice(6);
                                if (data === '[DONE]') continue;
                                try {
                                    const parsed = JSON.parse(data);
                                    if (parsed.content) {
                                        fullContent += parsed.content;
                                        updateStreamingMessage(assistantEl, fullContent);
                                    }
                                    if (parsed.conversationId) {
                                        state.currentConversationId = parsed.conversationId;
                                    }
                                } catch {
                                    // Non-JSON SSE data — treat as raw text
                                    fullContent += data;
                                    updateStreamingMessage(assistantEl, fullContent);
                                }
                            }
                        }
                    }
                } else {
                    // JSON response (non-streaming)
                    const data = await res.json();
                    fullContent = data.message || data.response || JSON.stringify(data);
                    if (data.conversationId) {
                        state.currentConversationId = data.conversationId;
                    }
                }

                updateStreamingMessage(assistantEl, fullContent);
            }
        } catch (err) {
            fullContent = `Network error: ${err.message}`;
            updateStreamingMessage(assistantEl, fullContent);
        }

        // Finalize
        assistantEl.classList.remove('streaming-cursor');
        state.messages.push({ role: 'assistant', content: fullContent });
        state.isStreaming = false;
        updateSendButton();

        // Update title from first message
        if (state.messages.length === 2) {
            const title = text.length > 40 ? text.substring(0, 40) + '...' : text;
            chatTitle.textContent = title;
        }

        // Refresh conversation list
        loadConversations();
    }

    // Formatting
    function formatContent(text) {
        if (!text) return '';
        // Escape HTML
        let html = escapeHtml(text);
        // Code blocks (```lang\n...\n```)
        html = html.replace(/```(\w*)\n([\s\S]*?)```/g, '<pre><code>$2</code></pre>');
        // Inline code (`...`)
        html = html.replace(/`([^`]+)`/g, '<code>$1</code>');
        // Bold (**...**)
        html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
        // Italic (*...*)
        html = html.replace(/\*(.+?)\*/g, '<em>$1</em>');
        // Newlines
        html = html.replace(/\n/g, '<br>');
        return html;
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    // Input handling
    function autoResizeInput() {
        messageInput.style.height = 'auto';
        messageInput.style.height = Math.min(messageInput.scrollHeight, 200) + 'px';
    }

    function updateSendButton() {
        sendBtn.disabled = !messageInput.value.trim() || state.isStreaming;
    }

    // Event Listeners
    loginBtn.addEventListener('click', login);
    apiKeyInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') login();
    });

    logoutBtn.addEventListener('click', logout);

    sidebarToggle.addEventListener('click', () => {
        sidebar.classList.toggle('collapsed');
    });

    newChatBtn.addEventListener('click', newConversation);

    messageInput.addEventListener('input', () => {
        autoResizeInput();
        updateSendButton();
    });

    messageInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    });

    sendBtn.addEventListener('click', sendMessage);

    // Suggestion buttons
    document.querySelectorAll('.suggestion').forEach((btn) => {
        btn.addEventListener('click', () => {
            messageInput.value = btn.dataset.prompt;
            autoResizeInput();
            updateSendButton();
            messageInput.focus();
        });
    });

    // Service Worker Registration (PWA)
    if ('serviceWorker' in navigator) {
        navigator.serviceWorker.register('/service-worker.js')
            .then(reg => console.log('SW registered:', reg.scope))
            .catch(err => console.log('SW registration failed:', err));
    }

    // Init
    if (state.token) {
        showChat();
    } else {
        showAuth();
    }
})();
