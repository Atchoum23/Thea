/**
 * Torrent Quality Selector
 *
 * Intelligent quality selection based on TRaSH Guides recommendations.
 * Automatically selects the best torrent based on:
 * - Resolution (4K, 1080p, 720p)
 * - Codec (x265 for 4K, x264 for HD)
 * - HDR format (DV with fallback, HDR10+, HDR10)
 * - Audio quality
 * - Release group reputation
 *
 * @see https://trash-guides.info/
 */

export interface TorrentInfo {
  title: string;
  size: number; // bytes
  seeders: number;
  resolution?: '2160p' | '1080p' | '720p' | '480p';
  codec?: 'x265' | 'x264' | 'av1' | 'xvid';
  hdr?: 'DV' | 'DV+HDR' | 'HDR10+' | 'HDR10' | 'HLG' | 'SDR';
  audio?: 'Atmos' | 'TrueHD' | 'DTS-HD MA' | 'DTS-HD' | 'DD+' | 'DD' | 'AAC';
  source?: 'remux' | 'bluray' | 'web-dl' | 'webrip' | 'hdtv' | 'dvdrip';
  releaseGroup?: string;
  proper?: boolean;
  repack?: boolean;
}

export interface QualityPreferences {
  preferredResolution: '2160p' | '1080p' | '720p';
  maxSizeGB: number;
  requireHDR: boolean;
  preferDolbyVision: boolean;
  preferAtmos: boolean;
  minSeeders: number;
  // Samsung TV limitation: No native DV support, needs HDR fallback
  requireDVFallback: boolean;
}

export interface ScoredTorrent {
  torrent: TorrentInfo;
  score: number;
  reasons: string[];
  warnings: string[];
}

// TRaSH Guides recommended release groups
const TRUSTED_RELEASE_GROUPS = {
  remux: ['FraMeSToR', 'EPSiLON', 'PmP', 'BHDStudio', 'Chotab', 'TRiToN', 'BMF'],
  web: ['NTb', 'FLUX', 'HONE', 'CMRG', 'TEPES', 'KOGi', 'SMURF', 'NOSiViD'],
  encode: ['DON', 'W4NK3R', 'playBD', 'iFT', 'MZABI', 'hallowed', 'SPARKS'],
  scene: ['SPARKS', 'GECKOS', 'ROVERS', 'FGT'],
};

// Known bad/avoid groups
const AVOID_GROUPS = ['YIFY', 'YTS', 'RARBG', 'eztv', 'EVO', 'aXXo'];

// Default quality preferences
const DEFAULT_PREFERENCES: QualityPreferences = {
  preferredResolution: '1080p',
  maxSizeGB: 15,
  requireHDR: false,
  preferDolbyVision: true,
  preferAtmos: false,
  minSeeders: 5,
  requireDVFallback: true, // Samsung TV needs HDR fallback
};

class TorrentQualityService {
  private static instance: TorrentQualityService;
  private preferences: QualityPreferences;

  private constructor() {
    this.preferences = this.loadPreferences();
  }

  static getInstance(): TorrentQualityService {
    if (!TorrentQualityService.instance) {
      TorrentQualityService.instance = new TorrentQualityService();
    }
    return TorrentQualityService.instance;
  }

  private loadPreferences(): QualityPreferences {
    try {
      const saved = localStorage.getItem('thea_quality_prefs');
      if (saved) {
        return { ...DEFAULT_PREFERENCES, ...JSON.parse(saved) };
      }
    } catch {
      // Ignore
    }
    return { ...DEFAULT_PREFERENCES };
  }

  savePreferences(prefs: Partial<QualityPreferences>): void {
    this.preferences = { ...this.preferences, ...prefs };
    localStorage.setItem('thea_quality_prefs', JSON.stringify(this.preferences));
  }

  getPreferences(): QualityPreferences {
    return { ...this.preferences };
  }

  // ============================================================
  // TORRENT PARSING
  // ============================================================

  /**
   * Parse torrent title to extract quality info
   */
  parseTorrentTitle(title: string): Partial<TorrentInfo> {
    const info: Partial<TorrentInfo> = { title };

    // Resolution
    if (/2160p|4k|uhd/i.test(title)) info.resolution = '2160p';
    else if (/1080p|1080i/i.test(title)) info.resolution = '1080p';
    else if (/720p/i.test(title)) info.resolution = '720p';
    else if (/480p|dvdrip|bdrip/i.test(title)) info.resolution = '480p';

    // Codec
    if (/x265|hevc|h\.?265/i.test(title)) info.codec = 'x265';
    else if (/x264|h\.?264|avc/i.test(title)) info.codec = 'x264';
    else if (/av1/i.test(title)) info.codec = 'av1';
    else if (/xvid|divx/i.test(title)) info.codec = 'xvid';

    // HDR
    if (/\bDV\b|dolby\.?vision/i.test(title)) {
      if (/HDR10\+|HDR10Plus/i.test(title) || /\bHDR\b/i.test(title)) {
        info.hdr = 'DV+HDR'; // DV with HDR fallback
      } else {
        info.hdr = 'DV';
      }
    } else if (/HDR10\+|HDR10Plus/i.test(title)) {
      info.hdr = 'HDR10+';
    } else if (/\bHDR\b|HDR10/i.test(title)) {
      info.hdr = 'HDR10';
    } else if (/\bHLG\b/i.test(title)) {
      info.hdr = 'HLG';
    } else {
      info.hdr = 'SDR';
    }

    // Audio
    if (/atmos/i.test(title)) info.audio = 'Atmos';
    else if (/truehd/i.test(title)) info.audio = 'TrueHD';
    else if (/dts-?hd\.?ma/i.test(title)) info.audio = 'DTS-HD MA';
    else if (/dts-?hd/i.test(title)) info.audio = 'DTS-HD';
    else if (/dd\+|ddp|eac3|e-ac-3/i.test(title)) info.audio = 'DD+';
    else if (/dd5\.?1|ac3|dolby\.?digital/i.test(title)) info.audio = 'DD';
    else if (/aac/i.test(title)) info.audio = 'AAC';

    // Source
    if (/remux/i.test(title)) info.source = 'remux';
    else if (/blu-?ray|bdremux/i.test(title)) info.source = 'bluray';
    else if (/web-?dl/i.test(title)) info.source = 'web-dl';
    else if (/webrip/i.test(title)) info.source = 'webrip';
    else if (/hdtv/i.test(title)) info.source = 'hdtv';
    else if (/dvdrip/i.test(title)) info.source = 'dvdrip';

    // Release group (usually at the end after -)
    const groupMatch = title.match(/-([A-Za-z0-9]+)(?:\[.*\])?$/);
    if (groupMatch) {
      info.releaseGroup = groupMatch[1];
    }

    // PROPER/REPACK
    info.proper = /\bproper\b/i.test(title);
    info.repack = /\brepack\b/i.test(title);

    return info;
  }

  // ============================================================
  // SCORING
  // ============================================================

  /**
   * Score a torrent based on quality preferences
   * Higher score = better quality
   */
  scoreTorrent(torrent: TorrentInfo): ScoredTorrent {
    let score = 0;
    const reasons: string[] = [];
    const warnings: string[] = [];

    // === Resolution Score ===
    const resolutionScores: Record<string, number> = {
      '2160p': 4000,
      '1080p': 3000,
      '720p': 2000,
      '480p': 1000,
    };
    if (torrent.resolution) {
      score += resolutionScores[torrent.resolution] || 0;

      // Penalty for non-preferred resolution
      if (torrent.resolution !== this.preferences.preferredResolution) {
        if (torrent.resolution === '2160p' && this.preferences.preferredResolution === '1080p') {
          // 4K is acceptable if user prefers 1080p
          score -= 500;
          reasons.push('4K (preferred 1080p)');
        } else if (torrent.resolution === '720p' && this.preferences.preferredResolution === '1080p') {
          score -= 1000;
          reasons.push('720p (preferred 1080p)');
        }
      } else {
        reasons.push(`${torrent.resolution} (preferred)`);
      }
    }

    // === Codec Score (TRaSH Golden Rule) ===
    // 4K: x265 preferred
    // 1080p: x264 preferred (unless HDR)
    if (torrent.resolution === '2160p') {
      if (torrent.codec === 'x265') {
        score += 500;
        reasons.push('x265 (correct for 4K)');
      } else if (torrent.codec === 'x264') {
        score -= 500;
        warnings.push('x264 not ideal for 4K');
      }
    } else if (torrent.resolution === '1080p') {
      if (torrent.hdr !== 'SDR') {
        // HDR content: x265 is fine
        if (torrent.codec === 'x265') {
          score += 200;
          reasons.push('x265 (acceptable for HDR 1080p)');
        }
      } else {
        // SDR content: x264 preferred
        if (torrent.codec === 'x264') {
          score += 500;
          reasons.push('x264 (correct for 1080p SDR)');
        } else if (torrent.codec === 'x265') {
          score -= 10000; // Strong penalty per TRaSH guide
          warnings.push('x265 for 1080p SDR (avoid)');
        }
      }
    }

    // === HDR Score ===
    if (torrent.hdr && torrent.hdr !== 'SDR') {
      if (torrent.hdr === 'DV+HDR') {
        score += 1500; // Best: DV with fallback
        reasons.push('Dolby Vision + HDR fallback');
      } else if (torrent.hdr === 'DV') {
        if (this.preferences.requireDVFallback) {
          score -= 10000; // Samsung TV can't play pure DV
          warnings.push('DV without HDR fallback (Samsung incompatible)');
        } else {
          score += 1000;
          reasons.push('Dolby Vision');
        }
      } else if (torrent.hdr === 'HDR10+') {
        score += 800;
        reasons.push('HDR10+');
      } else if (torrent.hdr === 'HDR10') {
        score += 500;
        reasons.push('HDR10');
      }
    } else if (this.preferences.requireHDR && torrent.resolution === '2160p') {
      score -= 5000;
      warnings.push('4K SDR (HDR preferred)');
    }

    // === Audio Score ===
    const audioScores: Record<string, number> = {
      'Atmos': 400,
      'TrueHD': 350,
      'DTS-HD MA': 300,
      'DTS-HD': 250,
      'DD+': 200,
      'DD': 100,
      'AAC': 50,
    };
    if (torrent.audio) {
      score += audioScores[torrent.audio] || 0;
      if (torrent.audio === 'Atmos' && this.preferences.preferAtmos) {
        score += 200;
        reasons.push('Dolby Atmos (preferred)');
      }
    }

    // === Source Score ===
    const sourceScores: Record<string, number> = {
      'remux': 500,
      'bluray': 400,
      'web-dl': 300,
      'webrip': 200,
      'hdtv': 100,
      'dvdrip': 50,
    };
    if (torrent.source) {
      score += sourceScores[torrent.source] || 0;
      if (torrent.source === 'remux') {
        reasons.push('Remux (lossless)');
      }
    }

    // === Release Group Score ===
    if (torrent.releaseGroup) {
      const group = torrent.releaseGroup.toUpperCase();

      // Check if trusted
      const isTrusted = Object.values(TRUSTED_RELEASE_GROUPS)
        .flat()
        .some(g => g.toUpperCase() === group);

      if (isTrusted) {
        score += 300;
        reasons.push(`Trusted group: ${torrent.releaseGroup}`);
      }

      // Check if should avoid
      if (AVOID_GROUPS.some(g => g.toUpperCase() === group)) {
        score -= 5000;
        warnings.push(`Avoid group: ${torrent.releaseGroup}`);
      }
    }

    // === PROPER/REPACK bonus ===
    if (torrent.proper) {
      score += 100;
      reasons.push('PROPER release');
    }
    if (torrent.repack) {
      score += 100;
      reasons.push('REPACK');
    }

    // === Seeders Score ===
    if (torrent.seeders < this.preferences.minSeeders) {
      score -= 1000;
      warnings.push(`Low seeders: ${torrent.seeders}`);
    } else if (torrent.seeders > 100) {
      score += 200;
      reasons.push('Well seeded');
    }

    // === Size Score ===
    const sizeGB = torrent.size / (1024 * 1024 * 1024);
    if (sizeGB > this.preferences.maxSizeGB) {
      score -= 500;
      warnings.push(`Large file: ${sizeGB.toFixed(1)}GB`);
    }

    return { torrent, score, reasons, warnings };
  }

  /**
   * Score and rank multiple torrents
   */
  rankTorrents(torrents: TorrentInfo[]): ScoredTorrent[] {
    return torrents
      .map(t => this.scoreTorrent(t))
      .sort((a, b) => b.score - a.score);
  }

  /**
   * Select the best torrent from a list
   */
  selectBest(torrents: TorrentInfo[]): ScoredTorrent | null {
    const ranked = this.rankTorrents(torrents);
    return ranked.length > 0 ? ranked[0] : null;
  }

  /**
   * Filter torrents that meet minimum quality standards
   */
  filterAcceptable(torrents: TorrentInfo[]): TorrentInfo[] {
    return torrents.filter(t => {
      const scored = this.scoreTorrent(t);
      // Accept if no critical warnings and positive score
      const hasCriticalWarning = scored.warnings.some(w =>
        w.includes('avoid') || w.includes('incompatible')
      );
      return !hasCriticalWarning && scored.score > 0;
    });
  }
}

export const torrentQualityService = TorrentQualityService.getInstance();
