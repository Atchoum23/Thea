/**
 * Media Library Service
 *
 * Manages media files with Plex-compatible naming and organization.
 * @see https://support.plex.tv/articles/naming-and-organizing-your-movie-media-files/
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

interface NamingConfig {
  movieFolder: string;
  movieFile: string;
  seriesFolder: string;
  seasonFolder: string;
  episodeFile: string;
  colonReplacement: string;
}

const DEFAULT_NAMING_CONFIG: NamingConfig = {
  movieFolder: '{Movie Title} ({Year})',
  movieFile: '{Movie Title} ({Year}) {Edition Tags}',
  seriesFolder: '{Series Title}',
  seasonFolder: 'Season {Season:00}',
  episodeFile: '{Series Title} - S{Season:00}E{Episode:00} - {Episode Title}',
  colonReplacement: ' - ',
};

const DEFAULT_ROOT_PATHS = { movies: '/media/movies', tvShows: '/media/tv', anime: '/media/anime' };

class MediaLibraryService {
  private static instance: MediaLibraryService;
  private movies: Map<string, Movie> = new Map();
  private tvShows: Map<string, TVShow> = new Map();
  private mediaItems: Map<string, MediaItem> = new Map();
  private namingConfig = DEFAULT_NAMING_CONFIG;
  private rootPaths = DEFAULT_ROOT_PATHS;

  private constructor() {}

  static getInstance(): MediaLibraryService {
    if (!MediaLibraryService.instance) MediaLibraryService.instance = new MediaLibraryService();
    return MediaLibraryService.instance;
  }

  generateMovieFolderName(movie: { title: string; year?: number }): string {
    let name = this.namingConfig.movieFolder.replace('{Movie Title}', movie.title).replace('{Year}', movie.year?.toString() || '');
    return name.replace(/:/g, this.namingConfig.colonReplacement).replace(/[<>"|?*\/\\]/g, '').trim();
  }

  generateMovieFileName(movie: { title: string; year?: number }, release: ParsedRelease, ext = 'mkv'): string {
    const quality = this.buildQualityTags(release);
    const edition = this.buildEditionTags(release);
    let name = this.namingConfig.movieFile.replace('{Movie Title}', movie.title).replace('{Year}', movie.year?.toString() || '').replace('{Quality Full}', quality).replace('{Edition Tags}', edition);
    return `${name.replace(/:/g, this.namingConfig.colonReplacement).replace(/[<>"|?*\/\\]/g, '').trim()}.${ext}`;
  }

  generateSeriesFolderName(show: { title: string; year?: number }): string {
    let name = this.namingConfig.seriesFolder.replace('{Series Title}', show.title);
    if (show.year) name = `${name} (${show.year})`;
    return name.replace(/:/g, this.namingConfig.colonReplacement).replace(/[<>"|?*\/\\]/g, '').trim();
  }

  generateSeasonFolderName(seasonNumber: number): string {
    return this.namingConfig.seasonFolder.replace('{Season:00}', seasonNumber.toString().padStart(2, '0'));
  }

  generateEpisodeFileName(show: { title: string }, episode: { season: number; episode: number; title?: string }, release: ParsedRelease, ext = 'mkv'): string {
    const quality = this.buildQualityTags(release);
    let name = this.namingConfig.episodeFile
      .replace('{Series Title}', show.title)
      .replace('{Season:00}', episode.season.toString().padStart(2, '0'))
      .replace('{Episode:00}', episode.episode.toString().padStart(2, '0'))
      .replace('{Episode Title}', episode.title || 'Episode')
      .replace('{Quality Full}', quality);
    return `${name.replace(/:/g, this.namingConfig.colonReplacement).replace(/[<>"|?*\/\\]/g, '').trim()}.${ext}`;
  }

  private buildQualityTags(release: ParsedRelease): string {
    const parts: string[] = [];
    if (release.resolution !== 'unknown') parts.push(release.resolution);
    if (release.source !== 'unknown') {
      const names: Record<string, string> = { bluray: 'Bluray', webdl: 'WEB-DL', webrip: 'WEBRip', hdtv: 'HDTV', dvd: 'DVD' };
      parts.push(names[release.source] || release.source);
    }
    if (release.hdrFormat !== 'sdr') {
      const names: Record<string, string> = { 'dv-hdr': 'DV HDR', dv: 'DV', hdr10plus: 'HDR10Plus', hdr10: 'HDR10', hdr: 'HDR', hlg: 'HLG' };
      parts.push(names[release.hdrFormat] || release.hdrFormat.toUpperCase());
    }
    if (release.codec !== 'unknown') parts.push(release.codec.toUpperCase());
    if (release.audioCodec !== 'unknown') {
      const names: Record<string, string> = { truehd: 'TrueHD', 'dts-hd-ma': 'DTS-HD.MA', 'dts-x': 'DTS-X', atmos: 'Atmos', dts: 'DTS', dd: 'DD', aac: 'AAC', flac: 'FLAC' };
      parts.push(names[release.audioCodec] || release.audioCodec.toUpperCase());
    }
    if (release.releaseGroup) parts.push(`-${release.releaseGroup}`);
    return parts.join(' ');
  }

  private buildEditionTags(release: ParsedRelease): string {
    const parts: string[] = [];
    if (release.isRemux) parts.push('REMUX');
    if (release.isProper) parts.push('PROPER');
    if (release.isRepack) parts.push('REPACK');
    if (release.is3D) parts.push('3D');
    return parts.length > 0 ? `{${parts.join(' ')}}` : '';
  }

  generateMoviePath(movie: { title: string; year?: number }, release: ParsedRelease, rootPath?: string) {
    const root = rootPath || this.rootPaths.movies;
    const folder = this.generateMovieFolderName(movie);
    const file = this.generateMovieFileName(movie, release);
    return { folder: `${root}/${folder}`, file, fullPath: `${root}/${folder}/${file}` };
  }

  generateEpisodePath(show: { title: string; year?: number }, episode: { season: number; episode: number; title?: string }, release: ParsedRelease, rootPath?: string) {
    const root = rootPath || this.rootPaths.tvShows;
    const seriesFolder = this.generateSeriesFolderName(show);
    const seasonFolder = this.generateSeasonFolderName(episode.season);
    const file = this.generateEpisodeFileName(show, episode, release);
    return { folder: `${root}/${seriesFolder}`, seasonFolder: `${root}/${seriesFolder}/${seasonFolder}`, file, fullPath: `${root}/${seriesFolder}/${seasonFolder}/${file}` };
  }

  addMovie(movie: Omit<Movie, 'id' | 'addedAt' | 'lastUpdated'>): Movie {
    const id = `movie-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const now = new Date();
    const newMovie: Movie = { ...movie, id, addedAt: now, lastUpdated: now };
    this.movies.set(id, newMovie);
    return newMovie;
  }

  addTVShow(show: Omit<TVShow, 'id' | 'addedAt' | 'lastUpdated'>): TVShow {
    const id = `show-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const now = new Date();
    const newShow: TVShow = { ...show, id, addedAt: now, lastUpdated: now };
    this.tvShows.set(id, newShow);
    return newShow;
  }

  importFile(sourcePath: string, release: ParsedRelease, metadata: { type: 'movie' | 'episode'; title: string; year?: number; season?: number; episode?: number; episodeTitle?: string; imdbId?: string; tmdbId?: number; tvdbId?: number }): { destPath: string; mediaItem: MediaItem } {
    let destPath: string;
    if (metadata.type === 'movie') {
      destPath = this.generateMoviePath({ title: metadata.title, year: metadata.year }, release).fullPath;
    } else {
      destPath = this.generateEpisodePath({ title: metadata.title }, { season: metadata.season || 1, episode: metadata.episode || 1, title: metadata.episodeTitle }, release).fullPath;
    }
    const mediaItem: MediaItem = {
      id: `media-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      type: metadata.type, title: metadata.title, year: metadata.year, season: metadata.season, episode: metadata.episode, episodeTitle: metadata.episodeTitle,
      imdbId: metadata.imdbId, tmdbId: metadata.tmdbId, tvdbId: metadata.tvdbId, filePath: destPath, fileSize: 0, addedAt: new Date(),
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
    let movieStats = { total: this.movies.size, monitored: 0, downloaded: 0, missing: 0, sizeOnDisk: 0 };
    for (const movie of this.movies.values()) {
      if (movie.monitored) movieStats.monitored++;
      if (movie.hasFile) { movieStats.downloaded++; if (movie.mediaItem) movieStats.sizeOnDisk += movie.mediaItem.fileSize; }
      else if (movie.monitored) movieStats.missing++;
    }
    let tvStats = { total: this.tvShows.size, monitored: 0, episodesTotal: 0, episodesDownloaded: 0, episodesMissing: 0, sizeOnDisk: 0 };
    for (const show of this.tvShows.values()) {
      if (show.monitorStatus !== 'none') tvStats.monitored++;
      for (const season of show.seasons) {
        for (const episode of season.episodes) {
          tvStats.episodesTotal++;
          if (episode.hasFile) { tvStats.episodesDownloaded++; if (episode.mediaItem) tvStats.sizeOnDisk += episode.mediaItem.fileSize; }
          else if (episode.monitored) tvStats.episodesMissing++;
        }
      }
    }
    return { movies: movieStats, tvShows: tvStats };
  }

  getRootPaths() { return { ...this.rootPaths }; }
  setRootPaths(paths: Partial<typeof DEFAULT_ROOT_PATHS>): void { this.rootPaths = { ...this.rootPaths, ...paths }; }
}

export const mediaLibraryService = MediaLibraryService.getInstance();
