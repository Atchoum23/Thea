// Thea Chrome Extension - Life Monitoring Module
// Captures browsing activity, page content, and reading behavior
// for THEA's comprehensive life monitoring system.
//
// Privacy note: All data stays on-device and syncs via iCloud.
// User controls what's captured via extension settings.

(function() {
  'use strict';

  // ============================================================================
  // Configuration
  // ============================================================================

  const CONFIG = {
    // Monitoring toggles (synced with THEA settings)
    capturePageContent: true,
    captureReadingBehavior: true,
    captureSelections: true,
    captureLinkClicks: true,

    // Throttling
    scrollThrottleMs: 1000,
    sendIntervalMs: 30000, // Send data every 30 seconds

    // Content limits
    maxContentLength: 50000, // ~50KB of text per page
    maxSelectionsPerPage: 50,

    // Exclusions (privacy-sensitive)
    excludedDomains: [
      'bank', 'banking', 'finance', 'paypal', 'venmo',
      'password', 'login', 'signin', 'auth',
      'healthcare', 'medical', 'health',
      'mail.google.com', 'outlook.live.com', // Email compose
    ],

    excludedUrlPatterns: [
      /\/login/i,
      /\/signin/i,
      /\/auth/i,
      /\/password/i,
      /\/checkout/i,
      /\/payment/i,
      /\/billing/i,
    ]
  };

  // ============================================================================
  // State
  // ============================================================================

  let monitoringEnabled = true;
  let pageStartTime = Date.now();
  let lastScrollTime = 0;
  let maxScrollDepth = 0;
  let scrollEvents = [];
  let clickEvents = [];
  let selections = [];
  let highlights = [];
  let focusTime = 0;
  let focusStartTime = null;
  let isPageVisible = true;
  let sendInterval = null;

  // ============================================================================
  // Privacy Checks
  // ============================================================================

  function shouldMonitorPage() {
    const url = window.location.href;
    const hostname = window.location.hostname;

    // Check excluded domains
    for (const domain of CONFIG.excludedDomains) {
      if (hostname.toLowerCase().includes(domain.toLowerCase())) {
        console.log('[Thea Monitor] Skipping excluded domain:', hostname);
        return false;
      }
    }

    // Check excluded URL patterns
    for (const pattern of CONFIG.excludedUrlPatterns) {
      if (pattern.test(url)) {
        console.log('[Thea Monitor] Skipping excluded URL pattern');
        return false;
      }
    }

    // Skip extension pages, about: pages, etc.
    if (url.startsWith('chrome://') ||
        url.startsWith('chrome-extension://') ||
        url.startsWith('about:') ||
        url.startsWith('file://')) {
      return false;
    }

    return true;
  }

  function isPasswordField(element) {
    return element.type === 'password' ||
           element.autocomplete === 'current-password' ||
           element.autocomplete === 'new-password';
  }

  // ============================================================================
  // Page Content Extraction
  // ============================================================================

  function extractPageContent() {
    if (!CONFIG.capturePageContent) return null;

    // Try to find main content
    const contentSelectors = [
      'article',
      '[role="main"]',
      'main',
      '.post-content',
      '.entry-content',
      '.article-content',
      '.content',
      '#content',
      '.story-body',
      '.article-body'
    ];

    let mainElement = null;
    for (const selector of contentSelectors) {
      mainElement = document.querySelector(selector);
      if (mainElement) break;
    }

    // Fallback to body
    if (!mainElement) {
      mainElement = document.body;
    }

    // Clone to avoid modifying the page
    const clone = mainElement.cloneNode(true);

    // Remove non-content elements
    const removeSelectors = [
      'script', 'style', 'noscript', 'iframe',
      'nav', 'header', 'footer', 'aside',
      '.ad', '.ads', '.advertisement', '.sidebar',
      '.comments', '.comment', '.social-share',
      '.related-posts', '.recommended', '.promo',
      '[aria-hidden="true"]', '.hidden', '.sr-only'
    ];

    removeSelectors.forEach(selector => {
      clone.querySelectorAll(selector).forEach(el => el.remove());
    });

    // Extract text
    let text = clone.innerText || clone.textContent || '';

    // Clean up whitespace
    text = text.replace(/\s+/g, ' ').trim();

    // Truncate if too long
    if (text.length > CONFIG.maxContentLength) {
      text = text.substring(0, CONFIG.maxContentLength) + '... [truncated]';
    }

    return text;
  }

  function extractMetadata() {
    return {
      title: document.title,
      url: window.location.href,
      hostname: window.location.hostname,
      pathname: window.location.pathname,

      // OpenGraph / meta tags
      description: document.querySelector('meta[name="description"]')?.content ||
                   document.querySelector('meta[property="og:description"]')?.content,
      author: document.querySelector('meta[name="author"]')?.content ||
              document.querySelector('[rel="author"]')?.textContent,
      publishedDate: document.querySelector('meta[property="article:published_time"]')?.content ||
                     document.querySelector('time[datetime]')?.getAttribute('datetime'),
      keywords: document.querySelector('meta[name="keywords"]')?.content,

      // Page structure
      headings: extractHeadings(),
      links: extractLinks(),
      images: extractImageCount(),
      wordCount: extractWordCount(),
      estimatedReadTime: calculateReadTime()
    };
  }

  function extractHeadings() {
    const headings = [];
    document.querySelectorAll('h1, h2, h3').forEach((h, index) => {
      if (index < 20) { // Limit headings
        headings.push({
          level: parseInt(h.tagName.charAt(1)),
          text: h.textContent.trim().substring(0, 200)
        });
      }
    });
    return headings;
  }

  function extractLinks() {
    const links = [];
    const seen = new Set();
    document.querySelectorAll('a[href]').forEach(a => {
      try {
        const url = new URL(a.href);
        if (!seen.has(url.href) && url.protocol.startsWith('http')) {
          seen.add(url.href);
          if (links.length < 100) { // Limit links
            links.push({
              url: url.href,
              text: a.textContent.trim().substring(0, 100),
              isExternal: url.hostname !== window.location.hostname
            });
          }
        }
      } catch (e) {}
    });
    return links;
  }

  function extractImageCount() {
    return document.querySelectorAll('img').length;
  }

  function extractWordCount() {
    const text = document.body.innerText || '';
    return text.split(/\s+/).filter(w => w.length > 0).length;
  }

  function calculateReadTime() {
    const words = extractWordCount();
    return Math.ceil(words / 200); // ~200 words per minute
  }

  // ============================================================================
  // Reading Behavior Tracking
  // ============================================================================

  function initReadingTracking() {
    if (!CONFIG.captureReadingBehavior) return;

    // Scroll tracking
    document.addEventListener('scroll', handleScroll, { passive: true });

    // Click tracking
    document.addEventListener('click', handleClick, { capture: true });

    // Selection tracking
    document.addEventListener('selectionchange', handleSelection);

    // Visibility tracking
    document.addEventListener('visibilitychange', handleVisibilityChange);

    // Start focus timer if page is visible
    if (document.visibilityState === 'visible') {
      focusStartTime = Date.now();
    }
  }

  function handleScroll() {
    const now = Date.now();

    // Throttle scroll events
    if (now - lastScrollTime < CONFIG.scrollThrottleMs) return;
    lastScrollTime = now;

    // Calculate scroll depth
    const scrollHeight = document.documentElement.scrollHeight - window.innerHeight;
    const scrollPercent = scrollHeight > 0
      ? Math.round((window.scrollY / scrollHeight) * 100)
      : 100;

    maxScrollDepth = Math.max(maxScrollDepth, scrollPercent);

    scrollEvents.push({
      timestamp: now,
      depth: scrollPercent,
      position: window.scrollY
    });

    // Keep only recent events (last 100)
    if (scrollEvents.length > 100) {
      scrollEvents = scrollEvents.slice(-100);
    }
  }

  function handleClick(e) {
    // Skip password fields
    if (isPasswordField(e.target)) return;

    const target = e.target.closest('a, button, [role="button"], [onclick]');
    if (!target) return;

    const clickData = {
      timestamp: Date.now(),
      tag: target.tagName.toLowerCase(),
      text: target.textContent?.trim().substring(0, 100) || '',
      isLink: target.tagName === 'A',
      href: target.href || null,
      position: {
        x: e.clientX,
        y: e.clientY
      }
    };

    // Track link clicks specially
    if (clickData.isLink && CONFIG.captureLinkClicks) {
      clickData.linkType = isExternalLink(target.href) ? 'external' : 'internal';
    }

    clickEvents.push(clickData);

    // Keep only recent clicks (last 50)
    if (clickEvents.length > 50) {
      clickEvents = clickEvents.slice(-50);
    }
  }

  function handleSelection() {
    if (!CONFIG.captureSelections) return;

    const selection = window.getSelection();
    const text = selection?.toString().trim();

    if (text && text.length > 3 && text.length < 1000) {
      // Check we're not in a sensitive field
      const anchorNode = selection.anchorNode;
      if (anchorNode) {
        const parentElement = anchorNode.parentElement;
        if (parentElement && isPasswordField(parentElement)) return;
      }

      // Avoid duplicates
      if (!selections.some(s => s.text === text)) {
        selections.push({
          timestamp: Date.now(),
          text: text.substring(0, 500),
          context: getSelectionContext(selection)
        });

        // Keep only recent selections
        if (selections.length > CONFIG.maxSelectionsPerPage) {
          selections = selections.slice(-CONFIG.maxSelectionsPerPage);
        }
      }
    }
  }

  function getSelectionContext(selection) {
    try {
      const range = selection.getRangeAt(0);
      const container = range.commonAncestorContainer;
      const parentElement = container.nodeType === Node.TEXT_NODE
        ? container.parentElement
        : container;

      return {
        tag: parentElement?.tagName?.toLowerCase(),
        className: parentElement?.className?.substring?.(0, 50)
      };
    } catch (e) {
      return null;
    }
  }

  function handleVisibilityChange() {
    if (document.visibilityState === 'visible') {
      isPageVisible = true;
      focusStartTime = Date.now();
    } else {
      isPageVisible = false;
      if (focusStartTime) {
        focusTime += Date.now() - focusStartTime;
        focusStartTime = null;
      }
    }
  }

  function isExternalLink(href) {
    try {
      const url = new URL(href);
      return url.hostname !== window.location.hostname;
    } catch (e) {
      return false;
    }
  }

  // ============================================================================
  // Data Collection & Transmission
  // ============================================================================

  function collectPageData() {
    // Calculate final focus time
    let totalFocusTime = focusTime;
    if (focusStartTime && isPageVisible) {
      totalFocusTime += Date.now() - focusStartTime;
    }

    const data = {
      type: 'pageVisit',
      timestamp: Date.now(),
      startTime: pageStartTime,
      duration: Date.now() - pageStartTime,
      focusTime: totalFocusTime,

      // Page info
      metadata: extractMetadata(),

      // Content (if enabled)
      content: CONFIG.capturePageContent ? extractPageContent() : null,

      // Reading behavior
      readingBehavior: CONFIG.captureReadingBehavior ? {
        maxScrollDepth,
        scrollEvents: scrollEvents.length,
        scrollPattern: analyzeScrollPattern(),
        clicks: clickEvents,
        selections,
        engagement: calculateEngagement(totalFocusTime)
      } : null
    };

    return data;
  }

  function analyzeScrollPattern() {
    if (scrollEvents.length < 2) return 'none';

    // Analyze scroll behavior
    let ups = 0, downs = 0;
    for (let i = 1; i < scrollEvents.length; i++) {
      if (scrollEvents[i].position > scrollEvents[i-1].position) downs++;
      else ups++;
    }

    const total = ups + downs;
    if (total === 0) return 'none';

    const upRatio = ups / total;
    if (upRatio > 0.3) return 'revisiting'; // User scrolled back up to re-read
    if (maxScrollDepth > 75) return 'thorough';
    if (maxScrollDepth > 50) return 'moderate';
    return 'skimming';
  }

  function calculateEngagement(focusTime) {
    const readTime = calculateReadTime() * 60 * 1000; // Convert to ms
    if (readTime === 0) return 'unknown';

    const ratio = focusTime / readTime;

    if (ratio > 1.2) return 'high'; // Spent more time than expected
    if (ratio > 0.6) return 'medium';
    if (ratio > 0.2) return 'low';
    return 'bounce';
  }

  async function sendDataToThea(data) {
    try {
      // Send via extension messaging to background script
      const response = await chrome.runtime.sendMessage({
        type: 'lifeMonitorData',
        data
      });

      if (response?.success) {
        console.log('[Thea Monitor] Data sent successfully');
      }
    } catch (e) {
      console.log('[Thea Monitor] Failed to send data:', e.message);
    }
  }

  function startPeriodicSend() {
    sendInterval = setInterval(() => {
      if (monitoringEnabled && shouldMonitorPage()) {
        const data = collectPageData();
        sendDataToThea(data);
      }
    }, CONFIG.sendIntervalMs);
  }

  // ============================================================================
  // Page Lifecycle
  // ============================================================================

  function handlePageUnload() {
    if (!monitoringEnabled || !shouldMonitorPage()) return;

    // Send final data
    const data = collectPageData();
    data.isComplete = true;

    // Use sendBeacon for reliable delivery
    try {
      const blob = new Blob([JSON.stringify({
        type: 'lifeMonitorData',
        data
      })], { type: 'application/json' });

      // Try to send via background script first (more reliable)
      chrome.runtime.sendMessage({
        type: 'lifeMonitorData',
        data,
        urgent: true
      });
    } catch (e) {
      console.log('[Thea Monitor] Failed to send final data');
    }
  }

  // ============================================================================
  // Settings Sync
  // ============================================================================

  async function loadSettings() {
    try {
      const response = await chrome.runtime.sendMessage({
        type: 'getLifeMonitorSettings'
      });

      if (response?.success && response.data) {
        Object.assign(CONFIG, response.data);
        monitoringEnabled = response.data.enabled !== false;
      }
    } catch (e) {
      console.log('[Thea Monitor] Failed to load settings');
    }
  }

  // Listen for settings changes
  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === 'lifeMonitorSettingsChanged') {
      Object.assign(CONFIG, message.data);
      monitoringEnabled = message.data.enabled !== false;
      sendResponse({ success: true });
    }
    return true;
  });

  // ============================================================================
  // Initialization
  // ============================================================================

  async function init() {
    await loadSettings();

    if (!monitoringEnabled) {
      console.log('[Thea Monitor] Monitoring disabled');
      return;
    }

    if (!shouldMonitorPage()) {
      console.log('[Thea Monitor] Page excluded from monitoring');
      return;
    }

    console.log('[Thea Monitor] Initializing life monitoring...');

    // Initialize tracking
    initReadingTracking();

    // Start periodic data sending
    startPeriodicSend();

    // Handle page unload
    window.addEventListener('beforeunload', handlePageUnload);
    window.addEventListener('pagehide', handlePageUnload);

    // Send initial page visit event
    setTimeout(() => {
      const data = collectPageData();
      data.isInitial = true;
      sendDataToThea(data);
    }, 2000); // Wait for page to fully load
  }

  // Start when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
