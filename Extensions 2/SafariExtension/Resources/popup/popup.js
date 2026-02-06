// Thea Safari Extension - Popup Script

document.addEventListener('DOMContentLoaded', () => {
    initializePopup();
});

async function initializePopup() {
    // Update page context
    const tabs = await browser.tabs.query({ active: true, currentWindow: true });
    if (tabs[0]) {
        const pageContext = document.getElementById('page-context');
        const url = new URL(tabs[0].url);
        pageContext.textContent = url.hostname;
    }

    // Setup action cards
    document.querySelectorAll('.action-card').forEach(card => {
        card.addEventListener('click', () => {
            const action = card.dataset.action;
            executeAction(action);
        });
    });

    // Setup ask button
    document.getElementById('ask-btn').addEventListener('click', handleAsk);
    document.getElementById('query-input').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') handleAsk();
    });

    // Setup open app link
    document.getElementById('open-app').addEventListener('click', (e) => {
        e.preventDefault();
        // Open the main Thea app via URL scheme
        browser.tabs.create({ url: 'thea://' });
        window.close();
    });

    // Load recent saves
    loadRecentSaves();
}

async function handleAsk() {
    const input = document.getElementById('query-input');
    const query = input.value.trim();

    if (!query) return;

    // Get page context
    const pageData = await browser.runtime.sendMessage({ action: 'getPageData' });

    // Send to native
    const response = await browser.runtime.sendMessage({
        target: 'native',
        data: {
            action: 'analyzeContent',
            content: query + '\n\nContext: ' + (pageData.content || '').substring(0, 5000),
            url: pageData.url
        }
    });

    // Show result
    if (response.quickSummary) {
        showResult(response.quickSummary);
    } else {
        showResult('Query sent to Thea. Open the app for results.');
    }

    input.value = '';
}

async function executeAction(action) {
    const tabs = await browser.tabs.query({ active: true, currentWindow: true });
    if (!tabs[0]) return;

    // Send action to content script
    browser.runtime.sendMessage({
        action: 'executeQuickAction',
        actionId: action
    });

    // Show feedback
    const actionNames = {
        summarize: 'Summarizing page...',
        save: 'Saving to memory...',
        translate: 'Translating...',
        extract: 'Extracting data...'
    };

    showResult(actionNames[action] || 'Processing...');

    // Close popup after short delay
    setTimeout(() => window.close(), 1500);
}

function showResult(message) {
    const content = document.querySelector('.content');
    const resultDiv = document.createElement('div');
    resultDiv.style.cssText = `
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 12px;
        border-radius: 8px;
        margin-bottom: 16px;
        font-size: 14px;
        animation: slideIn 0.3s ease-out;
    `;
    resultDiv.textContent = message;
    content.insertBefore(resultDiv, content.firstChild);

    // Remove after delay
    setTimeout(() => {
        resultDiv.style.animation = 'slideOut 0.3s ease-in forwards';
        setTimeout(() => resultDiv.remove(), 300);
    }, 3000);
}

async function loadRecentSaves() {
    try {
        const response = await browser.runtime.sendMessage({
            target: 'native',
            data: { action: 'getRecentSaves' }
        });

        if (response.saves && response.saves.length > 0) {
            const list = document.getElementById('recent-list');
            list.innerHTML = '';

            response.saves.slice(0, 5).forEach(save => {
                const item = document.createElement('div');
                item.className = 'recent-item';
                item.innerHTML = `
                    <div class="recent-icon">📄</div>
                    <div class="recent-text">
                        <div class="recent-title">${save.title}</div>
                        <div class="recent-subtitle">${formatDate(save.timestamp)}</div>
                    </div>
                `;
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

function formatDate(timestamp) {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now - date;

    if (diff < 60000) return 'Just now';
    if (diff < 3600000) return Math.floor(diff / 60000) + ' min ago';
    if (diff < 86400000) return Math.floor(diff / 3600000) + ' hours ago';
    return date.toLocaleDateString();
}

// Add animation styles
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from {
            opacity: 0;
            transform: translateY(-10px);
        }
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }
    @keyframes slideOut {
        from {
            opacity: 1;
            transform: translateY(0);
        }
        to {
            opacity: 0;
            transform: translateY(-10px);
        }
    }
`;
document.head.appendChild(style);
