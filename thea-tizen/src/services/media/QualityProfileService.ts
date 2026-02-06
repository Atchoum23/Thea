/**
 * Quality Profile Service
 *
 * Implements Sonarr/Radarr-like quality profiles with:
 * - Custom format scoring (TRaSH Guides compatible)
 * - Upgrade logic with cutoffs
 * - Samsung TV-aware optimizations (avoid pure DV)
 *
 * @see https://trash-guides.info/Radarr/Radarr-Quality-Settings-File-Size/
 */

import { ParsedRelease, Resolution, Source, AudioCodec, HDRFormat, ReleaseType } from './ReleaseParserService';

export interface QualityProfile {
  id: string;
  name: string;
  description: string;
  cutoff: { minResolution: Resolution; minSource: Source; minScore: number };
  allowedResolutions: Resolution[];
  allowedSources: Source[];
  preferredGroups: string[];
  blockedGroups: string[];
  hdrPreference: 'any' | 'prefer-dv-hdr' | 'prefer-hdr10' | 'require-hdr' | 'sdr-only';
  upgradeAllowed: boolean;
  upgradeUntilScore: number;
  minUpgradeImprovement: number;
  preferProper: boolean;
  preferRepack: boolean;
  preferRemux: boolean;
}

const PROFILE_PRESETS: Record<string, Omit<QualityProfile, 'id'>> = {
  'trash-4k-samsung': {
    name: 'TRaSH 4K (Samsung TV)',
    description: 'Optimized for Samsung 4K TVs - avoids pure DV, prefers DV+HDR fallback',
    cutoff: { minResolution: '2160p', minSource: 'webdl', minScore: 6000 },
    allowedResolutions: ['2160p', '1080p'],
    allowedSources: ['bluray', 'webdl', 'webrip'],
    preferredGroups: ['FraMeSToR', 'BHDStudio', 'HiFi', 'FLUX', 'DON', 'NTb', 'HONE'],
    blockedGroups: ['YIFY', 'YTS', 'EVO', 'AMIABLE', 'STUTTERSHIT'],
    hdrPreference: 'prefer-dv-hdr',
    upgradeAllowed: true,
    upgradeUntilScore: 8000,
    minUpgradeImprovement: 500,
    preferProper: true,
    preferRepack: true,
    preferRemux: true,
  },
  'trash-1080p': {
    name: 'TRaSH 1080p',
    description: 'Balanced 1080p profile with good quality and reasonable size',
    cutoff: { minResolution: '1080p', minSource: 'webdl', minScore: 4000 },
    allowedResolutions: ['1080p', '720p'],
    allowedSources: ['bluray', 'webdl', 'webrip', 'hdtv'],
    preferredGroups: ['CtrlHD', 'DON', 'NTb', 'HONE', 'FLUX'],
    blockedGroups: ['YIFY', 'YTS', 'EVO', 'AMIABLE'],
    hdrPreference: 'sdr-only',
    upgradeAllowed: true,
    upgradeUntilScore: 5500,
    minUpgradeImprovement: 300,
    preferProper: true,
    preferRepack: true,
    preferRemux: false,
  },
  'anime': {
    name: 'Anime',
    description: 'Optimized for anime with dual audio support',
    cutoff: { minResolution: '1080p', minSource: 'webdl', minScore: 3500 },
    allowedResolutions: ['2160p', '1080p', '720p'],
    allowedSources: ['bluray', 'webdl', 'webrip'],
    preferredGroups: ['SubsPlease', 'Erai-raws', 'Judas', 'Tsundere-Raws', 'Kametsu'],
    blockedGroups: ['HorribleSubs-Lite', 'Mini-Encodes'],
    hdrPreference: 'any',
    upgradeAllowed: true,
    upgradeUntilScore: 5000,
    minUpgradeImprovement: 300,
    preferProper: true,
    preferRepack: true,
    preferRemux: false,
  },
};

class QualityProfileService {
  private static instance: QualityProfileService;
  private profiles: Map<string, QualityProfile> = new Map();
  private activeProfileId: string = 'trash-4k-samsung';

  private constructor() { this.initializePresets(); }

  static getInstance(): QualityProfileService {
    if (!QualityProfileService.instance) {
      QualityProfileService.instance = new QualityProfileService();
    }
    return QualityProfileService.instance;
  }

  private initializePresets(): void {
    for (const [id, preset] of Object.entries(PROFILE_PRESETS)) {
      this.profiles.set(id, { id, ...preset });
    }
  }

  getAllProfiles(): QualityProfile[] { return Array.from(this.profiles.values()); }
  getProfile(id: string): QualityProfile | undefined { return this.profiles.get(id); }
  getActiveProfile(): QualityProfile { return this.profiles.get(this.activeProfileId) || this.profiles.get('trash-4k-samsung')!; }
  setActiveProfile(id: string): void { if (this.profiles.has(id)) this.activeProfileId = id; }

  scoreRelease(release: ParsedRelease, profile?: QualityProfile): number {
    const p = profile || this.getActiveProfile();
    let score = release.qualityScore;
    if (release.releaseGroup && p.preferredGroups.includes(release.releaseGroup)) score += 300;
    if (release.releaseGroup && p.blockedGroups.includes(release.releaseGroup)) score -= 5000;
    if (release.isProper && p.preferProper) score += 100;
    if (release.isRepack && p.preferRepack) score += 100;
    if (release.isRemux && p.preferRemux) score += 200;
    score += this.applyHDRPreference(release.hdrFormat, p.hdrPreference);
    return score;
  }

  private applyHDRPreference(hdr: HDRFormat, preference: QualityProfile['hdrPreference']): number {
    if (preference === 'prefer-dv-hdr') {
      if (hdr === 'dv-hdr') return 1000;
      if (hdr === 'dv') return -2000;
      if (hdr === 'hdr10plus') return 500;
      if (hdr === 'hdr10' || hdr === 'hdr') return 300;
    }
    if (preference === 'require-hdr' && hdr === 'sdr') return -5000;
    if (preference === 'sdr-only' && hdr !== 'sdr') return -200;
    return 0;
  }

  isAcceptable(release: ParsedRelease, profile?: QualityProfile): { acceptable: boolean; reason?: string } {
    const p = profile || this.getActiveProfile();
    if (!p.allowedResolutions.includes(release.resolution) && release.resolution !== 'unknown') {
      return { acceptable: false, reason: `Resolution ${release.resolution} not allowed` };
    }
    if (!p.allowedSources.includes(release.source) && release.source !== 'unknown') {
      return { acceptable: false, reason: `Source ${release.source} not allowed` };
    }
    if (release.releaseGroup && p.blockedGroups.includes(release.releaseGroup)) {
      return { acceptable: false, reason: `Release group ${release.releaseGroup} is blocked` };
    }
    if (p.hdrPreference === 'prefer-dv-hdr' && release.hdrFormat === 'dv') {
      return { acceptable: false, reason: 'Pure Dolby Vision not supported on Samsung TV' };
    }
    const score = this.scoreRelease(release, p);
    if (score < p.cutoff.minScore) {
      return { acceptable: false, reason: `Score ${score} below minimum ${p.cutoff.minScore}` };
    }
    return { acceptable: true };
  }

  isUpgrade(newRelease: ParsedRelease, existingRelease: ParsedRelease, profile?: QualityProfile): { isUpgrade: boolean; reason: string; improvement: number } {
    const p = profile || this.getActiveProfile();
    if (!p.upgradeAllowed) return { isUpgrade: false, reason: 'Upgrades not allowed', improvement: 0 };
    const newScore = this.scoreRelease(newRelease, p);
    const existingScore = this.scoreRelease(existingRelease, p);
    const improvement = newScore - existingScore;
    if (existingScore >= p.upgradeUntilScore) return { isUpgrade: false, reason: 'Already at maximum quality', improvement };
    if (improvement < p.minUpgradeImprovement) return { isUpgrade: false, reason: `Improvement ${improvement} below threshold`, improvement };
    if ((newRelease.isProper || newRelease.isRepack) && !existingRelease.isProper && !existingRelease.isRepack) {
      return { isUpgrade: true, reason: 'Proper/Repack upgrade', improvement };
    }
    return { isUpgrade: true, reason: `Quality improvement: ${improvement}`, improvement };
  }

  rankReleases(releases: ParsedRelease[], profile?: QualityProfile): ParsedRelease[] {
    const p = profile || this.getActiveProfile();
    return [...releases]
      .map(r => ({ release: r, score: this.scoreRelease(r, p), acceptable: this.isAcceptable(r, p).acceptable }))
      .filter(item => item.acceptable)
      .sort((a, b) => b.score - a.score)
      .map(item => item.release);
  }

  getBestRelease(releases: ParsedRelease[], profile?: QualityProfile): ParsedRelease | undefined {
    return this.rankReleases(releases, profile)[0];
  }
}

export const qualityProfileService = QualityProfileService.getInstance();
