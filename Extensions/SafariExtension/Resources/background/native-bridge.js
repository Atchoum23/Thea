// Thea Safari Extension - Native Bridge
// Wrapper for Safari native messaging via browser.runtime.sendNativeMessage
// Communicates with the Thea macOS app through the Safari extension handler

var NATIVE_APP_ID = 'app.thea.safari';
var NATIVE_MAX_RETRIES = 2;
var NATIVE_RETRY_DELAY_MS = 500;

/**
 * Send a message to the native Thea app with retry logic.
 * @param {Object} data - The message payload
 * @param {number} [retries] - Number of retry attempts remaining
 * @returns {Promise<Object>} The native app response
 */
async function sendNativeMessage(data, retries) {
    if (typeof retries === 'undefined') retries = NATIVE_MAX_RETRIES;

    try {
        var response = await browser.runtime.sendNativeMessage(NATIVE_APP_ID, data);

        // Update connection state on success
        if (!state.isConnectedToApp) {
            state.isConnectedToApp = true;
            state.lastSyncTime = Date.now();
            await saveState();
        }

        return response;
    } catch (err) {
        console.error('[Thea Native] Message failed:', err.message, 'Data:', data.action);

        if (retries > 0) {
            await new Promise(function (resolve) {
                setTimeout(resolve, NATIVE_RETRY_DELAY_MS);
            });
            return sendNativeMessage(data, retries - 1);
        }

        // Mark as disconnected after all retries exhausted
        if (state.isConnectedToApp) {
            state.isConnectedToApp = false;
            await saveState();
        }

        return { error: err.message || 'Native messaging failed', success: false };
    }
}

/**
 * Ask Thea AI a question with optional context.
 */
async function askTheaAI(question, context) {
    return sendNativeMessage({
        action: 'askAI',
        question: question,
        context: context || {}
    });
}

/**
 * Perform deep research on a query using multiple sources.
 */
async function deepResearch(query, sources) {
    return sendNativeMessage({
        action: 'deepResearch',
        query: query,
        sources: sources || []
    });
}

/**
 * Retrieve stored credentials for a domain from the native keychain.
 */
async function getCredentialsFromNative(domain) {
    return sendNativeMessage({
        action: 'getCredentials',
        domain: domain
    });
}

/**
 * Save a credential to the native keychain.
 */
async function saveCredentialToNative(data) {
    return sendNativeMessage({
        action: 'saveCredential',
        domain: data.domain,
        username: data.username,
        password: data.password,
        url: data.url,
        notes: data.notes || ''
    });
}

/**
 * Generate a secure password via the native app.
 */
async function generatePasswordNative() {
    return sendNativeMessage({
        action: 'generatePassword'
    });
}

/**
 * Get a TOTP code for a domain from the native app.
 */
async function getTOTPFromNative(domain) {
    return sendNativeMessage({
        action: 'getTOTPSecret',
        domain: domain
    });
}

/**
 * Rewrite text using Thea AI with the given style and tone.
 */
async function rewriteTextNative(text, style, tone) {
    return sendNativeMessage({
        action: 'rewriteText',
        text: text,
        style: style || 'default',
        tone: tone || 'neutral'
    });
}

/**
 * Analyze writing style of the given text via the native app.
 */
async function analyzeWritingStyleNative(text) {
    return sendNativeMessage({
        action: 'analyzeWritingStyle',
        text: text
    });
}

/**
 * Search memories via the native app (semantic search).
 */
async function searchMemoryNative(query) {
    return sendNativeMessage({
        action: 'searchMemory',
        query: query
    });
}

/**
 * Analyze page content via the native app.
 */
async function analyzeContentNative(content, url) {
    return sendNativeMessage({
        action: 'analyzeContent',
        content: content,
        url: url
    });
}

/**
 * Track a page visit via the native app.
 */
async function trackVisitNative(url, title) {
    return sendNativeMessage({
        action: 'trackBrowsing',
        url: url,
        title: title
    });
}

/**
 * Check if the native app connection is alive.
 */
async function pingNativeApp() {
    try {
        var response = await browser.runtime.sendNativeMessage(NATIVE_APP_ID, {
            action: 'ping'
        });
        state.isConnectedToApp = true;
        state.lastSyncTime = Date.now();
        await saveState();
        return { connected: true, response: response };
    } catch (err) {
        state.isConnectedToApp = false;
        await saveState();
        return { connected: false, error: err.message };
    }
}
