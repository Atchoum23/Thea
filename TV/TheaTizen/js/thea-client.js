/**
 * Thea TV Client — WebSocket/REST client connecting to Thea's web companion API.
 * Handles authentication, chat, dashboard data, and conversation management.
 */
'use strict';

var TheaClient = (function () {
    // --- Configuration ---
    var DEFAULT_SERVER = 'https://api.theathe.app';
    var STORAGE_KEY_TOKEN = 'thea_tv_token';
    var STORAGE_KEY_SERVER = 'thea_tv_server';
    var STORAGE_KEY_SETTINGS = 'thea_tv_settings';
    var PAIRING_CODE_LENGTH = 6;
    var PAIRING_CODE_TTL = 300; // seconds
    var MAX_MESSAGE_LENGTH = 8192;
    var RECONNECT_DELAY_MS = 3000;
    var MAX_RECONNECT_ATTEMPTS = 10;

    // --- State ---
    var state = {
        token: null,
        serverUrl: DEFAULT_SERVER,
        ws: null,
        wsReconnectAttempts: 0,
        currentConversationId: null,
        conversations: [],
        messages: [],
        isStreaming: false,
        pairingCode: null,
        pairingTimer: null,
        pairingTimerSeconds: PAIRING_CODE_TTL,
        settings: {
            model: 'Claude Sonnet',
            voiceInput: true,
            familySafe: false,
            theme: 'dark',
            fontSize: 'large'
        }
    };

    // --- Storage ---
    function saveToken(token) {
        try { localStorage.setItem(STORAGE_KEY_TOKEN, token); } catch (e) { /* TV storage may fail */ }
    }

    function loadToken() {
        try { return localStorage.getItem(STORAGE_KEY_TOKEN); } catch (e) { return null; }
    }

    function clearToken() {
        try { localStorage.removeItem(STORAGE_KEY_TOKEN); } catch (e) { /* ignore */ }
    }

    function saveSettings() {
        try { localStorage.setItem(STORAGE_KEY_SETTINGS, JSON.stringify(state.settings)); } catch (e) { /* ignore */ }
    }

    function loadSettings() {
        try {
            var saved = localStorage.getItem(STORAGE_KEY_SETTINGS);
            if (saved) {
                var parsed = JSON.parse(saved);
                for (var key in parsed) {
                    if (state.settings.hasOwnProperty(key)) {
                        state.settings[key] = parsed[key];
                    }
                }
            }
        } catch (e) { /* ignore */ }
    }

    function saveServerUrl(url) {
        try { localStorage.setItem(STORAGE_KEY_SERVER, url); } catch (e) { /* ignore */ }
    }

    function loadServerUrl() {
        try { return localStorage.getItem(STORAGE_KEY_SERVER) || DEFAULT_SERVER; } catch (e) { return DEFAULT_SERVER; }
    }

    // --- HTTP Helpers ---
    function apiRequest(method, path, body) {
        var url = state.serverUrl + '/api/v1' + path;
        var headers = { 'Content-Type': 'application/json' };
        if (state.token) {
            headers['Authorization'] = 'Bearer ' + state.token;
        }
        var opts = { method: method, headers: headers };
        if (body) {
            opts.body = JSON.stringify(body);
        }
        return fetch(url, opts).then(function (res) {
            if (res.status === 401) {
                handleAuthExpired();
                throw new Error('Authentication expired');
            }
            if (!res.ok) {
                return res.text().then(function (text) {
                    throw new Error('API error ' + res.status + ': ' + text);
                });
            }
            var ct = res.headers.get('content-type') || '';
            if (ct.indexOf('application/json') >= 0) {
                return res.json();
            }
            return res.text();
        });
    }

    function handleAuthExpired() {
        clearToken();
        state.token = null;
        showScreen('pairing-screen');
        showToast('Session expired. Please reconnect.');
    }

    // --- Pairing ---
    function generatePairingCode() {
        var chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1 for readability
        var code = '';
        for (var i = 0; i < PAIRING_CODE_LENGTH; i++) {
            code += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return code;
    }

    function startPairing() {
        state.pairingCode = generatePairingCode();
        state.pairingTimerSeconds = PAIRING_CODE_TTL;

        var codeEl = document.getElementById('pairing-code');
        if (codeEl) codeEl.textContent = state.pairingCode;

        // Register code with server
        apiRequest('POST', '/auth/pair', {
            code: state.pairingCode,
            deviceType: 'samsung_tv',
            deviceName: 'Samsung TV'
        }).catch(function () {
            // Server may not be reachable — code still displays for manual entry
        });

        // Start countdown
        clearInterval(state.pairingTimer);
        state.pairingTimer = setInterval(function () {
            state.pairingTimerSeconds--;
            var timerEl = document.getElementById('pairing-timer');
            if (timerEl) timerEl.textContent = state.pairingTimerSeconds;
            if (state.pairingTimerSeconds <= 0) {
                startPairing(); // regenerate
            }
            // Poll for pairing completion
            if (state.pairingTimerSeconds % 3 === 0) {
                checkPairingStatus();
            }
        }, 1000);
    }

    function checkPairingStatus() {
        if (!state.pairingCode) return;
        apiRequest('GET', '/auth/pair/' + state.pairingCode + '/status')
            .then(function (res) {
                if (res && res.token) {
                    clearInterval(state.pairingTimer);
                    state.token = res.token;
                    saveToken(res.token);
                    showScreen('chat-screen');
                    loadConversations();
                    connectWebSocket();
                    showToast('Connected to Thea');
                }
            })
            .catch(function () { /* not yet paired */ });
    }

    function stopPairing() {
        clearInterval(state.pairingTimer);
        state.pairingTimer = null;
    }

    // --- Authentication ---
    function authenticateWithApiKey(apiKey) {
        if (!apiKey || apiKey.length < 8) {
            showError('apikey-error', 'Invalid API key');
            return;
        }
        state.serverUrl = loadServerUrl();

        apiRequest('POST', '/auth/apikey', { key: apiKey })
            .then(function (res) {
                if (res && res.token) {
                    state.token = res.token;
                    saveToken(res.token);
                    showScreen('chat-screen');
                    loadConversations();
                    connectWebSocket();
                    showToast('Connected via API key');
                } else {
                    showError('apikey-error', 'Invalid response from server');
                }
            })
            .catch(function (err) {
                showError('apikey-error', 'Connection failed: ' + err.message);
            });
    }

    function disconnect() {
        clearToken();
        state.token = null;
        state.conversations = [];
        state.messages = [];
        state.currentConversationId = null;
        if (state.ws) {
            state.ws.close();
            state.ws = null;
        }
        showScreen('pairing-screen');
        startPairing();
        showToast('Disconnected');
    }

    // --- WebSocket ---
    function connectWebSocket() {
        if (!state.token) return;
        var wsUrl = state.serverUrl.replace('https://', 'wss://').replace('http://', 'ws://');
        wsUrl += '/api/v1/ws?token=' + encodeURIComponent(state.token);

        try {
            state.ws = new WebSocket(wsUrl);
        } catch (e) {
            console.error('WebSocket creation failed:', e);
            return;
        }

        state.ws.onopen = function () {
            state.wsReconnectAttempts = 0;
            console.log('WebSocket connected');
        };

        state.ws.onmessage = function (event) {
            try {
                var msg = JSON.parse(event.data);
                handleWebSocketMessage(msg);
            } catch (e) {
                console.error('WS message parse error:', e);
            }
        };

        state.ws.onclose = function () {
            console.log('WebSocket closed');
            scheduleReconnect();
        };

        state.ws.onerror = function (err) {
            console.error('WebSocket error:', err);
        };
    }

    function scheduleReconnect() {
        if (!state.token) return;
        if (state.wsReconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
            showToast('Connection lost. Pull down to reconnect.');
            return;
        }
        state.wsReconnectAttempts++;
        var delay = RECONNECT_DELAY_MS * Math.min(state.wsReconnectAttempts, 5);
        setTimeout(function () { connectWebSocket(); }, delay);
    }

    function handleWebSocketMessage(msg) {
        switch (msg.type) {
            case 'stream_start':
                state.isStreaming = true;
                appendStreamingMessage(msg.conversationId);
                break;
            case 'stream_chunk':
                appendStreamChunk(msg.content);
                break;
            case 'stream_end':
                state.isStreaming = false;
                finalizeStreamingMessage(msg);
                break;
            case 'conversation_updated':
                loadConversations();
                break;
            case 'notification':
                showToast(msg.title || msg.content);
                break;
            case 'dashboard_update':
                updateDashboard(msg.data);
                break;
        }
    }

    // --- Conversations ---
    function loadConversations() {
        apiRequest('GET', '/chat/conversations')
            .then(function (convos) {
                state.conversations = convos || [];
                renderConversationList();
            })
            .catch(function (err) {
                console.error('Failed to load conversations:', err);
            });
    }

    function createConversation() {
        apiRequest('POST', '/chat/conversations', { title: 'New Conversation' })
            .then(function (conv) {
                state.conversations.unshift(conv);
                selectConversation(conv.id);
                renderConversationList();
            })
            .catch(function (err) {
                showToast('Failed to create conversation');
                console.error(err);
            });
    }

    function selectConversation(id) {
        state.currentConversationId = id;
        state.messages = [];
        renderConversationList();

        // Load messages
        apiRequest('GET', '/chat/conversations/' + id)
            .then(function (detail) {
                state.messages = detail.messages || [];
                var titleEl = document.getElementById('chat-title');
                if (titleEl) titleEl.textContent = detail.title || 'Conversation';
                renderMessages();
            })
            .catch(function (err) {
                console.error('Failed to load conversation:', err);
            });

        switchView('chat-view');
    }

    // --- Chat ---
    function sendMessage(text) {
        if (!text || text.trim().length === 0) return;
        if (text.length > MAX_MESSAGE_LENGTH) {
            showToast('Message too long (max ' + MAX_MESSAGE_LENGTH + ' characters)');
            return;
        }
        if (state.isStreaming) {
            showToast('Please wait for the current response');
            return;
        }

        var userMessage = {
            role: 'user',
            content: text.trim(),
            timestamp: new Date().toISOString()
        };
        state.messages.push(userMessage);
        renderMessages();
        scrollToBottom();

        // Clear input
        var input = document.getElementById('chat-input');
        if (input) input.value = '';

        // Send to API
        var body = {
            message: userMessage.content,
            conversationId: state.currentConversationId,
            model: state.settings.model
        };
        if (state.settings.familySafe) {
            body.familySafe = true;
        }

        apiRequest('POST', '/chat/send', body)
            .then(function (res) {
                if (res && res.response) {
                    var assistantMsg = {
                        role: 'assistant',
                        content: res.response,
                        timestamp: new Date().toISOString(),
                        model: res.model || state.settings.model
                    };
                    state.messages.push(assistantMsg);
                    renderMessages();
                    scrollToBottom();
                    renderSuggestions(res.suggestions);
                }
                if (res && res.conversationId && !state.currentConversationId) {
                    state.currentConversationId = res.conversationId;
                    loadConversations();
                }
            })
            .catch(function (err) {
                appendErrorMessage('Failed to send: ' + err.message);
            });
    }

    // --- Streaming ---
    function appendStreamingMessage(conversationId) {
        var msg = {
            role: 'assistant',
            content: '',
            timestamp: new Date().toISOString(),
            streaming: true
        };
        state.messages.push(msg);
        renderMessages();
        scrollToBottom();
    }

    function appendStreamChunk(content) {
        var lastMsg = state.messages[state.messages.length - 1];
        if (lastMsg && lastMsg.streaming) {
            lastMsg.content += content;
            updateLastMessage(lastMsg.content, true);
            scrollToBottom();
        }
    }

    function finalizeStreamingMessage(msg) {
        var lastMsg = state.messages[state.messages.length - 1];
        if (lastMsg && lastMsg.streaming) {
            lastMsg.streaming = false;
            if (msg.model) lastMsg.model = msg.model;
            updateLastMessage(lastMsg.content, false);
            if (msg.suggestions) {
                renderSuggestions(msg.suggestions);
            }
        }
    }

    function appendErrorMessage(text) {
        var errorMsg = {
            role: 'system',
            content: text,
            timestamp: new Date().toISOString(),
            error: true
        };
        state.messages.push(errorMsg);
        renderMessages();
        scrollToBottom();
    }

    // --- Dashboard ---
    function loadDashboard() {
        apiRequest('GET', '/dashboard')
            .then(function (data) { updateDashboard(data); })
            .catch(function () { /* Dashboard data may not be available */ });
    }

    function updateDashboard(data) {
        if (!data) return;
        var fields = ['weather', 'calendar', 'health', 'tasks', 'finance', 'agents'];
        fields.forEach(function (field) {
            var el = document.getElementById('dash-' + field);
            if (el && data[field]) {
                el.innerHTML = formatDashboardData(field, data[field]);
            }
        });
    }

    function formatDashboardData(field, data) {
        if (typeof data === 'string') return data;
        switch (field) {
            case 'weather':
                return '<div class="card-stat">' + (data.temp || '--') + '&deg;</div>' +
                       '<div class="card-label">' + (data.condition || 'Unknown') + '</div>';
            case 'tasks':
                return '<div class="card-stat">' + (data.pending || 0) + '</div>' +
                       '<div class="card-label">tasks pending</div>';
            case 'health':
                return '<div class="card-stat">' + (data.steps || '--') + '</div>' +
                       '<div class="card-label">steps today</div>';
            case 'finance':
                return '<div class="card-stat">' + (data.balance || '--') + '</div>' +
                       '<div class="card-label">' + (data.currency || 'CHF') + '</div>';
            case 'agents':
                return '<div class="card-stat">' + (data.active || 0) + '</div>' +
                       '<div class="card-label">agents running</div>';
            case 'calendar':
                if (Array.isArray(data.events)) {
                    return data.events.slice(0, 3).map(function (e) {
                        return '<div>' + (e.time || '') + ' ' + (e.title || '') + '</div>';
                    }).join('');
                }
                return data.summary || 'No events today';
            default:
                return JSON.stringify(data);
        }
    }

    // --- Rendering ---
    function renderConversationList() {
        var list = document.getElementById('conversation-list');
        if (!list) return;
        if (state.conversations.length === 0) {
            list.innerHTML = '<div class="empty-state"><p>No conversations</p></div>';
            return;
        }
        list.innerHTML = state.conversations.map(function (conv) {
            var active = conv.id === state.currentConversationId ? ' active' : '';
            return '<div class="conversation-item focusable' + active + '" tabindex="0" data-conv-id="' +
                   conv.id + '">' + escapeHtml(conv.title || 'Untitled') + '</div>';
        }).join('');
    }

    function renderMessages() {
        var container = document.getElementById('messages');
        if (!container) return;
        if (state.messages.length === 0) {
            container.innerHTML = '<div class="empty-state">' +
                '<div class="thea-logo"><svg viewBox="0 0 80 80" width="80" height="80">' +
                '<circle cx="40" cy="40" r="28" fill="#F5A623" opacity="0.3"/>' +
                '<circle cx="40" cy="40" r="16" fill="#F5A623"/></svg></div>' +
                '<p>Ask Thea anything</p></div>';
            return;
        }
        container.innerHTML = state.messages.map(function (msg, i) {
            var roleClass = msg.role === 'user' ? 'user' : (msg.error ? 'error' : 'assistant');
            var roleName = msg.role === 'user' ? 'You' : 'Thea';
            var streaming = msg.streaming ? ' streaming-cursor' : '';
            var meta = '';
            if (msg.model) meta = msg.model;
            if (msg.timestamp) {
                var t = new Date(msg.timestamp);
                meta += (meta ? ' · ' : '') + t.getHours() + ':' + String(t.getMinutes()).padStart(2, '0');
            }
            return '<div class="message ' + roleClass + '">' +
                   '<div class="message-role">' + roleName + '</div>' +
                   '<div class="message-content' + streaming + '">' + formatContent(msg.content) + '</div>' +
                   (meta ? '<div class="message-meta">' + escapeHtml(meta) + '</div>' : '') +
                   '</div>';
        }).join('');
    }

    function updateLastMessage(content, isStreaming) {
        var container = document.getElementById('messages');
        if (!container) return;
        var msgs = container.querySelectorAll('.message');
        var last = msgs[msgs.length - 1];
        if (last) {
            var contentEl = last.querySelector('.message-content');
            if (contentEl) {
                contentEl.innerHTML = formatContent(content);
                if (isStreaming) {
                    contentEl.classList.add('streaming-cursor');
                } else {
                    contentEl.classList.remove('streaming-cursor');
                }
            }
        }
    }

    function renderSuggestions(suggestions) {
        var container = document.getElementById('suggestions');
        if (!container) return;
        if (!suggestions || suggestions.length === 0) {
            container.innerHTML = '';
            return;
        }
        container.innerHTML = suggestions.map(function (s, i) {
            var text = typeof s === 'string' ? s : s.text;
            return '<button class="suggestion-chip focusable" tabindex="0" data-suggestion="' +
                   escapeHtml(text) + '">' + escapeHtml(text) + '</button>';
        }).join('');
    }

    function formatContent(text) {
        if (!text) return '';
        var html = escapeHtml(text);
        // Code blocks
        html = html.replace(/```(\w*)\n?([\s\S]*?)```/g, '<pre><code>$2</code></pre>');
        // Inline code
        html = html.replace(/`([^`]+)`/g, '<code>$1</code>');
        // Bold
        html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
        // Italic
        html = html.replace(/\*([^*]+)\*/g, '<em>$1</em>');
        // Line breaks
        html = html.replace(/\n/g, '<br>');
        return html;
    }

    function scrollToBottom() {
        var container = document.getElementById('messages');
        if (container) {
            container.scrollTop = container.scrollHeight;
        }
    }

    // --- UI Helpers ---
    function showScreen(screenId) {
        document.querySelectorAll('.screen').forEach(function (s) { s.classList.remove('active'); });
        var screen = document.getElementById(screenId);
        if (screen) {
            screen.classList.add('active');
            // Focus first focusable element
            var first = screen.querySelector('.focusable');
            if (first) first.focus();
        }
    }

    function switchView(viewId) {
        document.querySelectorAll('.content-view').forEach(function (v) { v.classList.remove('active'); });
        var view = document.getElementById(viewId);
        if (view) {
            view.classList.add('active');
            if (viewId === 'dashboard-view') loadDashboard();
        }
    }

    function showError(elementId, message) {
        var el = document.getElementById(elementId);
        if (el) el.textContent = message;
    }

    function showToast(message) {
        var existing = document.querySelector('.toast');
        if (existing) existing.remove();
        var toast = document.createElement('div');
        toast.className = 'toast';
        toast.textContent = message;
        document.body.appendChild(toast);
        setTimeout(function () { toast.remove(); }, 3000);
    }

    function escapeHtml(text) {
        var div = document.createElement('div');
        div.appendChild(document.createTextNode(text));
        return div.innerHTML;
    }

    function updateSettingsUI() {
        var settingMap = {
            'setting-server': state.serverUrl.replace('https://', ''),
            'setting-model': state.settings.model,
            'setting-voice': state.settings.voiceInput ? 'Enabled' : 'Disabled',
            'setting-family': state.settings.familySafe ? 'On' : 'Off',
            'setting-theme': state.settings.theme === 'dark' ? 'Dark' : 'Light',
            'setting-font-size': state.settings.fontSize.charAt(0).toUpperCase() + state.settings.fontSize.slice(1)
        };
        for (var id in settingMap) {
            var el = document.getElementById(id);
            if (el) el.textContent = settingMap[id];
        }
    }

    // --- Settings Actions ---
    function handleSettingAction(settingName) {
        switch (settingName) {
            case 'model':
                var models = ['Claude Sonnet', 'Claude Opus', 'Claude Haiku', 'GPT-4o', 'Local Model'];
                var idx = models.indexOf(state.settings.model);
                state.settings.model = models[(idx + 1) % models.length];
                break;
            case 'voice':
                state.settings.voiceInput = !state.settings.voiceInput;
                break;
            case 'family':
                state.settings.familySafe = !state.settings.familySafe;
                break;
            case 'theme':
                state.settings.theme = state.settings.theme === 'dark' ? 'light' : 'dark';
                break;
            case 'font-size':
                var sizes = ['small', 'medium', 'large', 'extra-large'];
                var sIdx = sizes.indexOf(state.settings.fontSize);
                state.settings.fontSize = sizes[(sIdx + 1) % sizes.length];
                break;
            case 'disconnect':
                disconnect();
                return;
        }
        saveSettings();
        updateSettingsUI();
    }

    // --- Initialization ---
    function init() {
        loadSettings();
        state.serverUrl = loadServerUrl();
        state.token = loadToken();

        // Wire up event listeners
        document.addEventListener('click', function (e) {
            var target = e.target.closest('[data-action]');
            if (target) {
                if (target.dataset.action === 'manual-auth') {
                    stopPairing();
                    showScreen('apikey-screen');
                }
                return;
            }

            target = e.target.closest('[data-conv-id]');
            if (target) {
                selectConversation(target.dataset.convId);
                return;
            }

            target = e.target.closest('[data-suggestion]');
            if (target) {
                var input = document.getElementById('chat-input');
                if (input) {
                    input.value = target.dataset.suggestion;
                    input.focus();
                }
                return;
            }

            target = e.target.closest('[data-setting]');
            if (target) {
                handleSettingAction(target.dataset.setting);
                return;
            }
        });

        var submitBtn = document.getElementById('apikey-submit');
        if (submitBtn) {
            submitBtn.addEventListener('click', function () {
                var input = document.getElementById('apikey-input');
                if (input) authenticateWithApiKey(input.value.trim());
            });
        }

        var cancelBtn = document.getElementById('apikey-cancel');
        if (cancelBtn) {
            cancelBtn.addEventListener('click', function () {
                showScreen('pairing-screen');
                startPairing();
            });
        }

        var sendBtn = document.getElementById('send-btn');
        if (sendBtn) {
            sendBtn.addEventListener('click', function () {
                var input = document.getElementById('chat-input');
                if (input) sendMessage(input.value);
            });
        }

        var newChatBtn = document.getElementById('new-chat-btn');
        if (newChatBtn) {
            newChatBtn.addEventListener('click', function () {
                createConversation();
            });
        }

        var dashBtn = document.getElementById('dashboard-btn');
        if (dashBtn) {
            dashBtn.addEventListener('click', function () {
                switchView('dashboard-view');
            });
        }

        var settingsBtn = document.getElementById('settings-btn');
        if (settingsBtn) {
            settingsBtn.addEventListener('click', function () {
                switchView('settings-view');
                updateSettingsUI();
            });
        }

        // Check auth
        if (state.token) {
            showScreen('chat-screen');
            loadConversations();
            connectWebSocket();
        } else {
            showScreen('pairing-screen');
            startPairing();
        }
    }

    // Public API
    return {
        init: init,
        sendMessage: sendMessage,
        selectConversation: selectConversation,
        createConversation: createConversation,
        disconnect: disconnect,
        switchView: switchView,
        state: state
    };
})();

// Start when DOM is ready
document.addEventListener('DOMContentLoaded', TheaClient.init);
