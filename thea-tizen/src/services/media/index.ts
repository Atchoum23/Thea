/**
 * Media Automation Services - Native Sonarr/Radarr Implementation
 *
 * This module provides native media automation for Thea:
 * - ReleaseParserService: Parse release names (quality, source, HDR, etc.)
 * - QualityProfileService: TRaSH Guides compatible quality profiles
 * - MediaLibraryService: Plex-compatible library management
 * - ReleaseMonitorService: RSS/search monitoring for releases
 * - DownloadQueueService: Intelligent download queue with qBittorrent
 * - MediaAutomationService: Orchestrator for all services
 */

export * from './ReleaseParserService';
export * from './QualityProfileService';
export * from './MediaLibraryService';
export * from './ReleaseMonitorService';
export * from './MediaAutomationService';
