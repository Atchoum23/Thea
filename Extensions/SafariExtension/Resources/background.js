// Thea Safari Extension - Background Script
// Handles extension lifecycle and messaging

// Use browser.menus (Safari) with fallback to browser.contextMenus (Chrome compat)
const menus = browser.menus || browser.contextMenus;

// Context menu setup
browser.runtime.onInstalled.addListener(() => {
    if (!menus) return;

    menus.create({
        id: "thea-ask",
        title: "Ask Thea about \"%s\"",
        contexts: ["selection"]
    });

    menus.create({
        id: "thea-summarize",
        title: "Summarize with Thea",
        contexts: ["page", "link"]
    });

    menus.create({
        id: "thea-save",
        title: "Save to Thea Memory",
        contexts: ["selection", "link", "image"]
    });

    menus.create({
        id: "thea-translate",
        title: "Translate with Thea",
        contexts: ["selection"]
    });
});

// Handle context menu clicks
if (menus) {
    menus.onClicked.addListener((info, tab) => {
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
}

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
        return true;
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
    }).catch(() => {});
});

// Action handlers
async function handleAsk(text, tab) {
    try {
        const response = await browser.runtime.sendNativeMessage("app.thea.safari", {
            action: "analyzeContent",
            content: text,
            url: tab.url
        });

        if (response && response.quickSummary) {
            browser.tabs.sendMessage(tab.id, {
                action: "showNotification",
                title: "Thea",
                message: response.quickSummary
            });
        }
    } catch (err) {
        console.error("handleAsk error:", err);
    }
}

async function handleSummarize(url, tab) {
    try {
        browser.tabs.sendMessage(tab.id, { action: "showLoading" });

        const content = await getPageContent(tab.id);
        const response = await browser.runtime.sendNativeMessage("app.thea.safari", {
            action: "analyzeContent",
            content: content,
            url: url
        });

        browser.tabs.sendMessage(tab.id, {
            action: "showResult",
            title: "Summary",
            content: (response && response.quickSummary) || "Could not summarize"
        });
    } catch (err) {
        console.error("handleSummarize error:", err);
    }
}

async function handleSave(info, tab) {
    try {
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
    } catch (err) {
        console.error("handleSave error:", err);
    }
}

async function handleTranslate(text, tab) {
    try {
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
    } catch (err) {
        console.error("handleTranslate error:", err);
    }
}

async function getPageContent(tabId) {
    try {
        const response = await browser.tabs.sendMessage(tabId, { action: "extractPageData" });
        return response.content || "";
    } catch {
        return "";
    }
}
