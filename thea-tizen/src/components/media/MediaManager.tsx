/**
 * Media Manager Component
 *
 * Comprehensive UI for managing media automation:
 * - Library overview (movies, TV shows)
 * - Download queue with progress
 * - Wanted list
 * - Search results
 * - Activity log
 * - Health status
 *
 * Designed for Samsung TV with remote navigation.
 */

import React, { useState, useEffect, useCallback } from 'react';
import { useFocusable, FocusContext } from '@noriginmedia/norigin-spatial-navigation';
import { mediaAutomationService, AutomationStatus, ActivityItem } from '../../services/media/MediaAutomationService';
import { DownloadItem } from '../../services/download/DownloadQueueService';
import { SearchResult } from '../../services/media/ReleaseMonitorService';
import { ParsedRelease } from '../../services/media/ReleaseParserService';
import './MediaManager.css';

// ============================================================
// TYPES
// ============================================================

type TabId = 'overview' | 'queue' | 'wanted' | 'activity' | 'settings';

interface Tab {
  id: TabId;
  label: string;
  icon: string;
}

// ============================================================
// TABS
// ============================================================

const TABS: Tab[] = [
  { id: 'overview', label: 'Overview', icon: '📊' },
  { id: 'queue', label: 'Queue', icon: '⬇️' },
  { id: 'wanted', label: 'Wanted', icon: '🎯' },
  { id: 'activity', label: 'Activity', icon: '📋' },
  { id: 'settings', label: 'Settings', icon: '⚙️' },
];

// ============================================================
// MAIN COMPONENT
// ============================================================

export const MediaManager: React.FC = () => {
  const [activeTab, setActiveTab] = useState<TabId>('overview');
  const [status, setStatus] = useState<AutomationStatus | null>(null);
  const [queue, setQueue] = useState<DownloadItem[]>([]);
  const [searchResults, setSearchResults] = useState<SearchResult[]>([]);

  const { ref, focusKey } = useFocusable({
    focusable: true,
    saveLastFocusedChild: true,
  });

  // Refresh status periodically
  useEffect(() => {
    const updateStatus = () => {
      setStatus(mediaAutomationService.getStatus());
      setQueue(mediaAutomationService.getQueue());
    };

    updateStatus();
    const interval = setInterval(updateStatus, 2000);
    return () => clearInterval(interval);
  }, []);

  return (
    <FocusContext.Provider value={focusKey}>
      <div ref={ref} className="media-manager">
        <header className="media-manager-header">
          <h1>🎬 Media Manager</h1>
          <div className="status-indicator">
            {status?.started ? (
              <span className="status-active">● Active</span>
            ) : (
              <span className="status-inactive">○ Inactive</span>
            )}
          </div>
        </header>

        <nav className="media-manager-tabs">
          {TABS.map((tab) => (
            <TabButton
              key={tab.id}
              tab={tab}
              isActive={activeTab === tab.id}
              onSelect={() => setActiveTab(tab.id)}
            />
          ))}
        </nav>

        <main className="media-manager-content">
          {activeTab === 'overview' && status && (
            <OverviewTab status={status} />
          )}
          {activeTab === 'queue' && (
            <QueueTab queue={queue} />
          )}
          {activeTab === 'wanted' && status && (
            <WantedTab wantedCount={status.monitoring.wantedItems} />
          )}
          {activeTab === 'activity' && status && (
            <ActivityTab activities={status.recentActivity} />
          )}
          {activeTab === 'settings' && (
            <SettingsTab />
          )}
        </main>

        <footer className="media-manager-footer">
          <div className="footer-hint">
            <span className="key">🟢</span> Select
            <span className="key">🔴</span> Back
            <span className="key">🟡</span> Options
            <span className="key">🔵</span> Search
          </div>
        </footer>
      </div>
    </FocusContext.Provider>
  );
};

// ============================================================
// TAB BUTTON
// ============================================================

interface TabButtonProps {
  tab: Tab;
  isActive: boolean;
  onSelect: () => void;
}

const TabButton: React.FC<TabButtonProps> = ({ tab, isActive, onSelect }) => {
  const { ref, focused } = useFocusable({
    onEnterPress: onSelect,
  });

  return (
    <button
      ref={ref}
      className={`tab-button ${isActive ? 'active' : ''} ${focused ? 'focused' : ''}`}
      onClick={onSelect}
    >
      <span className="tab-icon">{tab.icon}</span>
      <span className="tab-label">{tab.label}</span>
    </button>
  );
};

// ============================================================
// OVERVIEW TAB
// ============================================================

interface OverviewTabProps {
  status: AutomationStatus;
}

const OverviewTab: React.FC<OverviewTabProps> = ({ status }) => {
  return (
    <div className="overview-tab">
      {/* Stats Cards */}
      <div className="stats-grid">
        <StatCard
          icon="🎬"
          label="Movies"
          value={status.library.movies}
          subValue={`${status.queue.queue.downloading} downloading`}
        />
        <StatCard
          icon="📺"
          label="TV Shows"
          value={status.library.tvShows}
          subValue={`${status.library.episodes} episodes`}
        />
        <StatCard
          icon="💾"
          label="Library Size"
          value={formatBytes(status.library.sizeOnDisk)}
          subValue=""
        />
        <StatCard
          icon="🔍"
          label="Wanted"
          value={status.monitoring.wantedItems}
          subValue="items"
        />
      </div>

      {/* Download Speed */}
      <div className="speed-section">
        <h3>Download Speed</h3>
        <div className="speed-display">
          <div className="speed-item">
            <span className="speed-icon">⬇️</span>
            <span className="speed-value">{formatSpeed(status.queue.speed.download)}</span>
          </div>
          <div className="speed-item">
            <span className="speed-icon">⬆️</span>
            <span className="speed-value">{formatSpeed(status.queue.speed.upload)}</span>
          </div>
        </div>
      </div>

      {/* Queue Summary */}
      <div className="queue-summary">
        <h3>Queue</h3>
        <div className="queue-stats">
          <div className="queue-stat">
            <span className="stat-label">Downloading</span>
            <span className="stat-value">{status.queue.queue.downloading}</span>
          </div>
          <div className="queue-stat">
            <span className="stat-label">Queued</span>
            <span className="stat-value">{status.queue.queue.queued}</span>
          </div>
          <div className="queue-stat">
            <span className="stat-label">Seeding</span>
            <span className="stat-value">{status.queue.queue.seeding}</span>
          </div>
          <div className="queue-stat">
            <span className="stat-label">Completed</span>
            <span className="stat-value">{status.queue.queue.completed}</span>
          </div>
        </div>
      </div>

      {/* Health Issues */}
      {status.healthIssues.length > 0 && (
        <div className="health-section">
          <h3>⚠️ Health Issues</h3>
          <div className="health-list">
            {status.healthIssues.map((issue) => (
              <div key={issue.id} className={`health-item ${issue.type}`}>
                <span className="health-icon">
                  {issue.type === 'error' ? '❌' : '⚠️'}
                </span>
                <span className="health-message">{issue.message}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Indexer Status */}
      <div className="indexer-section">
        <h3>Indexers</h3>
        <div className="indexer-status">
          <span className="indexer-count">
            {status.monitoring.indexersHealthy} / {status.monitoring.indexersTotal} healthy
          </span>
          {status.monitoring.lastRssSync && (
            <span className="last-sync">
              Last sync: {formatRelativeTime(status.monitoring.lastRssSync)}
            </span>
          )}
        </div>
      </div>
    </div>
  );
};

// ============================================================
// STAT CARD
// ============================================================

interface StatCardProps {
  icon: string;
  label: string;
  value: number | string;
  subValue: string;
}

const StatCard: React.FC<StatCardProps> = ({ icon, label, value, subValue }) => {
  const { ref, focused } = useFocusable();

  return (
    <div ref={ref} className={`stat-card ${focused ? 'focused' : ''}`}>
      <span className="stat-icon">{icon}</span>
      <div className="stat-content">
        <span className="stat-value">{value}</span>
        <span className="stat-label">{label}</span>
        {subValue && <span className="stat-sub">{subValue}</span>}
      </div>
    </div>
  );
};

// ============================================================
// QUEUE TAB
// ============================================================

interface QueueTabProps {
  queue: DownloadItem[];
}

const QueueTab: React.FC<QueueTabProps> = ({ queue }) => {
  if (queue.length === 0) {
    return (
      <div className="queue-tab empty">
        <span className="empty-icon">📭</span>
        <span className="empty-text">Queue is empty</span>
      </div>
    );
  }

  return (
    <div className="queue-tab">
      <div className="queue-list">
        {queue.map((item) => (
          <QueueItem key={item.id} item={item} />
        ))}
      </div>
    </div>
  );
};

interface QueueItemProps {
  item: DownloadItem;
}

const QueueItem: React.FC<QueueItemProps> = ({ item }) => {
  const { ref, focused } = useFocusable({
    onEnterPress: () => {
      // Show item details/options
    },
  });

  const statusColors: Record<string, string> = {
    downloading: '#4caf50',
    queued: '#ff9800',
    paused: '#9e9e9e',
    seeding: '#2196f3',
    completed: '#8bc34a',
    failed: '#f44336',
    warning: '#ffeb3b',
  };

  return (
    <div ref={ref} className={`queue-item ${focused ? 'focused' : ''}`}>
      <div className="queue-item-status" style={{ backgroundColor: statusColors[item.status] }}>
        {item.status === 'downloading' ? '⬇️' :
         item.status === 'seeding' ? '⬆️' :
         item.status === 'completed' ? '✓' :
         item.status === 'failed' ? '✕' : '⏸️'}
      </div>
      <div className="queue-item-info">
        <span className="queue-item-title">{item.title}</span>
        <div className="queue-item-details">
          <span className="quality">
            {item.parsedRelease.resolution} {item.parsedRelease.source}
          </span>
          <span className="size">{formatBytes(item.size)}</span>
          {item.seeders !== undefined && (
            <span className="seeders">👥 {item.seeders}</span>
          )}
        </div>
        {item.status === 'downloading' && (
          <div className="queue-item-progress">
            <div className="progress-bar">
              <div
                className="progress-fill"
                style={{ width: `${item.progress}%` }}
              />
            </div>
            <span className="progress-text">
              {item.progress.toFixed(1)}% • {formatSpeed(item.downloadSpeed)}
              {item.eta && ` • ${formatETA(item.eta)}`}
            </span>
          </div>
        )}
        {item.lastError && (
          <span className="queue-item-error">{item.lastError}</span>
        )}
      </div>
      <div className="queue-item-actions">
        <span className="priority">P{item.priority}</span>
      </div>
    </div>
  );
};

// ============================================================
// WANTED TAB
// ============================================================

interface WantedTabProps {
  wantedCount: number;
}

const WantedTab: React.FC<WantedTabProps> = ({ wantedCount }) => {
  const wantedItems = mediaAutomationService.getStatus()?.recentActivity
    .filter(a => a.type === 'added')
    .slice(0, 10) || [];

  return (
    <div className="wanted-tab">
      <div className="wanted-header">
        <h2>Wanted Items</h2>
        <span className="wanted-count">{wantedCount} total</span>
      </div>

      <div className="wanted-actions">
        <FocusableButton
          icon="🔍"
          label="Search All"
          onPress={() => {
            // Trigger search for all wanted items
          }}
        />
        <FocusableButton
          icon="➕"
          label="Add Movie"
          onPress={() => {
            // Open add movie dialog
          }}
        />
        <FocusableButton
          icon="📺"
          label="Add TV Show"
          onPress={() => {
            // Open add TV show dialog
          }}
        />
      </div>

      <div className="wanted-list">
        {wantedItems.length === 0 ? (
          <div className="empty-state">
            <span className="empty-icon">🎯</span>
            <span className="empty-text">No wanted items</span>
            <span className="empty-hint">Add movies or TV shows to start tracking</span>
          </div>
        ) : (
          wantedItems.map((item) => (
            <WantedItemCard key={item.id} item={item} />
          ))
        )}
      </div>
    </div>
  );
};

interface WantedItemCardProps {
  item: ActivityItem;
}

const WantedItemCard: React.FC<WantedItemCardProps> = ({ item }) => {
  const { ref, focused } = useFocusable();

  return (
    <div ref={ref} className={`wanted-item ${focused ? 'focused' : ''}`}>
      <span className="wanted-item-icon">
        {item.mediaType === 'movie' ? '🎬' : '📺'}
      </span>
      <div className="wanted-item-info">
        <span className="wanted-item-title">{item.title}</span>
        <span className="wanted-item-status">{item.message}</span>
      </div>
    </div>
  );
};

// ============================================================
// ACTIVITY TAB
// ============================================================

interface ActivityTabProps {
  activities: ActivityItem[];
}

const ActivityTab: React.FC<ActivityTabProps> = ({ activities }) => {
  return (
    <div className="activity-tab">
      <h2>Recent Activity</h2>

      <div className="activity-list">
        {activities.length === 0 ? (
          <div className="empty-state">
            <span className="empty-icon">📋</span>
            <span className="empty-text">No recent activity</span>
          </div>
        ) : (
          activities.map((activity) => (
            <ActivityItemCard key={activity.id} activity={activity} />
          ))
        )}
      </div>
    </div>
  );
};

interface ActivityItemCardProps {
  activity: ActivityItem;
}

const ActivityItemCard: React.FC<ActivityItemCardProps> = ({ activity }) => {
  const { ref, focused } = useFocusable();

  const typeIcons: Record<string, string> = {
    grabbed: '📥',
    downloaded: '✅',
    imported: '📁',
    upgraded: '⬆️',
    failed: '❌',
    added: '➕',
    removed: '🗑️',
  };

  const typeColors: Record<string, string> = {
    grabbed: '#2196f3',
    downloaded: '#4caf50',
    imported: '#8bc34a',
    upgraded: '#9c27b0',
    failed: '#f44336',
    added: '#ff9800',
    removed: '#9e9e9e',
  };

  return (
    <div ref={ref} className={`activity-item ${focused ? 'focused' : ''}`}>
      <div
        className="activity-icon"
        style={{ backgroundColor: typeColors[activity.type] }}
      >
        {typeIcons[activity.type]}
      </div>
      <div className="activity-info">
        <span className="activity-title">{activity.title}</span>
        <span className="activity-message">{activity.message}</span>
        {activity.quality && (
          <span className="activity-quality">{activity.quality}</span>
        )}
      </div>
      <span className="activity-time">
        {formatRelativeTime(activity.timestamp)}
      </span>
    </div>
  );
};

// ============================================================
// SETTINGS TAB
// ============================================================

const SettingsTab: React.FC = () => {
  const config = mediaAutomationService.getConfig();

  return (
    <div className="settings-tab">
      <h2>Settings</h2>

      <div className="settings-section">
        <h3>General</h3>
        <SettingToggle
          label="Enable Automation"
          value={config.enabled}
          onChange={(v) => mediaAutomationService.setConfig({ enabled: v })}
        />
        <SettingToggle
          label="Auto Search on Add"
          value={config.autoSearchOnAdd}
          onChange={(v) => mediaAutomationService.setConfig({ autoSearchOnAdd: v })}
        />
        <SettingToggle
          label="Auto Grab Best Match"
          value={config.autoGrabBestMatch}
          onChange={(v) => mediaAutomationService.setConfig({ autoGrabBestMatch: v })}
        />
      </div>

      <div className="settings-section">
        <h3>Quality Profiles</h3>
        <SettingSelect
          label="Default Movie Profile"
          value={config.defaultMovieProfileId}
          options={[
            { value: 'trash-4k-samsung', label: 'TRaSH 4K (Samsung)' },
            { value: 'trash-1080p', label: 'TRaSH 1080p' },
            { value: 'space-saver', label: 'Space Saver' },
          ]}
          onChange={(v) => mediaAutomationService.setConfig({ defaultMovieProfileId: v })}
        />
        <SettingSelect
          label="Default TV Profile"
          value={config.defaultTVProfileId}
          options={[
            { value: 'trash-1080p', label: 'TRaSH 1080p' },
            { value: 'trash-4k-samsung', label: 'TRaSH 4K (Samsung)' },
            { value: 'space-saver', label: 'Space Saver' },
          ]}
          onChange={(v) => mediaAutomationService.setConfig({ defaultTVProfileId: v })}
        />
      </div>

      <div className="settings-section">
        <h3>Notifications</h3>
        <SettingToggle
          label="Notify on Grab"
          value={config.notifyOnGrab}
          onChange={(v) => mediaAutomationService.setConfig({ notifyOnGrab: v })}
        />
        <SettingToggle
          label="Notify on Download"
          value={config.notifyOnDownload}
          onChange={(v) => mediaAutomationService.setConfig({ notifyOnDownload: v })}
        />
        <SettingToggle
          label="Notify on Health Issues"
          value={config.notifyOnHealth}
          onChange={(v) => mediaAutomationService.setConfig({ notifyOnHealth: v })}
        />
      </div>

      <div className="settings-section">
        <h3>Download</h3>
        <SettingToggle
          label="Prefer Torrents"
          value={config.preferTorrent}
          onChange={(v) => mediaAutomationService.setConfig({ preferTorrent: v })}
        />
      </div>
    </div>
  );
};

// ============================================================
// SETTING CONTROLS
// ============================================================

interface SettingToggleProps {
  label: string;
  value: boolean;
  onChange: (value: boolean) => void;
}

const SettingToggle: React.FC<SettingToggleProps> = ({ label, value, onChange }) => {
  const { ref, focused } = useFocusable({
    onEnterPress: () => onChange(!value),
  });

  return (
    <div ref={ref} className={`setting-item toggle ${focused ? 'focused' : ''}`}>
      <span className="setting-label">{label}</span>
      <div className={`toggle-switch ${value ? 'on' : 'off'}`}>
        <div className="toggle-knob" />
      </div>
    </div>
  );
};

interface SettingSelectProps {
  label: string;
  value: string;
  options: { value: string; label: string }[];
  onChange: (value: string) => void;
}

const SettingSelect: React.FC<SettingSelectProps> = ({ label, value, options, onChange }) => {
  const [expanded, setExpanded] = useState(false);
  const { ref, focused } = useFocusable({
    onEnterPress: () => setExpanded(!expanded),
  });

  const currentOption = options.find((o) => o.value === value);

  return (
    <div ref={ref} className={`setting-item select ${focused ? 'focused' : ''}`}>
      <span className="setting-label">{label}</span>
      <div className="select-value">
        {currentOption?.label || value}
        <span className="select-arrow">{expanded ? '▲' : '▼'}</span>
      </div>
      {expanded && (
        <div className="select-options">
          {options.map((option) => (
            <div
              key={option.value}
              className={`select-option ${option.value === value ? 'selected' : ''}`}
              onClick={() => {
                onChange(option.value);
                setExpanded(false);
              }}
            >
              {option.label}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

// ============================================================
// FOCUSABLE BUTTON
// ============================================================

interface FocusableButtonProps {
  icon: string;
  label: string;
  onPress: () => void;
  disabled?: boolean;
}

const FocusableButton: React.FC<FocusableButtonProps> = ({
  icon,
  label,
  onPress,
  disabled,
}) => {
  const { ref, focused } = useFocusable({
    onEnterPress: disabled ? undefined : onPress,
  });

  return (
    <button
      ref={ref}
      className={`focusable-button ${focused ? 'focused' : ''} ${disabled ? 'disabled' : ''}`}
      onClick={disabled ? undefined : onPress}
      disabled={disabled}
    >
      <span className="button-icon">{icon}</span>
      <span className="button-label">{label}</span>
    </button>
  );
};

// ============================================================
// UTILITY FUNCTIONS
// ============================================================

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
}

function formatSpeed(bytesPerSec: number): string {
  if (bytesPerSec === 0) return '0 KB/s';
  if (bytesPerSec < 1024) return `${bytesPerSec} B/s`;
  if (bytesPerSec < 1024 * 1024) return `${(bytesPerSec / 1024).toFixed(1)} KB/s`;
  return `${(bytesPerSec / (1024 * 1024)).toFixed(2)} MB/s`;
}

function formatETA(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ${Math.floor((seconds % 3600) / 60)}m`;
  return `${Math.floor(seconds / 86400)}d ${Math.floor((seconds % 86400) / 3600)}h`;
}

function formatRelativeTime(date: Date): string {
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffSec = Math.floor(diffMs / 1000);
  const diffMin = Math.floor(diffSec / 60);
  const diffHour = Math.floor(diffMin / 60);
  const diffDay = Math.floor(diffHour / 24);

  if (diffSec < 60) return 'just now';
  if (diffMin < 60) return `${diffMin}m ago`;
  if (diffHour < 24) return `${diffHour}h ago`;
  if (diffDay < 7) return `${diffDay}d ago`;

  return date.toLocaleDateString();
}

export default MediaManager;
