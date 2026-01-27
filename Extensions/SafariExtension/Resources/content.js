// Thea Safari Extension - Content Script
// Injects into web pages for AI-powered assistance

(function() {
    'use strict';

    // Thea overlay container
    let theaOverlay = null;

    // Initialize
    function init() {
        createOverlay();
        setupListeners();
        observeSelections();
    }

    // Create the Thea overlay element
    function createOverlay() {
        theaOverlay = document.createElement('div');
        theaOverlay.id = 'thea-overlay';
        theaOverlay.style.cssText = `
            position: fixed;
            z-index: 2147483647;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: none;
        `;
        document.body.appendChild(theaOverlay);
    }

    // Setup message listeners
    function setupListeners() {
        browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
            switch (message.action) {
                case "extractPageData":
                    sendResponse(extractPageData());
                    break;
                case "showQuickAction":
                    showQuickActionMenu();
                    break;
                case "executeQuickAction":
                    executeQuickAction(message.actionId);
                    break;
                case "showNotification":
                    showNotification(message.title, message.message);
                    break;
                case "showLoading":
                    showLoading();
                    break;
                case "showResult":
                    showResult(message.title, message.content);
                    break;
            }
            return true;
        });
    }

    // Observe text selections for quick actions
    function observeSelections() {
        let selectionTimeout = null;

        document.addEventListener('mouseup', (e) => {
            clearTimeout(selectionTimeout);

            const selection = window.getSelection();
            const selectedText = selection.toString().trim();

            if (selectedText.length > 10 && selectedText.length < 5000) {
                selectionTimeout = setTimeout(() => {
                    showSelectionPopup(e.clientX, e.clientY, selectedText);
                }, 500);
            } else {
                hideSelectionPopup();
            }
        });

        document.addEventListener('mousedown', () => {
            hideSelectionPopup();
        });
    }

    // Extract page data for analysis
    function extractPageData() {
        // Get main content
        const article = document.querySelector('article, main, [role="main"]');
        const content = article ? article.innerText : document.body.innerText;

        // Get metadata
        const title = document.title;
        const url = window.location.href;
        const description = document.querySelector('meta[name="description"]')?.content || '';

        // Get structured data
        const structuredData = [];
        document.querySelectorAll('script[type="application/ld+json"]').forEach(script => {
            try {
                structuredData.push(JSON.parse(script.textContent));
            } catch (e) {}
        });

        // Get headings structure
        const headings = [];
        document.querySelectorAll('h1, h2, h3').forEach(h => {
            headings.push({
                level: h.tagName.toLowerCase(),
                text: h.textContent.trim()
            });
        });

        return {
            title,
            url,
            description,
            content: content.substring(0, 50000), // Limit content size
            headings,
            structuredData,
            language: document.documentElement.lang || 'en'
        };
    }

    // Show selection popup with Thea actions
    function showSelectionPopup(x, y, text) {
        const popup = document.createElement('div');
        popup.id = 'thea-selection-popup';
        popup.style.cssText = `
            position: fixed;
            left: ${x}px;
            top: ${y + 10}px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border-radius: 20px;
            padding: 8px 16px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.2);
            display: flex;
            gap: 12px;
            z-index: 2147483647;
            animation: theaSlideIn 0.2s ease-out;
        `;

        const actions = [
            { icon: '✨', title: 'Ask Thea', action: 'ask' },
            { icon: '📝', title: 'Summarize', action: 'summarize' },
            { icon: '🌐', title: 'Translate', action: 'translate' },
            { icon: '💾', title: 'Save', action: 'save' }
        ];

        actions.forEach(({ icon, title, action }) => {
            const btn = document.createElement('button');
            btn.textContent = icon;
            btn.title = title;
            btn.style.cssText = `
                background: rgba(255,255,255,0.2);
                border: none;
                border-radius: 50%;
                width: 32px;
                height: 32px;
                cursor: pointer;
                font-size: 16px;
                transition: transform 0.2s, background 0.2s;
            `;
            btn.addEventListener('mouseenter', () => {
                btn.style.transform = 'scale(1.1)';
                btn.style.background = 'rgba(255,255,255,0.3)';
            });
            btn.addEventListener('mouseleave', () => {
                btn.style.transform = 'scale(1)';
                btn.style.background = 'rgba(255,255,255,0.2)';
            });
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                handleSelectionAction(action, text);
                hideSelectionPopup();
            });
            popup.appendChild(btn);
        });

        // Remove any existing popup
        hideSelectionPopup();
        document.body.appendChild(popup);

        // Adjust position if off-screen
        const rect = popup.getBoundingClientRect();
        if (rect.right > window.innerWidth) {
            popup.style.left = (window.innerWidth - rect.width - 10) + 'px';
        }
        if (rect.bottom > window.innerHeight) {
            popup.style.top = (y - rect.height - 10) + 'px';
        }
    }

    function hideSelectionPopup() {
        const existing = document.getElementById('thea-selection-popup');
        if (existing) {
            existing.remove();
        }
    }

    // Handle selection actions
    function handleSelectionAction(action, text) {
        browser.runtime.sendMessage({
            target: "native",
            data: {
                action: action === 'ask' ? 'analyzeContent' :
                        action === 'save' ? 'saveToMemory' :
                        'executeAction',
                content: text,
                actionId: action,
                params: { text: text },
                data: {
                    selection: text,
                    url: window.location.href,
                    title: document.title
                }
            }
        }).then(response => {
            if (response.message || response.quickSummary) {
                showNotification('Thea', response.message || response.quickSummary);
            }
        });
    }

    // Show quick action menu
    function showQuickActionMenu() {
        const menu = document.createElement('div');
        menu.id = 'thea-quick-menu';
        menu.style.cssText = `
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: white;
            border-radius: 16px;
            padding: 20px;
            box-shadow: 0 10px 50px rgba(0,0,0,0.3);
            z-index: 2147483647;
            min-width: 300px;
        `;

        const title = document.createElement('h3');
        title.textContent = 'Thea Quick Actions';
        title.style.cssText = `
            margin: 0 0 16px 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            font-size: 18px;
        `;
        menu.appendChild(title);

        const actions = [
            { icon: '📝', title: 'Summarize Page', action: 'summarize' },
            { icon: '💾', title: 'Save to Memory', action: 'save' },
            { icon: '🔍', title: 'Explain Page', action: 'explain' },
            { icon: '📊', title: 'Extract Data', action: 'extract' },
            { icon: '🌐', title: 'Translate Page', action: 'translate' }
        ];

        actions.forEach(({ icon, title, action }) => {
            const btn = document.createElement('button');
            btn.innerHTML = `${icon} ${title}`;
            btn.style.cssText = `
                display: block;
                width: 100%;
                padding: 12px;
                margin: 8px 0;
                border: 1px solid #eee;
                border-radius: 8px;
                background: #f8f9fa;
                cursor: pointer;
                font-size: 14px;
                text-align: left;
                transition: background 0.2s;
            `;
            btn.addEventListener('mouseenter', () => {
                btn.style.background = '#e9ecef';
            });
            btn.addEventListener('mouseleave', () => {
                btn.style.background = '#f8f9fa';
            });
            btn.addEventListener('click', () => {
                executeQuickAction(action);
                menu.remove();
                if (backdrop) backdrop.remove();
            });
            menu.appendChild(btn);
        });

        // Backdrop
        const backdrop = document.createElement('div');
        backdrop.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0,0,0,0.5);
            z-index: 2147483646;
        `;
        backdrop.addEventListener('click', () => {
            menu.remove();
            backdrop.remove();
        });

        document.body.appendChild(backdrop);
        document.body.appendChild(menu);
    }

    // Execute quick action
    function executeQuickAction(actionId) {
        const pageData = extractPageData();

        browser.runtime.sendMessage({
            target: "native",
            data: {
                action: 'executeAction',
                actionId: actionId,
                params: pageData
            }
        }).then(response => {
            showNotification('Thea', response.message || 'Action queued');
        });
    }

    // Show notification
    function showNotification(title, message) {
        const notification = document.createElement('div');
        notification.id = 'thea-notification';
        notification.style.cssText = `
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 16px 24px;
            border-radius: 12px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.2);
            z-index: 2147483647;
            max-width: 350px;
            animation: theaSlideIn 0.3s ease-out;
        `;

        notification.innerHTML = `
            <div style="font-weight: bold; margin-bottom: 4px;">${title}</div>
            <div style="font-size: 14px; opacity: 0.9;">${message}</div>
        `;

        // Remove existing
        const existing = document.getElementById('thea-notification');
        if (existing) existing.remove();

        document.body.appendChild(notification);

        // Auto-dismiss
        setTimeout(() => {
            notification.style.animation = 'theaSlideOut 0.3s ease-in forwards';
            setTimeout(() => notification.remove(), 300);
        }, 4000);
    }

    // Show loading indicator
    function showLoading() {
        showNotification('Thea', '✨ Processing...');
    }

    // Show result
    function showResult(title, content) {
        const modal = document.createElement('div');
        modal.id = 'thea-result-modal';
        modal.style.cssText = `
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: white;
            border-radius: 16px;
            padding: 24px;
            box-shadow: 0 10px 50px rgba(0,0,0,0.3);
            z-index: 2147483647;
            max-width: 500px;
            max-height: 80vh;
            overflow-y: auto;
        `;

        modal.innerHTML = `
            <h3 style="margin: 0 0 16px 0; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent;">${title}</h3>
            <div style="color: #333; line-height: 1.6;">${content}</div>
            <button id="thea-close-result" style="margin-top: 16px; padding: 8px 16px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; border-radius: 8px; cursor: pointer;">Close</button>
        `;

        const backdrop = document.createElement('div');
        backdrop.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0,0,0,0.5);
            z-index: 2147483646;
        `;

        const close = () => {
            modal.remove();
            backdrop.remove();
        };

        backdrop.addEventListener('click', close);
        document.body.appendChild(backdrop);
        document.body.appendChild(modal);
        document.getElementById('thea-close-result').addEventListener('click', close);
    }

    // Add CSS animations
    const style = document.createElement('style');
    style.textContent = `
        @keyframes theaSlideIn {
            from {
                opacity: 0;
                transform: translateY(10px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        @keyframes theaSlideOut {
            from {
                opacity: 1;
                transform: translateY(0);
            }
            to {
                opacity: 0;
                transform: translateY(10px);
            }
        }
    `;
    document.head.appendChild(style);

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
