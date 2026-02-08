// Thea Safari Extension - Memory Handler
// Local memory system stored in browser.storage.local
// Supports CRUD, search, pagination, import/export, and auto-capture

var STORAGE_KEY = 'thea_memories';
var MAX_MEMORIES = 1000;
var DEFAULT_EXPIRY_DAYS = 365;

/**
 * Load all memories from browser.storage.local.
 * @returns {Array} Array of memory objects
 */
async function loadMemories() {
    try {
        var result = await browser.storage.local.get(STORAGE_KEY);
        return result[STORAGE_KEY] || [];
    } catch (err) {
        console.error('[Thea Memory] Failed to load memories:', err);
        return [];
    }
}

/**
 * Save the full memories array to browser.storage.local.
 * @param {Array} memories - Array of memory objects
 */
async function saveMemories(memories) {
    try {
        var data = {};
        data[STORAGE_KEY] = memories;
        await browser.storage.local.set(data);
    } catch (err) {
        console.error('[Thea Memory] Failed to save memories:', err);
    }
}

/**
 * Generate a unique ID for a memory.
 */
function generateMemoryId() {
    return 'mem_' + Date.now().toString(36) + '_' + Math.random().toString(36).substring(2, 9);
}

/**
 * Add a new memory.
 * @param {Object} data - { text, type, source, url, title, tags }
 */
async function handleAddMemory(data) {
    var memories = await loadMemories();

    var memory = {
        id: generateMemoryId(),
        text: data.text || '',
        type: data.type || 'note',          // note, highlight, bookmark, page, snippet
        source: data.source || 'manual',    // manual, capture, highlight, import
        url: data.url || '',
        title: data.title || '',
        tags: data.tags || [],
        createdAt: Date.now(),
        updatedAt: Date.now(),
        state: 'active',                    // active, archived
        metadata: data.metadata || {}
    };

    memories.unshift(memory);

    // Enforce max memories limit
    if (memories.length > MAX_MEMORIES) {
        memories = memories.slice(0, MAX_MEMORIES);
    }

    await saveMemories(memories);
    await incrementStat('memoriesSaved');

    return { success: true, memory: memory };
}

/**
 * Search memories by keyword with relevance scoring.
 * @param {Object} data - { query, type, limit }
 */
async function handleSearchMemory(data) {
    var memories = await loadMemories();
    var query = (data.query || '').toLowerCase().trim();
    var typeFilter = data.type || null;
    var limit = data.limit || 20;

    if (!query) {
        return { success: true, results: [], total: 0 };
    }

    var queryWords = query.split(/\s+/);
    var scored = [];

    for (var i = 0; i < memories.length; i++) {
        var mem = memories[i];
        if (mem.state !== 'active') continue;
        if (typeFilter && mem.type !== typeFilter) continue;

        var score = 0;
        var textLower = (mem.text || '').toLowerCase();
        var titleLower = (mem.title || '').toLowerCase();
        var tagsLower = (mem.tags || []).join(' ').toLowerCase();

        // Exact phrase match (highest score)
        if (textLower.indexOf(query) !== -1) score += 10;
        if (titleLower.indexOf(query) !== -1) score += 8;
        if (tagsLower.indexOf(query) !== -1) score += 6;

        // Individual word matches
        for (var j = 0; j < queryWords.length; j++) {
            var word = queryWords[j];
            if (word.length < 2) continue;
            if (textLower.indexOf(word) !== -1) score += 3;
            if (titleLower.indexOf(word) !== -1) score += 2;
            if (tagsLower.indexOf(word) !== -1) score += 2;
        }

        // Recency bonus (up to 2 points for memories from the last 7 days)
        var ageMs = Date.now() - (mem.createdAt || 0);
        var ageDays = ageMs / (1000 * 60 * 60 * 24);
        if (ageDays < 7) {
            score += 2 * (1 - ageDays / 7);
        }

        if (score > 0) {
            scored.push({ memory: mem, score: score });
        }
    }

    // Sort by score descending
    scored.sort(function (a, b) { return b.score - a.score; });

    var results = scored.slice(0, limit).map(function (item) {
        return item.memory;
    });

    return { success: true, results: results, total: scored.length };
}

/**
 * List memories with pagination and optional filters.
 * @param {Object} data - { page, pageSize, type, state, sortBy }
 */
async function handleListMemories(data) {
    var memories = await loadMemories();
    var page = data.page || 1;
    var pageSize = data.pageSize || 20;
    var typeFilter = data.type || null;
    var stateFilter = data.state || 'active';
    var sortBy = data.sortBy || 'createdAt';

    // Filter
    var filtered = memories.filter(function (mem) {
        if (typeFilter && mem.type !== typeFilter) return false;
        if (stateFilter && mem.state !== stateFilter) return false;
        return true;
    });

    // Sort
    filtered.sort(function (a, b) {
        if (sortBy === 'updatedAt') return (b.updatedAt || 0) - (a.updatedAt || 0);
        return (b.createdAt || 0) - (a.createdAt || 0);
    });

    // Paginate
    var start = (page - 1) * pageSize;
    var paged = filtered.slice(start, start + pageSize);

    return {
        success: true,
        memories: paged,
        total: filtered.length,
        page: page,
        pageSize: pageSize,
        totalPages: Math.ceil(filtered.length / pageSize)
    };
}

/**
 * Delete a memory by ID.
 * @param {Object} data - { id }
 */
async function handleDeleteMemory(data) {
    var memories = await loadMemories();
    var idx = -1;
    for (var i = 0; i < memories.length; i++) {
        if (memories[i].id === data.id) { idx = i; break; }
    }

    if (idx === -1) {
        return { success: false, error: 'Memory not found' };
    }

    memories.splice(idx, 1);
    await saveMemories(memories);
    return { success: true };
}

/**
 * Delete all memories.
 */
async function handleDeleteAllMemories() {
    await saveMemories([]);
    return { success: true };
}

/**
 * Archive a memory (set state to 'archived').
 * @param {Object} data - { id }
 */
async function handleArchiveMemory(data) {
    var memories = await loadMemories();
    var found = false;

    for (var i = 0; i < memories.length; i++) {
        if (memories[i].id === data.id) {
            memories[i].state = 'archived';
            memories[i].updatedAt = Date.now();
            found = true;
            break;
        }
    }

    if (!found) {
        return { success: false, error: 'Memory not found' };
    }

    await saveMemories(memories);
    return { success: true };
}

/**
 * Update fields of an existing memory.
 * @param {Object} data - { id, text?, tags?, type?, metadata? }
 */
async function handleUpdateMemory(data) {
    var memories = await loadMemories();
    var found = false;

    for (var i = 0; i < memories.length; i++) {
        if (memories[i].id === data.id) {
            if (data.text !== undefined) memories[i].text = data.text;
            if (data.tags !== undefined) memories[i].tags = data.tags;
            if (data.type !== undefined) memories[i].type = data.type;
            if (data.title !== undefined) memories[i].title = data.title;
            if (data.metadata !== undefined) {
                memories[i].metadata = Object.assign(memories[i].metadata || {}, data.metadata);
            }
            memories[i].updatedAt = Date.now();
            found = true;
            break;
        }
    }

    if (!found) {
        return { success: false, error: 'Memory not found' };
    }

    await saveMemories(memories);
    return { success: true };
}

/**
 * Get statistics about memories.
 */
async function handleGetMemoryStats() {
    var memories = await loadMemories();
    var stats = {
        total: memories.length,
        active: 0,
        archived: 0,
        byType: {},
        oldest: null,
        newest: null
    };

    for (var i = 0; i < memories.length; i++) {
        var mem = memories[i];
        if (mem.state === 'active') stats.active++;
        else if (mem.state === 'archived') stats.archived++;

        stats.byType[mem.type] = (stats.byType[mem.type] || 0) + 1;

        if (!stats.oldest || mem.createdAt < stats.oldest) stats.oldest = mem.createdAt;
        if (!stats.newest || mem.createdAt > stats.newest) stats.newest = mem.createdAt;
    }

    return { success: true, stats: stats };
}

/**
 * Export all memories as JSON.
 */
async function handleExportMemories() {
    var memories = await loadMemories();
    return {
        success: true,
        data: {
            version: 1,
            exportedAt: Date.now(),
            count: memories.length,
            memories: memories
        }
    };
}

/**
 * Import memories from a JSON export, merging with existing.
 * @param {Object} data - { memories: Array, overwrite?: boolean }
 */
async function handleImportMemories(data) {
    var importedList = data.memories || [];
    if (!Array.isArray(importedList) || importedList.length === 0) {
        return { success: false, error: 'No memories to import' };
    }

    var existing = data.overwrite ? [] : await loadMemories();
    var existingIds = new Set(existing.map(function (m) { return m.id; }));

    var added = 0;
    var skipped = 0;

    for (var i = 0; i < importedList.length; i++) {
        var mem = importedList[i];
        if (!mem.id || !mem.text) { skipped++; continue; }

        if (existingIds.has(mem.id)) {
            skipped++;
            continue;
        }

        // Ensure required fields
        mem.state = mem.state || 'active';
        mem.createdAt = mem.createdAt || Date.now();
        mem.updatedAt = mem.updatedAt || Date.now();
        mem.type = mem.type || 'note';
        mem.source = mem.source || 'import';
        mem.tags = mem.tags || [];

        existing.push(mem);
        added++;
    }

    // Enforce max limit
    if (existing.length > MAX_MEMORIES) {
        existing = existing.slice(0, MAX_MEMORIES);
    }

    await saveMemories(existing);
    return { success: true, added: added, skipped: skipped, total: existing.length };
}

/**
 * Auto-capture a page visit as a memory.
 * @param {Object} data - { url, title, content, type }
 */
async function handleCapturePageMemory(data) {
    if (!state.memoryEnabled) {
        return { success: false, error: 'Memory feature disabled' };
    }

    // Don't capture internal or empty pages
    if (!data.url || data.url.startsWith('about:') || data.url.startsWith('safari-web-extension:')) {
        return { success: false, error: 'Invalid page for capture' };
    }

    return handleAddMemory({
        text: data.content || data.title || data.url,
        type: data.type || 'page',
        source: 'capture',
        url: data.url,
        title: data.title || '',
        tags: ['auto-captured'],
        metadata: {
            capturedAt: Date.now(),
            contentLength: (data.content || '').length
        }
    });
}

/**
 * Remove memories older than the configured expiry (default 365 days).
 */
async function pruneExpiredMemories() {
    var memories = await loadMemories();
    var expiryMs = DEFAULT_EXPIRY_DAYS * 24 * 60 * 60 * 1000;
    var now = Date.now();
    var pruned = 0;

    var kept = memories.filter(function (mem) {
        if (mem.state === 'archived') return true; // never prune archived
        if (now - (mem.createdAt || 0) > expiryMs) {
            pruned++;
            return false;
        }
        return true;
    });

    if (pruned > 0) {
        await saveMemories(kept);
        console.log('[Thea Memory] Pruned', pruned, 'expired memories');
    }

    return { pruned: pruned, remaining: kept.length };
}
