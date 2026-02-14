/**
 * Thea Cosmetic Filter Engine
 *
 * Inspired by: uBlock Origin, AdGuard, Brave Shields
 *
 * Features:
 * - Comprehensive cosmetic filtering (hide ad elements via CSS)
 * - Generic selectors (apply to all sites)
 * - Site-specific selectors
 * - Element picker tool (click-to-hide custom elements)
 * - Collapsed ad placeholder removal
 * - Cookie notice removal
 * - Newsletter popup blocking
 * - Anti-adblock warning dismissal
 */

(function() {
  'use strict';

  let enabled = true;
  let customRules = [];
  let styleElement = null;

  // ============================================================================
  // Generic Cosmetic Selectors (apply to all sites)
  // ============================================================================

  const GENERIC_HIDE_SELECTORS = [
    // Ad containers
    '.ad', '.ads', '.ad-container', '.ad-wrapper', '.ad-slot', '.ad-unit',
    '.ad-banner', '.ad-block', '.ad-holder', '.ad-placement', '.ad-zone',
    '.ad-section', '.ad-leaderboard', '.ad-sidebar', '.ad-footer',
    '.ad-header', '.ad-top', '.ad-bottom', '.ad-left', '.ad-right',
    '.ad-inner', '.ad-outer', '.ad-frame', '.ad-box', '.ad-card',
    '[class*="ad-container"]', '[class*="ad-wrapper"]', '[class*="ad-slot"]',
    '[id*="ad-container"]', '[id*="ad-wrapper"]', '[id*="ad-slot"]',

    // Google Ads
    '.adsbygoogle', 'ins.adsbygoogle', '[id^="google_ads_"]',
    '[id^="div-gpt-ad"]', '.dfp-ad', '.google-ad', '.gpt-ad',
    '#google_ads_frame', 'iframe[src*="googlesyndication"]',
    'iframe[src*="doubleclick"]',

    // Sponsored content
    '.sponsored', '.sponsored-content', '.sponsored-post',
    '.promoted', '.promoted-content', '.promoted-post',
    '.native-ad', '.content-ad', '.advertorial',
    '[data-ad]', '[data-advertisement]', '[data-ad-slot]',
    '[data-ad-unit]', '[data-adid]', '[data-ad-region]',

    // Recommendation widgets
    '.taboola', '.taboola-container', '#taboola-below',
    '.outbrain', '.OUTBRAIN', '[data-outbrain-widget]',
    '.zergnet', '.revcontent', '.content-recommendation',
    '.mgid', '.monetize', '.yahoo-gemini',

    // Social share buttons
    '.share-buttons', '.social-share', '.social-buttons',
    '.share-bar', '.sharing-buttons', '.addthis',

    // Newsletter popups
    '.newsletter-popup', '.popup-newsletter', '.email-popup',
    '.subscribe-popup', '.subscribe-modal', '.signup-popup',
    '#newsletter-modal', '#email-subscribe-modal',
    '[class*="newsletter-popup"]', '[class*="subscribe-popup"]',

    // Cookie/consent notices (handled more aggressively by privacy-shield.js)
    '.cookie-banner', '.cookie-notice', '.cookie-bar',

    // Sticky ads
    '.sticky-ad', '.fixed-ad', '.floating-ad',
    '[class*="sticky-ad"]', '[class*="fixed-ad"]',

    // Video ads
    '.video-ad', '.preroll-ad', '.midroll-ad',
    '.video-ad-container',

    // Mobile interstitials
    '.interstitial', '.interstitial-ad',
    '.app-install-banner', '.smart-banner',
    '.app-download-banner',

    // Generic patterns
    '[aria-label="advertisement"]',
    '[aria-label="Advertisement"]',
    '[aria-label="Sponsored"]',
    'aside[class*="ad"]',
    'section[class*="ad-"]',
    'div[class*="AdSlot"]',
    'div[class*="adUnit"]',
    'div[data-testid*="ad"]',
    'div[data-qa*="ad"]',
  ];

  // ============================================================================
  // Site-Specific Rules
  // ============================================================================

  const SITE_RULES = {
    'youtube.com': [
      '.ytp-ad-module', '.ytd-promoted-sparkles-web-renderer',
      '#player-ads', '.ytd-display-ad-renderer',
      'ytd-promoted-sparkles-web-renderer', 'ytd-action-companion-ad-renderer',
      '#masthead-ad', '.ytd-banner-promo-renderer',
      'ytd-merch-shelf-renderer', '.ytd-in-feed-ad-layout-renderer'
    ],
    'reddit.com': [
      '.promoted', '[data-promoted]', '.promotedlink',
      'shreddit-ad-post', '[slot="promoted"]',
      '.ad-container', '#ad-container'
    ],
    'twitter.com': [
      '[data-testid="promotedIndicator"]',
      'article:has([data-testid="promotedIndicator"])'
    ],
    'x.com': [
      '[data-testid="promotedIndicator"]',
      'article:has([data-testid="promotedIndicator"])'
    ],
    'facebook.com': [
      '[data-ad-preview]', '.sponsored',
      'div[data-pagelet*="FeedUnit"]:has(a[href*="ads"])'
    ],
    'instagram.com': [
      'article:has([aria-label*="Sponsored"])',
      'div[class*="Sponsored"]'
    ],
    'linkedin.com': [
      '.feed-shared-update-v2--ad',
      '.ad-banner-container',
      '.ads-container'
    ],
    'amazon.com': [
      '.s-sponsored-header', '.AdHolder',
      'div[data-ad-details]', '.s-sponsored-info-icon',
      '[cel_widget_id*="SPONSORED"]'
    ],
    'stackoverflow.com': [
      '.everyonelovesstackoverflow', '#dfp-tlb',
      '#hireme', '.js-zone-container'
    ],
    'medium.com': [
      '.branch-journeys-top', '.meteredContent',
      '[class*="paywall"]'
    ]
  };

  // ============================================================================
  // Anti-Adblock Warning Selectors
  // ============================================================================

  const ANTI_ADBLOCK_SELECTORS = [
    '.adblock-notice', '.adblock-warning', '.adblock-modal',
    '#adblock-notice', '#adblock-warning', '#adblock-modal',
    '.adblocker-detected', '.adblocker-notice',
    '[class*="adblock-detect"]', '[class*="adblocker-detect"]',
    '[id*="adblock-detect"]', '[id*="adblocker-detect"]',
    '.disable-adblock', '#disable-adblock',
    '.ad-blocker-message', '#ad-blocker-message'
  ];

  // ============================================================================
  // Apply Cosmetic Filters
  // ============================================================================

  function applyFilters() {
    if (!enabled) return;

    const selectors = [...GENERIC_HIDE_SELECTORS];

    // Add site-specific rules
    const hostname = window.location.hostname;
    for (const [domain, rules] of Object.entries(SITE_RULES)) {
      if (hostname.includes(domain)) {
        selectors.push(...rules);
      }
    }

    // Add anti-adblock selectors
    selectors.push(...ANTI_ADBLOCK_SELECTORS);

    // Add custom user rules
    selectors.push(...customRules);

    if (styleElement) {
      styleElement.remove();
    }

    const css = selectors.join(',\n') + ` {
      display: none !important;
      visibility: hidden !important;
      height: 0 !important;
      min-height: 0 !important;
      max-height: 0 !important;
      overflow: hidden !important;
      opacity: 0 !important;
      pointer-events: none !important;
    }`;

    styleElement = document.createElement('style');
    styleElement.id = 'thea-cosmetic-filter';
    styleElement.textContent = css;

    // Insert early to prevent flash of ads
    const target = document.head || document.documentElement;
    if (target.firstChild) {
      target.insertBefore(styleElement, target.firstChild);
    } else {
      target.appendChild(styleElement);
    }

    // Count hidden elements
    countBlockedElements(selectors);
  }

  function countBlockedElements(selectors) {
    let count = 0;
    try {
      const joined = selectors.join(',');
      count = document.querySelectorAll(joined).length;
    } catch (e) {
      // Some selectors might not be valid in all browsers
    }

    if (count > 0) {
      chrome.runtime.sendMessage({
        type: 'updateStats',
        data: { adsBlocked: count }
      }).catch(() => {});
    }
  }

  // ============================================================================
  // Collapse Empty Ad Frames
  // ============================================================================

  function collapseEmptyFrames() {
    const iframes = document.querySelectorAll('iframe');
    iframes.forEach(iframe => {
      const src = iframe.src || '';
      const adPatterns = [
        'googlesyndication', 'doubleclick', 'adsystem',
        'adserver', 'adservice', '/ads/', '/ad/',
        'amazon-adsystem', 'criteo', 'taboola', 'outbrain'
      ];

      if (adPatterns.some(p => src.includes(p))) {
        iframe.style.display = 'none';
        iframe.style.height = '0';
      }
    });
  }

  // ============================================================================
  // Element Picker Tool
  // ============================================================================

  let pickerActive = false;
  let pickerOverlay = null;
  let pickerHighlight = null;

  function activateElementPicker() {
    if (pickerActive) return;
    pickerActive = true;

    // Create overlay
    pickerOverlay = document.createElement('div');
    pickerOverlay.style.cssText = `
      position: fixed; top: 0; left: 0; right: 0; bottom: 0;
      z-index: 2147483645; cursor: crosshair;
    `;

    // Create highlight element
    pickerHighlight = document.createElement('div');
    pickerHighlight.style.cssText = `
      position: fixed; pointer-events: none;
      z-index: 2147483646;
      border: 2px dashed #e94560;
      background: rgba(233, 69, 96, 0.1);
      transition: all 0.1s ease;
    `;

    // Info tooltip
    const info = document.createElement('div');
    info.style.cssText = `
      position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%);
      background: #1a1a2e; color: white; padding: 10px 20px;
      border-radius: 8px; font-size: 13px; z-index: 2147483647;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
    `;
    info.textContent = 'Click an element to hide it. Press Escape to cancel.';

    document.body.appendChild(pickerOverlay);
    document.body.appendChild(pickerHighlight);
    document.body.appendChild(info);

    pickerOverlay.addEventListener('mousemove', (e) => {
      pickerOverlay.style.pointerEvents = 'none';
      const el = document.elementFromPoint(e.clientX, e.clientY);
      pickerOverlay.style.pointerEvents = 'auto';

      if (el && el !== pickerOverlay && el !== pickerHighlight && el !== info) {
        const rect = el.getBoundingClientRect();
        pickerHighlight.style.top = rect.top + 'px';
        pickerHighlight.style.left = rect.left + 'px';
        pickerHighlight.style.width = rect.width + 'px';
        pickerHighlight.style.height = rect.height + 'px';
      }
    });

    pickerOverlay.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();

      pickerOverlay.style.pointerEvents = 'none';
      const el = document.elementFromPoint(e.clientX, e.clientY);
      pickerOverlay.style.pointerEvents = 'auto';

      if (el && el !== pickerOverlay && el !== pickerHighlight && el !== info) {
        // Generate a selector for this element
        const selector = generateSelector(el);
        if (selector) {
          customRules.push(selector);
          saveCustomRules();
          el.style.display = 'none';
        }
      }

      deactivateElementPicker();
    });

    const escHandler = (e) => {
      if (e.key === 'Escape') {
        deactivateElementPicker();
        document.removeEventListener('keydown', escHandler);
      }
    };
    document.addEventListener('keydown', escHandler);

    // Store reference for cleanup
    pickerOverlay._info = info;
    pickerOverlay._escHandler = escHandler;
  }

  function deactivateElementPicker() {
    pickerActive = false;
    if (pickerOverlay) {
      pickerOverlay._info?.remove();
      document.removeEventListener('keydown', pickerOverlay._escHandler);
      pickerOverlay.remove();
      pickerOverlay = null;
    }
    if (pickerHighlight) {
      pickerHighlight.remove();
      pickerHighlight = null;
    }
  }

  function generateSelector(el) {
    // Try ID first
    if (el.id) return `#${CSS.escape(el.id)}`;

    // Try unique class
    if (el.className && typeof el.className === 'string') {
      const classes = el.className.split(/\s+/).filter(c => c.length > 0);
      for (const cls of classes) {
        const selector = `.${CSS.escape(cls)}`;
        if (document.querySelectorAll(selector).length <= 3) {
          return selector;
        }
      }
    }

    // Try data attributes
    for (const attr of el.attributes) {
      if (attr.name.startsWith('data-') && attr.value) {
        const selector = `[${attr.name}="${CSS.escape(attr.value)}"]`;
        if (document.querySelectorAll(selector).length <= 3) {
          return selector;
        }
      }
    }

    // Fallback: tag + nth-child path
    const parts = [];
    let current = el;
    while (current && current !== document.body) {
      const parent = current.parentElement;
      if (!parent) break;
      const index = [...parent.children].indexOf(current) + 1;
      parts.unshift(`${current.tagName.toLowerCase()}:nth-child(${index})`);
      current = parent;
      if (parts.length >= 3) break;
    }
    return parts.join(' > ') || null;
  }

  async function saveCustomRules() {
    try {
      const stored = await chrome.storage.local.get('thea_custom_cosmetic_rules');
      const existing = stored.thea_custom_cosmetic_rules || {};
      existing[window.location.hostname] = [
        ...(existing[window.location.hostname] || []),
        ...customRules
      ];
      await chrome.storage.local.set({ thea_custom_cosmetic_rules: existing });
    } catch (e) {
      // Silently fail
    }
  }

  async function loadCustomRules() {
    try {
      const stored = await chrome.storage.local.get('thea_custom_cosmetic_rules');
      const rules = stored.thea_custom_cosmetic_rules || {};
      customRules = rules[window.location.hostname] || [];
    } catch (e) {
      customRules = [];
    }
  }

  // ============================================================================
  // Message Handling
  // ============================================================================

  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (!sender.id || sender.id !== chrome.runtime.id) {
      sendResponse({ success: false });
      return true;
    }

    switch (message.type) {
      case 'activateElementPicker':
        activateElementPicker();
        sendResponse({ success: true });
        break;

      case 'toggleCosmeticFilter':
        enabled = message.enabled !== false;
        if (enabled) {
          applyFilters();
        } else if (styleElement) {
          styleElement.remove();
          styleElement = null;
        }
        sendResponse({ success: true });
        break;

      case 'getCosmeticFilterState':
        sendResponse({
          success: true,
          data: {
            enabled,
            genericRuleCount: GENERIC_HIDE_SELECTORS.length,
            siteRuleCount: Object.values(SITE_RULES).reduce((sum, r) => sum + r.length, 0),
            customRuleCount: customRules.length
          }
        });
        break;
    }
    return true;
  });

  // ============================================================================
  // Initialize
  // ============================================================================

  async function init() {
    await loadCustomRules();
    applyFilters();
    collapseEmptyFrames();

    // Re-apply after dynamic content loads
    const observer = new MutationObserver(() => {
      collapseEmptyFrames();
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
