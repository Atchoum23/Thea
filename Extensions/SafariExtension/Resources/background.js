// Thea Safari Extension - Background Script
// Handles extension lifecycle and messaging

// Context menu setup
browser.runtime.onInstalled.addListener(() => {
    // Create context menu items
    browser.contextMenus.create({
        id: "thea-ask",
        title: "Ask Thea about \"%s\"",
        contexts: ["selection"]
    });

    browser.contextMenus.create({
        id: "thea-summarize",
        title: "Summarize with Thea",
        contexts: ["page", "link"]
    });

    browser.contextMenus.create({
        id: "thea-save",
        title: "Save to Thea Memory",
        contexts: ["selection", "link", "image"]
    });

    browser.contextMenus.create({
        id: "thea-translate",
        title: "Translate with Thea",
        contexts: ["selection"]
    });
});

// Handle context menu clicks
browser.contextMenus.onClicked.addListener((info, tab) => {
    switch (info.menuItemId) {
        case "thea-ask":
            handleAsk(info.selectionText, tab);
            break;
        case "thea-summarize":
            handleSummarize(info.pageUrl || info.linkUrl, tab);
            break;
        case "thea-save":
            handleSave(info, tab);
            break;
        case "thea-translate":
            handleTranslate(info.selectionText, tab);
            break;
    }
});

// Handle keyboard shortcuts
browser.commands.onCommand.addListener((command) => {
    if (command === "quick-action") {
        browser.tabs.query({ active: true, currentWindow: true }).then((tabs) => {
            if (tabs[0]) {
                browser.tabs.sendMessage(tabs[0].id, { action: "showQuickAction" });
            }
        });
    }
});

// Message handling from content scripts and popup
browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.target === "native") {
        // Forward to native handler
        browser.runtime.sendNativeMessage("app.thea.safari", message.data)
            .then(response => sendResponse(response))
            .catch(error => sendResponse({ error: error.message }));
        return true; // Keep channel open for async response
    }

    switch (message.action) {
        case "getPageData":
            browser.tabs.query({ active: true, currentWindow: true }).then((tabs) => {
                if (tabs[0]) {
                    browser.tabs.sendMessage(tabs[0].id, { action: "extractPageData" })
                        .then(response => sendResponse(response))
                        .catch(() => sendResponse({ error: "Could not extract page data" }));
                }
            });
            return true;

        case "trackVisit":
            // Send to native for tracking
            browser.runtime.sendNativeMessage("app.thea.safari", {
                action: "trackBrowsing",
                url: message.url,
                title: message.title
            }).catch(() => {});
            sendResponse({ success: true });
            break;

        case "executeQuickAction":
            browser.tabs.query({ active: true, currentWindow: true }).then((tabs) => {
                if (tabs[0]) {
                    browser.tabs.sendMessage(tabs[0].id, {
                        action: "executeQuickAction",
                        actionId: message.actionId
                    });
                }
            });
            sendResponse({ success: true });
            break;
    }

    return false;
});

// Track tab changes
browser.tabs.onActivated.addListener((activeInfo) => {
    browser.tabs.get(activeInfo.tabId).then((tab) => {
        if (tab.url && !tab.url.startsWith("about:")) {
            browser.runtime.sendNativeMessage("app.thea.safari", {
                action: "trackBrowsing",
                url: tab.url,
                title: tab.title
            }).catch(() => {});
        }
    });
});

// Handle page complete loads
browser.webNavigation.onCompleted.addListener((details) => {
    if (details.frameId === 0) { // Main frame only
        browser.tabs.get(details.tabId).then((tab) => {
            browser.runtime.sendNativeMessage("app.thea.safari", {
                action: "trackBrowsing",
                url: tab.url,
                title: tab.title
            }).catch(() => {});
        });
    }
});

// Action handlers
async function handleAsk(text, tab) {
    const response = await browser.runtime.sendNativeMessage("app.thea.safari", {
        action: "analyzeContent",
        content: text,
        url: tab.url
    });

    if (response.quickSummary) {
        browser.tabs.sendMessage(tab.id, {
            action: "showNotification",
            title: "Thea",
            message: response.quickSummary
        });
    }
}

async function handleSummarize(url, tab) {
    browser.tabs.sendMessage(tab.id, { action: "showLoading" });

    const response = await browser.runtime.sendNativeMessage("app.thea.safari", {
        action: "analyzeContent",
        content: await getPageContent(tab.id),
        url: url
    });

    browser.tabs.sendMessage(tab.id, {
        action: "showResult",
        title: "Summary",
        content: response.quickSummary || response.message
    });
}

async function handleSave(info, tab) {
    const data = {
        url: tab.url,
        title: tab.title,
        selection: info.selectionText,
        linkUrl: info.linkUrl,
        imageUrl: info.srcUrl,
        timestamp: Date.now()
    };

    await browser.runtime.sendNativeMessage("app.thea.safari", {
        action: "saveToMemory",
        data: data
    });

    browser.tabs.sendMessage(tab.id, {
        action: "showNotification",
        title: "Saved to Memory",
        message: "Content saved to Thea"
    });
}

async function handleTranslate(text, tab) {
    await browser.runtime.sendNativeMessage("app.thea.safari", {
        action: "executeAction",
        actionId: "translate",
        params: { text: text }
    });

    browser.tabs.sendMessage(tab.id, {
        action: "showNotification",
        title: "Translation",
        message: "Open Thea for translation"
    });
}

async function getPageContent(tabId) {
    try {
        const response = await browser.tabs.sendMessage(tabId, { action: "extractPageData" });
        return response.content || "";
    } catch {
        return "";
    }
}
