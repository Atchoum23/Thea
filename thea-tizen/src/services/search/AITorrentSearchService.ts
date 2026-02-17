/**
 * AI-Powered Torrent Search Service
 *
 * Uses AI to transform natural language voice input into optimized torrent search queries.
 *
 * Best Practices Applied:
 * 1. Query Normalization - Standardizes show names, handles typos, expands abbreviations
 * 2. Scene Release Naming - Converts to standard naming (S01E01, 1080p, x265, etc.)
 * 3. Quality Preference Learning - Adapts to user's preferred quality/release groups
 * 4. Synonym Expansion - "Game of Thrones" → "GoT", "Game.of.Thrones"
 * 5. Contextual Awareness - Knows current episode airing, movie release years
 */

import { ProviderRegistry } from '../ai/ProviderRegistry';
import type { TorrentSearchResult } from '../hub/SmartHubService';

export interface VoiceSearchResult {
  originalQuery: string;
  optimizedQuery: string;
  searchType: 'movie' | 'tv' | 'episode' | 'general';
  parsed: {
    title?: string;
    year?: number;
    season?: number;
    episode?: number;
    quality?: string;
    codec?: string;
    releaseGroup?: string;
  };
  alternativeQueries: string[];
  confidence: number;
  torrents: TorrentSearchResult[];
}

export interface UserPreferences {
  preferredQuality: '4K' | '1080p' | '720p' | 'any';
  preferredCodec: 'x265' | 'x264' | 'any';
  preferredReleaseGroups: string[];
  avoidReleaseGroups: string[];
  preferHDR: boolean;
  preferDolbyAtmos: boolean;
}

// Scene release naming patterns
const QUALITY_PATTERNS = {
  '4k': ['2160p', '4K', 'UHD', '4K UHD'],
  '1080p': ['1080p', '1080i', 'Full HD'],
  '720p': ['720p', 'HD'],
  '480p': ['480p', 'SD', 'DVDRip'],
};

const CODEC_PATTERNS = {
  'x265': ['x265', 'HEVC', 'H.265', 'h265'],
  'x264': ['x264', 'H.264', 'AVC', 'h264'],
  'av1': ['AV1'],
};

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const AUDIO_PATTERNS = {
  'atmos': ['Atmos', 'TrueHD.Atmos', 'DDP5.1.Atmos'],
  'truehd': ['TrueHD', 'True-HD'],
  'dts': ['DTS-HD', 'DTS-HD.MA', 'DTS'],
  'aac': ['AAC', 'AAC2.0', 'AAC5.1'],
};

// Known show abbreviations and variations
const SHOW_ALIASES: Record<string, string[]> = {
  'game of thrones': ['GoT', 'Game.of.Thrones'],
  'the walking dead': ['TWD', 'Walking.Dead'],
  'breaking bad': ['BB', 'Breaking.Bad'],
  'better call saul': ['BCS', 'Better.Call.Saul'],
  'house of the dragon': ['HotD', 'House.of.the.Dragon'],
  'the last of us': ['TLOU', 'Last.of.Us'],
  'the bear': ['The.Bear'],
  'succession': ['Succession'],
  'the office': ['The.Office', 'Office.US'],
  'its always sunny': ["It's.Always.Sunny", 'IASIP', 'Always.Sunny'],
  'stranger things': ['Stranger.Things', 'ST'],
  'the boys': ['The.Boys'],
  'the mandalorian': ['Mandalorian', 'Mando'],
};

class AITorrentSearchService {
  private userPreferences: UserPreferences = {
    preferredQuality: '1080p',
    preferredCodec: 'x265',
    preferredReleaseGroups: ['FLUX', 'NTb', 'SPARKS', 'RARBG', 'YTS'],
    avoidReleaseGroups: ['YIFY', 'eztv'],
    preferHDR: true,
    preferDolbyAtmos: false,
  };

  private searchHistory: Array<{
    query: string;
    optimizedQuery: string;
    selectedTorrent?: string;
    timestamp: number;
  }> = [];

  private syncBridgeUrl: string = '';

  /**
   * Configure the service
   */
  configure(options: { syncBridgeUrl: string; preferences?: Partial<UserPreferences> }): void {
    this.syncBridgeUrl = options.syncBridgeUrl;
    if (options.preferences) {
      this.userPreferences = { ...this.userPreferences, ...options.preferences };
    }
  }

  /**
   * Update user preferences
   */
  updatePreferences(preferences: Partial<UserPreferences>): void {
    this.userPreferences = { ...this.userPreferences, ...preferences };
    this.savePreferences();
  }

  /**
   * Main entry point: Process voice input and search for torrents
   */
  async searchFromVoice(voiceInput: string): Promise<VoiceSearchResult> {
    console.log(`[AI Search] Voice input: "${voiceInput}"`);

    // Step 1: Use AI to parse and optimize the query
    const parsed = await this.aiParseQuery(voiceInput);
    console.log('[AI Search] Parsed:', parsed);

    // Step 2: Generate optimized search queries
    const { primary, alternatives } = this.generateOptimizedQueries(parsed);
    console.log('[AI Search] Optimized query:', primary);
    console.log('[AI Search] Alternatives:', alternatives);

    // Step 3: Search with primary query first
    let torrents = await this.executeTorrentSearch(primary, parsed.searchType);

    // Step 4: If few results, try alternative queries
    if (torrents.length < 5 && alternatives.length > 0) {
      for (const altQuery of alternatives.slice(0, 2)) {
        const altResults = await this.executeTorrentSearch(altQuery, parsed.searchType);
        torrents = this.mergeAndDeduplicate(torrents, altResults);
        if (torrents.length >= 10) break;
      }
    }

    // Step 5: Rank results based on user preferences
    torrents = this.rankByPreferences(torrents);

    // Step 6: Record search for learning
    this.recordSearch(voiceInput, primary);

    return {
      originalQuery: voiceInput,
      optimizedQuery: primary,
      searchType: parsed.searchType,
      parsed: parsed.extracted,
      alternativeQueries: alternatives,
      confidence: parsed.confidence,
      torrents,
    };
  }

  /**
   * Use AI to parse natural language query into structured data
   */
  private async aiParseQuery(input: string): Promise<{
    searchType: 'movie' | 'tv' | 'episode' | 'general';
    extracted: VoiceSearchResult['parsed'];
    confidence: number;
  }> {
    const provider = ProviderRegistry.getDefaultProvider();

    if (!provider?.isConfigured) {
      // Fallback to rule-based parsing if AI not available
      return this.ruleBasedParse(input);
    }

    try {
      const systemPrompt = `You are a torrent search query optimizer. Parse natural language requests into structured search parameters.

Output a JSON object with these fields:
- type: "movie" | "tv" | "episode" | "general"
- title: the show/movie name (normalized, no "the" prefix unless part of official title)
- year: release year if mentioned or known (null if unknown)
- season: season number if mentioned (null for movies)
- episode: episode number if mentioned (null for movies or full seasons)
- quality: "4K" | "1080p" | "720p" | null
- codec: "x265" | "x264" | null
- releaseGroup: specific release group if mentioned

Examples:
Input: "the bear season 3 episode 1"
Output: {"type":"episode","title":"The Bear","season":3,"episode":1,"year":2024}

Input: "download dune 2 in 4k"
Output: {"type":"movie","title":"Dune Part Two","year":2024,"quality":"4K"}

Input: "game of thrones"
Output: {"type":"tv","title":"Game of Thrones","year":2011}

Input: "latest episode of succession"
Output: {"type":"episode","title":"Succession","season":4,"episode":10}

Be smart about:
- Correcting typos and mishearing (e.g., "dunne" → "Dune")
- Expanding abbreviations (e.g., "GoT" → "Game of Thrones")
- Understanding context (e.g., "new bear episode" → latest S3 episode)
- Official titles (e.g., "the batman" → "The Batman" but "batman begins" → "Batman Begins")`;

      const response = await provider.chatSync(
        [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: input },
        ],
        provider.supportedModels[0]?.id || 'default',
        { temperature: 0.3, maxTokens: 200 }
      );

      // Extract JSON from response
      const jsonMatch = response.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        return this.ruleBasedParse(input);
      }

      const parsed = JSON.parse(jsonMatch[0]);

      return {
        searchType: parsed.type || 'general',
        extracted: {
          title: parsed.title,
          year: parsed.year,
          season: parsed.season,
          episode: parsed.episode,
          quality: parsed.quality,
          codec: parsed.codec,
          releaseGroup: parsed.releaseGroup,
        },
        confidence: 0.9,
      };
    } catch (error) {
      console.error('[AI Search] AI parsing failed, using fallback:', error);
      return this.ruleBasedParse(input);
    }
  }

  /**
   * Fallback rule-based parser when AI is unavailable
   */
  private ruleBasedParse(input: string): {
    searchType: 'movie' | 'tv' | 'episode' | 'general';
    extracted: VoiceSearchResult['parsed'];
    confidence: number;
  } {
    const normalized = input.toLowerCase().trim();
    const extracted: VoiceSearchResult['parsed'] = {};

    // Extract season/episode patterns
    const seasonEpMatch = normalized.match(/s(?:eason)?\s*(\d+)\s*e(?:pisode)?\s*(\d+)/i) ||
                          normalized.match(/season\s*(\d+)\s*episode\s*(\d+)/i);
    const seasonOnlyMatch = normalized.match(/s(?:eason)?\s*(\d+)/i) ||
                           normalized.match(/season\s*(\d+)/i);

    if (seasonEpMatch) {
      extracted.season = parseInt(seasonEpMatch[1]);
      extracted.episode = parseInt(seasonEpMatch[2]);
    } else if (seasonOnlyMatch) {
      extracted.season = parseInt(seasonOnlyMatch[1]);
    }

    // Extract year
    const yearMatch = normalized.match(/\b(19|20)\d{2}\b/);
    if (yearMatch) {
      extracted.year = parseInt(yearMatch[0]);
    }

    // Extract quality
    for (const [quality, patterns] of Object.entries(QUALITY_PATTERNS)) {
      if (patterns.some(p => normalized.includes(p.toLowerCase()))) {
        extracted.quality = quality;
        break;
      }
    }

    // Extract codec
    for (const [codec, patterns] of Object.entries(CODEC_PATTERNS)) {
      if (patterns.some(p => normalized.includes(p.toLowerCase()))) {
        extracted.codec = codec;
        break;
      }
    }

    // Remove extracted parts to get title
    const title = normalized
      .replace(/s(?:eason)?\s*\d+\s*e(?:pisode)?\s*\d+/gi, '')
      .replace(/season\s*\d+\s*episode\s*\d+/gi, '')
      .replace(/s(?:eason)?\s*\d+/gi, '')
      .replace(/\b(19|20)\d{2}\b/g, '')
      .replace(/\b(4k|1080p|720p|480p|x265|x264|hevc|hdr|atmos)\b/gi, '')
      .replace(/\b(download|find|search|get|torrent)\b/gi, '')
      .replace(/\s+/g, ' ')
      .trim();

    // Capitalize title
    extracted.title = title
      .split(' ')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');

    // Determine search type
    let searchType: 'movie' | 'tv' | 'episode' | 'general' = 'general';
    if (extracted.episode) {
      searchType = 'episode';
    } else if (extracted.season) {
      searchType = 'tv';
    } else if (normalized.includes('movie') || normalized.includes('film')) {
      searchType = 'movie';
    } else if (normalized.includes('show') || normalized.includes('series')) {
      searchType = 'tv';
    }

    return {
      searchType,
      extracted,
      confidence: 0.6,
    };
  }

  /**
   * Generate optimized search queries from parsed data
   */
  private generateOptimizedQueries(parsed: {
    searchType: 'movie' | 'tv' | 'episode' | 'general';
    extracted: VoiceSearchResult['parsed'];
    confidence: number;
  }): { primary: string; alternatives: string[] } {
    const { extracted, searchType } = parsed;
    const alternatives: string[] = [];

    let primary = extracted.title || '';

    // Add scene-style season/episode notation
    if (searchType === 'episode' && extracted.season && extracted.episode) {
      const sNum = String(extracted.season).padStart(2, '0');
      const eNum = String(extracted.episode).padStart(2, '0');
      primary += ` S${sNum}E${eNum}`;

      // Alternative: full word format
      alternatives.push(`${extracted.title} Season ${extracted.season} Episode ${extracted.episode}`);
    } else if (searchType === 'tv' && extracted.season) {
      const sNum = String(extracted.season).padStart(2, '0');
      primary += ` S${sNum}`;
      alternatives.push(`${extracted.title} Season ${extracted.season}`);
    }

    // Add year for movies
    if (searchType === 'movie' && extracted.year) {
      primary += ` ${extracted.year}`;
    }

    // Add quality preference
    const qualityTag = this.getQualityTag();
    if (qualityTag) {
      primary += ` ${qualityTag}`;
      // Also search without quality as alternative
      alternatives.unshift(primary.replace(` ${qualityTag}`, ''));
    }

    // Add codec preference for efficiency
    if (this.userPreferences.preferredCodec !== 'any') {
      alternatives.push(`${primary} ${this.userPreferences.preferredCodec}`);
    }

    // Generate alias-based alternatives
    const titleLower = (extracted.title || '').toLowerCase();
    for (const [canonical, aliases] of Object.entries(SHOW_ALIASES)) {
      if (titleLower.includes(canonical)) {
        for (const alias of aliases) {
          const altQuery = primary.replace(new RegExp(canonical, 'gi'), alias);
          if (!alternatives.includes(altQuery)) {
            alternatives.push(altQuery);
          }
        }
      }
    }

    // Add release group preference if available
    if (this.userPreferences.preferredReleaseGroups.length > 0) {
      const topGroup = this.userPreferences.preferredReleaseGroups[0];
      alternatives.push(`${primary} ${topGroup}`);
    }

    return { primary, alternatives: alternatives.slice(0, 5) };
  }

  /**
   * Get quality tag based on user preference
   */
  private getQualityTag(): string {
    switch (this.userPreferences.preferredQuality) {
      case '4K':
        return '2160p';
      case '1080p':
        return '1080p';
      case '720p':
        return '720p';
      default:
        return '';
    }
  }

  /**
   * Execute torrent search via sync bridge
   */
  private async executeTorrentSearch(
    query: string,
    type: 'movie' | 'tv' | 'episode' | 'general'
  ): Promise<TorrentSearchResult[]> {
    const category = type === 'movie' ? 'movies' : type === 'tv' || type === 'episode' ? 'tv' : 'all';

    try {
      const response = await fetch(
        `${this.syncBridgeUrl}/torrents/search?q=${encodeURIComponent(query)}&category=${category}`,
        {
          headers: {
            'X-Device-Token': localStorage.getItem('deviceToken') || '',
          },
        }
      );

      if (!response.ok) {
        console.error('[AI Search] Search failed:', response.status);
        return [];
      }

      const data = await response.json();
      return data.results || [];
    } catch (error) {
      console.error('[AI Search] Search error:', error);
      return [];
    }
  }

  /**
   * Merge and deduplicate torrent results
   */
  private mergeAndDeduplicate(
    existing: TorrentSearchResult[],
    newResults: TorrentSearchResult[]
  ): TorrentSearchResult[] {
    const seen = new Set(existing.map(t => t.title.toLowerCase()));
    const merged = [...existing];

    for (const torrent of newResults) {
      if (!seen.has(torrent.title.toLowerCase())) {
        seen.add(torrent.title.toLowerCase());
        merged.push(torrent);
      }
    }

    return merged;
  }

  /**
   * Rank torrents based on user preferences
   */
  private rankByPreferences(torrents: TorrentSearchResult[]): TorrentSearchResult[] {
    return torrents.sort((a, b) => {
      let scoreA = 0;
      let scoreB = 0;

      const titleA = a.title.toLowerCase();
      const titleB = b.title.toLowerCase();

      // Quality scoring
      const qualityScore = (title: string): number => {
        if (this.userPreferences.preferredQuality === '4K') {
          if (title.includes('2160p') || title.includes('4k')) return 30;
          if (title.includes('1080p')) return 20;
        } else if (this.userPreferences.preferredQuality === '1080p') {
          if (title.includes('1080p')) return 30;
          if (title.includes('2160p') || title.includes('4k')) return 25;
          if (title.includes('720p')) return 15;
        }
        return 10;
      };

      scoreA += qualityScore(titleA);
      scoreB += qualityScore(titleB);

      // Codec scoring
      if (this.userPreferences.preferredCodec === 'x265') {
        if (titleA.includes('x265') || titleA.includes('hevc')) scoreA += 15;
        if (titleB.includes('x265') || titleB.includes('hevc')) scoreB += 15;
      } else if (this.userPreferences.preferredCodec === 'x264') {
        if (titleA.includes('x264')) scoreA += 15;
        if (titleB.includes('x264')) scoreB += 15;
      }

      // HDR scoring
      if (this.userPreferences.preferHDR) {
        if (titleA.includes('hdr') || titleA.includes('dolby vision') || titleA.includes('dv')) scoreA += 10;
        if (titleB.includes('hdr') || titleB.includes('dolby vision') || titleB.includes('dv')) scoreB += 10;
      }

      // Dolby Atmos scoring
      if (this.userPreferences.preferDolbyAtmos) {
        if (titleA.includes('atmos')) scoreA += 10;
        if (titleB.includes('atmos')) scoreB += 10;
      }

      // Preferred release groups
      for (const group of this.userPreferences.preferredReleaseGroups) {
        if (titleA.includes(group.toLowerCase())) scoreA += 20;
        if (titleB.includes(group.toLowerCase())) scoreB += 20;
      }

      // Avoid certain release groups
      for (const group of this.userPreferences.avoidReleaseGroups) {
        if (titleA.includes(group.toLowerCase())) scoreA -= 30;
        if (titleB.includes(group.toLowerCase())) scoreB -= 30;
      }

      // Seeder bonus (more seeders = better)
      scoreA += Math.min(a.seeders * 0.5, 25);
      scoreB += Math.min(b.seeders * 0.5, 25);

      // Penalize very low seeders
      if (a.seeders < 5) scoreA -= 20;
      if (b.seeders < 5) scoreB -= 20;

      return scoreB - scoreA;
    });
  }

  /**
   * Record search for preference learning
   */
  private recordSearch(original: string, optimized: string): void {
    this.searchHistory.push({
      query: original,
      optimizedQuery: optimized,
      timestamp: Date.now(),
    });

    // Keep only last 100 searches
    if (this.searchHistory.length > 100) {
      this.searchHistory = this.searchHistory.slice(-100);
    }

    this.saveSearchHistory();
  }

  /**
   * Record when user selects a torrent (for learning)
   */
  recordTorrentSelection(torrent: TorrentSearchResult): void {
    const lastSearch = this.searchHistory[this.searchHistory.length - 1];
    if (lastSearch) {
      lastSearch.selectedTorrent = torrent.title;
      this.learnFromSelection(torrent);
      this.saveSearchHistory();
    }
  }

  /**
   * Learn preferences from user's torrent selection
   */
  private learnFromSelection(torrent: TorrentSearchResult): void {
    const title = torrent.title.toLowerCase();

    // Learn quality preference
    if (title.includes('2160p') || title.includes('4k')) {
      this.adjustQualityPreference('4K');
    } else if (title.includes('1080p')) {
      this.adjustQualityPreference('1080p');
    } else if (title.includes('720p')) {
      this.adjustQualityPreference('720p');
    }

    // Learn codec preference
    if (title.includes('x265') || title.includes('hevc')) {
      this.adjustCodecPreference('x265');
    } else if (title.includes('x264')) {
      this.adjustCodecPreference('x264');
    }

    // Learn release group preference
    const releaseGroupMatch = title.match(/[-](\w+)$/);
    if (releaseGroupMatch) {
      const group = releaseGroupMatch[1].toUpperCase();
      if (!this.userPreferences.preferredReleaseGroups.includes(group)) {
        this.userPreferences.preferredReleaseGroups.unshift(group);
        // Keep only top 10
        this.userPreferences.preferredReleaseGroups =
          this.userPreferences.preferredReleaseGroups.slice(0, 10);
      }
    }

    this.savePreferences();
  }

  private adjustQualityPreference(selected: '4K' | '1080p' | '720p'): void {
    // Simple reinforcement: if user keeps selecting same quality, prefer it
    // In a more sophisticated system, this would use weighted scoring
    this.userPreferences.preferredQuality = selected;
  }

  private adjustCodecPreference(selected: 'x265' | 'x264'): void {
    this.userPreferences.preferredCodec = selected;
  }

  /**
   * Save preferences to localStorage
   */
  private savePreferences(): void {
    try {
      localStorage.setItem('torrentSearchPreferences', JSON.stringify(this.userPreferences));
    } catch (error) {
      console.error('[AI Search] Failed to save preferences:', error);
    }
  }

  /**
   * Load preferences from localStorage
   */
  loadPreferences(): void {
    try {
      const saved = localStorage.getItem('torrentSearchPreferences');
      if (saved) {
        this.userPreferences = { ...this.userPreferences, ...JSON.parse(saved) };
      }
    } catch (error) {
      console.error('[AI Search] Failed to load preferences:', error);
    }
  }

  /**
   * Save search history to localStorage
   */
  private saveSearchHistory(): void {
    try {
      localStorage.setItem('torrentSearchHistory', JSON.stringify(this.searchHistory));
    } catch (error) {
      console.error('[AI Search] Failed to save history:', error);
    }
  }

  /**
   * Load search history from localStorage
   */
  loadSearchHistory(): void {
    try {
      const saved = localStorage.getItem('torrentSearchHistory');
      if (saved) {
        this.searchHistory = JSON.parse(saved);
      }
    } catch (error) {
      console.error('[AI Search] Failed to load history:', error);
    }
  }

  /**
   * Get user preferences (for settings UI)
   */
  getPreferences(): UserPreferences {
    return { ...this.userPreferences };
  }
}

// Singleton instance
export const aiTorrentSearchService = new AITorrentSearchService();
