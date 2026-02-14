/**
 * iCloud Keychain Operations for Thea Chrome/Brave Extension
 *
 * Extends the iCloud bridge singleton with Keychain-specific operations:
 * getCredentials, saveCredential, generatePassword,
 * autofillCredential, deleteCredential
 *
 * This module imports the singleton from icloud-bridge.js and attaches
 * Keychain methods to the iCloudBridge prototype, then re-exports the singleton.
 *
 * Usage:
 *   import icloudBridge from './icloud-keychain.js';
 *   const creds = await icloudBridge.getCredentials('example.com');
 */

import icloudBridge, { iCloudBridge } from './icloud-bridge.js';

// ========================================
// Password Management (iCloud Keychain)
// ========================================

/**
 * Get credentials for a domain
 * @param {string} domain - The domain to get credentials for
 * @returns {Promise<Array>} Array of credentials
 */
iCloudBridge.prototype.getCredentials = async function(domain) {
    await this.ensureConnected();

    const response = await this.sendRequest('getCredentials', { domain });

    if (response.success) {
        return response.data?.credentials ?? [];
    }

    throw new Error(response.error || 'Failed to get credentials');
};

/**
 * Save a credential to iCloud Passwords
 * @param {Object} credential - The credential to save
 * @returns {Promise<boolean>}
 */
iCloudBridge.prototype.saveCredential = async function({ username, password, domain, notes }) {
    await this.ensureConnected();

    const response = await this.sendRequest('saveCredential', {
        username,
        password,
        domain,
        notes
    });

    if (response.success) {
        this.emit('credentialSaved', { domain, username });
        return true;
    }

    throw new Error(response.error || 'Failed to save credential');
};

/**
 * Generate a strong password (Apple-style format)
 * @returns {Promise<string>} Generated password
 */
iCloudBridge.prototype.generatePassword = async function() {
    await this.ensureConnected();

    const response = await this.sendRequest('generatePassword', {});

    if (response.success) {
        return response.data?.password;
    }

    throw new Error(response.error || 'Failed to generate password');
};

/**
 * Autofill credential for a domain (quick access)
 * @param {string} domain
 */
iCloudBridge.prototype.autofillCredential = async function(domain) {
    await this.ensureConnected();

    const response = await this.sendRequest('autofillCredential', { domain });

    if (response.success && response.data?.found) {
        return {
            found: true,
            username: response.data.username,
            password: response.data.password
        };
    }

    return { found: false };
};

/**
 * Delete a credential from iCloud Passwords
 * @param {string} domain
 * @param {string} username
 */
iCloudBridge.prototype.deleteCredential = async function(domain, username) {
    await this.ensureConnected();

    const response = await this.sendRequest('deleteCredential', {
        domain,
        username
    });

    if (response.success) {
        this.emit('credentialDeleted', { domain, username });
        return true;
    }

    throw new Error(response.error || 'Failed to delete credential');
};

// Re-export the same singleton, now with Keychain methods attached
export default icloudBridge;
export { iCloudBridge };
