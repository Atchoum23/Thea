/**
 * Auto Download Settings Panel
 * Configure automatic episode downloading to Plex
 */

import { useState, useEffect } from 'react';
import { useFocusable, FocusContext } from '@noriginmedia/norigin-spatial-navigation';
import { FocusableButton, FocusableList } from '../ui/FocusableCard';
import {
  autoDownloadService,
  AutoDownloadConfig,
  AutoDownloadStats,
  PendingDownload,
} from '../../services/automation/AutoDownloadService';

interface AutoDownloadSettingsProps {
  onClose?: () => void;
}

export function AutoDownloadSettings({ onClose: _onClose }: AutoDownloadSettingsProps) {
  const { ref, focusKey } = useFocusable({
    focusable: false,
    saveLastFocusedChild: true,
  });

  const [config, setConfig] = useState<AutoDownloadConfig>(autoDownloadService.getConfig());
  const [stats, setStats] = useState<AutoDownloadStats>(autoDownloadService.getStats());
  const [pendingDownloads, setPendingDownloads] = useState<PendingDownload[]>([]);
  const [activeTab, setActiveTab] = useState<'settings' | 'queue' | 'history'>('settings');

  // Refresh stats periodically
  useEffect(() => {
    const refresh = () => {
      setStats(autoDownloadService.getStats());
      setPendingDownloads(autoDownloadService.getPendingDownloads());
    };

    refresh();
    const interval = setInterval(refresh, 5000);
    return () => clearInterval(interval);
  }, []);

  const updateConfig = (updates: Partial<AutoDownloadConfig>) => {
    autoDownloadService.updateConfig(updates);
    setConfig(autoDownloadService.getConfig());
  };

  const handleToggleService = () => {
    updateConfig({ enabled: !config.enabled });
  };

  const handleTriggerCheck = async () => {
    await autoDownloadService.triggerCheck();
    setStats(autoDownloadService.getStats());
    setPendingDownloads(autoDownloadService.getPendingDownloads());
  };

  return (
    <FocusContext.Provider value={focusKey}>
      <div ref={ref} className="flex flex-col h-full">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <div>
            <h2 className="text-2xl font-bold text-white">Auto-Download</h2>
            <p className="text-gray-400">
              Automatically download new episodes to Plex
            </p>
          </div>
          <div className="flex items-center gap-4">
            <StatusBadge isRunning={autoDownloadService.isRunning()} />
            <FocusableButton
              onClick={handleToggleService}
              variant={config.enabled ? 'danger' : 'primary'}
            >
              {config.enabled ? 'Disable' : 'Enable'}
            </FocusableButton>
          </div>
        </div>

        {/* Stats Bar */}
        <StatsBar stats={stats} onTriggerCheck={handleTriggerCheck} />

        {/* Tabs */}
        <div className="flex gap-2 mb-6 border-b border-gray-700 pb-2">
          <TabButton
            label="Settings"
            isActive={activeTab === 'settings'}
            onSelect={() => setActiveTab('settings')}
          />
          <TabButton
            label={`Queue (${pendingDownloads.filter(d => d.status === 'pending' || d.status === 'searching' || d.status === 'downloading').length})`}
            isActive={activeTab === 'queue'}
            onSelect={() => setActiveTab('queue')}
          />
          <TabButton
            label="History"
            isActive={activeTab === 'history'}
            onSelect={() => setActiveTab('history')}
          />
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto">
          {activeTab === 'settings' && (
            <SettingsPanel config={config} onUpdate={updateConfig} />
          )}
          {activeTab === 'queue' && (
            <QueuePanel
              downloads={pendingDownloads.filter(d =>
                ['pending', 'searching', 'downloading'].includes(d.status)
              )}
              onSkip={(id) => {
                autoDownloadService.skipDownload(id);
                setPendingDownloads(autoDownloadService.getPendingDownloads());
              }}
            />
          )}
          {activeTab === 'history' && (
            <HistoryPanel
              downloads={pendingDownloads.filter(d =>
                ['completed', 'failed', 'skipped'].includes(d.status)
              )}
              onRetry={async (id) => {
                await autoDownloadService.retryDownload(id);
                setPendingDownloads(autoDownloadService.getPendingDownloads());
              }}
            />
          )}
        </div>
      </div>
    </FocusContext.Provider>
  );
}

// Status Badge
function StatusBadge({ isRunning }: { isRunning: boolean }) {
  return (
    <div className={`
      flex items-center gap-2 px-3 py-1 rounded-full text-sm
      ${isRunning ? 'bg-green-900 text-green-300' : 'bg-gray-800 text-gray-400'}
    `}>
      <div className={`w-2 h-2 rounded-full ${isRunning ? 'bg-green-500 animate-pulse' : 'bg-gray-500'}`} />
      {isRunning ? 'Running' : 'Stopped'}
    </div>
  );
}

// Stats Bar
interface StatsBarProps {
  stats: AutoDownloadStats;
  onTriggerCheck: () => void;
}

function StatsBar({ stats, onTriggerCheck }: StatsBarProps) {
  return (
    <div className="bg-gray-800 rounded-xl p-4 mb-6 flex items-center justify-between">
      <div className="flex gap-8">
        <StatItem label="Downloaded" value={stats.totalDownloaded} color="text-green-400" />
        <StatItem label="Failed" value={stats.totalFailed} color="text-red-400" />
        <StatItem label="Skipped" value={stats.totalSkipped} color="text-gray-400" />
        <StatItem label="Pending" value={stats.pendingCount} color="text-blue-400" />
        <StatItem label="Active" value={stats.activeDownloads} color="text-yellow-400" />
      </div>
      <div className="flex items-center gap-4">
        {stats.nextCheck && (
          <span className="text-sm text-gray-400">
            Next check: {new Date(stats.nextCheck).toLocaleTimeString()}
          </span>
        )}
        <FocusableButton onClick={onTriggerCheck} variant="secondary" size="sm">
          Check Now
        </FocusableButton>
      </div>
    </div>
  );
}

function StatItem({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className="text-center">
      <div className={`text-2xl font-bold ${color}`}>{value}</div>
      <div className="text-xs text-gray-500">{label}</div>
    </div>
  );
}

// Tab Button
interface TabButtonProps {
  label: string;
  isActive: boolean;
  onSelect: () => void;
}

function TabButton({ label, isActive, onSelect }: TabButtonProps) {
  const { ref, focused } = useFocusable({
    onEnterPress: onSelect,
  });

  return (
    <button
      ref={ref}
      onClick={onSelect}
      className={`
        px-4 py-2 rounded-lg text-lg transition-all
        ${isActive ? 'bg-blue-600 text-white' : 'text-gray-400 hover:text-white'}
        ${focused ? 'ring-2 ring-white' : ''}
      `}
    >
      {label}
    </button>
  );
}

// Settings Panel
interface SettingsPanelProps {
  config: AutoDownloadConfig;
  onUpdate: (updates: Partial<AutoDownloadConfig>) => void;
}

function SettingsPanel({ config, onUpdate }: SettingsPanelProps) {
  return (
    <FocusableList direction="vertical" className="gap-4">
      {/* Check Interval */}
      <SettingRow
        label="Check Interval"
        description="How often to check for new episodes"
      >
        <NumberSelector
          value={config.checkIntervalMinutes}
          min={15}
          max={360}
          step={15}
          unit="min"
          onChange={(v) => onUpdate({ checkIntervalMinutes: v })}
        />
      </SettingRow>

      {/* Delay After Air */}
      <SettingRow
        label="Download Delay"
        description="Wait after air time for better releases"
      >
        <NumberSelector
          value={config.delayHoursAfterAir}
          min={0}
          max={24}
          step={1}
          unit="hours"
          onChange={(v) => onUpdate({ delayHoursAfterAir: v })}
        />
      </SettingRow>

      {/* Minimum Seeders */}
      <SettingRow
        label="Minimum Seeders"
        description="Only download torrents with enough seeders"
      >
        <NumberSelector
          value={config.minSeeders}
          min={1}
          max={50}
          step={1}
          unit=""
          onChange={(v) => onUpdate({ minSeeders: v })}
        />
      </SettingRow>

      {/* Max File Size */}
      <SettingRow
        label="Max File Size"
        description="Skip torrents larger than this (0 = no limit)"
      >
        <NumberSelector
          value={config.maxFileSizeGB}
          min={0}
          max={50}
          step={1}
          unit="GB"
          onChange={(v) => onUpdate({ maxFileSizeGB: v })}
        />
      </SettingRow>

      {/* Quality Preference */}
      <SettingRow
        label="Preferred Quality"
        description="Target video quality for downloads"
      >
        <QualitySelector
          value={config.qualityPreferences.preferredQuality}
          onChange={(v) => onUpdate({
            qualityPreferences: { ...config.qualityPreferences, preferredQuality: v }
          })}
        />
      </SettingRow>

      {/* Include Watchlist */}
      <SettingRow
        label="Include Watchlist"
        description="Also download shows from your Trakt watchlist"
      >
        <ToggleSwitch
          value={config.includeWatchlist}
          onChange={(v) => onUpdate({ includeWatchlist: v })}
        />
      </SettingRow>

      {/* Only In Progress */}
      <SettingRow
        label="Only Shows In Progress"
        description="Only download shows you're actively watching"
      >
        <ToggleSwitch
          value={config.onlyInProgress}
          onChange={(v) => onUpdate({ onlyInProgress: v })}
        />
      </SettingRow>

      {/* Auto Select */}
      <SettingRow
        label="Auto-Select Best"
        description="Automatically pick the best torrent without confirmation"
      >
        <ToggleSwitch
          value={config.autoSelectBest}
          onChange={(v) => onUpdate({ autoSelectBest: v })}
        />
      </SettingRow>

      {/* Notifications Section */}
      <div className="mt-6 pt-6 border-t border-gray-700">
        <h3 className="text-lg font-semibold text-white mb-4">Notifications</h3>

        <SettingRow label="New Episode Found" description="">
          <ToggleSwitch
            value={config.notifications.onNewEpisode}
            onChange={(v) => onUpdate({
              notifications: { ...config.notifications, onNewEpisode: v }
            })}
          />
        </SettingRow>

        <SettingRow label="Download Started" description="">
          <ToggleSwitch
            value={config.notifications.onDownloadStart}
            onChange={(v) => onUpdate({
              notifications: { ...config.notifications, onDownloadStart: v }
            })}
          />
        </SettingRow>

        <SettingRow label="Download Complete" description="">
          <ToggleSwitch
            value={config.notifications.onDownloadComplete}
            onChange={(v) => onUpdate({
              notifications: { ...config.notifications, onDownloadComplete: v }
            })}
          />
        </SettingRow>

        <SettingRow label="Errors" description="">
          <ToggleSwitch
            value={config.notifications.onError}
            onChange={(v) => onUpdate({
              notifications: { ...config.notifications, onError: v }
            })}
          />
        </SettingRow>
      </div>
    </FocusableList>
  );
}

// Queue Panel
interface QueuePanelProps {
  downloads: PendingDownload[];
  onSkip: (id: string) => void;
}

function QueuePanel({ downloads, onSkip }: QueuePanelProps) {
  if (downloads.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-48 text-gray-500">
        <span className="text-4xl mb-2">📭</span>
        <p>No pending downloads</p>
      </div>
    );
  }

  return (
    <FocusableList direction="vertical" className="gap-3">
      {downloads.map((download) => (
        <DownloadItem
          key={download.id}
          download={download}
          onSkip={() => onSkip(download.id)}
        />
      ))}
    </FocusableList>
  );
}

// History Panel
interface HistoryPanelProps {
  downloads: PendingDownload[];
  onRetry: (id: string) => void;
}

function HistoryPanel({ downloads, onRetry }: HistoryPanelProps) {
  if (downloads.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-48 text-gray-500">
        <span className="text-4xl mb-2">📋</span>
        <p>No download history</p>
      </div>
    );
  }

  // Sort by most recent first
  const sorted = [...downloads].sort((a, b) =>
    new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime()
  );

  return (
    <FocusableList direction="vertical" className="gap-3">
      {sorted.map((download) => (
        <DownloadItem
          key={download.id}
          download={download}
          onRetry={download.status === 'failed' ? () => onRetry(download.id) : undefined}
        />
      ))}
    </FocusableList>
  );
}

// Download Item
interface DownloadItemProps {
  download: PendingDownload;
  onSkip?: () => void;
  onRetry?: () => void;
}

function DownloadItem({ download, onSkip, onRetry }: DownloadItemProps) {
  const { ref, focused } = useFocusable();

  const statusColors: Record<string, string> = {
    pending: 'bg-blue-600',
    searching: 'bg-yellow-600',
    downloading: 'bg-purple-600',
    completed: 'bg-green-600',
    failed: 'bg-red-600',
    skipped: 'bg-gray-600',
  };

  return (
    <div
      ref={ref}
      className={`
        bg-gray-800 rounded-xl p-4 transition-all
        ${focused ? 'ring-2 ring-blue-500' : ''}
      `}
    >
      <div className="flex items-center justify-between">
        <div className="flex-1">
          <div className="flex items-center gap-3">
            <h4 className="text-lg font-medium text-white">
              {download.showTitle}
            </h4>
            <span className={`px-2 py-0.5 rounded text-xs ${statusColors[download.status]}`}>
              {download.status}
            </span>
          </div>
          <p className="text-gray-400">
            S{download.season}E{download.episode}: {download.episodeTitle}
          </p>
          <p className="text-sm text-gray-500 mt-1">
            Aired: {new Date(download.airDate).toLocaleDateString()}
            {download.status === 'pending' && (
              <> • Eligible: {new Date(download.eligibleAt).toLocaleTimeString()}</>
            )}
          </p>
          {download.error && (
            <p className="text-sm text-red-400 mt-1">{download.error}</p>
          )}
          {download.torrent && (
            <p className="text-sm text-gray-500 mt-1 truncate">
              {download.torrent.title}
            </p>
          )}
        </div>

        <div className="flex gap-2">
          {onSkip && (
            <FocusableButton onClick={onSkip} variant="secondary" size="sm">
              Skip
            </FocusableButton>
          )}
          {onRetry && (
            <FocusableButton onClick={onRetry} variant="primary" size="sm">
              Retry
            </FocusableButton>
          )}
        </div>
      </div>
    </div>
  );
}

// Setting Row
interface SettingRowProps {
  label: string;
  description: string;
  children: React.ReactNode;
}

function SettingRow({ label, description, children }: SettingRowProps) {
  return (
    <div className="flex items-center justify-between py-3 border-b border-gray-800">
      <div>
        <div className="text-lg text-white">{label}</div>
        {description && <div className="text-sm text-gray-500">{description}</div>}
      </div>
      {children}
    </div>
  );
}

// Number Selector
interface NumberSelectorProps {
  value: number;
  min: number;
  max: number;
  step: number;
  unit: string;
  onChange: (value: number) => void;
}

function NumberSelector({ value, min, max, step, unit, onChange }: NumberSelectorProps) {
  const { ref, focused } = useFocusable();

  const decrease = () => onChange(Math.max(min, value - step));
  const increase = () => onChange(Math.min(max, value + step));

  return (
    <div
      ref={ref}
      className={`flex items-center gap-2 ${focused ? 'ring-2 ring-blue-500 rounded-lg' : ''}`}
    >
      <button
        onClick={decrease}
        className="w-8 h-8 rounded bg-gray-700 text-white hover:bg-gray-600"
      >
        -
      </button>
      <span className="w-20 text-center text-lg text-white">
        {value} {unit}
      </span>
      <button
        onClick={increase}
        className="w-8 h-8 rounded bg-gray-700 text-white hover:bg-gray-600"
      >
        +
      </button>
    </div>
  );
}

// Quality Selector
interface QualitySelectorProps {
  value: '4K' | '1080p' | '720p' | 'any';
  onChange: (value: '4K' | '1080p' | '720p' | 'any') => void;
}

function QualityOptionButton({ opt, isSelected, onChange }: { opt: '4K' | '1080p' | '720p' | 'any'; isSelected: boolean; onChange: (v: '4K' | '1080p' | '720p' | 'any') => void }) {
  const { ref, focused } = useFocusable({
    onEnterPress: () => onChange(opt),
  });
  return (
    <button
      ref={ref}
      onClick={() => onChange(opt)}
      className={`
        px-4 py-2 text-sm transition-colors
        ${isSelected ? 'bg-blue-600 text-white' : 'bg-gray-700 text-gray-300'}
        ${focused ? 'ring-2 ring-white ring-inset' : ''}
      `}
    >
      {opt}
    </button>
  );
}

function QualitySelector({ value, onChange }: QualitySelectorProps) {
  const options: Array<'4K' | '1080p' | '720p' | 'any'> = ['4K', '1080p', '720p', 'any'];

  return (
    <div className="flex rounded-lg overflow-hidden">
      {options.map((opt) => (
        <QualityOptionButton key={opt} opt={opt} isSelected={value === opt} onChange={onChange} />
      ))}
    </div>
  );
}

// Toggle Switch
interface ToggleSwitchProps {
  value: boolean;
  onChange: (value: boolean) => void;
}

function ToggleSwitch({ value, onChange }: ToggleSwitchProps) {
  const { ref, focused } = useFocusable({
    onEnterPress: () => onChange(!value),
  });

  return (
    <button
      ref={ref}
      onClick={() => onChange(!value)}
      className={`
        relative w-14 h-8 rounded-full transition-colors
        ${value ? 'bg-blue-600' : 'bg-gray-700'}
        ${focused ? 'ring-2 ring-white' : ''}
      `}
    >
      <div
        className={`
          absolute top-1 w-6 h-6 bg-white rounded-full transition-transform
          ${value ? 'translate-x-7' : 'translate-x-1'}
        `}
      />
    </button>
  );
}
