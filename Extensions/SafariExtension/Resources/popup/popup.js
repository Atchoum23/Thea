// Thea Safari Extension - Popup Script
// Handles tabs, toggles, actions, and state sync with background

document.addEventListener('DOMContentLoaded', () => {
    initializePopup();
});

async function initializePopup() {
    await loadPageContext();
    setupTabs();
    setupActionButtons();
    setupAskButton();
    setupToggles();
    setupThemeDropdown();
    setupOpenApp();
    await loadState();
    await loadRecentSaves();
    checkConnection();
}

// --- Page Context ---

async function loadPageContext() {
    try {
        const tabs = await browser.tabs.query({ active: true, currentWindow: true });
        if (tabs[0] && tabs[0].url) {
            const url = new URL(tabs[0].url);
            document.getElementById('page-context').textContent = url.hostname || 'New Tab';
        }
    } catch (e) {
        document.getElementById('page-context').textContent = 'Safari';
    }
}

// --- Tab Switching ---

function setupTabs() {
    document.querySelectorAll('.tab').forEach(tab => {
        tab.addEventListener('click', () => {
            const targetId = tab.dataset.tab;
            // Update tab buttons
            document.querySelectorAll('.tab').forEach(t => {
                t.classList.remove('active');
                t.setAttribute('aria-selected', 'false');
            });
            tab.classList.add('active');
            tab.setAttribute('aria-selected', 'true');
            // Update panels
            document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
            document.getElementById('panel-' + targetId).classList.add('active');
        });
    });
}

// --- Action Buttons ---

function setupActionButtons() {
    document.querySelectorAll('.action-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            executeAction(btn.dataset.action);
        });
    });
}

async function executeAction(action) {
    const tabs = await browser.tabs.query({ active: true, currentWindow: true });
    if (!tabs[0]) return;

    const actionMessages = {
        summarize: 'Summarizing page...',
        save: 'Saving to memory...',
        translate: 'Translating...',
        extract: 'Extracting data...',
        askAI: 'Opening AI assistant...',
        memory: 'Opening memory...'
    };

    // Send to background/content script
    browser.runtime.sendMessage({
        action: 'executeQuickAction',
        actionId: action
    });

    showResult(actionMessages[action] || 'Processing...');
    setTimeout(() => window.close(), 1500);
}

// --- Ask Button ---

function setupAskButton() {
    document.getElementById('ask-btn').addEventListener('click', handleAsk);
    document.getElementById('query-input').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') handleAsk();
    });
}

async function handleAsk() {
    const input = document.getElementById('query-input');
    const query = input.value.trim();
    if (!query) return;

    // Get page context
    let pageData = {};
    try {
        pageData = await browser.runtime.sendMessage({ action: 'getPageData' });
    } catch (e) {
        pageData = {};
    }

    // Send to native app
    try {
        const response = await browser.runtime.sendMessage({
            target: 'native',
            data: {
                action: 'analyzeContent',
                content: query + '\n\nContext: ' + ((pageData.content || '').substring(0, 5000)),
                url: pageData.url || ''
            }
        });

        if (response && response.quickSummary) {
            showResult(response.quickSummary);
        } else {
            showResult('Query sent to Thea. Open the app for results.');
        }
    } catch (e) {
        showResult('Query sent to Thea. Open the app for results.');
    }

    input.value = '';
}

// --- Feature Toggles ---

function setupToggles() {
    document.querySelectorAll('.toggle-row').forEach(row => {
        const feature = row.dataset.feature;
        const checkbox = row.querySelector('input[type="checkbox"]');
        if (!checkbox || !feature) return;

        checkbox.addEventListener('change', async () => {
            await toggleFeature(feature, checkbox.checked);

            // Show/hide theme selector when dark mode is toggled
            if (feature === 'darkModeEnabled') {
                const selector = document.getElementById('theme-selector');
                if (selector) {
                    selector.style.display = checkbox.checked ? 'block' : 'none';
                }
            }
        });
    });
}

async function toggleFeature(feature, enabled) {
    try {
        // For nested config flags (like fingerprintProtection), update the config object
        if (feature === 'fingerprintProtection') {
            await browser.runtime.sendMessage({
                action: 'updateState',
                updates: { privacyConfig: { fingerprintProtection: enabled } }
            });
        } else {
            await browser.runtime.sendMessage({
                action: 'toggleFeature',
                feature: feature,
                value: enabled
            });
        }
    } catch (e) {
        console.error('[Thea Popup] Toggle error:', e);
    }
}

// --- Theme Dropdown ---

function setupThemeDropdown() {
    const dropdown = document.getElementById('theme-dropdown');
    if (!dropdown) return;

    dropdown.addEventListener('change', async () => {
        try {
            await browser.runtime.sendMessage({
                action: 'updateState',
                updates: { darkModeConfig: { theme: dropdown.value } }
            });
        } catch (e) {
            console.error('[Thea Popup] Theme change error:', e);
        }
    });
}

// --- State Loading ---

async function loadState() {
    try {
        const response = await browser.runtime.sendMessage({ action: 'getState' });
        if (!response) return;

        // Set toggle states
        const toggleMap = [
            'adBlockerEnabled', 'darkModeEnabled', 'privacyProtectionEnabled',
            'passwordManagerEnabled', 'videoControllerEnabled', 'printFriendlyEnabled',
            'aiAssistantEnabled', 'writingAssistantEnabled'
        ];

        toggleMap.forEach(key => {
            const checkbox = document.getElementById('toggle-' + key);
            if (checkbox) checkbox.checked = !!response[key];
        });

        // Fingerprint protection (nested)
        const fpCheckbox = document.getElementById('toggle-fingerprintProtection');
        if (fpCheckbox && response.privacyConfig) {
            fpCheckbox.checked = !!response.privacyConfig.fingerprintProtection;
        }

        // Dark mode theme selector visibility
        const selector = document.getElementById('theme-selector');
        if (selector) {
            selector.style.display = response.darkModeEnabled ? 'block' : 'none';
        }

        // Dark mode theme dropdown
        const dropdown = document.getElementById('theme-dropdown');
        if (dropdown && response.darkModeConfig && response.darkModeConfig.theme) {
            dropdown.value = response.darkModeConfig.theme;
        }

        // Stats
        if (response.stats) {
            loadStats(response.stats);
        }
    } catch (e) {
        console.error('[Thea Popup] Load state error:', e);
    }
}

function loadStats(stats) {
    document.getElementById('stat-ads').textContent = formatNumber(stats.adsBlocked || 0);
    document.getElementById('stat-trackers').textContent = formatNumber(stats.trackersBlocked || 0);
    document.getElementById('stat-cookies').textContent = formatNumber(stats.cookiesDeclined || 0);
    document.getElementById('stat-params').textContent = formatNumber(stats.trackingParamsStripped || 0);
}

// --- Recent Saves ---

async function loadRecentSaves() {
    try {
        const response = await browser.runtime.sendMessage({
            target: 'native',
            data: { action: 'getRecentSaves' }
        });

        if (response && response.saves && response.saves.length > 0) {
            const list = document.getElementById('recent-list');
            list.innerHTML = '';

            response.saves.slice(0, 4).forEach(save => {
                const item = document.createElement('div');
                item.className = 'recent-item';
                item.innerHTML =
                    '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>' +
                    '<div class="recent-text">' +
                    '<div class="recent-title">' + escapeHtml(save.title || 'Untitled') + '</div>' +
                    '<div class="recent-sub">' + formatDate(save.timestamp) + '</div>' +
                    '</div>';
                item.addEventListener('click', () => {
                    browser.tabs.create({ url: save.url });
                    window.close();
                });
                list.appendChild(item);
            });
        }
    } catch (e) {
        // Keep default empty state
    }
}

// --- Open App ---

function setupOpenApp() {
    document.getElementById('open-app').addEventListener('click', (e) => {
        e.preventDefault();
        browser.tabs.create({ url: 'thea://' });
        window.close();
    });
}

// --- Connection Check ---

async function checkConnection() {
    const dot = document.getElementById('status-dot');
    const text = document.getElementById('status-text');
    dot.className = 'status-dot checking';
    text.textContent = 'Checking...';

    try {
        const response = await browser.runtime.sendMessage({
            target: 'native',
            data: { action: 'ping' }
        });
        if (response && !response.error) {
            dot.className = 'status-dot';
            text.textContent = 'Connected';
        } else {
            dot.className = 'status-dot disconnected';
            text.textContent = 'Disconnected';
        }
    } catch (e) {
        dot.className = 'status-dot disconnected';
        text.textContent = 'Disconnected';
    }
}

// --- Result Notification ---

function showResult(message) {
    // Remove any existing result
    const existing = document.querySelector('.thea-result');
    if (existing) existing.remove();

    const resultDiv = document.createElement('div');
    resultDiv.className = 'thea-result';
    resultDiv.textContent = message;

    const header = document.querySelector('header');
    header.insertAdjacentElement('afterend', resultDiv);

    setTimeout(() => {
        resultDiv.style.animation = 'slideOut 0.3s ease-in forwards';
        setTimeout(() => resultDiv.remove(), 300);
    }, 3000);
}

// --- Utilities ---

function formatNumber(num) {
    if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
    if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
    return String(num);
}

function formatDate(timestamp) {
    if (!timestamp) return '';
    const diff = Date.now() - new Date(timestamp).getTime();
    if (diff < 60000) return 'Just now';
    if (diff < 3600000) return Math.floor(diff / 60000) + ' min ago';
    if (diff < 86400000) return Math.floor(diff / 3600000) + 'h ago';
    if (diff < 604800000) return Math.floor(diff / 86400000) + 'd ago';
    return new Date(timestamp).toLocaleDateString();
}

function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}
