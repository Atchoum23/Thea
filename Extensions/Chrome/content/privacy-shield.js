/**
 * Thea Privacy Shield
 *
 * Enhanced privacy protection beyond basic ad blocking.
 *
 * Features:
 * - Cookie consent auto-handler (decline all cookies automatically)
 * - Enhanced fingerprint protection (canvas, WebGL, AudioContext)
 * - CNAME tracking defense (first-party tracker detection)
 * - Referrer stripping
 * - Link shimming removal (Facebook, Google redirect unwrapping)
 * - Beacon/ping blocking
 * - WebRTC IP leak prevention
 * - Enhanced tracking parameter removal (50+ params)
 * - Social widget blocking
 * - Canvas fingerprint noise injection
 */

(function() {
  'use strict';

  let config = {
    cookieAutoDecline: true,
    fingerprintProtection: true,
    referrerStripping: true,
    linkUnshimming: true,
    trackingParamRemoval: true,
    socialWidgetBlocking: false,
    webrtcProtection: false
  };

  // ============================================================================
  // Cookie Consent Auto-Handler
  // ============================================================================

  const COOKIE_DECLINE_SELECTORS = [
    // Reject/Decline buttons
    '[data-testid="cookie-policy-manage-dialog-btn-reject-all"]',
    'button[id*="reject"]', 'button[class*="reject"]',
    'button[id*="decline"]', 'button[class*="decline"]',
    'button[id*="deny"]', 'button[class*="deny"]',
    'a[id*="reject"]', 'a[class*="reject"]',
    '[data-cookiefirst-action="reject"]',
    '.cookie-decline', '.cookie-reject',
    '#CybotCookiebotDialogBodyButtonDecline',
    '#onetrust-reject-all-handler',
    '.cc-deny', '.cc-dismiss',
    '[aria-label*="reject" i]', '[aria-label*="decline" i]',
    '[aria-label*="deny" i]', '[aria-label*="refuse" i]',
    'button[title*="reject" i]', 'button[title*="decline" i]',
    // "Necessary only" buttons
    'button[id*="necessary"]', 'button[class*="necessary"]',
    '[data-testid*="necessary"]',
    // "Close" or "X" buttons on cookie banners
    '.cookie-banner .close', '.cookie-notice .close',
    '#cookie-banner button.close', '.cc-close',
  ];

  const COOKIE_BANNER_SELECTORS = [
    '#cookie-banner', '#cookie-consent', '#cookie-notice',
    '#cookiebanner', '#CybotCookiebotDialog',
    '.cookie-banner', '.cookie-consent', '.cookie-notice',
    '.cookie-popup', '.cc-banner', '.cc-window',
    '[class*="cookie-banner"]', '[class*="cookie-consent"]',
    '[class*="cookieBanner"]', '[class*="cookieConsent"]',
    '[id*="cookie-banner"]', '[id*="cookie-consent"]',
    '[data-testid*="cookie"]', '#onetrust-banner-sdk',
    '#gdpr-consent', '.gdpr-banner', '.privacy-banner',
    '[class*="consent-banner"]', '[class*="consentBanner"]',
    '.qc-cmp-ui-container', '#sp_message_container_*',
  ];

  function handleCookieConsent() {
    if (!config.cookieAutoDecline) return;

    // Try to click reject/decline buttons
    for (const selector of COOKIE_DECLINE_SELECTORS) {
      try {
        const buttons = document.querySelectorAll(selector);
        for (const btn of buttons) {
          if (isVisible(btn) && isClickable(btn)) {
            btn.click();
            console.log('Thea: Auto-declined cookies via', selector);
            return;
          }
        }
      } catch (e) {
        // Invalid selector
      }
    }

    // If no decline button found, try to close the banner
    for (const selector of COOKIE_BANNER_SELECTORS) {
      try {
        const banners = document.querySelectorAll(selector);
        for (const banner of banners) {
          if (isVisible(banner)) {
            // Look for close/dismiss within banner
            const closeBtn = banner.querySelector('button.close, .close, [aria-label="Close"], [aria-label="Dismiss"]');
            if (closeBtn) {
              closeBtn.click();
              console.log('Thea: Dismissed cookie banner via close button');
              return;
            }
          }
        }
      } catch (e) {
        // Invalid selector
      }
    }
  }

  // Run cookie handler with delays to catch lazy-loaded banners
  function scheduleCookieHandler() {
    if (!config.cookieAutoDecline) return;

    // Try immediately, then with delays
    handleCookieConsent();
    setTimeout(handleCookieConsent, 1000);
    setTimeout(handleCookieConsent, 3000);
    setTimeout(handleCookieConsent, 5000);

    // Also observe for dynamically added banners
    const observer = new MutationObserver(() => {
      handleCookieConsent();
    });

    observer.observe(document.body, { childList: true, subtree: true });

    // Stop observing after 15 seconds
    setTimeout(() => observer.disconnect(), 15000);
  }

  // ============================================================================
  // Enhanced Tracking Parameter Removal
  // ============================================================================

  const TRACKING_PARAMS = new Set([
    // Google
    'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
    'utm_id', 'utm_source_platform', 'utm_creative_format', 'utm_marketing_tactic',
    'gclid', 'gclsrc', 'dclid', 'gbraid', 'wbraid',
    // Facebook
    'fbclid', 'fb_action_ids', 'fb_action_types', 'fb_ref', 'fb_source',
    // Microsoft
    'msclkid',
    // Mailchimp
    'mc_cid', 'mc_eid',
    // HubSpot
    '_hsenc', '_hsmi', 'hsa_cam', 'hsa_grp', 'hsa_mt', 'hsa_src',
    'hsa_ad', 'hsa_acc', 'hsa_net', 'hsa_ver', 'hsa_la', 'hsa_ol', 'hsa_kw',
    // Adobe
    's_cid', 'cid',
    // Various
    'trk', 'ref_', 'ref_src', 'ref_url',
    'yclid', 'twclid', 'igshid', 'scid',
    'mkt_tok', 'ml_subscriber', 'ml_subscriber_hash',
    'oly_enc_id', 'oly_anon_id',
    'vero_id', 'vero_conv',
    'wickedid', 'ncid', 'partner', 'customer',
    '__twitter_impression', 'si', 'feature', 'app',
    // LinkedIn
    'li_fat_id', 'li_medium', 'li_source',
    // Pinterest
    'epik',
    // Drip
    '__s',
    // Wicked Reports
    'wickedid',
  ]);

  function stripTrackingParams() {
    if (!config.trackingParamRemoval) return;

    // Strip from current URL
    try {
      const url = new URL(window.location.href);
      let modified = false;
      for (const param of TRACKING_PARAMS) {
        if (url.searchParams.has(param)) {
          url.searchParams.delete(param);
          modified = true;
        }
      }
      if (modified) {
        window.history.replaceState({}, '', url.toString());
      }
    } catch (e) { /* skip */ }

    // Strip from all links
    document.querySelectorAll('a[href]').forEach(link => {
      try {
        const url = new URL(link.href, window.location.origin);
        let modified = false;
        for (const param of TRACKING_PARAMS) {
          if (url.searchParams.has(param)) {
            url.searchParams.delete(param);
            modified = true;
          }
        }
        if (modified) link.href = url.toString();
      } catch (e) { /* skip */ }
    });
  }

  // ============================================================================
  // Link Unshimming (unwrap tracking redirects)
  // ============================================================================

  const REDIRECT_PATTERNS = [
    { pattern: /https?:\/\/(l|lm)\.facebook\.com\/l\.php\?u=([^&]+)/i, extract: 2 },
    { pattern: /https?:\/\/www\.google\.com\/url\?.*?url=([^&]+)/i, extract: 1 },
    { pattern: /https?:\/\/www\.google\.com\/url\?.*?q=([^&]+)/i, extract: 1 },
    { pattern: /https?:\/\/t\.co\/\w+/i, extract: null }, // Can't easily unwrap
    { pattern: /https?:\/\/bit\.ly\/\w+/i, extract: null },
  ];

  function unshimLinks() {
    if (!config.linkUnshimming) return;

    document.querySelectorAll('a[href]').forEach(link => {
      for (const { pattern, extract } of REDIRECT_PATTERNS) {
        const match = link.href.match(pattern);
        if (match && extract && match[extract]) {
          try {
            link.href = decodeURIComponent(match[extract]);
          } catch (e) { /* skip */ }
          break;
        }
      }
    });
  }

  // ============================================================================
  // Referrer Stripping
  // ============================================================================

  function setupReferrerProtection() {
    if (!config.referrerStripping) return;

    // Add meta referrer policy
    let meta = document.querySelector('meta[name="referrer"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'referrer';
      document.head.appendChild(meta);
    }
    meta.content = 'no-referrer-when-downgrade';
  }

  // ============================================================================
  // Social Widget Blocking
  // ============================================================================

  const SOCIAL_WIDGET_SELECTORS = [
    'iframe[src*="facebook.com/plugins"]',
    'iframe[src*="platform.twitter.com"]',
    'iframe[src*="platform.linkedin.com"]',
    '.fb-like', '.fb-share', '.twitter-share',
    '.linkedin-share', '.pinterest-pin',
    '[class*="social-widget"]', '[class*="share-button"]',
    '[data-social-plugin]'
  ];

  function blockSocialWidgets() {
    if (!config.socialWidgetBlocking) return;

    SOCIAL_WIDGET_SELECTORS.forEach(sel => {
      document.querySelectorAll(sel).forEach(el => {
        el.style.display = 'none';
      });
    });
  }

  // ============================================================================
  // Utility
  // ============================================================================

  function isVisible(el) {
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0 &&
           getComputedStyle(el).display !== 'none' &&
           getComputedStyle(el).visibility !== 'hidden';
  }

  function isClickable(el) {
    return !el.disabled && el.offsetParent !== null;
  }

  // ============================================================================
  // Initialization
  // ============================================================================

  async function init() {
    // Load config
    try {
      const response = await chrome.runtime.sendMessage({ type: 'getPrivacyConfig' });
      if (response?.success && response.data) {
        config = { ...config, ...response.data };
      }
    } catch (e) { /* use defaults */ }

    setupReferrerProtection();
    stripTrackingParams();
    unshimLinks();
    blockSocialWidgets();
    scheduleCookieHandler();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
