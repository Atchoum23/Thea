/**
 * iCloud Bridge for Thea Chrome/Brave Extension
 *
 * Core native messaging bridge: connection management, request/response
 * handling, event emitter, and status tracking.
 *
 * Keychain-specific operations (getCredentials, saveCredential,
 * generatePassword, autofillCredential, deleteCredential) are in
 * icloud-keychain.js (attached to this singleton's prototype).
 *
 * This bridge communicates with TheaNativeMessagingHost through Chrome's
 * native messaging API to access iCloud services.
 */

const NATIVE_HOST_NAME = 'com.thea.native';

class iCloudBridge {
    constructor() {
        this.port = null;
        this.pendingRequests = new Map();
        this.isConnected = false;
        this.isAuthenticated = false;
        this.connectionAttempts = 0;
        this.maxConnectionAttempts = 3;
        this.reconnectDelay = 1000;

        // Connection status
        this.status = {
            passwordsConnected: false,
            passwordsAuthenticated: false,
            hideMyEmailConnected: false,
            hideMyEmailAuthenticated: false,
            lastError: null
        };

        // Event listeners
        this.eventListeners = new Map();
    }

    // ========================================
    // Connection Management
    // ========================================

    /**
     * Connect to the native messaging host
     */
    async connect() {
        if (this.isConnected && this.port) {
            return { success: true, status: this.status };
        }

        try {
            this.port = chrome.runtime.connectNative(NATIVE_HOST_NAME);

            this.port.onMessage.addListener((message) => {
                this.handleNativeMessage(message);
            });

            this.port.onDisconnect.addListener(() => {
                this.handleDisconnect();
            });

            // Send initial connect request
            const response = await this.sendRequest('connect', {});

            if (response.success) {
                this.isConnected = true;
                this.isAuthenticated = true;
                this.status = {
                    ...this.status,
                    passwordsConnected: response.data?.passwordsConnected ?? false,
                    passwordsAuthenticated: response.data?.passwordsConnected ?? false,
                    hideMyEmailConnected: response.data?.hideMyEmailConnected ?? false,
                    hideMyEmailAuthenticated: response.data?.hideMyEmailConnected ?? false
                };
                this.connectionAttempts = 0;
                this.emit('connected', this.status);
            }

            return { success: true, status: this.status };

        } catch (error) {
            this.status.lastError = error.message;
            this.connectionAttempts++;

            if (this.connectionAttempts < this.maxConnectionAttempts) {
                await this.delay(this.reconnectDelay);
                return this.connect();
            }

            return {
                success: false,
                error: error.message,
                suggestion: 'Please ensure Thea is installed and the native host is set up.'
            };
        }
    }

    /**
     * Disconnect from native host
     */
    disconnect() {
        if (this.port) {
            this.sendRequest('disconnect', {}).catch(() => {});
            this.port.disconnect();
            this.port = null;
        }
        this.isConnected = false;
        this.isAuthenticated = false;
        this.status = {
            passwordsConnected: false,
            passwordsAuthenticated: false,
            hideMyEmailConnected: false,
            hideMyEmailAuthenticated: false,
            lastError: null
        };
        this.emit('disconnected');
    }

    /**
     * Handle disconnect event
     */
    handleDisconnect() {
        const error = chrome.runtime.lastError;
        console.log('Native host disconnected:', error?.message);

        this.isConnected = false;
        this.port = null;

        // Reject all pending requests
        for (const [requestId, { reject }] of this.pendingRequests) {
            reject(new Error('Connection lost'));
        }
        this.pendingRequests.clear();

        this.emit('disconnected', { error: error?.message });
    }

    /**
     * Get current connection status
     */
    async getStatus() {
        if (!this.isConnected) {
            return { connected: false, ...this.status };
        }

        try {
            const response = await this.sendRequest('getStatus', {});
            if (response.success) {
                this.status = {
                    ...this.status,
                    ...response.data
                };
            }
            return { connected: true, ...this.status };
        } catch (error) {
            return { connected: false, error: error.message };
        }
    }

    // ========================================
    // Hide My Email (via native bridge)
    // ========================================

    /**
     * Create a new Hide My Email alias
     * @param {string} domain - The domain this alias is for
     * @param {string} [label] - Optional label for the alias
     * @returns {Promise<Object>} The created alias
     */
    async createAlias(domain, label) {
        await this.ensureConnected();

        const response = await this.sendRequest('createAlias', { domain, label });

        if (response.success) {
            const alias = {
                id: response.data.id,
                email: response.data.email,
                label: response.data.label,
                domain: response.data.domain,
                isActive: response.data.isActive,
                createdAt: response.data.createdAt
            };
            this.emit('aliasCreated', alias);
            return alias;
        }

        throw new Error(response.error || 'Failed to create alias');
    }

    /**
     * Get all Hide My Email aliases
     * @returns {Promise<Array>} Array of aliases
     */
    async getAliases() {
        await this.ensureConnected();

        const response = await this.sendRequest('getAliases', {});

        if (response.success) {
            return response.data?.aliases ?? [];
        }

        throw new Error(response.error || 'Failed to get aliases');
    }

    /**
     * Get alias for a specific domain
     * @param {string} domain
     */
    async getAliasForDomain(domain) {
        await this.ensureConnected();

        const response = await this.sendRequest('getAliasForDomain', { domain });

        if (response.success) {
            return response.data;
        }

        throw new Error(response.error || 'Failed to get alias');
    }

    /**
     * Deactivate an alias
     * @param {string} aliasId
     */
    async deactivateAlias(aliasId) {
        await this.ensureConnected();

        const response = await this.sendRequest('deactivateAlias', { aliasId });

        if (response.success) {
            this.emit('aliasDeactivated', { aliasId });
            return true;
        }

        throw new Error(response.error || 'Failed to deactivate alias');
    }

    /**
     * Reactivate an alias
     * @param {string} aliasId
     */
    async reactivateAlias(aliasId) {
        await this.ensureConnected();

        const response = await this.sendRequest('reactivateAlias', { aliasId });

        if (response.success) {
            this.emit('aliasReactivated', { aliasId });
            return true;
        }

        throw new Error(response.error || 'Failed to reactivate alias');
    }

    /**
     * Delete an alias permanently
     * @param {string} aliasId
     */
    async deleteAlias(aliasId) {
        await this.ensureConnected();

        const response = await this.sendRequest('deleteAlias', { aliasId });

        if (response.success) {
            this.emit('aliasDeleted', { aliasId });
            return true;
        }

        throw new Error(response.error || 'Failed to delete alias');
    }

    /**
     * Autofill alias for a domain (creates if doesn't exist)
     * @param {string} domain
     */
    async autofillAlias(domain) {
        await this.ensureConnected();

        const response = await this.sendRequest('autofillAlias', { domain });

        if (response.success) {
            return {
                email: response.data.email,
                isNew: response.data.isNew
            };
        }

        throw new Error(response.error || 'Failed to autofill alias');
    }

    // ========================================
    // Internal Methods
    // ========================================

    /**
     * Ensure we're connected before making requests
     */
    async ensureConnected() {
        if (!this.isConnected || !this.port) {
            const result = await this.connect();
            if (!result.success) {
                throw new Error(result.error || 'Failed to connect to native host');
            }
        }
    }

    /**
     * Send a request to the native host
     */
    sendRequest(type, data) {
        return new Promise((resolve, reject) => {
            if (!this.port) {
                reject(new Error('Not connected to native host'));
                return;
            }

            const requestId = this.generateRequestId();

            const timeout = setTimeout(() => {
                this.pendingRequests.delete(requestId);
                reject(new Error('Request timeout'));
            }, 30000); // 30 second timeout

            this.pendingRequests.set(requestId, { resolve, reject, timeout });

            this.port.postMessage({
                type,
                requestId,
                data
            });
        });
    }

    /**
     * Handle message from native host
     */
    handleNativeMessage(message) {
        const { requestId, type, success, data, error } = message;

        if (requestId && this.pendingRequests.has(requestId)) {
            const { resolve, reject, timeout } = this.pendingRequests.get(requestId);
            clearTimeout(timeout);
            this.pendingRequests.delete(requestId);

            resolve({ success, data, error });
        } else {
            // Unsolicited message (e.g., sync updates)
            this.handleUnsolicited(message);
        }
    }

    /**
     * Handle unsolicited messages (sync updates, etc.)
     */
    handleUnsolicited(message) {
        switch (message.type) {
            case 'credentialUpdated':
                this.emit('credentialUpdated', message.data);
                break;
            case 'aliasUpdated':
                this.emit('aliasUpdated', message.data);
                break;
            case 'syncComplete':
                this.emit('syncComplete', message.data);
                break;
        }
    }

    /**
     * Generate unique request ID
     */
    generateRequestId() {
        return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    }

    /**
     * Delay helper
     */
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
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
}

// Export singleton instance
const icloudBridge = new iCloudBridge();

export default icloudBridge;
export { iCloudBridge };
