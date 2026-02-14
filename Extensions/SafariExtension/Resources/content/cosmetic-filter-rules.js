(function() {
  'use strict';

  var GENERIC_SELECTORS = [
    // Ad containers by class
    '[class*="ad-container"]', '[class*="ad-wrapper"]', '[class*="ad-slot"]',
    '[class*="ad-banner"]', '[class*="ad-unit"]', '[class*="ad-block"]',
    '[class*="ads-container"]', '[class*="ads-wrapper"]',
    '[class*="advert-"]', '[class*="advertisement"]',
    // Ad containers by ID
    '[id*="ad-container"]', '[id*="ad-wrapper"]', '[id*="ad-slot"]',
    '[id*="ad-banner"]', '[id*="ads-container"]',
    // Data attributes
    '[data-ad]', '[data-ad-slot]', '[data-adunit]', '[data-ad-region]',
    '[data-ad-format]', '[data-google-query-id]', '[data-ad-client]',
    // Sponsor content
    '[class*="sponsor"]', '[id*="sponsor"]', '[class*="promoted"]',
    '[class*="paid-content"]', '[class*="native-ad"]',
    // Common ad networks
    'ins.adsbygoogle', '.google-ad', '.dfp-ad', '#google_ads_iframe',
    '.doubleclick-ad', '.taboola-widget', '.outbrain-widget',
    '[id^="div-gpt-ad"]', '[id^="google_ads"]',
    'iframe[src*="doubleclick"]', 'iframe[src*="googlesyndication"]',
    'iframe[src*="amazon-adsystem"]',
    // Social widgets
    '.fb-like', '.fb-share-button', '.fb-comments',
    '.twitter-share-button', '.twitter-follow-button',
    '.social-share', '.share-buttons', '.sharing-buttons',
    '[class*="social-share"]', '[class*="share-bar"]',
    // Cookie banners
    '#cookie-banner', '.cookie-consent', '.cookie-notice', '#cookieConsent',
    '[class*="cookie-banner"]', '[id*="cookie-banner"]',
    '[class*="cookie-consent"]', '[id*="cookie-consent"]',
    '[class*="cookie-notice"]', '[id*="cookie-notice"]',
    '[class*="gdpr"]', '#gdpr-banner', '.gdpr-consent',
    '[class*="consent-banner"]', '[id*="consent-banner"]',
    '[class*="cookie-wall"]', '[class*="cookie-popup"]',
    '#onetrust-banner-sdk', '#onetrust-consent-sdk',
    '.cc-banner', '.cc-window', '#CybotCookiebotDialog',
    // Newsletter popups
    '.newsletter-popup', '.email-signup-popup', '.subscribe-popup',
    '[class*="newsletter-modal"]', '[class*="subscribe-modal"]',
    '[class*="email-capture"]', '[class*="newsletter-overlay"]',
    // Paywalls
    '[class*="paywall"]', '#paywall', '.subscription-wall',
    '[class*="metered-content"]', '[class*="premium-wall"]',
    // Floating / sticky ads
    '.sticky-ad', '.floating-ad', '[class*="sticky-banner"]',
    '[class*="sticky-footer"]', '[class*="sticky-sidebar"]',
    '[class*="fixed-bottom"]', '[class*="bottom-banner"]',
    // Interstitials
    '[class*="interstitial"]', '[class*="overlay-ad"]',
    '[class*="modal-ad"]', '[class*="popup-ad"]',
    // Push notification prompts
    '[class*="push-notification"]', '[class*="notification-prompt"]',
    '[class*="web-push"]', '[class*="push-subscribe"]',
    // Chat widgets (external)
    '#drift-widget', '.intercom-lightweight-app',
    '[class*="chat-widget"]', '#hubspot-messages-iframe-container',
    '#fc_frame', '.crisp-client',
    // Survey popups
    '[class*="survey-popup"]', '[class*="feedback-widget"]',
    '[class*="nps-survey"]', '#qualaroo',
    // Video overlays / pre-roll markers
    '[class*="video-ad"]', '[class*="preroll"]',
    '[class*="ad-overlay"]'
  ];

  var SITE_SPECIFIC = {
    'youtube.com': [
      '#masthead-ad', 'ytd-ad-slot-renderer', '.ytp-ad-overlay-container',
      '#player-ads', 'ytd-promoted-sparkles-web-renderer',
      'ytd-display-ad-renderer', '.ytp-ad-text',
      'ytd-promoted-video-renderer', 'ytd-banner-promo-renderer',
      '.ytd-mealbar-promo-renderer', 'ytd-statement-banner-renderer',
      '#offer-module'
    ],
    'reddit.com': [
      '[data-testid="promoted-post"]', '.promotedlink',
      'shreddit-ad-post', '[data-promoted]',
      '.premium-banner', '.listingsignupbar'
    ],
    'twitter.com': [
      '[data-testid="placementTracking"]', '[data-promoted="true"]',
      '[class*="promoted-tweet"]'
    ],
    'x.com': [
      '[data-testid="placementTracking"]', '[data-promoted="true"]'
    ],
    'facebook.com': [
      '[data-testid="sponsored_post"]', '[aria-label="Sponsored"]',
      '[data-pagelet*="FeedUnit"]:has([aria-label="Sponsored"])'
    ],
    'instagram.com': [
      '[data-testid="sponsored-post"]',
      'article:has([aria-label="Sponsored"])'
    ],
    'linkedin.com': [
      '[data-ad-banner]', '.feed-shared-update-v2:has(.feed-shared-actor__sub-description:contains("Promoted"))',
      '.ad-banner-container'
    ],
    'amazon.com': [
      '[class*="AdHolder"]', '[data-component-type="sp-sponsored-result"]',
      '.s-sponsored-label-info-icon', '[class*="sponsored-products"]'
    ],
    'ebay.com': [
      '.srp-river-answer--REWRITE_START', '.s-item--REWRITE_START',
      '[class*="sponsored-listings"]'
    ],
    'cnn.com': [
      '.ad', '.ad-slot', '[data-ad-type]', '.pg-ad-zone'
    ],
    'nytimes.com': [
      '[data-testid="StandardAd"]', '.ad-container', '.ad-wrapper'
    ],
    'bbc.com': [
      '.bbccom_advert', '.bbccom_slot', '[data-bbc-container="advert"]'
    ],
    'theguardian.com': [
      '.ad-slot', '.ad-slot-container', '.contributions__epic'
    ],
    'stackoverflow.com': [
      '.js-zone-container', '#clc-tlb', '.s-sidebarwidget--ad'
    ],
    'medium.com': [
      '.postMetaInline-feedSocialProof', '.meteredContent',
      '[data-testid="meter-footer"]'
    ]
  };

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.CosmeticFilterRules = {
    GENERIC_SELECTORS: GENERIC_SELECTORS,
    SITE_SPECIFIC: SITE_SPECIFIC
  };
})();
