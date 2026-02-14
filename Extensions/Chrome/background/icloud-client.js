/**
 * iCloud Client for Thea Chrome/Brave Extension
 *
 * Core iCloud session management, authentication, session validation,
 * event emitter base, getStatus, and disconnect.
 *
 * Hide My Email API methods are in icloud-email-api.js (attached to this singleton).
 *
 * Based on analysis of:
 * - Hide My Email+ (olkpkcclmmjmmknlhdggcjiefbdgjfke)
 * - iCloud Hide My Email (omiaekblhgfopjkjnenhahfgcgnbohlk)
 *
 * Architecture:
 * Extension Background Worker -> iCloud.com APIs -> iCloud+ Services
 *
 * Authentication:
 * Uses existing icloud.com session cookies (user must be signed into icloud.com)
 * The extension requires host_permissions for *.icloud.com to access cookies.
 */

// API Base URLs
const ICLOUD_SETUP_URL = 'https://setup.icloud.com/setup/ws/1';
const ICLOUD_SETUP_URL_CN = 'https://setup.icloud.com.cn/setup/ws/1';

// Storage keys
const STORAGE_KEYS = {
    AUTH_STATE: 'thea_icloud_auth_state',
    HME_BASE_URL: 'thea_hme_base_url',
    CACHED_ALIASES: 'thea_hme_cached_aliases',
    LAST_SYNC: 'thea_hme_last_sync',
    USER_INFO: 'thea_icloud_user_info'
};

/**
 * iCloud Client - Handles all iCloud API communication
 */
class iCloudClient {
    constructor() {
        this.isAuthenticated = false;
        this.hmeBaseUrl = null;
        this.userInfo = null;
        this.cachedAliases = [];
        this.lastSync = null;
        this.eventListeners = new Map();

        // Initialize from storage
        this.init();
    }

    /**
     * Initialize client from stored state
     */
    async init() {
        try {
            const stored = await chrome.storage.local.get([
                STORAGE_KEYS.AUTH_STATE,
                STORAGE_KEYS.HME_BASE_URL,
                STORAGE_KEYS.CACHED_ALIASES,
                STORAGE_KEYS.LAST_SYNC,
                STORAGE_KEYS.USER_INFO
            ]);

            if (stored[STORAGE_KEYS.AUTH_STATE]) {
                this.isAuthenticated = stored[STORAGE_KEYS.AUTH_STATE];
            }
            if (stored[STORAGE_KEYS.HME_BASE_URL]) {
                this.hmeBaseUrl = stored[STORAGE_KEYS.HME_BASE_URL];
            }
            if (stored[STORAGE_KEYS.CACHED_ALIASES]) {
                this.cachedAliases = stored[STORAGE_KEYS.CACHED_ALIASES];
            }
            if (stored[STORAGE_KEYS.LAST_SYNC]) {
                this.lastSync = new Date(stored[STORAGE_KEYS.LAST_SYNC]);
            }
            if (stored[STORAGE_KEYS.USER_INFO]) {
                this.userInfo = stored[STORAGE_KEYS.USER_INFO];
            }

            // Validate authentication state on startup
            if (this.isAuthenticated) {
                await this.validateSession();
            }
        } catch (error) {
            console.error('Failed to initialize iCloud client:', error);
        }
    }

    /**
     * Save state to storage
     */
    async saveState() {
        await chrome.storage.local.set({
            [STORAGE_KEYS.AUTH_STATE]: this.isAuthenticated,
            [STORAGE_KEYS.HME_BASE_URL]: this.hmeBaseUrl,
            [STORAGE_KEYS.CACHED_ALIASES]: this.cachedAliases,
            [STORAGE_KEYS.LAST_SYNC]: this.lastSync?.toISOString(),
            [STORAGE_KEYS.USER_INFO]: this.userInfo
        });
    }

    // ========================================
    // Authentication
    // ========================================

    /**
     * Check if user is signed into iCloud.com
     * @returns {Promise<boolean>}
     */
    async checkAuthentication() {
        try {
            const response = await this.validateSession();
            return response.success;
        } catch (error) {
            return false;
        }
    }

    /**
     * Validate current session with iCloud
     * @returns {Promise<Object>}
     */
    async validateSession() {
        try {
            // Try standard icloud.com first
            let response = await this.fetchWithAuth(`${ICLOUD_SETUP_URL}/validate`, {
                method: 'POST',
                body: JSON.stringify({})
            });

            if (!response.ok) {
                // Try China region
                response = await this.fetchWithAuth(`${ICLOUD_SETUP_URL_CN}/validate`, {
                    method: 'POST',
                    body: JSON.stringify({})
                });
            }

            if (response.ok) {
                const data = await response.json();

                // Extract HME (Hide My Email) base URL from response
                if (data.webservices?.['premiummailsettings']?.url) {
                    this.hmeBaseUrl = data.webservices['premiummailsettings'].url;
                }

                // Store user info
                this.userInfo = {
                    dsid: data.dsInfo?.dsid,
                    firstName: data.dsInfo?.firstName,
                    lastName: data.dsInfo?.lastName,
                    appleId: data.dsInfo?.appleId,
                    hasHideMyEmail: !!data.webservices?.['premiummailsettings']
                };

                this.isAuthenticated = true;
                await this.saveState();

                this.emit('authenticated', this.userInfo);

                return {
                    success: true,
                    userInfo: this.userInfo,
                    hasHideMyEmail: this.userInfo.hasHideMyEmail
                };
            }

            this.isAuthenticated = false;
            await this.saveState();

            return {
                success: false,
                error: 'Not authenticated with iCloud',
                requiresLogin: true
            };

        } catch (error) {
            console.error('Session validation failed:', error);
            this.isAuthenticated = false;
            await this.saveState();

            return {
                success: false,
                error: error.message,
                requiresLogin: true
            };
        }
    }

    /**
     * Open iCloud.com login page
     */
    openLoginPage() {
        chrome.tabs.create({ url: 'https://www.icloud.com/' });
    }

    /**
     * Disconnect and clear all stored data
     */
    async disconnect() {
        this.isAuthenticated = false;
        this.hmeBaseUrl = null;
        this.userInfo = null;
        this.cachedAliases = [];
        this.lastSync = null;

        await chrome.storage.local.remove([
            STORAGE_KEYS.AUTH_STATE,
            STORAGE_KEYS.HME_BASE_URL,
            STORAGE_KEYS.CACHED_ALIASES,
            STORAGE_KEYS.LAST_SYNC,
            STORAGE_KEYS.USER_INFO
        ]);

        this.emit('disconnected');
    }

    // ========================================
    // Helper Methods
    // ========================================

    /**
     * Ensure user is authenticated before API calls
     */
    async ensureAuthenticated() {
        if (!this.isAuthenticated || !this.hmeBaseUrl) {
            const result = await this.validateSession();
            if (!result.success) {
                throw new Error('Authentication required. Please sign in to iCloud.com');
            }
        }
    }

    /**
     * Make authenticated fetch request to iCloud
     */
    async fetchWithAuth(url, options = {}) {
        const defaultHeaders = {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Origin': 'https://www.icloud.com',
            'Referer': 'https://www.icloud.com/'
        };

        return fetch(url, {
            ...options,
            headers: {
                ...defaultHeaders,
                ...options.headers
            },
            credentials: 'include', // Include cookies for authentication
            mode: 'cors'
        });
    }

    /**
     * Normalize alias data from iCloud API
     */
    normalizeAlias(alias) {
        return {
            anonymousId: alias.anonymousId,
            email: alias.hme || alias.email,
            label: alias.label || '',
            note: alias.note || '',
            domain: alias.domain || this.extractDomain(alias.note || alias.label || ''),
            isActive: alias.isActive !== false,
            forwardToEmail: alias.forwardToEmail,
            recipientMailId: alias.recipientMailId,
            origin: alias.origin || 'ON_DEMAND',
            createdAt: alias.createTimestamp ? new Date(alias.createTimestamp) : new Date()
        };
    }

    /**
     * Format a label from domain
     */
    formatLabel(domain) {
        // Remove www. prefix and capitalize first letter
        const cleaned = domain.replace(/^www\./, '');
        const parts = cleaned.split('.');
        if (parts.length > 0) {
            return parts[0].charAt(0).toUpperCase() + parts[0].slice(1);
        }
        return cleaned;
    }

    /**
     * Extract domain from text
     */
    extractDomain(text) {
        const match = text.match(/(?:for\s+)?([a-zA-Z0-9][-a-zA-Z0-9]*\.)+[a-zA-Z]{2,}/i);
        return match ? match[0].replace(/^for\s+/i, '') : '';
    }

    // ========================================
    // Event Emitter
    // ========================================

    on(event, callback) {
        if (!this.eventListeners.has(event)) {
            this.eventListeners.set(event, []);
        }
        this.eventListeners.get(event).push(callback);
    }

    off(event, callback) {
        if (this.eventListeners.has(event)) {
            const listeners = this.eventListeners.get(event);
            const index = listeners.indexOf(callback);
            if (index > -1) {
                listeners.splice(index, 1);
            }
        }
    }

    emit(event, data) {
        if (this.eventListeners.has(event)) {
            for (const callback of this.eventListeners.get(event)) {
                try {
                    callback(data);
                } catch (error) {
                    console.error(`Error in event listener for ${event}:`, error);
                }
            }
        }
    }

    // ========================================
    // Status & Info
    // ========================================

    /**
     * Get current client status
     */
    getStatus() {
        return {
            isAuthenticated: this.isAuthenticated,
            hasHideMyEmail: this.userInfo?.hasHideMyEmail || false,
            userInfo: this.userInfo ? {
                firstName: this.userInfo.firstName,
                lastName: this.userInfo.lastName,
                appleId: this.userInfo.appleId
            } : null,
            aliasCount: this.cachedAliases.length,
            lastSync: this.lastSync
        };
    }

    /**
     * Get cached aliases
     */
    getCachedAliases() {
        return this.cachedAliases;
    }
}

// Export singleton instance
const icloudClient = new iCloudClient();

export default icloudClient;
export { iCloudClient, STORAGE_KEYS };
