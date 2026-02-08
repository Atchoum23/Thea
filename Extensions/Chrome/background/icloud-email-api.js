/**
 * iCloud Hide My Email API for Thea Chrome/Brave Extension
 *
 * Extends the iCloud client singleton with Hide My Email operations:
 * generateAlias, reserveAlias, createAlias, getAliases,
 * deactivateAlias, reactivateAlias, deleteAlias, getAliasForDomain
 *
 * This module imports the singleton from icloud-client.js and attaches
 * HME methods to the iCloudClient prototype, then re-exports the singleton.
 *
 * Usage:
 *   import icloudClient from './icloud-email-api.js';
 *   const alias = await icloudClient.createAlias('example.com');
 */

import icloudClient, { iCloudClient } from './icloud-client.js';

// ========================================
// Hide My Email API
// ========================================

/**
 * Get all Hide My Email aliases from iCloud
 * @returns {Promise<Array>}
 */
iCloudClient.prototype.getAliases = async function() {
    await this.ensureAuthenticated();

    try {
        const response = await this.fetchWithAuth(`${this.hmeBaseUrl}/v2/hme/list`);

        if (response.ok) {
            const data = await response.json();
            const aliases = data.result?.hmeEmails || [];

            // Cache the aliases
            this.cachedAliases = aliases.map(this.normalizeAlias);
            this.lastSync = new Date();
            await this.saveState();

            return this.cachedAliases;
        }

        throw new Error('Failed to fetch aliases');
    } catch (error) {
        console.error('Failed to get aliases:', error);
        // Return cached data if available
        return this.cachedAliases;
    }
};

/**
 * Generate a new Hide My Email alias
 * @returns {Promise<string>} The generated email address
 */
iCloudClient.prototype.generateAlias = async function() {
    await this.ensureAuthenticated();

    const response = await this.fetchWithAuth(`${this.hmeBaseUrl}/v1/hme/generate`, {
        method: 'POST',
        body: JSON.stringify({})
    });

    if (response.ok) {
        const data = await response.json();
        const email = data.result?.hme;

        if (email) {
            return email;
        }
    }

    throw new Error('Failed to generate alias');
};

/**
 * Reserve (confirm) a generated alias with metadata
 * @param {string} email - The generated email address
 * @param {string} label - Label for the alias (e.g., website name)
 * @param {string} [note] - Optional note
 * @returns {Promise<Object>} The reserved alias
 */
iCloudClient.prototype.reserveAlias = async function(email, label, note = '') {
    await this.ensureAuthenticated();

    const response = await this.fetchWithAuth(`${this.hmeBaseUrl}/v1/hme/reserve`, {
        method: 'POST',
        body: JSON.stringify({
            hme: email,
            label: label,
            note: note
        })
    });

    if (response.ok) {
        const data = await response.json();
        const alias = data.result;

        if (alias) {
            // Add to cache
            const normalizedAlias = this.normalizeAlias(alias);
            this.cachedAliases.unshift(normalizedAlias);
            await this.saveState();

            this.emit('aliasCreated', normalizedAlias);
            return normalizedAlias;
        }
    }

    throw new Error('Failed to reserve alias');
};

/**
 * Create a new Hide My Email alias (generate + reserve in one step)
 * @param {string} domain - The domain this alias is for
 * @param {string} [label] - Optional custom label
 * @returns {Promise<Object>} The created alias
 */
iCloudClient.prototype.createAlias = async function(domain, label) {
    // Generate a new alias
    const email = await this.generateAlias();

    // Reserve it with the domain/label
    const aliasLabel = label || this.formatLabel(domain);
    const alias = await this.reserveAlias(email, aliasLabel, `Created for ${domain}`);

    return alias;
};

/**
 * Deactivate an alias (stops forwarding)
 * @param {string} anonymousId - The alias ID
 * @returns {Promise<boolean>}
 */
iCloudClient.prototype.deactivateAlias = async function(anonymousId) {
    await this.ensureAuthenticated();

    const response = await this.fetchWithAuth(`${this.hmeBaseUrl}/v1/hme/deactivate`, {
        method: 'POST',
        body: JSON.stringify({ anonymousId })
    });

    if (response.ok) {
        // Update cache
        const index = this.cachedAliases.findIndex(a => a.anonymousId === anonymousId);
        if (index !== -1) {
            this.cachedAliases[index].isActive = false;
            await this.saveState();
        }

        this.emit('aliasDeactivated', { anonymousId });
        return true;
    }

    throw new Error('Failed to deactivate alias');
};

/**
 * Reactivate an alias (resumes forwarding)
 * @param {string} anonymousId - The alias ID
 * @returns {Promise<boolean>}
 */
iCloudClient.prototype.reactivateAlias = async function(anonymousId) {
    await this.ensureAuthenticated();

    const response = await this.fetchWithAuth(`${this.hmeBaseUrl}/v1/hme/reactivate`, {
        method: 'POST',
        body: JSON.stringify({ anonymousId })
    });

    if (response.ok) {
        // Update cache
        const index = this.cachedAliases.findIndex(a => a.anonymousId === anonymousId);
        if (index !== -1) {
            this.cachedAliases[index].isActive = true;
            await this.saveState();
        }

        this.emit('aliasReactivated', { anonymousId });
        return true;
    }

    throw new Error('Failed to reactivate alias');
};

/**
 * Delete an alias permanently
 * @param {string} anonymousId - The alias ID
 * @returns {Promise<boolean>}
 */
iCloudClient.prototype.deleteAlias = async function(anonymousId) {
    await this.ensureAuthenticated();

    const response = await this.fetchWithAuth(`${this.hmeBaseUrl}/v1/hme/delete`, {
        method: 'POST',
        body: JSON.stringify({ anonymousId })
    });

    if (response.ok) {
        // Remove from cache
        this.cachedAliases = this.cachedAliases.filter(a => a.anonymousId !== anonymousId);
        await this.saveState();

        this.emit('aliasDeleted', { anonymousId });
        return true;
    }

    throw new Error('Failed to delete alias');
};

/**
 * Get alias for a specific domain (from cache)
 * @param {string} domain
 * @returns {Object|null}
 */
iCloudClient.prototype.getAliasForDomain = function(domain) {
    return this.cachedAliases.find(alias =>
        alias.label?.toLowerCase().includes(domain.toLowerCase()) ||
        alias.note?.toLowerCase().includes(domain.toLowerCase())
    ) || null;
};

// Re-export the same singleton, now with HME methods attached
export default icloudClient;
export { iCloudClient };
