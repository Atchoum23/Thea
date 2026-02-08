// Thea Safari Extension - Ad Block Handler
// Manages ad/tracker domain blocking and whitelist

// Common ad and tracker domains
var blockList = new Set([
    // Major ad networks
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'google-analytics.com',
    'googletagmanager.com',
    'googletagservices.com',
    'pagead2.googlesyndication.com',
    'adservice.google.com',
    'adsrvr.org',
    'adnxs.com',
    'ads-twitter.com',
    'advertising.com',
    'amazon-adsystem.com',
    'bidswitch.net',
    'casalemedia.com',
    'criteo.com',
    'criteo.net',
    'demdex.net',
    'everesttech.net',
    'exelator.com',
    'eyeota.net',
    'media.net',
    'moatads.com',
    'mookie1.com',
    'outbrain.com',
    'pubmatic.com',
    'rfihub.com',
    'rlcdn.com',
    'rubiconproject.com',
    'scorecardresearch.com',
    'serving-sys.com',
    'sharethrough.com',
    'smaato.net',
    'smartadserver.com',
    'taboola.com',
    'tapad.com',
    'teads.tv',
    'tribalfusion.com',
    'turn.com',
    'yieldmo.com',

    // Tracking and analytics
    'facebook.net',
    'facebook.com/tr',
    'connect.facebook.net',
    'pixel.facebook.com',
    'hotjar.com',
    'hotjar.io',
    'segment.com',
    'segment.io',
    'mixpanel.com',
    'amplitude.com',
    'fullstory.com',
    'mouseflow.com',
    'crazyegg.com',
    'luckyorange.com',
    'inspectlet.com',
    'newrelic.com',
    'nr-data.net',
    'omtrdc.net',
    'quantserve.com',
    'chartbeat.com',
    'chartbeat.net',
    'parsely.com',
    'optimizely.com',
    'branch.io',
    'branchster.link',
    'appsflyer.com',
    'adjust.com',
    'kochava.com',

    // Fingerprinting and data brokers
    'bluekai.com',
    'bounceexchange.com',
    'crwdcntrl.net',
    'dataxu.com',
    'dotomi.com',
    'intentiq.com',
    'krxd.net',
    'liadm.com',
    'liveramp.com',
    'mathtag.com',
    'mxptint.net',
    'narrativ.com',
    'onetrust.com',
    'pippio.com',
    'quantcast.com',
    'semasio.net',
    'tagging.cloud',
    'trackjs.com',
    'zqtk.net',

    // Pop-ups and overlays
    'pushcrew.com',
    'pushwoosh.com',
    'onesignal.com',
    'pushengage.com',
    'izooto.com',
    'subscribers.com'
]);

/**
 * Extract the registrable domain from a URL.
 * Handles common multi-part TLDs.
 */
function extractDomain(url) {
    try {
        var urlObj = new URL(url);
        return urlObj.hostname.replace(/^www\./, '');
    } catch (e) {
        return '';
    }
}

/**
 * Check if a URL's domain or any of its parent domains are in the block list.
 */
function isDomainBlocked(hostname) {
    if (blockList.has(hostname)) return true;

    // Check parent domains (e.g., sub.ad.example.com -> ad.example.com -> example.com)
    var parts = hostname.split('.');
    for (var i = 1; i < parts.length - 1; i++) {
        var parentDomain = parts.slice(i).join('.');
        if (blockList.has(parentDomain)) return true;
    }
    return false;
}

/**
 * Check whether a network request should be blocked.
 * @param {string} url - The request URL
 * @param {string} resourceType - The resource type (script, image, xmlhttprequest, etc.)
 * @returns {Object} { blocked: boolean, reason: string }
 */
async function checkShouldBlock(url, resourceType) {
    if (!state.adBlockerEnabled) {
        return { blocked: false, reason: 'disabled' };
    }

    var hostname = extractDomain(url);
    if (!hostname) {
        return { blocked: false, reason: 'invalid_url' };
    }

    // Check whitelist - never block whitelisted domains
    var whitelist = state.whitelist || [];
    for (var i = 0; i < whitelist.length; i++) {
        if (hostname === whitelist[i] || hostname.endsWith('.' + whitelist[i])) {
            return { blocked: false, reason: 'whitelisted' };
        }
    }

    // Check block list
    if (isDomainBlocked(hostname)) {
        // Increment stats
        var statName = resourceType === 'script' || resourceType === 'xmlhttprequest'
            ? 'trackersBlocked'
            : 'adsBlocked';
        await incrementStat(statName);

        return {
            blocked: true,
            reason: 'blocklist',
            domain: hostname,
            resourceType: resourceType
        };
    }

    return { blocked: false, reason: 'allowed' };
}

/**
 * Update the whitelist - add or remove a domain.
 * @param {string} domain - The domain to add/remove
 * @param {string} action - 'add' or 'remove'
 */
async function updateWhitelist(domain, action) {
    var cleanDomain = domain.replace(/^www\./, '').toLowerCase();
    var whitelist = state.whitelist || [];

    if (action === 'add') {
        if (whitelist.indexOf(cleanDomain) === -1) {
            whitelist.push(cleanDomain);
        }
    } else if (action === 'remove') {
        var idx = whitelist.indexOf(cleanDomain);
        if (idx !== -1) {
            whitelist.splice(idx, 1);
        }
    }

    state.whitelist = whitelist;
    await saveState();

    return { success: true, whitelist: whitelist };
}

/**
 * Get the total count of blocked ads and trackers.
 */
async function getBlockedCount() {
    return {
        adsBlocked: state.stats.adsBlocked || 0,
        trackersBlocked: state.stats.trackersBlocked || 0,
        total: (state.stats.adsBlocked || 0) + (state.stats.trackersBlocked || 0)
    };
}

/**
 * Check if a domain is currently whitelisted.
 */
function isDomainWhitelisted(domain) {
    var cleanDomain = domain.replace(/^www\./, '').toLowerCase();
    var whitelist = state.whitelist || [];
    return whitelist.indexOf(cleanDomain) !== -1;
}
