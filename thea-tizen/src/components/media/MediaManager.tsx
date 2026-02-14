/**
 * Media Manager Component
 *
 * TV-optimized UI for managing native Sonarr/Radarr functionality.
 */

import React, { useState, useEffect } from 'react';
import { mediaAutomationService, AutomationStatus, ActivityItem } from '../../services/media/MediaAutomationService';
import { downloadQueueService, DownloadItem, QueueStats } from '../../services/download/DownloadQueueService';
import './MediaManager.css';

type TabId = 'overview' | 'queue' | 'wanted' | 'activity' | 'settings';

export const MediaManager: React.FC = () => {
  const [activeTab, setActiveTab] = useState<TabId>('overview');
  const [status, setStatus] = useState<AutomationStatus | null>(null);
  const [queue, setQueue] = useState<DownloadItem[]>([]);
  const [queueStats, setQueueStats] = useState<QueueStats | null>(null);

  useEffect(() => {
    const update = () => {
      setStatus(mediaAutomationService.getStatus());
      setQueue(downloadQueueService.getSortedQueue());
      setQueueStats(downloadQueueService.getStats());
    };
    update();
    const interval = setInterval(update, 2000);
    return () => clearInterval(interval);
  }, []);

  const tabs: { id: TabId; label: string; icon: string }[] = [
    { id: 'overview', label: 'Overview', icon: '📊' },
    { id: 'queue', label: 'Queue', icon: '⬇️' },
    { id: 'wanted', label: 'Wanted', icon: '🎯' },
    { id: 'activity', label: 'Activity', icon: '📋' },
    { id: 'settings', label: 'Settings', icon: '⚙️' },
  ];

  return (
    <div className="media-manager">
      <header className="mm-header">
        <h1>🎬 Media Manager</h1>
        <span className={`status-badge ${status?.started ? 'active' : ''}`}>
          {status?.started ? '● Active' : '○ Inactive'}
        </span>
      </header>

      <nav className="mm-tabs">
        {tabs.map(t => (
          <button key={t.id} className={`tab ${activeTab === t.id ? 'active' : ''}`} onClick={() => setActiveTab(t.id)}>
            <span className="icon">{t.icon}</span>
            <span>{t.label}</span>
          </button>
        ))}
      </nav>

      <main className="mm-content">
        {activeTab === 'overview' && status && <OverviewTab status={status} queueStats={queueStats} />}
        {activeTab === 'queue' && <QueueTab queue={queue} />}
        {activeTab === 'wanted' && <WantedTab count={status?.monitoring.wantedItems || 0} />}
        {activeTab === 'activity' && <ActivityTab activities={status?.recentActivity || []} />}
        {activeTab === 'settings' && <SettingsTab />}
      </main>

      <footer className="mm-footer">
        <span>🟢 Select</span>
        <span>🔴 Back</span>
        <span>🔵 Search</span>
      </footer>
    </div>
  );
};

const OverviewTab: React.FC<{ status: AutomationStatus; queueStats: QueueStats | null }> = ({ status, queueStats }) => (
  <div className="overview-tab">
    <div className="stats-grid">
      <StatCard icon="🎬" label="Movies" value={status.library.movies} sub={`${queueStats?.queue.downloading || 0} downloading`} />
      <StatCard icon="📺" label="TV Shows" value={status.library.tvShows} sub={`${status.library.episodes} episodes`} />
      <StatCard icon="💾" label="Library" value={formatBytes(status.library.sizeOnDisk)} sub="" />
      <StatCard icon="🔍" label="Wanted" value={status.monitoring.wantedItems} sub="items" />
    </div>

    {queueStats && (
      <div className="speed-section">
        <h3>Speed</h3>
        <div className="speeds">
          <span>⬇️ {formatSpeed(queueStats.speed.download)}</span>
          <span>⬆️ {formatSpeed(queueStats.speed.upload)}</span>
        </div>
      </div>
    )}

    <div className="indexer-section">
      <h3>Indexers</h3>
      <span>{status.monitoring.indexersHealthy} / {status.monitoring.indexersTotal} healthy</span>
      {status.monitoring.lastRssSync && <span className="last-sync">Last sync: {formatRelativeTime(status.monitoring.lastRssSync)}</span>}
    </div>

    {status.healthIssues.length > 0 && (
      <div className="health-issues">
        <h3>⚠️ Issues</h3>
        {status.healthIssues.map(i => <div key={i.id} className={`issue ${i.type}`}>{i.message}</div>)}
      </div>
    )}
  </div>
);

const StatCard: React.FC<{ icon: string; label: string; value: number | string; sub: string }> = ({ icon, label, value, sub }) => (
  <div className="stat-card">
    <span className="stat-icon">{icon}</span>
    <div className="stat-info">
      <span className="stat-value">{value}</span>
      <span className="stat-label">{label}</span>
      {sub && <span className="stat-sub">{sub}</span>}
    </div>
  </div>
);

const QueueTab: React.FC<{ queue: DownloadItem[] }> = ({ queue }) => (
  <div className="queue-tab">
    {queue.length === 0 ? (
      <div className="empty">📭 Queue is empty</div>
    ) : (
      <div className="queue-list">
        {queue.map(item => (
          <div key={item.id} className={`queue-item ${item.status}`}>
            <div className="qi-status">{item.status === 'downloading' ? '⬇️' : item.status === 'seeding' ? '⬆️' : item.status === 'completed' ? '✓' : item.status === 'failed' ? '✕' : '⏸️'}</div>
            <div className="qi-info">
              <span className="qi-title">{item.title}</span>
              <div className="qi-details">
                <span>{item.parsedRelease.resolution} {item.parsedRelease.source}</span>
                <span>{formatBytes(item.size)}</span>
                {item.seeders !== undefined && <span>👥 {item.seeders}</span>}
              </div>
              {item.status === 'downloading' && (
                <div className="qi-progress">
                  <div className="progress-bar"><div className="fill" style={{ width: `${item.progress}%` }} /></div>
                  <span>{item.progress.toFixed(1)}% • {formatSpeed(item.downloadSpeed)}{item.eta ? ` • ${formatETA(item.eta)}` : ''}</span>
                </div>
              )}
              {item.lastError && <span className="qi-error">{item.lastError}</span>}
            </div>
            <span className="qi-priority">P{item.priority}</span>
          </div>
        ))}
      </div>
    )}
  </div>
);

const WantedTab: React.FC<{ count: number }> = ({ count }) => (
  <div className="wanted-tab">
    <div className="wanted-header">
      <h2>Wanted Items</h2>
      <span>{count} total</span>
    </div>
    <div className="wanted-actions">
      <button>🔍 Search All</button>
      <button>➕ Add Movie</button>
      <button>📺 Add TV Show</button>
    </div>
    {count === 0 && <div className="empty">🎯 No wanted items. Add movies or TV shows to start tracking.</div>}
  </div>
);

const ActivityTab: React.FC<{ activities: ActivityItem[] }> = ({ activities }) => (
  <div className="activity-tab">
    <h2>Recent Activity</h2>
    {activities.length === 0 ? (
      <div className="empty">📋 No recent activity</div>
    ) : (
      <div className="activity-list">
        {activities.map(a => (
          <div key={a.id} className={`activity-item ${a.type}`}>
            <span className="ai-icon">{a.type === 'grabbed' ? '📥' : a.type === 'downloaded' ? '✅' : a.type === 'imported' ? '📁' : a.type === 'failed' ? '❌' : a.type === 'added' ? '➕' : '🔄'}</span>
            <div className="ai-info">
              <span className="ai-title">{a.title}</span>
              <span className="ai-message">{a.message}</span>
              {a.quality && <span className="ai-quality">{a.quality}</span>}
            </div>
            <span className="ai-time">{formatRelativeTime(a.timestamp)}</span>
          </div>
        ))}
      </div>
    )}
  </div>
);

const SettingsTab: React.FC = () => {
  const config = mediaAutomationService.getConfig();
  const [enabled, setEnabled] = useState(config.enabled);
  const [autoSearch, setAutoSearch] = useState(config.autoSearchOnAdd);
  const [autoGrab, setAutoGrab] = useState(config.autoGrabBestMatch);

  const save = () => mediaAutomationService.setConfig({ enabled, autoSearchOnAdd: autoSearch, autoGrabBestMatch: autoGrab });

  return (
    <div className="settings-tab">
      <h2>Settings</h2>
      <div className="settings-section">
        <h3>General</h3>
        <label><input type="checkbox" checked={enabled} onChange={e => { setEnabled(e.target.checked); save(); }} /> Enable Automation</label>
        <label><input type="checkbox" checked={autoSearch} onChange={e => { setAutoSearch(e.target.checked); save(); }} /> Auto Search on Add</label>
        <label><input type="checkbox" checked={autoGrab} onChange={e => { setAutoGrab(e.target.checked); save(); }} /> Auto Grab Best Match</label>
      </div>
      <div className="settings-section">
        <h3>Quality Profiles</h3>
        <p>Default Movie: TRaSH 4K (Samsung)</p>
        <p>Default TV: TRaSH 1080p</p>
      </div>
    </div>
  );
};

function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
}

function formatSpeed(bps: number): string {
  if (bps === 0) return '0 KB/s';
  if (bps < 1024) return `${bps} B/s`;
  if (bps < 1024 * 1024) return `${(bps / 1024).toFixed(1)} KB/s`;
  return `${(bps / (1024 * 1024)).toFixed(2)} MB/s`;
}

function formatETA(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ${Math.floor((seconds % 3600) / 60)}m`;
  return `${Math.floor(seconds / 86400)}d`;
}

function formatRelativeTime(date: Date): string {
  const diff = (Date.now() - date.getTime()) / 1000;
  if (diff < 60) return 'just now';
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
  return `${Math.floor(diff / 86400)}d ago`;
}

export default MediaManager;
