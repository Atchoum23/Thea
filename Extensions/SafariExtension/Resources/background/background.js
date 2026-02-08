// Thea Safari Extension - Background Entry Point
// Sets up all event listeners and initializes the extension
// Loaded last — all other modules are already available in global scope

// Use browser.menus (Safari) with fallback to browser.contextMenus
var menus = browser.menus || browser.contextMenus;

// ── Message Listener ──────────────────────────────────────────────────
browser.runtime.onMessage.addListener(function (message, sender, sendResponse) {
    // Handle legacy "target: native" format for backward compatibility
    if (message.target === 'native') {
        sendNativeMessage(message.data)
            .then(function (response) { sendResponse(response); })
            .catch(function (error) { sendResponse({ error: error.message }); });
        return true;
    }

    // Route through the central message handler
    handleMessage(message, sender)
        .then(function (response) { sendResponse(response); })
        .catch(function (error) {
            console.error('[Thea BG] Message handling error:', error);
            sendResponse({ error: error.message || 'Unknown error' });
        });

    // Return true to indicate async response
    return true;
});

// ── Extension Install / Update ────────────────────────────────────────
browser.runtime.onInstalled.addListener(function (details) {
    console.log('[Thea BG] Extension installed/updated:', details.reason);

    if (!menus) return;

    // Remove existing menus to avoid duplicates on update
    menus.removeAll(function () {
        // Context menu: Ask Thea about selected text
        menus.create({
            id: 'thea-ask',
            title: 'Ask Thea about "%s"',
            contexts: ['selection']
        });

        // Context menu: Summarize page or link
        menus.create({
            id: 'thea-summarize',
            title: 'Summarize with Thea',
            contexts: ['page', 'link']
        });

        // Context menu: Save to memory
        menus.create({
            id: 'thea-save',
            title: 'Save to Thea Memory',
            contexts: ['selection', 'link', 'image']
        });

        // Context menu: Translate selection
        menus.create({
            id: 'thea-translate',
            title: 'Translate with Thea',
            contexts: ['selection']
        });

        // Context menu: Rewrite selection
        menus.create({
            id: 'thea-rewrite',
            title: 'Rewrite with Thea',
            contexts: ['selection']
        });

        // Context menu: Toggle dark mode
        menus.create({
            id: 'thea-darkmode',
            title: 'Toggle Dark Mode',
            contexts: ['page']
        });

        // Context menu: Deep research
        menus.create({
            id: 'thea-research',
            title: 'Deep Research with Thea',
            contexts: ['selection', 'link']
        });

        // Context menu: Print friendly
        menus.create({
            id: 'thea-print',
            title: 'Make Print Friendly',
            contexts: ['page']
        });
    });
});

// ── Context Menu Click Handler ────────────────────────────────────────
if (menus) {
    menus.onClicked.addListener(function (info, tab) {
        switch (info.menuItemId) {
            case 'thea-ask':
                askTheaAI(info.selectionText, { url: tab.url, title: tab.title })
                    .then(function (response) {
                        if (response && response.answer) {
                            browser.tabs.sendMessage(tab.id, {
                                action: 'showResult',
                                title: 'Thea',
                                content: response.answer
                            });
                        }
                    });
                break;

            case 'thea-summarize':
                browser.tabs.sendMessage(tab.id, { action: 'showLoading' });
                browser.tabs.sendMessage(tab.id, { action: 'extractPageData' })
                    .then(function (pageData) {
                        return analyzeContentNative(pageData.content || '', info.pageUrl || info.linkUrl);
                    })
                    .then(function (response) {
                        browser.tabs.sendMessage(tab.id, {
                            action: 'showResult',
                            title: 'Summary',
                            content: (response && response.quickSummary) || 'Could not summarize'
                        });
                    })
                    .catch(function () {
                        browser.tabs.sendMessage(tab.id, {
                            action: 'showResult',
                            title: 'Error',
                            content: 'Could not summarize this page'
                        });
                    });
                break;

            case 'thea-save':
                handleAddMemory({
                    text: info.selectionText || info.linkUrl || info.srcUrl || '',
                    type: info.selectionText ? 'highlight' : (info.srcUrl ? 'image' : 'bookmark'),
                    source: 'context-menu',
                    url: tab.url,
                    title: tab.title
                }).then(function () {
                    browser.tabs.sendMessage(tab.id, {
                        action: 'showNotification',
                        title: 'Saved to Memory',
                        message: 'Content saved to Thea'
                    });
                });
                break;

            case 'thea-translate':
                sendNativeMessage({
                    action: 'executeAction',
                    actionId: 'translate',
                    params: { text: info.selectionText }
                }).then(function (response) {
                    browser.tabs.sendMessage(tab.id, {
                        action: 'showResult',
                        title: 'Translation',
                        content: (response && response.result) || 'Open Thea for translation'
                    });
                });
                break;

            case 'thea-rewrite':
                handleRewriteRequest({ text: info.selectionText, style: 'user' })
                    .then(function (response) {
                        browser.tabs.sendMessage(tab.id, {
                            action: 'showRewriteSuggestion',
                            original: info.selectionText,
                            suggestion: response.suggestion || info.selectionText
                        });
                    });
                break;

            case 'thea-darkmode':
                toggleFeature('darkModeEnabled').then(function (enabled) {
                    browser.tabs.sendMessage(tab.id, {
                        type: 'featureToggled',
                        feature: 'darkModeEnabled',
                        enabled: enabled
                    });
                });
                break;

            case 'thea-research':
                deepResearch(info.selectionText || info.linkUrl, [])
                    .then(function (response) {
                        browser.tabs.sendMessage(tab.id, {
                            action: 'showResult',
                            title: 'Research Results',
                            content: (response && response.result) || 'Open Thea for results'
                        });
                    });
                break;

            case 'thea-print':
                browser.tabs.sendMessage(tab.id, { action: 'activatePrintFriendly' });
                incrementStat('pagesCleaned');
                break;
        }
    });
}

// ── Keyboard Commands ─────────────────────────────────────────────────
browser.commands.onCommand.addListener(function (command) {
    browser.tabs.query({ active: true, currentWindow: true }).then(function (tabs) {
        if (!tabs[0]) return;
        var tabId = tabs[0].id;

        switch (command) {
            case 'toggle-dark-mode':
                toggleFeature('darkModeEnabled').then(function (enabled) {
                    browser.tabs.sendMessage(tabId, {
                        type: 'featureToggled',
                        feature: 'darkModeEnabled',
                        enabled: enabled
                    });
                });
                break;

            case 'toggle-ai-sidebar':
                browser.tabs.sendMessage(tabId, { action: 'toggleAISidebar' });
                break;

            case 'quick-action':
                browser.tabs.sendMessage(tabId, { action: 'showQuickAction' });
                break;
        }
    });
});

// ── Tab Update Listener ───────────────────────────────────────────────
browser.tabs.onUpdated.addListener(function (tabId, changeInfo, tab) {
    // When a page finishes loading, send current state to the content script
    if (changeInfo.status === 'complete' && tab.url && !tab.url.startsWith('about:')) {
        browser.tabs.sendMessage(tabId, {
            type: 'stateUpdate',
            state: getState()
        }).catch(function () {
            // Content script may not be loaded yet; ignore
        });

        // Track visit if connected to native app
        if (state.isConnectedToApp) {
            trackVisitNative(tab.url, tab.title).catch(function () {});
        }
    }
});

// ── Initialization ───────────────────────────────────────────────────
(async function initializeExtension() {
    await loadState();
    console.log('[Thea BG] Extension initialized. State loaded. Features:', {
        adBlocker: state.adBlockerEnabled,
        darkMode: state.darkModeEnabled,
        privacy: state.privacyProtectionEnabled,
        memory: state.memoryEnabled,
        ai: state.aiAssistantEnabled
    });

    // Prune expired memories on startup
    await pruneExpiredMemories();

    // Ping native app to check connection
    await pingNativeApp();
})();
