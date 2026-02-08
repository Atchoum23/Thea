// Thea Safari Extension - Message Router
// Central message dispatcher that routes all messages to appropriate handlers
// All handler functions are defined in other modules (global scope)

/**
 * Main message handler. Routes messages by type to the appropriate handler.
 * @param {Object} message - Message with a 'type' property
 * @param {Object} sender - The message sender info
 * @returns {Promise<Object>} Response object
 */
async function handleMessage(message, sender) {
    if (!message || !message.type) {
        return { error: 'Missing message type' };
    }

    var type = message.type;
    var data = message.data || message;

    try {
        switch (type) {
            // ── State Management ──────────────────────────────────────
            case 'getState':
                return { success: true, state: getState() };

            case 'setState':
                var updatedState = await updateState(data.updates || data, true);
                return { success: true, state: updatedState };

            case 'getStats':
                return { success: true, stats: state.stats };

            case 'updateStats':
                if (data.stat && data.amount !== undefined) {
                    await incrementStat(data.stat, data.amount);
                }
                return { success: true, stats: state.stats };

            case 'toggleFeature':
                var newValue = await toggleFeature(data.feature);
                return { success: newValue !== null, feature: data.feature, enabled: newValue };

            case 'getStatus':
                return {
                    success: true,
                    isConnectedToApp: state.isConnectedToApp,
                    lastSyncTime: state.lastSyncTime,
                    features: {
                        adBlocker: state.adBlockerEnabled,
                        darkMode: state.darkModeEnabled,
                        privacy: state.privacyProtectionEnabled,
                        passwords: state.passwordManagerEnabled,
                        email: state.emailProtectionEnabled,
                        printFriendly: state.printFriendlyEnabled,
                        aiAssistant: state.aiAssistantEnabled,
                        videoController: state.videoControllerEnabled,
                        memory: state.memoryEnabled,
                        writingAssistant: state.writingAssistantEnabled
                    }
                };

            case 'resetState':
                var freshState = await resetState();
                return { success: true, state: freshState };

            // ── Dark Mode ─────────────────────────────────────────────
            case 'getDarkModeConfig':
                return { success: true, config: state.darkModeConfig };

            case 'saveDarkModeConfig':
                state.darkModeConfig = Object.assign(state.darkModeConfig || {}, data.config || data);
                await saveState();
                await broadcastToTabs({ type: 'darkModeConfigChanged', config: state.darkModeConfig });
                return { success: true, config: state.darkModeConfig };

            case 'getDarkModeCSS':
                var domain = data.domain || '';
                var css = await generateDarkModeCSS(domain);
                return { success: true, css: css };

            // ── Video Controller ──────────────────────────────────────
            case 'getVideoConfig':
                return { success: true, config: state.videoConfig };

            case 'saveVideoConfig':
                state.videoConfig = Object.assign(state.videoConfig || {}, data.config || data);
                await saveState();
                return { success: true, config: state.videoConfig };

            // ── Privacy ───────────────────────────────────────────────
            case 'getPrivacyConfig':
                return { success: true, config: state.privacyConfig };

            case 'savePrivacyConfig':
                state.privacyConfig = Object.assign(state.privacyConfig || {}, data.config || data);
                await saveState();
                return { success: true, config: state.privacyConfig };

            // ── Ad Blocking ───────────────────────────────────────────
            case 'getBlockingDecision':
                return checkShouldBlock(data.url, data.resourceType);

            case 'updateWhitelist':
                return updateWhitelist(data.domain, data.action);

            case 'getBlockedCount':
                return getBlockedCount();

            // ── Memory ────────────────────────────────────────────────
            case 'addMemory':
            case 'saveToMemory':
                return handleAddMemory(data);

            case 'searchMemory':
                return handleSearchMemory(data);

            case 'listMemories':
                return handleListMemories(data);

            case 'deleteMemory':
                return handleDeleteMemory(data);

            case 'deleteAllMemories':
                return handleDeleteAllMemories();

            case 'archiveMemory':
                return handleArchiveMemory(data);

            case 'updateMemory':
                return handleUpdateMemory(data);

            case 'getMemoryStats':
                return handleGetMemoryStats();

            case 'exportMemories':
                return handleExportMemories();

            case 'importMemories':
                return handleImportMemories(data);

            case 'capturePageMemory':
                return handleCapturePageMemory(data);

            // ── AI / Thea Native ──────────────────────────────────────
            case 'askAI':
                return askTheaAI(data.question, data.context);

            case 'deepResearch':
                return deepResearch(data.query, data.sources);

            case 'analyzeContent':
                return analyzeContentNative(data.content, data.url);

            case 'toggleAISidebar':
                // Forward to the active tab's content script
                try {
                    var aiTabs = await browser.tabs.query({ active: true, currentWindow: true });
                    if (aiTabs[0]) {
                        await browser.tabs.sendMessage(aiTabs[0].id, { action: 'toggleAISidebar' });
                    }
                } catch (err) {
                    console.warn('[Thea Router] Could not toggle AI sidebar:', err.message);
                }
                return { success: true };

            // ── Print Friendly ────────────────────────────────────────
            case 'activatePrintFriendly':
            case 'cleanPage':
                try {
                    var printTabs = await browser.tabs.query({ active: true, currentWindow: true });
                    if (printTabs[0]) {
                        await browser.tabs.sendMessage(printTabs[0].id, { action: type });
                        await incrementStat('pagesCleaned');
                    }
                } catch (err) {
                    console.warn('[Thea Router] Print friendly failed:', err.message);
                }
                return { success: true };

            // ── Password Manager ──────────────────────────────────────
            case 'getCredentials':
                return getCredentialsFromNative(data.domain);

            case 'saveCredential':
                return saveCredentialToNative(data);

            case 'generatePassword':
                return generatePasswordNative();

            case 'getTOTPCode':
                return getTOTPFromNative(data.domain);

            case 'registerPasskey':
                return sendNativeMessage({
                    action: 'registerPasskey',
                    domain: data.domain,
                    username: data.username,
                    challenge: data.challenge
                });

            case 'authenticatePasskey':
                return sendNativeMessage({
                    action: 'authenticatePasskey',
                    domain: data.domain,
                    challenge: data.challenge
                });

            // ── Writing Assistant ─────────────────────────────────────
            case 'rewriteText':
                return handleRewriteRequest(data);

            case 'analyzeWritingStyle':
                return handleAnalyzeStyle(data);

            case 'getStyleProfile':
                return handleGetStyleProfile();

            case 'saveSuggestionFeedback':
                return handleSaveSuggestionFeedback(data);

            // ── Session Management ────────────────────────────────────
            case 'saveSession':
                return sendNativeMessage({
                    action: 'saveSession',
                    tabs: data.tabs,
                    name: data.name
                });

            case 'restoreSession':
                return sendNativeMessage({
                    action: 'restoreSession',
                    sessionId: data.sessionId
                });

            // ── Ping / Health ─────────────────────────────────────────
            case 'ping':
                return { success: true, pong: true, timestamp: Date.now() };

            case 'pingNative':
                return pingNativeApp();

            // ── Unknown ───────────────────────────────────────────────
            default:
                console.warn('[Thea Router] Unknown message type:', type);
                return { error: 'Unknown message type: ' + type };
        }
    } catch (err) {
        console.error('[Thea Router] Error handling message type:', type, err);
        return { error: err.message || 'Internal error', type: type };
    }
}
