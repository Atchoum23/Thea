/**
 * Release Research Service
 * Uses AI to research and validate torrent releases before downloading
 *
 * Features:
 * - Validates release groups reputation
 * - Checks for known bad/fake releases
 * - Researches proper release naming conventions
 * - Compares releases to find the best quality/safety balance
 * - Learns from community feedback and scene rules
 */

import { ProviderRegistry } from '../ai/ProviderRegistry';
import type { TorrentSearchResult } from '../hub/SmartHubService';

export interface ReleaseAnalysis {
  torrent: TorrentSearchResult;
  score: number; // 0-100
  recommendation: 'highly_recommended' | 'recommended' | 'acceptable' | 'caution' | 'avoid';
  reasons: string[];
  warnings: string[];
  releaseGroupInfo?: {
    name: string;
    reputation: 'excellent' | 'good' | 'mixed' | 'poor' | 'unknown';
    knownFor: string[];
  };
  qualityAnalysis: {
    videoQuality: string;
    audioQuality: string;
    estimatedBitrate: string;
    hasHDR: boolean;
    hasDolbyVision: boolean;
    hasAtmos: boolean;
  };
  safetyAnalysis: {
    isScene: boolean;
    isP2P: boolean;
    hasProperNaming: boolean;
    suspiciousFlags: string[];
  };
}

export interface ResearchResult {
  query: string;
  timestamp: string;
  torrents: ReleaseAnalysis[];
  bestChoice: ReleaseAnalysis | null;
  researchNotes: string;
}

// Known release groups and their reputations
const RELEASE_GROUP_DATABASE: Record<string, {
  reputation: 'excellent' | 'good' | 'mixed' | 'poor';
  type: 'scene' | 'p2p' | 'internal';
  knownFor: string[];
}> = {
  // Excellent P2P groups
  'FLUX': { reputation: 'excellent', type: 'p2p', knownFor: ['High quality WEB-DL', 'Consistent releases'] },
  'NTb': { reputation: 'excellent', type: 'p2p', knownFor: ['Premium quality', 'Accurate metadata'] },
  'SPARKS': { reputation: 'excellent', type: 'scene', knownFor: ['Fast releases', 'Good quality'] },
  'RARBG': { reputation: 'excellent', type: 'p2p', knownFor: ['Verified releases', 'Good encodes'] },
  'FGT': { reputation: 'excellent', type: 'scene', knownFor: ['Quality scene releases'] },
  'CMRG': { reputation: 'excellent', type: 'scene', knownFor: ['Quality WEB releases'] },
  'LAZY': { reputation: 'good', type: 'scene', knownFor: ['Fast TV releases'] },
  'LOL': { reputation: 'good', type: 'scene', knownFor: ['Fast TV releases'] },
  'DIMENSION': { reputation: 'good', type: 'scene', knownFor: ['Fast scene releases'] },
  'KILLERS': { reputation: 'good', type: 'scene', knownFor: ['Fast TV releases'] },
  'SVA': { reputation: 'good', type: 'scene', knownFor: ['Fast releases'] },
  'BATV': { reputation: 'good', type: 'scene', knownFor: ['TV releases'] },

  // Good but smaller groups
  'SYNCOPY': { reputation: 'good', type: 'p2p', knownFor: ['Quality encodes'] },
  'TEPES': { reputation: 'good', type: 'p2p', knownFor: ['Good quality'] },
  'ETHEL': { reputation: 'good', type: 'p2p', knownFor: ['Quality releases'] },
  'EDITH': { reputation: 'good', type: 'p2p', knownFor: ['Quality releases'] },

  // Mixed reputation
  'EZTV': { reputation: 'poor', type: 'p2p', knownFor: ['Fast but low quality', 'Sometimes fake'] },
  'YIFY': { reputation: 'poor', type: 'p2p', knownFor: ['Small files', 'Poor quality', 'Over-compressed'] },
  'YTS': { reputation: 'poor', type: 'p2p', knownFor: ['Small files', 'Poor quality'] },
};

// Red flags in torrent names
const SUSPICIOUS_PATTERNS = [
  /\bCAM\b/i,
  /\bTS\b/i,
  /\bTELESYNC\b/i,
  /\bHDCAM\b/i,
  /\bSCR\b/i,
  /\bSCREENER\b/i,
  /\bDVDSCR\b/i,
  /\bR5\b/i,
  /\bHC\b/i, // Hardcoded subs often means CAM
  /\bKORSUB\b/i,
  /\bHARDSUB\b/i,
  /\.exe$/i,
  /\.zip$/i,
  /password/i,
  /survey/i,
];

// Quality indicators
const QUALITY_RANKINGS: Record<string, number> = {
  '2160p': 100,
  '4K': 100,
  'UHD': 100,
  '1080p': 80,
  '720p': 60,
  '480p': 40,
  'SD': 30,
};

const CODEC_RANKINGS: Record<string, number> = {
  'x265': 100,
  'HEVC': 100,
  'H.265': 100,
  'x264': 80,
  'H.264': 80,
  'AVC': 80,
  'AV1': 95,
  'XviD': 40,
};

const AUDIO_RANKINGS: Record<string, number> = {
  'Atmos': 100,
  'TrueHD': 95,
  'DTS-HD.MA': 90,
  'DTS-HD': 85,
  'FLAC': 85,
  'DTS': 75,
  'DD5.1': 70,
  'AAC': 60,
  'MP3': 40,
};

class ReleaseResearchService {
  private researchCache: Map<string, ResearchResult> = new Map();
  private cacheExpiry = 30 * 60 * 1000; // 30 minutes

  /**
   * Research and analyze a list of torrents to find the best one
   */
  async researchReleases(
    torrents: TorrentSearchResult[],
    query: string,
    preferences: {
      preferQuality: boolean;
      preferSpeed: boolean;
      preferSafety: boolean;
      maxFileSizeGB?: number;
    } = { preferQuality: true, preferSpeed: false, preferSafety: true }
  ): Promise<ResearchResult> {
    // Check cache
    const cacheKey = `${query}-${JSON.stringify(preferences)}`;
    const cached = this.researchCache.get(cacheKey);
    if (cached && Date.now() - new Date(cached.timestamp).getTime() < this.cacheExpiry) {
      return cached;
    }

    console.log(`[ReleaseResearch] Analyzing ${torrents.length} releases for: ${query}`);

    // Analyze each torrent
    const analyses: ReleaseAnalysis[] = [];
    for (const torrent of torrents) {
      const analysis = await this.analyzeTorrent(torrent, preferences);
      analyses.push(analysis);
    }

    // Sort by score
    analyses.sort((a, b) => b.score - a.score);

    // Use AI to provide additional research notes
    const researchNotes = await this.getAIResearchNotes(query, analyses.slice(0, 5));

    // Find best choice
    const bestChoice = analyses.find(a =>
      a.recommendation === 'highly_recommended' || a.recommendation === 'recommended'
    ) || analyses[0];

    const result: ResearchResult = {
      query,
      timestamp: new Date().toISOString(),
      torrents: analyses,
      bestChoice,
      researchNotes,
    };

    // Cache result
    this.researchCache.set(cacheKey, result);

    return result;
  }

  /**
   * Analyze a single torrent
   */
  private async analyzeTorrent(
    torrent: TorrentSearchResult,
    preferences: {
      preferQuality: boolean;
      preferSpeed: boolean;
      preferSafety: boolean;
      maxFileSizeGB?: number;
    }
  ): Promise<ReleaseAnalysis> {
    const title = torrent.title;
    const titleLower = title.toLowerCase();
    const reasons: string[] = [];
    const warnings: string[] = [];
    let score = 50; // Start neutral

    // Extract release group
    const groupMatch = title.match(/[-]([A-Za-z0-9]+)(?:\[.*\])?$/);
    const releaseGroup = groupMatch ? groupMatch[1].toUpperCase() : null;
    const groupInfo = releaseGroup ? RELEASE_GROUP_DATABASE[releaseGroup] : null;

    // Release group reputation scoring
    if (groupInfo) {
      switch (groupInfo.reputation) {
        case 'excellent':
          score += 25;
          reasons.push(`Excellent release group: ${releaseGroup}`);
          break;
        case 'good':
          score += 15;
          reasons.push(`Good release group: ${releaseGroup}`);
          break;
        case 'mixed':
          score += 0;
          warnings.push(`Mixed reputation group: ${releaseGroup}`);
          break;
        case 'poor':
          score -= 20;
          warnings.push(`Poor reputation group: ${releaseGroup} - known for low quality`);
          break;
      }
    } else if (releaseGroup) {
      warnings.push(`Unknown release group: ${releaseGroup}`);
    }

    // Quality analysis
    const qualityAnalysis = this.analyzeQuality(title);

    // Quality scoring
    if (preferences.preferQuality) {
      if (qualityAnalysis.videoQuality.includes('2160p') || qualityAnalysis.videoQuality.includes('4K')) {
        score += 15;
        reasons.push('4K resolution');
      } else if (qualityAnalysis.videoQuality.includes('1080p')) {
        score += 10;
        reasons.push('Full HD resolution');
      }

      if (qualityAnalysis.hasHDR) {
        score += 5;
        reasons.push('HDR support');
      }
      if (qualityAnalysis.hasDolbyVision) {
        score += 5;
        reasons.push('Dolby Vision');
      }
      if (qualityAnalysis.hasAtmos) {
        score += 5;
        reasons.push('Dolby Atmos audio');
      }

      if (titleLower.includes('x265') || titleLower.includes('hevc')) {
        score += 5;
        reasons.push('Efficient x265 codec');
      }
    }

    // Safety analysis
    const safetyAnalysis = this.analyzeSafety(title);

    if (safetyAnalysis.suspiciousFlags.length > 0) {
      score -= 15 * safetyAnalysis.suspiciousFlags.length;
      warnings.push(...safetyAnalysis.suspiciousFlags.map(f => `Suspicious: ${f}`));
    }

    if (safetyAnalysis.isScene) {
      score += 5;
      reasons.push('Scene release (verified naming)');
    }

    if (!safetyAnalysis.hasProperNaming) {
      score -= 5;
      warnings.push('Non-standard naming convention');
    }

    // Seeder scoring (availability)
    if (preferences.preferSpeed) {
      if (torrent.seeders >= 100) {
        score += 15;
        reasons.push(`High availability (${torrent.seeders} seeders)`);
      } else if (torrent.seeders >= 20) {
        score += 10;
        reasons.push(`Good availability (${torrent.seeders} seeders)`);
      } else if (torrent.seeders >= 5) {
        score += 5;
      } else if (torrent.seeders < 3) {
        score -= 10;
        warnings.push(`Low seeders (${torrent.seeders}) - may be slow`);
      }
    }

    // File size check
    if (preferences.maxFileSizeGB && preferences.maxFileSizeGB > 0) {
      const sizeGB = torrent.size / (1024 * 1024 * 1024);
      if (sizeGB > preferences.maxFileSizeGB) {
        score -= 15;
        warnings.push(`File size (${sizeGB.toFixed(1)}GB) exceeds limit`);
      }
    }

    // Determine recommendation
    let recommendation: ReleaseAnalysis['recommendation'];
    if (score >= 80) {
      recommendation = 'highly_recommended';
    } else if (score >= 65) {
      recommendation = 'recommended';
    } else if (score >= 50) {
      recommendation = 'acceptable';
    } else if (score >= 35) {
      recommendation = 'caution';
    } else {
      recommendation = 'avoid';
    }

    return {
      torrent,
      score: Math.max(0, Math.min(100, score)),
      recommendation,
      reasons,
      warnings,
      releaseGroupInfo: groupInfo ? {
        name: releaseGroup!,
        reputation: groupInfo.reputation,
        knownFor: groupInfo.knownFor,
      } : undefined,
      qualityAnalysis,
      safetyAnalysis,
    };
  }

  /**
   * Analyze video/audio quality from title
   */
  private analyzeQuality(title: string): ReleaseAnalysis['qualityAnalysis'] {
    const titleLower = title.toLowerCase();

    // Video quality
    let videoQuality = 'Unknown';
    for (const [quality] of Object.entries(QUALITY_RANKINGS)) {
      if (titleLower.includes(quality.toLowerCase())) {
        videoQuality = quality;
        break;
      }
    }

    // Audio quality
    let audioQuality = 'Unknown';
    for (const [audio] of Object.entries(AUDIO_RANKINGS)) {
      if (title.includes(audio)) {
        audioQuality = audio;
        break;
      }
    }

    // HDR detection
    const hasHDR = /\bHDR\b/i.test(title) || /\bHDR10\b/i.test(title);
    const hasDolbyVision = /\bDV\b/i.test(title) || /\bDoVi\b/i.test(title) || /\bDolby\.?Vision\b/i.test(title);
    const hasAtmos = /\bAtmos\b/i.test(title);

    // Estimate bitrate from file size and duration (rough estimate for TV episodes ~45min)
    const estimatedBitrate = 'Unknown';
    // This would need actual runtime data for accuracy

    return {
      videoQuality,
      audioQuality,
      estimatedBitrate,
      hasHDR,
      hasDolbyVision,
      hasAtmos,
    };
  }

  /**
   * Analyze safety/legitimacy of release
   */
  private analyzeSafety(title: string): ReleaseAnalysis['safetyAnalysis'] {
    const suspiciousFlags: string[] = [];

    // Check for suspicious patterns
    for (const pattern of SUSPICIOUS_PATTERNS) {
      if (pattern.test(title)) {
        suspiciousFlags.push(pattern.source.replace(/\\b/g, '').replace(/\$/g, ''));
      }
    }

    // Scene release detection (proper naming convention)
    const isScene = /^[A-Za-z0-9.-]+-[A-Z0-9]+$/.test(title.replace(/\s/g, '.'));

    // P2P release detection
    const isP2P = !isScene && /[-][A-Za-z0-9]+$/.test(title);

    // Proper naming check
    const hasProperNaming =
      /S\d{2}E\d{2}/i.test(title) || // TV episode format
      /\b(19|20)\d{2}\b/.test(title); // Year for movies

    return {
      isScene,
      isP2P,
      hasProperNaming,
      suspiciousFlags,
    };
  }

  /**
   * Get AI-powered research notes
   */
  private async getAIResearchNotes(query: string, topAnalyses: ReleaseAnalysis[]): Promise<string> {
    const provider = ProviderRegistry.getDefaultProvider();

    if (!provider?.isConfigured || topAnalyses.length === 0) {
      return this.generateBasicNotes(topAnalyses);
    }

    try {
      const prompt = `You are a torrent release quality expert. Analyze these releases for "${query}" and provide a brief recommendation (2-3 sentences).

Top releases:
${topAnalyses.slice(0, 3).map((a, i) => `${i + 1}. ${a.torrent.title}
   - Score: ${a.score}/100, Recommendation: ${a.recommendation}
   - Quality: ${a.qualityAnalysis.videoQuality}, ${a.qualityAnalysis.audioQuality}
   - Group: ${a.releaseGroupInfo?.name || 'Unknown'} (${a.releaseGroupInfo?.reputation || 'unknown'})
   - Warnings: ${a.warnings.join(', ') || 'None'}`).join('\n\n')}

Provide a brief expert recommendation focusing on quality and safety.`;

      const response = await provider.chatSync(
        [{ role: 'user', content: prompt }],
        provider.supportedModels[0]?.id || 'default',
        { temperature: 0.3, maxTokens: 200 }
      );

      return response;
    } catch (error) {
      console.error('[ReleaseResearch] AI research failed:', error);
      return this.generateBasicNotes(topAnalyses);
    }
  }

  /**
   * Generate basic research notes without AI
   */
  private generateBasicNotes(analyses: ReleaseAnalysis[]): string {
    if (analyses.length === 0) {
      return 'No releases found to analyze.';
    }

    const best = analyses[0];
    if (best.recommendation === 'highly_recommended' || best.recommendation === 'recommended') {
      return `Recommended: "${best.torrent.title}" - ${best.releaseGroupInfo?.name || 'Unknown group'}, ${best.qualityAnalysis.videoQuality} quality with ${best.torrent.seeders} seeders.`;
    } else if (best.recommendation === 'acceptable') {
      return `Acceptable option: "${best.torrent.title}" - Consider waiting for better releases if not urgent.`;
    } else {
      return `Caution advised: Available releases have quality or safety concerns. Consider waiting for better options.`;
    }
  }

  /**
   * Clear research cache
   */
  clearCache(): void {
    this.researchCache.clear();
  }
}

// Singleton instance
export const releaseResearchService = new ReleaseResearchService();
