/**
 * Release Parser Service
 *
 * Parses release names into structured data, extracting:
 * - Title, year, season, episode
 * - Quality (resolution, source, codec)
 * - Audio format (Atmos, DTS-HD MA, etc.)
 * - HDR format (DV, HDR10, HDR10+)
 * - Release group (Scene vs P2P)
 * - Language, subtitles
 *
 * Based on TRaSH Guides recommendations and Sonarr/Radarr patterns.
 *
 * @see https://trash-guides.info/
 * @see https://github.com/Sonarr/Sonarr
 */

// ============================================================
// TYPES
// ============================================================

export interface ParsedRelease {
  rawTitle: string;
  cleanTitle: string;
  year?: number;
  mediaType: 'movie' | 'episode' | 'season' | 'unknown';
  season?: number;
  episode?: number;
  episodeEnd?: number;
  absoluteEpisode?: number;
  resolution: Resolution;
  source: Source;
  codec: Codec;
  audioCodec: AudioCodec;
  audioChannels?: string;
  hdrFormat: HDRFormat;
  releaseGroup?: string;
  releaseType: ReleaseType;
  isProper: boolean;
  isRepack: boolean;
  isRemux: boolean;
  is3D: boolean;
  languages: string[];
  subtitles: string[];
  isMulti: boolean;
  imdbId?: string;
  tmdbId?: number;
  tvdbId?: number;
  qualityScore: number;
  overallScore: number;
}

export type Resolution = '2160p' | '1080p' | '720p' | '576p' | '480p' | 'unknown';
export type Source = 'bluray' | 'webdl' | 'webrip' | 'hdtv' | 'dvd' | 'cam' | 'unknown';
export type Codec = 'x265' | 'x264' | 'xvid' | 'av1' | 'mpeg2' | 'unknown';
export type AudioCodec = 'truehd' | 'dts-hd-ma' | 'dts-x' | 'atmos' | 'dts' | 'dd' | 'aac' | 'flac' | 'opus' | 'unknown';
export type HDRFormat = 'dv' | 'dv-hdr' | 'hdr10plus' | 'hdr10' | 'hdr' | 'hlg' | 'sdr';
export type ReleaseType = 'scene' | 'p2p' | 'internal' | 'unknown';

// ============================================================
// PATTERNS
// ============================================================

const PATTERNS = {
  resolution: {
    '2160p': /\b(2160p|4k|uhd)\b/i,
    '1080p': /\b1080[pi]\b/i,
    '720p': /\b720p\b/i,
    '576p': /\b576[pi]\b/i,
    '480p': /\b(480[pi]|sd)\b/i,
  },
  source: {
    bluray: /\b(blu-?ray|bdrip|brrip|bdremux)\b/i,
    webdl: /\b(web-?dl|webdl|web)\b/i,
    webrip: /\bweb-?rip\b/i,
    hdtv: /\b(hdtv|pdtv|dsr)\b/i,
    dvd: /\b(dvd-?rip|dvd)\b/i,
    cam: /\b(cam-?rip|hdcam|ts|telesync)\b/i,
  },
  codec: {
    x265: /\b(x265|h\.?265|hevc)\b/i,
    x264: /\b(x264|h\.?264|avc)\b/i,
    av1: /\bav1\b/i,
    xvid: /\bxvid\b/i,
    mpeg2: /\bmpeg-?2\b/i,
  },
  audio: {
    truehd: /\b(true-?hd|truehd)\b/i,
    'dts-hd-ma': /\b(dts-?hd[- ]?ma|dts-?hd)\b/i,
    'dts-x': /\bdts-?x\b/i,
    atmos: /\batmos\b/i,
    dts: /\bdts\b/i,
    dd: /\b(dd|dolby|ac3|eac3|dd\+|ddp)\b/i,
    aac: /\baac\b/i,
    flac: /\bflac\b/i,
    opus: /\bopus\b/i,
  },
  hdr: {
    'dv-hdr': /\b(dv|dovi|dolby[- ]?vision)[- ]?(hdr10?|plus|\+)?\b.*\b(hdr10?|plus|\+|dv|dovi)\b/i,
    dv: /\b(dv|dovi|dolby[- ]?vision)\b/i,
    hdr10plus: /\b(hdr10\+|hdr10plus)\b/i,
    hdr10: /\bhdr10\b/i,
    hdr: /\bhdr\b/i,
    hlg: /\bhlg\b/i,
  },
  channels: /\b([257])\.([01])\b/,
  season: /\bS(\d{1,2})\b/i,
  episode: /\bE(\d{1,3})(?:-?E?(\d{1,3}))?\b/i,
  seasonEpisode: /\bS(\d{1,2})E(\d{1,3})(?:-?E?(\d{1,3}))?\b/i,
  absoluteEpisode: /\b(?:ep?|episode)[- ]?(\d{1,4})\b/i,
  year: /\b((?:19|20)\d{2})\b/,
  proper: /\bproper\b/i,
  repack: /\brepack\b/i,
  remux: /\bremux\b/i,
  is3d: /\b3d\b/i,
  multi: /\bmulti\b/i,
  imdb: /\{?imdb-?(tt\d{7,})\}?/i,
  tmdb: /\{?tmdb-?(\d+)\}?/i,
  tvdb: /\{?tvdb-?(\d+)\}?/i,
  releaseGroup: /-([a-zA-Z0-9]+)(?:\.[a-zA-Z]{2,4})?$/,
};

const RELEASE_GROUPS = {
  premiumP2P: ['FraMeSToR', 'BHDStudio', 'HiFi', 'SiCFoI', 'NCmt', 'PTer', 'FLUX', 'NTb', 'HONE', 'KRaLiMaRKo', 'DON', 'EbP', 'ZQ', 'TayTo', 'Chotab', 'TEPES', 'CtrlHD', 'MainFrame', 'E.N.D', 'Flights', 'W4NK3R', 'CMRG', 'HQMUX', 'WEBDL', 'playWEB'],
  p2p: ['SPARKS', 'GECKOS', 'ROVERS', 'DRONES', 'EPSILON', 'DEMAND', 'VETO', 'TRUMP', 'SHORTBREHD', 'EDITH', 'GALLOWS', 'NTSC'],
  scene: ['LOL', 'DIMENSION', 'KILLERS', 'FUM', 'AVS', '0SEC', 'RARBG', 'EZTV', 'TBS', 'BATV', 'REWARD', 'YIFY', 'YTS', 'SPARKS'],
  lowQuality: ['YIFY', 'YTS', 'EVO', 'AMIABLE', 'STUTTERSHIT', 'iPlanet', 'BONE', 'RARTV', 'TGx', 'MeGusta', 'HEVCBay', 'PSA'],
};

const LANGUAGE_PATTERNS: Record<string, RegExp> = {
  english: /\b(eng?|english)\b/i,
  french: /\b(fre?|french|vff|vfi|vf2|truefrench)\b/i,
  german: /\b(ger?|german|deutsch)\b/i,
  spanish: /\b(spa?|spanish|español|castellano|latino)\b/i,
  italian: /\b(ita?|italian|italiano)\b/i,
  japanese: /\b(jap?|japanese|日本語)\b/i,
  korean: /\b(kor?|korean|한국어)\b/i,
  chinese: /\b(chi?|chinese|中文)\b/i,
};

// ============================================================
// SERVICE
// ============================================================

class ReleaseParserService {
  private static instance: ReleaseParserService;

  private constructor() {}

  static getInstance(): ReleaseParserService {
    if (!ReleaseParserService.instance) {
      ReleaseParserService.instance = new ReleaseParserService();
    }
    return ReleaseParserService.instance;
  }

  parse(releaseName: string): ParsedRelease {
    const raw = releaseName;
    const resolution = this.extractResolution(raw);
    const source = this.extractSource(raw);
    const codec = this.extractCodec(raw);
    const audioCodec = this.extractAudioCodec(raw);
    const audioChannels = this.extractAudioChannels(raw);
    const hdrFormat = this.extractHDR(raw);
    const { season, episode, episodeEnd, absoluteEpisode } = this.extractEpisodeInfo(raw);
    const year = this.extractYear(raw);
    const releaseGroup = this.extractReleaseGroup(raw);
    const releaseType = this.classifyReleaseGroup(releaseGroup);
    const languages = this.extractLanguages(raw);
    const { imdbId, tmdbId, tvdbId } = this.extractIds(raw);

    let mediaType: ParsedRelease['mediaType'] = 'unknown';
    if (season !== undefined && episode !== undefined) {
      mediaType = 'episode';
    } else if (season !== undefined && episode === undefined) {
      mediaType = 'season';
    } else if (year !== undefined || !raw.match(/S\d{1,2}E\d{1,3}/i)) {
      mediaType = 'movie';
    }

    const cleanTitle = this.cleanTitle(raw, { year, season, episode });
    const qualityScore = this.computeQualityScore(resolution, source, codec, hdrFormat);
    const audioScore = this.computeAudioScore(audioCodec, audioChannels);
    const groupScore = this.computeGroupScore(releaseGroup, releaseType);

    return {
      rawTitle: raw,
      cleanTitle,
      year,
      mediaType,
      season,
      episode,
      episodeEnd,
      absoluteEpisode,
      resolution,
      source,
      codec,
      audioCodec,
      audioChannels,
      hdrFormat,
      releaseGroup,
      releaseType,
      isProper: PATTERNS.proper.test(raw),
      isRepack: PATTERNS.repack.test(raw),
      isRemux: PATTERNS.remux.test(raw),
      is3D: PATTERNS.is3d.test(raw),
      languages,
      subtitles: [],
      isMulti: PATTERNS.multi.test(raw),
      imdbId,
      tmdbId,
      tvdbId,
      qualityScore,
      overallScore: qualityScore + audioScore + groupScore,
    };
  }

  private extractResolution(name: string): Resolution {
    for (const [res, pattern] of Object.entries(PATTERNS.resolution)) {
      if (pattern.test(name)) return res as Resolution;
    }
    return 'unknown';
  }

  private extractSource(name: string): Source {
    for (const [src, pattern] of Object.entries(PATTERNS.source)) {
      if (pattern.test(name)) return src as Source;
    }
    return 'unknown';
  }

  private extractCodec(name: string): Codec {
    for (const [codec, pattern] of Object.entries(PATTERNS.codec)) {
      if (pattern.test(name)) return codec as Codec;
    }
    return 'unknown';
  }

  private extractAudioCodec(name: string): AudioCodec {
    for (const [codec, pattern] of Object.entries(PATTERNS.audio)) {
      if (pattern.test(name)) return codec as AudioCodec;
    }
    return 'unknown';
  }

  private extractAudioChannels(name: string): string | undefined {
    const match = name.match(PATTERNS.channels);
    if (match) return `${match[1]}.${match[2]}`;
    if (/atmos/i.test(name)) return 'Atmos';
    return undefined;
  }

  private extractHDR(name: string): HDRFormat {
    if (PATTERNS.hdr['dv-hdr'].test(name)) return 'dv-hdr';
    for (const [format, pattern] of Object.entries(PATTERNS.hdr)) {
      if (pattern.test(name)) return format as HDRFormat;
    }
    return 'sdr';
  }

  private extractEpisodeInfo(name: string) {
    const seMatch = name.match(PATTERNS.seasonEpisode);
    if (seMatch) {
      return {
        season: parseInt(seMatch[1], 10),
        episode: parseInt(seMatch[2], 10),
        episodeEnd: seMatch[3] ? parseInt(seMatch[3], 10) : undefined,
        absoluteEpisode: undefined,
      };
    }
    const sMatch = name.match(PATTERNS.season);
    const eMatch = name.match(PATTERNS.episode);
    const absMatch = name.match(PATTERNS.absoluteEpisode);
    return {
      season: sMatch ? parseInt(sMatch[1], 10) : undefined,
      episode: eMatch ? parseInt(eMatch[1], 10) : undefined,
      episodeEnd: eMatch && eMatch[2] ? parseInt(eMatch[2], 10) : undefined,
      absoluteEpisode: absMatch ? parseInt(absMatch[1], 10) : undefined,
    };
  }

  private extractYear(name: string): number | undefined {
    const match = name.match(PATTERNS.year);
    if (match) {
      const year = parseInt(match[1], 10);
      if (year >= 1900 && year <= new Date().getFullYear() + 1) return year;
    }
    return undefined;
  }

  private extractReleaseGroup(name: string): string | undefined {
    const match = name.match(PATTERNS.releaseGroup);
    return match ? match[1] : undefined;
  }

  private classifyReleaseGroup(group?: string): ReleaseType {
    if (!group) return 'unknown';
    const upperGroup = group.toUpperCase();
    if (RELEASE_GROUPS.premiumP2P.some(g => g.toUpperCase() === upperGroup)) return 'p2p';
    if (RELEASE_GROUPS.p2p.some(g => g.toUpperCase() === upperGroup)) return 'p2p';
    if (RELEASE_GROUPS.scene.some(g => g.toUpperCase() === upperGroup)) return 'scene';
    if (group === group.toUpperCase() && group.length <= 10) return 'scene';
    return 'unknown';
  }

  private extractLanguages(name: string): string[] {
    const languages: string[] = [];
    for (const [lang, pattern] of Object.entries(LANGUAGE_PATTERNS)) {
      if (pattern.test(name)) languages.push(lang);
    }
    if (languages.length === 0) languages.push('english');
    return languages;
  }

  private extractIds(name: string) {
    const imdbMatch = name.match(PATTERNS.imdb);
    const tmdbMatch = name.match(PATTERNS.tmdb);
    const tvdbMatch = name.match(PATTERNS.tvdb);
    return {
      imdbId: imdbMatch ? imdbMatch[1] : undefined,
      tmdbId: tmdbMatch ? parseInt(tmdbMatch[1], 10) : undefined,
      tvdbId: tvdbMatch ? parseInt(tvdbMatch[1], 10) : undefined,
    };
  }

  private cleanTitle(name: string, info: { year?: number; season?: number; episode?: number }): string {
    let clean = name.replace(/\.[a-zA-Z]{2,4}$/, '');
    const cutPatterns = [/\b(2160p|1080p|720p|480p|576p)\b.*/i, /\b(blu-?ray|web-?dl|webrip|hdtv|dvdrip)\b.*/i, /\b(x264|x265|hevc|h\.264|h\.265)\b.*/i];
    for (const pattern of cutPatterns) {
      const match = clean.match(pattern);
      if (match) { clean = clean.substring(0, match.index); break; }
    }
    if (info.year) clean = clean.replace(new RegExp(`\\(?${info.year}\\)?`), '');
    clean = clean.replace(/S\d{1,2}E\d{1,3}(-E?\d{1,3})?/gi, '').replace(/S\d{1,2}/gi, '');
    clean = clean.replace(/[._-]/g, ' ').replace(/\s+/g, ' ').trim();
    return clean;
  }

  private computeQualityScore(resolution: Resolution, source: Source, codec: Codec, hdr: HDRFormat): number {
    let score = 0;
    const resScores: Record<Resolution, number> = { '2160p': 5000, '1080p': 3000, '720p': 1000, '576p': 500, '480p': 200, 'unknown': 0 };
    score += resScores[resolution];
    const srcScores: Record<Source, number> = { bluray: 1000, webdl: 800, webrip: 600, hdtv: 400, dvd: 200, cam: -5000, unknown: 0 };
    score += srcScores[source];
    if (resolution === '2160p' && codec === 'x265') score += 500;
    else if (resolution === '1080p' && hdr === 'sdr' && codec === 'x265') score -= 500;
    if (codec === 'av1') score += 200;
    if (hdr === 'dv-hdr') score += 1000;
    else if (hdr === 'dv') score -= 2000; // Pure DV won't play on Samsung
    else if (hdr === 'hdr10plus') score += 800;
    else if (hdr === 'hdr10' || hdr === 'hdr') score += 500;
    return score;
  }

  private computeAudioScore(codec: AudioCodec, channels?: string): number {
    let score = 0;
    const audioScores: Record<AudioCodec, number> = { truehd: 500, atmos: 500, 'dts-hd-ma': 400, 'dts-x': 400, dts: 200, dd: 150, flac: 150, aac: 100, opus: 100, unknown: 0 };
    score += audioScores[codec];
    if (channels === 'Atmos' || channels === '7.1') score += 100;
    else if (channels === '5.1') score += 50;
    return score;
  }

  private computeGroupScore(group?: string, type?: ReleaseType): number {
    if (!group) return 0;
    const upperGroup = group.toUpperCase();
    if (RELEASE_GROUPS.premiumP2P.some(g => g.toUpperCase() === upperGroup)) return 500;
    if (RELEASE_GROUPS.p2p.some(g => g.toUpperCase() === upperGroup)) return 300;
    if (RELEASE_GROUPS.lowQuality.some(g => g.toUpperCase() === upperGroup)) return -1000;
    if (type === 'scene') return 0;
    return 100;
  }

  compare(a: ParsedRelease, b: ParsedRelease): number {
    return b.overallScore - a.overallScore;
  }

  meetsMinimumQuality(release: ParsedRelease, requirements: { minResolution?: Resolution; minSource?: Source; requireHDR?: boolean; avoidGroups?: string[] }): boolean {
    const resOrder: Resolution[] = ['480p', '576p', '720p', '1080p', '2160p'];
    const srcOrder: Source[] = ['cam', 'dvd', 'hdtv', 'webrip', 'webdl', 'bluray'];
    if (requirements.minResolution) {
      const minIdx = resOrder.indexOf(requirements.minResolution);
      const releaseIdx = resOrder.indexOf(release.resolution);
      if (releaseIdx < minIdx) return false;
    }
    if (requirements.minSource) {
      const minIdx = srcOrder.indexOf(requirements.minSource);
      const releaseIdx = srcOrder.indexOf(release.source);
      if (releaseIdx < minIdx) return false;
    }
    if (requirements.requireHDR && release.hdrFormat === 'sdr') return false;
    if (requirements.avoidGroups && release.releaseGroup) {
      const group = release.releaseGroup.toUpperCase();
      if (requirements.avoidGroups.some(g => g.toUpperCase() === group)) return false;
    }
    return true;
  }
}

export const releaseParserService = ReleaseParserService.getInstance();
