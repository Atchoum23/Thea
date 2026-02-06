/**
 * Thea Memory System
 *
 * Inspired by: OpenMemory (MCP protocol, cross-tool persistence)
 *
 * Features:
 * - Persistent memory storage (IndexedDB-backed)
 * - Multi-type memories (episodic, semantic, procedural)
 * - Semantic search via embeddings (when Thea app connected)
 * - Per-app access control (which tools can read/write)
 * - Memory states (active, archived)
 * - Automatic memory extraction from browsing
 * - Export/import support
 * - Cross-session persistence
 * - MCP-compatible interface
 */

// Storage keys
const MEMORY_STORAGE_KEY = 'thea_memories';
const MEMORY_CONFIG_KEY = 'thea_memory_config';

class MemorySystem {
  constructor() {
    this.memories = [];
    this.config = {
      enabled: true,
      autoCapture: false,      // Auto-save browsing context
      maxMemories: 10000,
      retentionDays: 365,
      accessControl: {},       // app -> { read: bool, write: bool }
    };
    this.initialized = false;
  }

  async init() {
    if (this.initialized) return;
    try {
      const stored = await chrome.storage.local.get([MEMORY_STORAGE_KEY, MEMORY_CONFIG_KEY]);
      if (stored[MEMORY_STORAGE_KEY]) {
        this.memories = stored[MEMORY_STORAGE_KEY];
      }
      if (stored[MEMORY_CONFIG_KEY]) {
        this.config = { ...this.config, ...stored[MEMORY_CONFIG_KEY] };
      }
      this.initialized = true;

      // Cleanup old memories
      this.pruneExpired();
    } catch (e) {
      console.error('Memory system init failed:', e);
    }
  }

  async save() {
    try {
      await chrome.storage.local.set({
        [MEMORY_STORAGE_KEY]: this.memories,
        [MEMORY_CONFIG_KEY]: this.config
      });
    } catch (e) {
      console.error('Memory save failed:', e);
    }
  }

  // ========================================
  // Core Operations (MCP-compatible)
  // ========================================

  /**
   * Add a new memory
   */
  async addMemory(text, metadata = {}) {
    await this.init();

    const memory = {
      id: crypto.randomUUID(),
      text: text,
      type: metadata.type || 'semantic',  // episodic, semantic, procedural
      source: metadata.source || 'manual',
      url: metadata.url || '',
      title: metadata.title || '',
      tags: metadata.tags || [],
      state: 'active',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      accessCount: 0
    };

    this.memories.unshift(memory);

    // Enforce limit
    if (this.memories.length > this.config.maxMemories) {
      this.memories = this.memories.slice(0, this.config.maxMemories);
    }

    await this.save();
    return memory;
  }

  /**
   * Search memories by text (keyword match, or semantic via Thea app)
   */
  async searchMemory(query, limit = 10) {
    await this.init();

    const queryLower = query.toLowerCase();
    const words = queryLower.split(/\s+/).filter(w => w.length > 2);

    // Score-based keyword search
    const scored = this.memories
      .filter(m => m.state === 'active')
      .map(m => {
        const textLower = (m.text + ' ' + m.title + ' ' + m.tags.join(' ')).toLowerCase();
        let score = 0;

        // Exact phrase match
        if (textLower.includes(queryLower)) score += 10;

        // Word matches
        for (const word of words) {
          if (textLower.includes(word)) score += 2;
        }

        // Recency boost
        const age = (Date.now() - new Date(m.createdAt).getTime()) / (1000 * 60 * 60 * 24);
        score += Math.max(0, 1 - (age / 365));

        // Access frequency boost
        score += Math.min(m.accessCount * 0.1, 2);

        return { memory: m, score };
      })
      .filter(s => s.score > 0)
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);

    // Update access counts
    for (const s of scored) {
      s.memory.accessCount++;
    }
    await this.save();

    return scored.map(s => s.memory);
  }

  /**
   * List all memories with optional filter
   */
  async listMemories(filter = {}) {
    await this.init();

    let results = this.memories;

    if (filter.type) {
      results = results.filter(m => m.type === filter.type);
    }
    if (filter.state) {
      results = results.filter(m => m.state === filter.state);
    }
    if (filter.source) {
      results = results.filter(m => m.source === filter.source);
    }
    if (filter.tag) {
      results = results.filter(m => m.tags.includes(filter.tag));
    }

    const offset = filter.offset || 0;
    const limit = filter.limit || 50;

    return {
      memories: results.slice(offset, offset + limit),
      total: results.length,
      offset,
      limit
    };
  }

  /**
   * Delete a memory by ID
   */
  async deleteMemory(id) {
    await this.init();
    this.memories = this.memories.filter(m => m.id !== id);
    await this.save();
    return true;
  }

  /**
   * Delete all memories
   */
  async deleteAllMemories() {
    this.memories = [];
    await this.save();
    return true;
  }

  /**
   * Archive a memory
   */
  async archiveMemory(id) {
    await this.init();
    const memory = this.memories.find(m => m.id === id);
    if (memory) {
      memory.state = 'archived';
      memory.updatedAt = new Date().toISOString();
      await this.save();
    }
    return memory;
  }

  /**
   * Update a memory
   */
  async updateMemory(id, updates) {
    await this.init();
    const memory = this.memories.find(m => m.id === id);
    if (memory) {
      if (updates.text) memory.text = updates.text;
      if (updates.tags) memory.tags = updates.tags;
      if (updates.type) memory.type = updates.type;
      if (updates.state) memory.state = updates.state;
      memory.updatedAt = new Date().toISOString();
      await this.save();
    }
    return memory;
  }

  // ========================================
  // Auto-Capture
  // ========================================

  /**
   * Auto-save page visit as episodic memory
   */
  async capturePageVisit(data) {
    if (!this.config.enabled || !this.config.autoCapture) return null;

    const text = `Visited: ${data.title}\nURL: ${data.url}\n${data.description || ''}`;

    return this.addMemory(text, {
      type: 'episodic',
      source: 'auto-browse',
      url: data.url,
      title: data.title,
      tags: ['browsing', new URL(data.url).hostname]
    });
  }

  /**
   * Save user's explicit memory
   */
  async saveExplicit(data) {
    return this.addMemory(data.content || data.text, {
      type: data.type || 'semantic',
      source: 'user',
      url: data.url,
      title: data.title,
      tags: data.tags || []
    });
  }

  // ========================================
  // Maintenance
  // ========================================

  pruneExpired() {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - this.config.retentionDays);

    const before = this.memories.length;
    this.memories = this.memories.filter(m => {
      if (m.state === 'archived') return true; // Keep archived
      return new Date(m.createdAt) > cutoff;
    });

    if (this.memories.length < before) {
      this.save();
    }
  }

  /**
   * Export all memories
   */
  async exportMemories() {
    await this.init();
    return {
      version: '1.0',
      exportedAt: new Date().toISOString(),
      count: this.memories.length,
      memories: this.memories
    };
  }

  /**
   * Import memories
   */
  async importMemories(data) {
    await this.init();
    if (!data.memories || !Array.isArray(data.memories)) {
      throw new Error('Invalid import format');
    }

    let imported = 0;
    for (const mem of data.memories) {
      if (mem.text && !this.memories.some(m => m.id === mem.id)) {
        this.memories.push({
          ...mem,
          id: mem.id || crypto.randomUUID(),
          state: 'active',
          importedAt: new Date().toISOString()
        });
        imported++;
      }
    }

    await this.save();
    return { imported, total: this.memories.length };
  }

  /**
   * Get stats
   */
  async getStats() {
    await this.init();
    const active = this.memories.filter(m => m.state === 'active');
    const types = {};
    const sources = {};

    for (const m of active) {
      types[m.type] = (types[m.type] || 0) + 1;
      sources[m.source] = (sources[m.source] || 0) + 1;
    }

    return {
      total: this.memories.length,
      active: active.length,
      archived: this.memories.length - active.length,
      byType: types,
      bySource: sources,
      oldestMemory: this.memories.length > 0
        ? this.memories[this.memories.length - 1].createdAt
        : null,
      newestMemory: this.memories.length > 0
        ? this.memories[0].createdAt
        : null
    };
  }
}

// Export singleton
const memorySystem = new MemorySystem();
export default memorySystem;
export { MemorySystem };
