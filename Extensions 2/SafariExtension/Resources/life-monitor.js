// Thea Safari Extension - Life Monitor Content Script
// Comprehensive life monitoring for Safari browser
// Tracks page content, reading behavior, and browsing patterns

(function() {
    'use strict';

    // Configuration (synced with background script)
    const config = {
        enabled: true,
        capturePageContent: true,
        trackReadingBehavior: true,
        trackNavigationHistory: true,
        minReadingTimeMs: 5000,
        maxContentLength: 50000
    };

    // Session state
    const session = {
        pageLoadTime: Date.now(),
        scrollDepth: 0,
        maxScrollDepth: 0,
        timeOnPage: 0,
        interactions: [],
        selections: [],
        lastScrollTime: Date.now(),
        activeTime: 0,
        idleThreshold: 30000, // 30 seconds
        lastActivityTime: Date.now()
    };

    // Sensitive URL patterns to skip for privacy
    const sensitivePatterns = [
        /banking|bank\./i,
        /paypal|venmo|stripe|checkout/i,
        /healthcare|medical|health\./i,
        /password|login|signin|auth/i,
        /\.gov\//i,
        /mail\.google|outlook\.live|protonmail|mail\./i,
        /account\.apple|appleid\.apple/i
    ];

    // Check if current page should be monitored
    function shouldMonitor() {
        if (!config.enabled) return false;
        const url = window.location.href;
        return !sensitivePatterns.some(pattern => pattern.test(url));
    }

    // Extract main content from page
    function extractPageContent() {
        if (!config.capturePageContent || !shouldMonitor()) {
            return null;
        }

        // Try to find main content area
        const mainSelectors = [
            'article',
            'main',
            '[role="main"]',
            '.post-content',
            '.article-content',
            '.entry-content',
            '#content',
            '.content'
        ];

        let mainContent = null;
        for (const selector of mainSelectors) {
            mainContent = document.querySelector(selector);
            if (mainContent) break;
        }

        const contentElement = mainContent || document.body;

        // Get text content
        let textContent = contentElement.innerText || '';

        // Truncate if too long
        if (textContent.length > config.maxContentLength) {
            textContent = textContent.substring(0, config.maxContentLength) + '...[truncated]';
        }

        // Extract metadata
        const metadata = {
            title: document.title,
            url: window.location.href,
            domain: window.location.hostname,
            description: document.querySelector('meta[name="description"]')?.content || '',
            author: document.querySelector('meta[name="author"]')?.content ||
                    document.querySelector('[rel="author"]')?.textContent || '',
            publishDate: document.querySelector('meta[property="article:published_time"]')?.content ||
                        document.querySelector('time[datetime]')?.getAttribute('datetime') || '',
            language: document.documentElement.lang || 'en',
            wordCount: textContent.split(/\s+/).filter(w => w.length > 0).length
        };

        // Get headings structure
        const headings = [];
        document.querySelectorAll('h1, h2, h3').forEach(h => {
            headings.push({
                level: parseInt(h.tagName.charAt(1)),
                text: h.textContent.trim().substring(0, 200)
            });
        });

        // Get links for context
        const links = [];
        document.querySelectorAll('a[href]').forEach(a => {
            const href = a.href;
            if (href && !href.startsWith('javascript:') && links.length < 50) {
                links.push({
                    text: a.textContent.trim().substring(0, 100),
                    href: href,
                    isExternal: !href.includes(window.location.hostname)
                });
            }
        });

        return {
            metadata,
            textContent,
            headings,
            links,
            extractedAt: new Date().toISOString()
        };
    }

    // Calculate scroll depth percentage
    function calculateScrollDepth() {
        const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
        const scrollHeight = document.documentElement.scrollHeight;
        const clientHeight = document.documentElement.clientHeight;

        if (scrollHeight <= clientHeight) {
            return 100;
        }

        return Math.round((scrollTop / (scrollHeight - clientHeight)) * 100);
    }

    // Track scroll behavior
    function trackScroll() {
        if (!config.trackReadingBehavior || !shouldMonitor()) return;

        const currentDepth = calculateScrollDepth();
        session.scrollDepth = currentDepth;
        session.maxScrollDepth = Math.max(session.maxScrollDepth, currentDepth);
        session.lastScrollTime = Date.now();
        session.lastActivityTime = Date.now();
    }

    // Track user interactions
    function trackInteraction(type, details = {}) {
        if (!config.trackReadingBehavior || !shouldMonitor()) return;

        session.interactions.push({
            type,
            timestamp: Date.now(),
            ...details
        });

        session.lastActivityTime = Date.now();
    }

    // Track text selections
    function trackSelection() {
        if (!config.trackReadingBehavior || !shouldMonitor()) return;

        const selection = window.getSelection();
        const selectedText = selection.toString().trim();

        if (selectedText.length >= 10 && selectedText.length <= 1000) {
            session.selections.push({
                text: selectedText,
                timestamp: Date.now()
            });

            // Notify background about selection
            sendToBackground('textSelection', {
                url: window.location.href,
                selectedText: selectedText.substring(0, 500),
                context: {
                    pageTitle: document.title,
                    domain: window.location.hostname
                }
            });
        }
    }

    // Track link clicks
    function trackLinkClick(event) {
        if (!config.trackNavigationHistory || !shouldMonitor()) return;

        const link = event.target.closest('a');
        if (!link || !link.href) return;

        sendToBackground('linkClick', {
            sourceUrl: window.location.href,
            targetUrl: link.href,
            linkText: link.textContent.trim().substring(0, 200),
            isExternal: !link.href.includes(window.location.hostname),
            timestamp: new Date().toISOString()
        });
    }

    // Send data to background script
    function sendToBackground(eventType, payload) {
        try {
            browser.runtime.sendMessage({
                action: 'lifeMonitorData',
                eventType,
                payload
            }).catch(() => {
                // Extension context may be invalidated
            });
        } catch (e) {
            // Ignore errors when extension context is invalid
        }
    }

    // Calculate active time (excluding idle periods)
    function updateActiveTime() {
        const now = Date.now();
        if (now - session.lastActivityTime < session.idleThreshold) {
            session.activeTime += 1000; // Add 1 second
        }
    }

    // Send page visit data
    function sendPageVisit() {
        if (!shouldMonitor()) return;

        const pageContent = extractPageContent();

        sendToBackground('pageVisit', {
            url: window.location.href,
            title: document.title,
            domain: window.location.hostname,
            content: pageContent,
            visitedAt: new Date().toISOString(),
            referrer: document.referrer || null
        });
    }

    // Send reading session data
    function sendReadingSession() {
        if (!config.trackReadingBehavior || !shouldMonitor()) return;

        const timeOnPage = Date.now() - session.pageLoadTime;

        // Only send if meaningful time was spent
        if (timeOnPage < config.minReadingTimeMs) {
            return;
        }

        sendToBackground('readingSession', {
            url: window.location.href,
            title: document.title,
            domain: window.location.hostname,
            timeOnPageMs: timeOnPage,
            activeTimeMs: session.activeTime,
            maxScrollDepth: session.maxScrollDepth,
            interactionCount: session.interactions.length,
            selectionCount: session.selections.length,
            wordCount: extractPageContent()?.metadata?.wordCount || 0,
            startedAt: new Date(session.pageLoadTime).toISOString(),
            endedAt: new Date().toISOString()
        });
    }

    // Initialize monitoring
    function init() {
        // Request settings from background
        browser.runtime.sendMessage({ action: 'getLifeMonitorSettings' })
            .then(response => {
                if (response && response.success) {
                    Object.assign(config, response.data);
                }
            })
            .catch(() => {
                // Use defaults if can't get settings
            });

        // Set up event listeners
        if (shouldMonitor()) {
            // Scroll tracking (throttled)
            let scrollTimeout = null;
            window.addEventListener('scroll', () => {
                if (scrollTimeout) return;
                scrollTimeout = setTimeout(() => {
                    trackScroll();
                    scrollTimeout = null;
                }, 200);
            }, { passive: true });

            // Click tracking
            document.addEventListener('click', (e) => {
                trackInteraction('click', {
                    element: e.target.tagName,
                    isLink: !!e.target.closest('a')
                });
                trackLinkClick(e);
            });

            // Selection tracking (debounced)
            let selectionTimeout = null;
            document.addEventListener('selectionchange', () => {
                clearTimeout(selectionTimeout);
                selectionTimeout = setTimeout(trackSelection, 500);
            });

            // Visibility change (for tracking when user leaves/returns)
            document.addEventListener('visibilitychange', () => {
                if (document.hidden) {
                    sendReadingSession();
                } else {
                    session.lastActivityTime = Date.now();
                }
            });

            // Keyboard activity
            document.addEventListener('keydown', () => {
                session.lastActivityTime = Date.now();
            }, { passive: true });

            // Mouse movement (less frequent)
            let lastMouseMove = 0;
            document.addEventListener('mousemove', () => {
                const now = Date.now();
                if (now - lastMouseMove > 5000) {
                    session.lastActivityTime = now;
                    lastMouseMove = now;
                }
            }, { passive: true });

            // Active time tracking
            setInterval(updateActiveTime, 1000);

            // Send page visit after content loads
            if (document.readyState === 'complete') {
                setTimeout(sendPageVisit, 1000);
            } else {
                window.addEventListener('load', () => {
                    setTimeout(sendPageVisit, 1000);
                });
            }

            // Send reading session when leaving
            window.addEventListener('beforeunload', sendReadingSession);

            // Periodic reading session updates (every 5 minutes for long sessions)
            setInterval(() => {
                const timeOnPage = Date.now() - session.pageLoadTime;
                if (timeOnPage > 300000) { // 5 minutes
                    sendReadingSession();
                }
            }, 300000);
        }
    }

    // Listen for settings updates from background
    browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
        if (message.action === 'lifeMonitorSettingsChanged') {
            Object.assign(config, message.data);
            sendResponse({ success: true });
        }
        return false;
    });

    // Initialize
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    console.log('[Thea Life Monitor] Safari content script loaded');
})();
