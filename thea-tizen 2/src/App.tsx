/**
 * THEA - Tizen TV Application
 * Main application component with spatial navigation
 *
 * Features:
 * - AI Chat with streaming responses
 * - Trakt integration for watch tracking
 * - Smart Hub with new releases and deep-linking
 * - AI-powered voice torrent search
 * - iCloud sync via bridge service
 */

import { useEffect, useState } from 'react';
import { BrowserRouter, Routes, Route, useNavigate, useLocation } from 'react-router-dom';
import {
  init as initSpatialNavigation,
  useFocusable,
  FocusContext,
} from '@noriginmedia/norigin-spatial-navigation';
import { registerTVKeys } from './config/keycodes';
import { useTVBackHandler } from './hooks/useTVRemote';
import { ProviderRegistry } from './services/ai/ProviderRegistry';
import { useTraktStore } from './stores/traktStore';
import { tvSystemService } from './services/tv/TVSystemService';
import { smartHubService } from './services/hub/SmartHubService';
import { aiTorrentSearchService } from './services/search/AITorrentSearchService';
import { SYNC_BRIDGE_URL, TMDB_API_KEY } from './config/constants';

// Pages
import { HomePage } from './pages/HomePage';
import { ChatPage } from './pages/ChatPage';
import { TraktPage } from './pages/TraktPage';
import { SettingsPage } from './pages/SettingsPage';
import { SmartHubPage } from './pages/SmartHubPage';

// Initialize spatial navigation
initSpatialNavigation({
  debug: false,
  visualDebug: false,
  distanceCalculationMethod: 'center',
});

// Register TV remote keys
registerTVKeys();

/**
 * Navigation sidebar
 */
function Sidebar() {
  const navigate = useNavigate();
  const location = useLocation();
  const { ref, focusKey } = useFocusable({
    focusable: false,
    saveLastFocusedChild: true,
    trackChildren: true,
  });

  const navItems = [
    { path: '/', label: 'Home', icon: '🏠' },
    { path: '/hub', label: 'Hub', icon: '🎬' },
    { path: '/chat', label: 'Chat', icon: '💬' },
    { path: '/trakt', label: 'Trakt', icon: '📺' },
    { path: '/settings', label: 'Settings', icon: '⚙️' },
  ];

  return (
    <FocusContext.Provider value={focusKey}>
      <nav
        ref={ref}
        className="w-24 bg-gray-900 flex flex-col items-center py-8 gap-4"
      >
        {/* Logo */}
        <div className="text-3xl font-bold mb-8">
          <span className="text-purple-500">T</span>
        </div>

        {/* Nav items */}
        {navItems.map((item) => (
          <NavItem
            key={item.path}
            {...item}
            isActive={location.pathname === item.path}
            onClick={() => navigate(item.path)}
          />
        ))}
      </nav>
    </FocusContext.Provider>
  );
}

interface NavItemProps {
  path: string;
  label: string;
  icon: string;
  isActive: boolean;
  onClick: () => void;
}

function NavItem({ label, icon, isActive, onClick }: NavItemProps) {
  const { ref, focused } = useFocusable({
    onEnterPress: onClick,
  });

  return (
    <button
      ref={ref}
      onClick={onClick}
      className={`
        w-16 h-16 rounded-xl
        flex flex-col items-center justify-center gap-1
        transition-all duration-200
        ${isActive ? 'bg-blue-600' : 'bg-gray-800'}
        ${focused ? 'ring-2 ring-white scale-110' : ''}
      `}
      title={label}
    >
      <span className="text-2xl">{icon}</span>
      <span className="text-xs text-gray-300">{label}</span>
    </button>
  );
}

/**
 * Main app layout
 */
function AppLayout() {
  const navigate = useNavigate();
  const location = useLocation();
  const { ref, focusKey } = useFocusable({
    focusable: false,
    saveLastFocusedChild: true,
  });

  // Handle back navigation
  useTVBackHandler(() => {
    if (location.pathname !== '/') {
      navigate('/');
    }
  });

  return (
    <FocusContext.Provider value={focusKey}>
      <div ref={ref} className="flex h-screen bg-gray-950 text-white overflow-hidden">
        <Sidebar />
        <main className="flex-1 overflow-hidden">
          <Routes>
            <Route path="/" element={<HomePage />} />
            <Route path="/hub" element={<SmartHubPage />} />
            <Route path="/chat" element={<ChatPage />} />
            <Route path="/chat/:conversationId" element={<ChatPage />} />
            <Route path="/trakt" element={<TraktPage />} />
            <Route path="/settings" element={<SettingsPage />} />
          </Routes>
        </main>
      </div>
    </FocusContext.Provider>
  );
}

/**
 * App initialization
 */
function AppInitializer({ children }: { children: React.ReactNode }) {
  const [isInitialized, setIsInitialized] = useState(false);
  const initTrakt = useTraktStore((s) => s.initAuth);

  useEffect(() => {
    const initializeApp = async () => {
      // Load API keys from localStorage
      ProviderRegistry.loadFromStorage(localStorage);

      // Initialize Trakt if credentials are stored
      const traktClientId = localStorage.getItem('thea_trakt_client_id');
      const traktClientSecret = localStorage.getItem('thea_trakt_client_secret');
      const traktAccessToken = localStorage.getItem('thea_trakt_access_token');
      if (traktClientId && traktClientSecret) {
        initTrakt(traktClientId, traktClientSecret);
      }

      // Initialize TV System Service
      await tvSystemService.initialize();
      console.log('[THEA] TV System initialized:', tvSystemService.getAIContextSummary());

      // Configure Smart Hub Service
      smartHubService.configure({
        syncBridgeUrl: SYNC_BRIDGE_URL,
        traktAccessToken: traktAccessToken || '',
        traktClientId: traktClientId || '',
        tmdbApiKey: TMDB_API_KEY,
      });

      // Configure AI Torrent Search Service
      aiTorrentSearchService.configure({
        syncBridgeUrl: SYNC_BRIDGE_URL,
      });
      aiTorrentSearchService.loadPreferences();
      aiTorrentSearchService.loadSearchHistory();

      // Register device with sync bridge if not already done
      const deviceToken = localStorage.getItem('deviceToken');
      if (!deviceToken) {
        await registerDevice();
      }

      setIsInitialized(true);
    };

    initializeApp();
  }, [initTrakt]);

  if (!isInitialized) {
    return (
      <div className="h-screen flex items-center justify-center bg-gray-950">
        <div className="text-4xl text-white animate-pulse">
          <span className="text-purple-500">T</span>
          <span className="text-blue-500">H</span>
          <span className="text-cyan-500">E</span>
          <span className="text-green-500">A</span>
        </div>
      </div>
    );
  }

  return <>{children}</>;
}

/**
 * Register device with sync bridge
 */
async function registerDevice(): Promise<void> {
  try {
    const systemInfo = tvSystemService.getSystemInfo();
    const response = await fetch(`${SYNC_BRIDGE_URL}/auth/device`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        deviceId: systemInfo?.duid || `tizen-${Date.now()}`,
        deviceName: systemInfo?.model || 'Samsung TV',
        deviceType: 'tizen-tv',
      }),
    });

    if (response.ok) {
      const { deviceToken } = await response.json();
      localStorage.setItem('deviceToken', deviceToken);
      console.log('[THEA] Device registered with sync bridge');
    }
  } catch (error) {
    console.error('[THEA] Failed to register device:', error);
  }
}

/**
 * Main App component
 */
export default function App() {
  return (
    <BrowserRouter>
      <AppInitializer>
        <AppLayout />
      </AppInitializer>
    </BrowserRouter>
  );
}
