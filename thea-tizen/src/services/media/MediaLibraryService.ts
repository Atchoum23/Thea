/**
 * Media Library Service
 *
 * Plex-compatible library management with naming conventions.
 */

import { ParsedRelease } from './ReleaseParserService';

export interface MediaItem {
  id: string;
  type: 'movie' | 'episode';
  title: string;
  year?: number;
  season?: number;
  episode?: number;
  episodeTitle?: string;
  imdbId?: string;
  tmdbId?: number;
  tvdbId?: number;
  filePath: string;
  fileSize: number;
  addedAt: Date;
  quality: { resolution: string; source: string; codec: string; hdr: string; audioCodec: string; releaseGroup?: string; qualityScore: number };
  status: 'pending' | 'downloading' | 'imported' | 'failed';
  monitorStatus: 'monitored' | 'unmonitored';
}

export interface Movie {
  id: string;
  title: string;
  year: number;
  imdbId?: string;
  tmdbId?: number;
  status: 'released' | 'inCinemas' | 'announced' | 'unknown';
  monitored: boolean;
  hasFile: boolean;
  rootPath: string;
  path: string;
  qualityProfileId: string;
  minimumAvailability: 'announced' | 'inCinemas' | 'released' | 'preDB';
  mediaItem?: MediaItem;
  addedAt: Date;
  lastUpdated: Date;
}

export interface TVShow {
  id: string;
  title: string;
  year?: number;
  imdbId?: string;
  tmdbId?: number;
  tvdbId?: number;
  status: 'continuing' | 'ended' | 'upcoming' | 'unknown';
  monitorStatus: 'all' | 'future' | 'missing' | 'none';
  rootPath: string;
  path: string;
  seasons: TVSeason[];
  qualityProfileId: string;
  addedAt: Date;
  lastUpdated: Date;
}

export interface TVSeason {
  seasonNumber: number;
  monitored: boolean;
  episodes: TVEpisode[];
  statistics: { episodeCount: number; episodeFileCount: number; percentOfEpisodes: number; sizeOnDisk: number };
}

export interface TVEpisode {
  episodeNumber: number;
  title: string;
  airDate?: Date;
  monitored: boolean;
  hasFile: boolean;
  mediaItem?: MediaItem;
}

const DEFAULT_ROOT_PATHS = { movies: '/media/movies', tvShows: '/media/tv', anime: '/media/anime' };

class MediaLibraryService {
  private static instance: MediaLibraryService;
  private movies: Map<string, Movie> = new Map();
  private tvShows: Map<string, TVShow> = new Map();
  private mediaItems: Map<string, MediaItem> = new Map();
  private rootPaths = DEFAULT_ROOT_PATHS;

  private constructor() {}
  static getInstance(): MediaLibraryService {
    if (!MediaLibraryService.instance) MediaLibraryService.instance = new MediaLibraryService();
    return MediaLibraryService.instance;
  }

  generateMovieFolderName(m: { title: string; year?: number }): string {
    const name = `${m.title} (${m.year || ''})`.replace(/:/g, ' - ').replace(/[<>"|?*/\\]/g, '').trim();
    return name.replace(/\s+/g, ' ');
  }

  generateMovieFileName(m: { title: string; year?: number }, r: ParsedRelease, ext = 'mkv'): string {
    const quality = this.buildQualityTags(r);
    const name = `${m.title} (${m.year || ''}) ${quality}`.replace(/:/g, ' - ').replace(/[<>"|?*/\\]/g, '').trim();
    return `${name}.${ext}`;
  }

  generateSeriesFolderName(s: { title: string; year?: number }): string {
    let name = s.title;
    if (s.year) name = `${name} (${s.year})`;
    return name.replace(/:/g, ' - ').replace(/[<>"|?*/\\]/g, '').trim();
  }

  generateSeasonFolderName(seasonNumber: number): string {
    return `Season ${seasonNumber.toString().padStart(2, '0')}`;
  }

  generateEpisodeFileName(show: { title: string }, ep: { season: number; episode: number; title?: string }, r: ParsedRelease, ext = 'mkv'): string {
    const quality = this.buildQualityTags(r);
    const s = ep.season.toString().padStart(2, '0');
    const e = ep.episode.toString().padStart(2, '0');
    const name = `${show.title} - S${s}E${e} - ${ep.title || 'Episode'} ${quality}`;
    return `${name.replace(/:/g, ' - ').replace(/[<>"|?*/\\]/g, '').trim()}.${ext}`;
  }

  private buildQualityTags(r: ParsedRelease): string {
    const parts: string[] = [];
    if (r.resolution !== 'unknown') parts.push(r.resolution);
    if (r.source !== 'unknown') {
      const names: Record<string, string> = { bluray: 'Bluray', webdl: 'WEB-DL', webrip: 'WEBRip', hdtv: 'HDTV', dvd: 'DVD' };
      parts.push(names[r.source] || r.source);
    }
    if (r.hdrFormat !== 'sdr') {
      const names: Record<string, string> = { 'dv-hdr': 'DV HDR', dv: 'DV', hdr10plus: 'HDR10+', hdr10: 'HDR10', hdr: 'HDR', hlg: 'HLG' };
      parts.push(names[r.hdrFormat] || r.hdrFormat.toUpperCase());
    }
    if (r.codec !== 'unknown') parts.push(r.codec.toUpperCase());
    if (r.releaseGroup) parts.push(`-${r.releaseGroup}`);
    return parts.join(' ');
  }

  generateMoviePath(m: { title: string; year?: number }, r: ParsedRelease, root?: string) {
    const base = root || this.rootPaths.movies;
    const folder = this.generateMovieFolderName(m);
    const file = this.generateMovieFileName(m, r);
    return { folder: `${base}/${folder}`, file, fullPath: `${base}/${folder}/${file}` };
  }

  generateEpisodePath(show: { title: string; year?: number }, ep: { season: number; episode: number; title?: string }, r: ParsedRelease, root?: string) {
    const base = root || this.rootPaths.tvShows;
    const seriesFolder = this.generateSeriesFolderName(show);
    const seasonFolder = this.generateSeasonFolderName(ep.season);
    const file = this.generateEpisodeFileName(show, ep, r);
    return { folder: `${base}/${seriesFolder}`, seasonFolder: `${base}/${seriesFolder}/${seasonFolder}`, file, fullPath: `${base}/${seriesFolder}/${seasonFolder}/${file}` };
  }

  addMovie(movie: Omit<Movie, 'id' | 'addedAt' | 'lastUpdated'>): Movie {
    const id = `movie-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const now = new Date();
    const m: Movie = { ...movie, id, addedAt: now, lastUpdated: now };
    this.movies.set(id, m);
    return m;
  }

  addTVShow(show: Omit<TVShow, 'id' | 'addedAt' | 'lastUpdated'>): TVShow {
    const id = `show-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const now = new Date();
    const s: TVShow = { ...show, id, addedAt: now, lastUpdated: now };
    this.tvShows.set(id, s);
    return s;
  }

  importFile(sourcePath: string, release: ParsedRelease, meta: { type: 'movie' | 'episode'; title: string; year?: number; season?: number; episode?: number; episodeTitle?: string; imdbId?: string; tmdbId?: number; tvdbId?: number }): { destPath: string; mediaItem: MediaItem } {
    let destPath: string;
    if (meta.type === 'movie') {
      destPath = this.generateMoviePath({ title: meta.title, year: meta.year }, release).fullPath;
    } else {
      destPath = this.generateEpisodePath({ title: meta.title }, { season: meta.season || 1, episode: meta.episode || 1, title: meta.episodeTitle }, release).fullPath;
    }
    const mediaItem: MediaItem = {
      id: `media-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      type: meta.type, title: meta.title, year: meta.year, season: meta.season, episode: meta.episode, episodeTitle: meta.episodeTitle,
      imdbId: meta.imdbId, tmdbId: meta.tmdbId, tvdbId: meta.tvdbId, filePath: destPath, fileSize: 0, addedAt: new Date(),
      quality: { resolution: release.resolution, source: release.source, codec: release.codec, hdr: release.hdrFormat, audioCodec: release.audioCodec, releaseGroup: release.releaseGroup, qualityScore: release.qualityScore },
      status: 'imported', monitorStatus: 'monitored',
    };
    this.mediaItems.set(mediaItem.id, mediaItem);
    return { destPath, mediaItem };
  }

  getMovie(id: string): Movie | undefined { return this.movies.get(id); }
  getMovieByImdbId(imdbId: string): Movie | undefined { for (const m of this.movies.values()) if (m.imdbId === imdbId) return m; return undefined; }
  getMovieByTmdbId(tmdbId: number): Movie | undefined { for (const m of this.movies.values()) if (m.tmdbId === tmdbId) return m; return undefined; }
  getAllMovies(): Movie[] { return Array.from(this.movies.values()); }
  getTVShow(id: string): TVShow | undefined { return this.tvShows.get(id); }
  getTVShowByTvdbId(tvdbId: number): TVShow | undefined { for (const s of this.tvShows.values()) if (s.tvdbId === tvdbId) return s; return undefined; }
  getAllTVShows(): TVShow[] { return Array.from(this.tvShows.values()); }

  getStats() {
    const movieStats = { total: this.movies.size, monitored: 0, downloaded: 0, missing: 0, sizeOnDisk: 0 };
    for (const m of this.movies.values()) {
      if (m.monitored) movieStats.monitored++;
      if (m.hasFile) { movieStats.downloaded++; if (m.mediaItem) movieStats.sizeOnDisk += m.mediaItem.fileSize; }
      else if (m.monitored) movieStats.missing++;
    }
    const tvStats = { total: this.tvShows.size, monitored: 0, episodesTotal: 0, episodesDownloaded: 0, episodesMissing: 0, sizeOnDisk: 0 };
    for (const show of this.tvShows.values()) {
      if (show.monitorStatus !== 'none') tvStats.monitored++;
      for (const season of show.seasons) {
        for (const ep of season.episodes) {
          tvStats.episodesTotal++;
          if (ep.hasFile) { tvStats.episodesDownloaded++; if (ep.mediaItem) tvStats.sizeOnDisk += ep.mediaItem.fileSize; }
          else if (ep.monitored) tvStats.episodesMissing++;
        }
      }
    }
    return { movies: movieStats, tvShows: tvStats };
  }

  getRootPaths() { return { ...this.rootPaths }; }
  setRootPaths(paths: Partial<typeof DEFAULT_ROOT_PATHS>): void { this.rootPaths = { ...this.rootPaths, ...paths }; }
}

export const mediaLibraryService = MediaLibraryService.getInstance();
