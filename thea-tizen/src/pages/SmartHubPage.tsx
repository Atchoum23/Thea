/**
 * Smart Hub Page
 * Shows new releases from Trakt calendar/watchlist/progress
 * Provides deep-linking to streaming apps and torrent search
 */

import { useState, useEffect } from 'react';
import { FocusContext, useFocusable } from '@noriginmedia/norigin-spatial-navigation';
import { FocusableButton, FocusableList } from '../components/ui/FocusableCard';
import { ColorButtonHints } from '../components/ui/ColorButtonHints';
import { useTVRemote } from '../hooks/useTVRemote';
import {
  smartHubService,
  SmartHubItem,
  TorrentSearchResult,
  TorrentStatus,
} from '../services/hub/SmartHubService';
import { tvSystemService } from '../services/tv/TVSystemService';

type TabType = 'new' | 'watchlist' | 'downloads';

export function SmartHubPage() {
  const { ref, focusKey } = useFocusable({
    focusable: false,
    saveLastFocusedChild: true,
  });

  const [activeTab, setActiveTab] = useState<TabType>('new');
  const [items, setItems] = useState<SmartHubItem[]>([]);
  const [downloads, setDownloads] = useState<TorrentStatus[]>([]);
  const [selectedItem, setSelectedItem] = useState<SmartHubItem | null>(null);
  const [torrents, setTorrents] = useState<TorrentSearchResult[]>([]);
  const [loading, setLoading] = useState(true);
  const [showTorrentModal, setShowTorrentModal] = useState(false);
  const [notification, setNotification] = useState<string | null>(null);

  // Load data on mount
  useEffect(() => {
    loadData();
    // Refresh downloads periodically
    const interval = setInterval(loadDownloads, 10000);
    return () => clearInterval(interval);
  }, []);

  const loadData = async () => {
    setLoading(true);
    try {
      const newReleases = await smartHubService.getNewReleases({
        days: 7,
        includeWatchlist: true,
        includeProgress: true,
      });
      setItems(newReleases);
    } catch (error) {
      console.error('Failed to load hub data:', error);
      showNotification('Failed to load new releases');
    }
    setLoading(false);
    await loadDownloads();
  };

  const loadDownloads = async () => {
    try {
      const status = await smartHubService.getDownloadStatus();
      setDownloads(status);
    } catch (error) {
      console.error('Failed to load downloads:', error);
    }
  };

  const showNotification = (message: string) => {
    setNotification(message);
    setTimeout(() => setNotification(null), 3000);
  };

  const handleItemSelect = async (item: SmartHubItem) => {
    setSelectedItem(item);

    if (item.needsTorrent) {
      // No streaming available - search for torrents
      setShowTorrentModal(true);
      const results = await smartHubService.searchTorrent(item);
      setTorrents(results);
    } else {
      // Try to launch in streaming app
      const success = await smartHubService.launchContent(item);
      if (!success) {
        showNotification('Failed to open content. Try searching for torrent.');
        setShowTorrentModal(true);
        const results = await smartHubService.searchTorrent(item);
        setTorrents(results);
      }
    }
  };

  const handleTorrentDownload = async (torrent: TorrentSearchResult) => {
    showNotification('Starting download...');
    const result = await smartHubService.downloadTorrent(torrent);
    showNotification(result.message);
    if (result.success) {
      setShowTorrentModal(false);
      setTorrents([]);
      await loadDownloads();
      setActiveTab('downloads');
    }
  };

  // Color button handlers
  useTVRemote({
    onRed: () => {
      if (showTorrentModal) {
        setShowTorrentModal(false);
        setTorrents([]);
      }
    },
    onGreen: () => {
      if (selectedItem && !showTorrentModal) {
        handleItemSelect(selectedItem);
      }
    },
    onYellow: () => {
      loadData();
    },
    onBlue: () => {
      // Voice search - handled elsewhere
    },
  });

  const filteredItems = items.filter(item => {
    if (activeTab === 'new') return item.isNewRelease || item.source === 'calendar';
    if (activeTab === 'watchlist') return item.source === 'watchlist';
    return false;
  });

  return (
    <FocusContext.Provider value={focusKey}>
      <div ref={ref} className="flex flex-col h-full bg-gray-950">
        {/* Header */}
        <div className="px-8 py-6 border-b border-gray-800">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold text-white">Smart Hub</h1>
              <p className="text-gray-400 text-lg mt-1">
                New releases from your watchlist and shows in progress
              </p>
            </div>
            <div className="flex items-center gap-4">
              <TVInfoBadge />
            </div>
          </div>

          {/* Tabs */}
          <div className="flex gap-4 mt-6">
            <TabButton
              label="New Releases"
              isActive={activeTab === 'new'}
              count={items.filter(i => i.isNewRelease || i.source === 'calendar').length}
              onSelect={() => setActiveTab('new')}
            />
            <TabButton
              label="Watchlist"
              isActive={activeTab === 'watchlist'}
              count={items.filter(i => i.source === 'watchlist').length}
              onSelect={() => setActiveTab('watchlist')}
            />
            <TabButton
              label="Downloads"
              isActive={activeTab === 'downloads'}
              count={downloads.filter(d => d.progress < 100).length}
              onSelect={() => setActiveTab('downloads')}
            />
          </div>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-8">
          {loading ? (
            <LoadingState />
          ) : activeTab === 'downloads' ? (
            <DownloadsList downloads={downloads} />
          ) : filteredItems.length === 0 ? (
            <EmptyState tab={activeTab} />
          ) : (
            <ContentGrid
              items={filteredItems}
              onSelect={handleItemSelect}
              onFocus={setSelectedItem}
            />
          )}
        </div>

        {/* Notification */}
        {notification && (
          <div className="fixed top-8 right-8 bg-blue-600 text-white px-6 py-3 rounded-lg shadow-lg text-xl">
            {notification}
          </div>
        )}

        {/* Torrent Modal */}
        {showTorrentModal && (
          <TorrentModal
            item={selectedItem}
            torrents={torrents}
            onSelect={handleTorrentDownload}
            onClose={() => {
              setShowTorrentModal(false);
              setTorrents([]);
            }}
          />
        )}

        {/* Color Button Hints */}
        <ColorButtonHints
          hints={[
            { color: 'red', label: showTorrentModal ? 'Close' : 'Back' },
            { color: 'green', label: 'Play' },
            { color: 'yellow', label: 'Refresh' },
            { color: 'blue', label: 'Voice Search' },
          ]}
        />
      </div>
    </FocusContext.Provider>
  );
}

// Tab Button Component
interface TabButtonProps {
  label: string;
  isActive: boolean;
  count: number;
  onSelect: () => void;
}

function TabButton({ label, isActive, count, onSelect }: TabButtonProps) {
  const { ref, focused } = useFocusable({
    onEnterPress: onSelect,
  });

  return (
    <button
      ref={ref}
      onClick={onSelect}
      className={`
        px-6 py-3 rounded-lg text-xl font-medium transition-all
        ${isActive ? 'bg-blue-600 text-white' : 'bg-gray-800 text-gray-300'}
        ${focused ? 'ring-2 ring-white scale-105' : ''}
      `}
    >
      {label}
      {count > 0 && (
        <span className={`ml-2 px-2 py-0.5 rounded-full text-sm ${isActive ? 'bg-blue-500' : 'bg-gray-700'}`}>
          {count}
        </span>
      )}
    </button>
  );
}

// TV Info Badge
function TVInfoBadge() {
  const [info, setInfo] = useState<string>('');

  useEffect(() => {
    const sysInfo = tvSystemService.getSystemInfo();
    if (sysInfo) {
      setInfo(`${sysInfo.model} • ${sysInfo.networkState}`);
    }
  }, []);

  return (
    <div className="bg-gray-800 px-4 py-2 rounded-lg text-gray-400 text-sm">
      {info || 'Samsung TV'}
    </div>
  );
}

// Content Grid
interface ContentGridProps {
  items: SmartHubItem[];
  onSelect: (item: SmartHubItem) => void;
  onFocus: (item: SmartHubItem) => void;
}

function ContentGrid({ items, onSelect, onFocus }: ContentGridProps) {
  return (
    <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-6">
      {items.map((item) => (
        <ContentCard
          key={item.id}
          item={item}
          onSelect={() => onSelect(item)}
          onFocus={() => onFocus(item)}
        />
      ))}
    </div>
  );
}

// Content Card
interface ContentCardProps {
  item: SmartHubItem;
  onSelect: () => void;
  onFocus: () => void;
}

function ContentCard({ item, onSelect, onFocus }: ContentCardProps) {
  const { ref, focused } = useFocusable({
    onEnterPress: onSelect,
    onFocus: onFocus,
  });

  return (
    <div
      ref={ref}
      className={`
        relative rounded-xl overflow-hidden cursor-pointer
        transition-all duration-200
        ${focused ? 'scale-105 ring-4 ring-blue-500 shadow-xl shadow-blue-500/20' : ''}
      `}
    >
      {/* Poster */}
      <div className="aspect-[2/3] bg-gray-800">
        {item.posterUrl ? (
          <img
            src={item.posterUrl}
            alt={item.title}
            className="w-full h-full object-cover"
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-gray-600">
            <span className="text-4xl">{item.type === 'movie' ? '🎬' : '📺'}</span>
          </div>
        )}
      </div>

      {/* Badges */}
      <div className="absolute top-2 left-2 flex gap-2">
        {item.isNewRelease && (
          <span className="bg-red-600 text-white px-2 py-1 rounded text-sm font-medium">
            NEW
          </span>
        )}
        {item.needsTorrent && (
          <span className="bg-yellow-600 text-white px-2 py-1 rounded text-sm font-medium">
            TORRENT
          </span>
        )}
      </div>

      {/* Info overlay */}
      <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/90 to-transparent p-4">
        <h3 className="text-lg font-semibold text-white truncate">{item.title}</h3>
        {item.subtitle && (
          <p className="text-sm text-gray-300 truncate">{item.subtitle}</p>
        )}
        {item.preferredApp && (
          <p className="text-xs text-blue-400 mt-1">
            Watch on {item.preferredApp.appName}
          </p>
        )}
      </div>
    </div>
  );
}

// Downloads List
interface DownloadsListProps {
  downloads: TorrentStatus[];
}

function DownloadsList({ downloads }: DownloadsListProps) {
  if (downloads.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-64 text-gray-500">
        <span className="text-6xl mb-4">📥</span>
        <p className="text-xl">No active downloads</p>
      </div>
    );
  }

  return (
    <FocusableList direction="vertical" className="gap-4">
      {downloads.map((download) => (
        <DownloadItem key={download.id} download={download} />
      ))}
    </FocusableList>
  );
}

// Download Item
interface DownloadItemProps {
  download: TorrentStatus;
}

function DownloadItem({ download }: DownloadItemProps) {
  const { ref, focused } = useFocusable();

  return (
    <div
      ref={ref}
      className={`
        bg-gray-800 rounded-xl p-6 transition-all
        ${focused ? 'ring-2 ring-blue-500' : ''}
      `}
    >
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-xl font-medium text-white truncate flex-1 mr-4">
          {download.name}
        </h3>
        <span className={`
          px-3 py-1 rounded-full text-sm font-medium
          ${download.status === 'downloading' ? 'bg-blue-600 text-white' :
            download.status === 'seeding' ? 'bg-green-600 text-white' :
            'bg-gray-700 text-gray-300'}
        `}>
          {download.status}
        </span>
      </div>

      {/* Progress bar */}
      <div className="relative h-3 bg-gray-700 rounded-full overflow-hidden mb-3">
        <div
          className="absolute left-0 top-0 h-full bg-blue-500 transition-all"
          style={{ width: `${download.progress}%` }}
        />
      </div>

      <div className="flex justify-between text-gray-400 text-sm">
        <span>{download.progress}% • {download.size}</span>
        <span>{download.speed}</span>
        {download.eta && <span>ETA: {download.eta}</span>}
      </div>
    </div>
  );
}

// Torrent Modal
interface TorrentModalProps {
  item: SmartHubItem | null;
  torrents: TorrentSearchResult[];
  onSelect: (torrent: TorrentSearchResult) => void;
  onClose: () => void;
}

function TorrentModal({ item, torrents, onSelect, onClose }: TorrentModalProps) {
  const { ref, focusKey } = useFocusable({
    focusable: false,
    isFocusBoundary: true,
  });

  useEffect(() => {
    setFocus('torrent-modal');
  }, []);

  return (
    <FocusContext.Provider value={focusKey}>
      <div className="fixed inset-0 bg-black/80 flex items-center justify-center p-8 z-50">
        <div
          ref={ref}
          className="bg-gray-900 rounded-2xl max-w-4xl w-full max-h-[80vh] overflow-hidden"
        >
          {/* Header */}
          <div className="p-6 border-b border-gray-800">
            <h2 className="text-2xl font-bold text-white">
              {item ? `Download: ${item.title}` : 'Torrent Search'}
            </h2>
            {item?.subtitle && (
              <p className="text-gray-400 text-lg">{item.subtitle}</p>
            )}
          </div>

          {/* Torrent list */}
          <div className="p-6 overflow-y-auto max-h-[60vh]">
            {torrents.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-12 text-gray-500">
                <span className="text-4xl mb-4">🔍</span>
                <p className="text-xl">Searching for torrents...</p>
              </div>
            ) : (
              <FocusableList direction="vertical" focusKey="torrent-modal" className="gap-3">
                {torrents.map((torrent, index) => (
                  <TorrentItem
                    key={torrent.id || index}
                    torrent={torrent}
                    onSelect={() => onSelect(torrent)}
                  />
                ))}
              </FocusableList>
            )}
          </div>

          {/* Footer */}
          <div className="p-6 border-t border-gray-800 flex justify-end">
            <FocusableButton onClick={onClose} variant="secondary">
              Cancel
            </FocusableButton>
          </div>
        </div>
      </div>
    </FocusContext.Provider>
  );
}

// Torrent Item
interface TorrentItemProps {
  torrent: TorrentSearchResult;
  onSelect: () => void;
}

function TorrentItem({ torrent, onSelect }: TorrentItemProps) {
  const { ref, focused } = useFocusable({
    onEnterPress: onSelect,
  });

  return (
    <div
      ref={ref}
      onClick={onSelect}
      className={`
        bg-gray-800 rounded-lg p-4 cursor-pointer transition-all
        ${focused ? 'ring-2 ring-blue-500 scale-[1.02]' : ''}
      `}
    >
      <div className="flex items-center justify-between">
        <div className="flex-1 min-w-0">
          <h4 className="text-lg text-white truncate">{torrent.title}</h4>
          <p className="text-sm text-gray-400 mt-1">
            {torrent.indexer} • {torrent.sizeFormatted}
          </p>
        </div>
        <div className="flex items-center gap-4 ml-4">
          <div className="text-center">
            <div className="text-green-500 font-bold">{torrent.seeders}</div>
            <div className="text-xs text-gray-500">Seeds</div>
          </div>
          <div className="text-center">
            <div className="text-red-500 font-bold">{torrent.leechers}</div>
            <div className="text-xs text-gray-500">Leech</div>
          </div>
        </div>
      </div>
    </div>
  );
}

// Loading State
function LoadingState() {
  return (
    <div className="flex flex-col items-center justify-center h-64">
      <div className="animate-spin rounded-full h-12 w-12 border-4 border-blue-500 border-t-transparent mb-4" />
      <p className="text-gray-400 text-xl">Loading new releases...</p>
    </div>
  );
}

// Empty State
function EmptyState({ tab }: { tab: TabType }) {
  return (
    <div className="flex flex-col items-center justify-center h-64 text-gray-500">
      <span className="text-6xl mb-4">{tab === 'new' ? '📅' : '📋'}</span>
      <p className="text-xl">
        {tab === 'new'
          ? 'No new releases this week'
          : 'Your watchlist is empty'}
      </p>
      <p className="text-lg mt-2">
        {tab === 'new'
          ? 'Check back later for new episodes and movies'
          : 'Add shows and movies on Trakt to see them here'}
      </p>
    </div>
  );
}
