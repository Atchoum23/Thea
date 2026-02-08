(function() {
  'use strict';

  var TRACKING_PARAMS = [
    'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
    'utm_id', 'utm_cid', 'utm_reader', 'utm_name', 'utm_pubreferrer',
    'fbclid', 'gclid', 'gclsrc', 'dclid', 'gbraid', 'wbraid',
    'msclkid', 'twclid', 'li_fat_id', 'igshid', 'mc_cid', 'mc_eid',
    '_ga', '_gl', '_hsenc', '_hsmi', '_openstat',
    'yclid', 'ymclid', 'ysclid',
    'ref', 'ref_src', 'ref_url', 'referrer',
    'source', 'src',
    'click_id', 'clickid', 'campaign_id',
    'ad_id', 'adid', 'ad_name',
    'spm', 'scm', 'pvid', 'algo_pvid',
    'vero_id', 'nr_email_referer',
    'mkt_tok', 'trk', 'trkCampaign',
    'sc_campaign', 'sc_channel', 'sc_content', 'sc_medium', 'sc_outcome', 'sc_geo', 'sc_country'
  ];

  var KNOWN_CNAME_TRACKERS = [
    'smetrics.', 'metrics.', 'tr.', 'tracking.', 'analytics.',
    'data.', 'pixel.', 'collect.', 'log.', 'tag.', 'beacon.',
    't.co', 'stats.', 'hit.', 'click.', 'track.'
  ];

  var DECLINE_BUTTON_SELECTORS = [
    'button[class*="reject"]', 'button[class*="decline"]', 'button[class*="deny"]',
    'button[class*="refuse"]', 'button[id*="reject"]', 'button[id*="decline"]',
    'a[class*="reject"]', 'a[class*="decline"]',
    'button[class*="necessary"]', 'button[class*="essential"]',
    '[data-testid*="reject"]', '[data-testid*="decline"]',
    'button:not([class*="accept"]):not([class*="agree"])[class*="secondary"]',
    '.cc-deny', '.cc-dismiss', '#onetrust-reject-all-handler',
    '#CybotCookiebotDialogBodyButtonDecline',
    'button[aria-label*="Reject"]', 'button[aria-label*="Decline"]',
    'button[aria-label*="reject"]', 'button[aria-label*="decline"]',
    '[class*="cookie"] button[class*="close"]',
    '[class*="consent"] button[class*="close"]'
  ];

  var BANNER_SELECTORS = [
    '#cookie-banner', '.cookie-consent', '.cookie-notice', '#cookieConsent',
    '[class*="cookie-banner"]', '[id*="cookie-banner"]',
    '[class*="cookie-consent"]', '[class*="consent-banner"]',
    '#onetrust-banner-sdk', '#onetrust-consent-sdk',
    '.cc-banner', '.cc-window', '#CybotCookiebotDialog',
    '[class*="gdpr"]', '#gdpr-banner', '.gdpr-consent',
    '[class*="cookie-wall"]', '[class*="cookie-popup"]',
    '[class*="cookie-overlay"]', '[role="dialog"][class*="cookie"]',
    '[role="dialog"][class*="consent"]'
  ];

  var config = {};
  var stats = { cookiesDeclined: 0, trackingParamsStripped: 0, cnameBlocked: 0 };

  function init(userConfig) {
    config = Object.assign({
      autoCookieDecline: true,
      fingerprintProtection: true,
      trackingParamStrip: true,
      cnameDefense: false
    }, userConfig || {});

    if (config.autoCookieDecline) {
      setTimeout(autoDeclineCookies, 1500);
      observeForCookieBanners();
    }

    if (config.fingerprintProtection) {
      protectCanvas();
      protectWebGL();
      protectAudioContext();
    }

    if (config.trackingParamStrip) {
      stripTrackingParams();
    }

    if (config.cnameDefense) {
      checkCNAMETracking();
    }
  }

  function detectCookieBanner() {
    for (var i = 0; i < BANNER_SELECTORS.length; i++) {
      var banner = document.querySelector(BANNER_SELECTORS[i]);
      if (banner && isVisible(banner)) return banner;
    }
    return null;
  }

  function autoDeclineCookies() {
    var banner = detectCookieBanner();
    if (!banner) return false;

    for (var i = 0; i < DECLINE_BUTTON_SELECTORS.length; i++) {
      var btn = banner.querySelector(DECLINE_BUTTON_SELECTORS[i]);
      if (btn && isVisible(btn)) {
        btn.click();
        stats.cookiesDeclined++;
        reportStats();
        return true;
      }
    }

    var allButtons = banner.querySelectorAll('button, a[role="button"], [class*="btn"]');
    for (var j = 0; j < allButtons.length; j++) {
      var text = (allButtons[j].textContent || '').toLowerCase().trim();
      if (matchesDeclineText(text)) {
        allButtons[j].click();
        stats.cookiesDeclined++;
        reportStats();
        return true;
      }
    }

    var closeBtn = banner.querySelector('button[class*="close"], [aria-label="Close"], .close');
    if (closeBtn && isVisible(closeBtn)) {
      closeBtn.click();
      stats.cookiesDeclined++;
      reportStats();
      return true;
    }

    return false;
  }

  function matchesDeclineText(text) {
    var declineWords = [
      'reject all', 'decline all', 'deny all', 'refuse all',
      'reject', 'decline', 'deny', 'refuse',
      'only necessary', 'only essential', 'necessary only',
      'essential only', 'manage preferences', 'customize',
      'no thanks', 'no, thanks', 'not now'
    ];
    return declineWords.some(function(word) { return text.indexOf(word) !== -1; });
  }

  function observeForCookieBanners() {
    var observer = new MutationObserver(function(mutations) {
      for (var i = 0; i < mutations.length; i++) {
        var added = mutations[i].addedNodes;
        for (var j = 0; j < added.length; j++) {
          if (added[j].nodeType === Node.ELEMENT_NODE) {
            setTimeout(autoDeclineCookies, 500);
            return;
          }
        }
      }
    });
    observer.observe(document.body, { childList: true, subtree: true });
    setTimeout(function() { observer.disconnect(); }, 30000);
  }

  function protectCanvas() {
    var origToDataURL = HTMLCanvasElement.prototype.toDataURL;
    var origToBlob = HTMLCanvasElement.prototype.toBlob;
    var noise = Math.random() * 0.01;

    HTMLCanvasElement.prototype.toDataURL = function() {
      var ctx = this.getContext('2d');
      if (ctx) {
        try {
          var imageData = ctx.getImageData(0, 0, Math.min(this.width, 2), Math.min(this.height, 2));
          for (var i = 0; i < imageData.data.length; i += 4) {
            imageData.data[i] = Math.max(0, Math.min(255, imageData.data[i] + (noise * 255) | 0));
          }
          ctx.putImageData(imageData, 0, 0);
        } catch (e) {}
      }
      return origToDataURL.apply(this, arguments);
    };

    HTMLCanvasElement.prototype.toBlob = function() {
      var ctx = this.getContext('2d');
      if (ctx) {
        try {
          var imageData = ctx.getImageData(0, 0, Math.min(this.width, 2), Math.min(this.height, 2));
          for (var i = 0; i < imageData.data.length; i += 4) {
            imageData.data[i] = Math.max(0, Math.min(255, imageData.data[i] + (noise * 255) | 0));
          }
          ctx.putImageData(imageData, 0, 0);
        } catch (e) {}
      }
      return origToBlob.apply(this, arguments);
    };
  }

  function protectWebGL() {
    var getParam = WebGLRenderingContext.prototype.getParameter;
    WebGLRenderingContext.prototype.getParameter = function(param) {
      var UNMASKED_VENDOR = 0x9245;
      var UNMASKED_RENDERER = 0x9246;
      if (param === UNMASKED_VENDOR) return 'Apple Inc.';
      if (param === UNMASKED_RENDERER) return 'Apple GPU';
      return getParam.apply(this, arguments);
    };

    if (typeof WebGL2RenderingContext !== 'undefined') {
      var getParam2 = WebGL2RenderingContext.prototype.getParameter;
      WebGL2RenderingContext.prototype.getParameter = function(param) {
        var UNMASKED_VENDOR = 0x9245;
        var UNMASKED_RENDERER = 0x9246;
        if (param === UNMASKED_VENDOR) return 'Apple Inc.';
        if (param === UNMASKED_RENDERER) return 'Apple GPU';
        return getParam2.apply(this, arguments);
      };
    }
  }

  function protectAudioContext() {
    if (typeof AudioContext === 'undefined' && typeof webkitAudioContext === 'undefined') return;

    var AC = typeof AudioContext !== 'undefined' ? AudioContext : webkitAudioContext;
    var origCreateOscillator = AC.prototype.createOscillator;
    AC.prototype.createOscillator = function() {
      var osc = origCreateOscillator.apply(this, arguments);
      var origConnect = osc.connect;
      osc.connect = function(dest) {
        if (dest instanceof AnalyserNode) {
          var gain = this.context.createGain();
          gain.gain.value = 1 + (Math.random() * 0.0001);
          origConnect.call(this, gain);
          gain.connect(dest);
          return dest;
        }
        return origConnect.apply(this, arguments);
      };
      return osc;
    };
  }

  function checkCNAMETracking() {
    var hostname = window.location.hostname;
    var links = document.querySelectorAll('script[src], link[href], img[src]');
    links.forEach(function(el) {
      var src = el.src || el.href;
      if (!src) return;
      try {
        var url = new URL(src);
        var subdomain = url.hostname;
        if (subdomain.endsWith('.' + hostname)) {
          var sub = subdomain.replace('.' + hostname, '');
          var isTracker = KNOWN_CNAME_TRACKERS.some(function(t) {
            return sub.indexOf(t.replace('.', '')) !== -1;
          });
          if (isTracker) {
            el.removeAttribute('src');
            el.removeAttribute('href');
            stats.cnameBlocked++;
          }
        }
      } catch (e) {}
    });
    if (stats.cnameBlocked > 0) reportStats();
  }

  function stripTrackingParams() {
    var url = new URL(window.location.href);
    var changed = false;
    TRACKING_PARAMS.forEach(function(param) {
      if (url.searchParams.has(param)) {
        url.searchParams.delete(param);
        changed = true;
        stats.trackingParamsStripped++;
      }
    });
    if (changed) {
      window.history.replaceState({}, '', url.toString());
      reportStats();
    }
  }

  function reportStats() {
    try {
      browser.runtime.sendMessage({
        type: 'privacyStats',
        stats: stats
      });
    } catch (e) {}
  }

  function isVisible(el) {
    if (!el) return false;
    var style = window.getComputedStyle(el);
    return style.display !== 'none' && style.visibility !== 'hidden' &&
           style.opacity !== '0' && el.offsetHeight > 0;
  }

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.PrivacyShield = {
    init: init,
    autoDeclineCookies: autoDeclineCookies,
    stripTrackingParams: stripTrackingParams,
    getStats: function() { return Object.assign({}, stats); }
  };
})();
