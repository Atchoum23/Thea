// Thea Safari Extension - State Manager
// Manages extension state via browser.storage.local
// Loaded first - provides state to all other modules

// Default state with all feature toggles, configs, and stats
var defaultState = {
    // Feature toggles
    adBlockerEnabled: true,
    darkModeEnabled: false,
    privacyProtectionEnabled: true,
    passwordManagerEnabled: false,
    emailProtectionEnabled: false,
    printFriendlyEnabled: false,
    aiAssistantEnabled: true,
    videoControllerEnabled: false,
    memoryEnabled: true,
    writingAssistantEnabled: false,

    // Dark mode configuration
    darkModeConfig: {
        enabled: false,
        theme: 'midnight',
        followSystem: true,
        sitePrefs: {},
        customThemes: {},
        pausedUntil: null
    },

    // Video controller configuration
    videoConfig: {
        enabled: false,
        defaultSpeed: 1.0,
        speedStep: 0.1,
        showOverlay: true,
        rememberSpeed: true,
        siteSpeedPrefs: {},
        autoSpeedRules: []
    },

    // Privacy configuration
    privacyConfig: {
        cookieAutoDecline: true,
        fingerprintProtection: true,
        referrerStripping: true,
        linkUnshimming: true,
        trackingParamRemoval: true,
        socialWidgetBlocking: false,
        cnameDefense: true
    },

    // Writing assistant configuration
    writingConfig: {
        enabled: false,
        styleProfile: {},
        suggestionDelay: 500
    },

    // Statistics
    stats: {
        adsBlocked: 0,
        trackersBlocked: 0,
        emailsProtected: 0,
        passwordsAutofilled: 0,
        pagesDarkened: 0,
        pagesCleaned: 0,
        dataSaved: 0,
        cookiesDeclined: 0,
        trackingParamsStripped: 0,
        memoriesSaved: 0
    },

    // Whitelisted domains (ad-blocker bypass)
    whitelist: [],

    // App connection state
    isConnectedToApp: false,
    lastSyncTime: null
};

// Current in-memory state
var state = JSON.parse(JSON.stringify(defaultState));

// Keys that external sources (popup, content scripts) are allowed to modify
var ALLOWED_EXTERNAL_STATE_KEYS = new Set([
    'adBlockerEnabled',
    'darkModeEnabled',
    'privacyProtectionEnabled',
    'passwordManagerEnabled',
    'emailProtectionEnabled',
    'printFriendlyEnabled',
    'aiAssistantEnabled',
    'videoControllerEnabled',
    'memoryEnabled',
    'writingAssistantEnabled',
    'darkModeConfig',
    'videoConfig',
    'privacyConfig',
    'writingConfig',
    'whitelist'
]);

/**
 * Validate that external state updates only touch allowed keys.
 * Returns an object containing only the valid key-value pairs.
 */
function validateExternalState(updates) {
    if (!updates || typeof updates !== 'object') {
        return {};
    }

    var validated = {};
    var keys = Object.keys(updates);
    for (var i = 0; i < keys.length; i++) {
        var key = keys[i];
        if (ALLOWED_EXTERNAL_STATE_KEYS.has(key)) {
            validated[key] = updates[key];
        } else {
            console.warn('[Thea State] Rejected external update for key:', key);
        }
    }
    return validated;
}

/**
 * Deep merge source into target, preserving existing keys not in source.
 */
function deepMerge(target, source) {
    if (!source || typeof source !== 'object') return target;
    if (!target || typeof target !== 'object') return source;

    var result = Object.assign({}, target);
    var keys = Object.keys(source);
    for (var i = 0; i < keys.length; i++) {
        var key = keys[i];
        if (
            source[key] !== null &&
            typeof source[key] === 'object' &&
            !Array.isArray(source[key]) &&
            target[key] !== null &&
            typeof target[key] === 'object' &&
            !Array.isArray(target[key])
        ) {
            result[key] = deepMerge(target[key], source[key]);
        } else {
            result[key] = source[key];
        }
    }
    return result;
}

/**
 * Load state from browser.storage.local.
 * Merges saved state with defaults so new keys are always present.
 */
async function loadState() {
    try {
        var result = await browser.storage.local.get('theaState');
        if (result.theaState) {
            state = deepMerge(defaultState, result.theaState);
            console.log('[Thea State] Loaded state from storage');
        } else {
            state = JSON.parse(JSON.stringify(defaultState));
            console.log('[Thea State] No saved state, using defaults');
        }
    } catch (err) {
        console.error('[Thea State] Failed to load state:', err);
        state = JSON.parse(JSON.stringify(defaultState));
    }
    return state;
}

/**
 * Save current state to browser.storage.local.
 */
async function saveState() {
    try {
        await browser.storage.local.set({ theaState: state });
    } catch (err) {
        console.error('[Thea State] Failed to save state:', err);
    }
}

/**
 * Get a shallow copy of the current state.
 */
function getState() {
    return Object.assign({}, state);
}

/**
 * Update state with new values and persist.
 * If fromExternal is true, validates keys against the allowed set.
 */
async function updateState(updates, fromExternal) {
    var safeUpdates = fromExternal ? validateExternalState(updates) : updates;

    if (Object.keys(safeUpdates).length === 0) {
        return state;
    }

    state = deepMerge(state, safeUpdates);
    await saveState();
    return state;
}

/**
 * Increment a stat counter by the given amount (default 1).
 */
async function incrementStat(statName, amount) {
    if (typeof amount === 'undefined') amount = 1;
    if (state.stats.hasOwnProperty(statName)) {
        state.stats[statName] += amount;
        await saveState();
    }
}

/**
 * Toggle a boolean feature flag by name.
 * Returns the new value.
 */
async function toggleFeature(featureName) {
    if (typeof state[featureName] === 'boolean') {
        state[featureName] = !state[featureName];
        await saveState();
        await broadcastToTabs({
            type: 'featureToggled',
            feature: featureName,
            enabled: state[featureName]
        });
        return state[featureName];
    }
    return null;
}

/**
 * Broadcast a message to all open tabs.
 */
async function broadcastToTabs(message) {
    try {
        var tabs = await browser.tabs.query({});
        var promises = [];
        for (var i = 0; i < tabs.length; i++) {
            if (tabs[i].id && tabs[i].url && !tabs[i].url.startsWith('about:')) {
                promises.push(
                    browser.tabs.sendMessage(tabs[i].id, message).catch(function () {
                        // Tab may not have content script loaded; ignore
                    })
                );
            }
        }
        await Promise.allSettled(promises);
    } catch (err) {
        console.error('[Thea State] Broadcast failed:', err);
    }
}

/**
 * Reset state to defaults and persist.
 */
async function resetState() {
    state = JSON.parse(JSON.stringify(defaultState));
    await saveState();
    console.log('[Thea State] State reset to defaults');
    return state;
}
