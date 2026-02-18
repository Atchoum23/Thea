/**
 * Unified Settings Component
 *
 * Central settings hub for all Thea-Tizen configurations:
 * - API Keys (TMDB)
 * - NordVPN (SmartDNS & Proxy)
 * - Trakt Integration
 * - Sync Bridge
 * - User Preferences
 */

import React, { useState, useEffect } from 'react';
import { secureConfigService, AppConfiguration } from '../../services/config/SecureConfigService';
import { NordVPNSettings } from './NordVPNSettings';
import { SMARTDNS_ACTIVATION_GUIDE } from '../../services/vpn/NordVPNProxyService';
import './UnifiedSettings.css';

type SettingsSection = 'overview' | 'tmdb' | 'nordvpn' | 'trakt' | 'sync' | 'preferences';

interface UnifiedSettingsProps {
  onClose?: () => void;
  initialSection?: SettingsSection;
}

export const UnifiedSettings: React.FC<UnifiedSettingsProps> = ({
  onClose,
  initialSection = 'overview',
}) => {
  const [activeSection, setActiveSection] = useState<SettingsSection>(initialSection);
  const [config, setConfig] = useState<AppConfiguration>(secureConfigService.get());
  const [testingTMDB, setTestingTMDB] = useState(false);
  const [tmdbStatus, setTmdbStatus] = useState<'untested' | 'success' | 'error'>('untested');
  const [tmdbError, setTmdbError] = useState<string | null>(null);

  // Form state
  const [tmdbApiKey, setTmdbApiKey] = useState(config.tmdb.apiKey);
  const [tmdbAccessToken, setTmdbAccessToken] = useState(config.tmdb.accessToken);
  const [syncBridgeUrl, setSyncBridgeUrl] = useState(config.syncBridge.url);

  useEffect(() => {
    const unsubscribe = secureConfigService.subscribe((newConfig) => {
      setConfig(newConfig);
    });
    return unsubscribe;
  }, []);

  const handleTestTMDB = async () => {
    setTestingTMDB(true);
    setTmdbStatus('untested');
    setTmdbError(null);

    const result = await secureConfigService.testTMDB();

    if (result.success) {
      setTmdbStatus('success');
    } else {
      setTmdbStatus('error');
      setTmdbError(result.error || 'Unknown error');
    }

    setTestingTMDB(false);
  };

  const handleSaveTMDB = () => {
    secureConfigService.setTMDB({
      apiKey: tmdbApiKey,
      accessToken: tmdbAccessToken,
    });
    setTmdbStatus('untested');
  };

  const handleSaveSyncBridge = () => {
    secureConfigService.setSyncBridge({
      url: syncBridgeUrl,
    });
  };

  const handleSyncToCloud = async () => {
    const success = await secureConfigService.syncToCloud();
    if (success) {
      alert('Settings synced to cloud successfully!');
    } else {
      alert('Failed to sync settings. Check your sync bridge configuration.');
    }
  };

  const handleSyncFromCloud = async () => {
    const success = await secureConfigService.syncFromCloud();
    if (success) {
      alert('Settings pulled from cloud successfully!');
    } else {
      alert('Failed to pull settings from cloud.');
    }
  };

  const renderNavigation = () => (
    <nav className="settings-nav">
      <button
        className={activeSection === 'overview' ? 'active' : ''}
        onClick={() => setActiveSection('overview')}
      >
        <span className="icon">🏠</span>
        Overview
      </button>
      <button
        className={activeSection === 'tmdb' ? 'active' : ''}
        onClick={() => setActiveSection('tmdb')}
      >
        <span className="icon">🎬</span>
        TMDB
      </button>
      <button
        className={activeSection === 'nordvpn' ? 'active' : ''}
        onClick={() => setActiveSection('nordvpn')}
      >
        <span className="icon">🔐</span>
        NordVPN
      </button>
      <button
        className={activeSection === 'trakt' ? 'active' : ''}
        onClick={() => setActiveSection('trakt')}
      >
        <span className="icon">📺</span>
        Trakt
      </button>
      <button
        className={activeSection === 'sync' ? 'active' : ''}
        onClick={() => setActiveSection('sync')}
      >
        <span className="icon">☁️</span>
        Sync
      </button>
      <button
        className={activeSection === 'preferences' ? 'active' : ''}
        onClick={() => setActiveSection('preferences')}
      >
        <span className="icon">⚙️</span>
        Preferences
      </button>
    </nav>
  );

  const renderOverview = () => (
    <div className="settings-section overview">
      <h2>Settings Overview</h2>

      <div className="status-grid">
        <div
          className={`status-card ${secureConfigService.isTMDBConfigured() ? 'configured' : 'not-configured'}`}
          onClick={() => setActiveSection('tmdb')}
        >
          <span className="status-icon">{secureConfigService.isTMDBConfigured() ? '✓' : '!'}</span>
          <div className="status-info">
            <h3>TMDB</h3>
            <p>{secureConfigService.isTMDBConfigured() ? 'Configured' : 'Not configured'}</p>
          </div>
        </div>

        <div
          className={`status-card ${secureConfigService.isNordVPNConfigured() ? 'configured' : 'not-configured'}`}
          onClick={() => setActiveSection('nordvpn')}
        >
          <span className="status-icon">{secureConfigService.isNordVPNConfigured() ? '✓' : '!'}</span>
          <div className="status-info">
            <h3>NordVPN</h3>
            <p>{secureConfigService.isNordVPNConfigured() ? 'Configured' : 'Not configured'}</p>
          </div>
        </div>

        <div
          className={`status-card ${secureConfigService.isSmartDNSEnabled() ? 'configured' : 'not-configured'}`}
          onClick={() => setActiveSection('nordvpn')}
        >
          <span className="status-icon">{secureConfigService.isSmartDNSEnabled() ? '✓' : '○'}</span>
          <div className="status-info">
            <h3>SmartDNS</h3>
            <p>{secureConfigService.isSmartDNSEnabled() ? 'Enabled' : 'Not enabled'}</p>
          </div>
        </div>

        <div
          className={`status-card ${secureConfigService.isTraktConfigured() ? 'configured' : 'not-configured'}`}
          onClick={() => setActiveSection('trakt')}
        >
          <span className="status-icon">{secureConfigService.isTraktConfigured() ? '✓' : '!'}</span>
          <div className="status-info">
            <h3>Trakt</h3>
            <p>{secureConfigService.isTraktConfigured() ? 'Connected' : 'Not connected'}</p>
          </div>
        </div>

        <div
          className={`status-card ${config.syncBridge.url ? 'configured' : 'not-configured'}`}
          onClick={() => setActiveSection('sync')}
        >
          <span className="status-icon">{config.syncBridge.url ? '✓' : '○'}</span>
          <div className="status-info">
            <h3>Cloud Sync</h3>
            <p>{config.syncBridge.url ? 'Configured' : 'Not configured'}</p>
          </div>
        </div>

        <div className="status-card configured" onClick={() => setActiveSection('preferences')}>
          <span className="status-icon">🌍</span>
          <div className="status-info">
            <h3>Region</h3>
            <p>{config.user.country}</p>
          </div>
        </div>
      </div>

      <div className="quick-actions">
        <h3>Quick Actions</h3>
        <div className="action-buttons">
          <button onClick={handleSyncToCloud} disabled={!config.syncBridge.url}>
            ☁️ Sync to Cloud
          </button>
          <button onClick={handleSyncFromCloud} disabled={!config.syncBridge.url}>
            ⬇️ Pull from Cloud
          </button>
          <button onClick={() => secureConfigService.reset()}>
            🔄 Reset to Defaults
          </button>
        </div>
      </div>
    </div>
  );

  const renderTMDBSection = () => (
    <div className="settings-section tmdb">
      <h2>🎬 TMDB Configuration</h2>
      <p className="section-description">
        The Movie Database (TMDB) provides streaming availability data.
        Get your API key at{' '}
        <a href="https://www.themoviedb.org/settings/api" target="_blank" rel="noopener noreferrer">
          themoviedb.org
        </a>
      </p>

      <div className="form-group">
        <label>API Key</label>
        <input
          type="password"
          value={tmdbApiKey}
          onChange={(e) => setTmdbApiKey(e.target.value)}
          placeholder="Enter your TMDB API key"
        />
      </div>

      <div className="form-group">
        <label>Access Token (Recommended)</label>
        <input
          type="password"
          value={tmdbAccessToken}
          onChange={(e) => setTmdbAccessToken(e.target.value)}
          placeholder="Enter your TMDB access token"
        />
        <span className="hint">Access token provides better rate limits</span>
      </div>

      <div className="form-actions">
        <button className="primary-btn" onClick={handleSaveTMDB}>
          Save TMDB Settings
        </button>
        <button
          className="secondary-btn"
          onClick={handleTestTMDB}
          disabled={testingTMDB}
        >
          {testingTMDB ? 'Testing...' : 'Test Connection'}
        </button>
      </div>

      {tmdbStatus === 'success' && (
        <div className="status-message success">✓ TMDB connection successful!</div>
      )}
      {tmdbStatus === 'error' && (
        <div className="status-message error">✗ {tmdbError}</div>
      )}
    </div>
  );

  const renderTraktSection = () => (
    <div className="settings-section trakt">
      <h2>📺 Trakt Integration</h2>
      <p className="section-description">
        Connect to Trakt.tv to track what you watch and sync your watchlist.
      </p>

      {secureConfigService.isTraktConfigured() ? (
        <div className="connected-status">
          <span className="status-icon">✓</span>
          <div>
            <strong>Connected to Trakt</strong>
            <p>Your watch history is being tracked</p>
          </div>
          <button className="secondary-btn">Disconnect</button>
        </div>
      ) : (
        <div className="not-connected">
          <p>Connect your Trakt account to:</p>
          <ul>
            <li>Track movies and shows you watch</li>
            <li>Sync your watchlist across devices</li>
            <li>Get personalized recommendations</li>
          </ul>
          <button className="primary-btn">Connect Trakt Account</button>
        </div>
      )}

      <div className="trakt-info">
        <h3>Client Credentials (for developers)</h3>
        <p className="hint">
          Create an app at{' '}
          <a href="https://trakt.tv/oauth/applications" target="_blank" rel="noopener noreferrer">
            trakt.tv/oauth/applications
          </a>
        </p>
        <div className="form-group">
          <label>Client ID</label>
          <input
            type="text"
            value={config.trakt.clientId}
            onChange={(e) => secureConfigService.setTrakt({ clientId: e.target.value })}
            placeholder="Your Trakt Client ID"
          />
        </div>
        <div className="form-group">
          <label>Client Secret</label>
          <input
            type="password"
            value={config.trakt.clientSecret}
            onChange={(e) => secureConfigService.setTrakt({ clientSecret: e.target.value })}
            placeholder="Your Trakt Client Secret"
          />
        </div>
      </div>
    </div>
  );

  const renderSyncSection = () => (
    <div className="settings-section sync">
      <h2>☁️ Cloud Sync</h2>
      <p className="section-description">
        Sync your settings across devices using the Thea Sync Bridge.
      </p>

      <div className="form-group">
        <label>Sync Bridge URL</label>
        <input
          type="url"
          value={syncBridgeUrl}
          onChange={(e) => setSyncBridgeUrl(e.target.value)}
          placeholder="https://thea-sync.your-worker.workers.dev"
        />
        <span className="hint">Your Cloudflare Worker URL</span>
      </div>

      <div className="form-group">
        <label>Device Token</label>
        <input
          type="text"
          value={config.syncBridge.deviceToken}
          readOnly
          placeholder="Auto-generated on first sync"
        />
        <span className="hint">Identifies this device for sync</span>
      </div>

      <div className="form-actions">
        <button className="primary-btn" onClick={handleSaveSyncBridge}>
          Save Sync Settings
        </button>
      </div>

      <div className="sync-actions">
        <h3>Sync Actions</h3>
        <div className="action-buttons">
          <button onClick={handleSyncToCloud} disabled={!syncBridgeUrl}>
            ☁️ Push to Cloud
          </button>
          <button onClick={handleSyncFromCloud} disabled={!syncBridgeUrl}>
            ⬇️ Pull from Cloud
          </button>
        </div>
        <p className="hint">
          Note: Sensitive credentials (API keys, passwords) are NOT synced to cloud.
          Only preferences and non-sensitive settings are shared across devices.
        </p>
      </div>
    </div>
  );

  const renderPreferencesSection = () => (
    <div className="settings-section preferences">
      <h2>⚙️ User Preferences</h2>

      <div className="form-group">
        <label>Country</label>
        <select
          value={config.user.country}
          onChange={(e) => secureConfigService.setUser({ country: e.target.value })}
        >
          <option value="US">United States</option>
          <option value="GB">United Kingdom</option>
          <option value="CA">Canada</option>
          <option value="AU">Australia</option>
          <option value="DE">Germany</option>
          <option value="FR">France</option>
          <option value="ES">Spain</option>
          <option value="IT">Italy</option>
          <option value="NL">Netherlands</option>
          <option value="SE">Sweden</option>
          <option value="JP">Japan</option>
          <option value="KR">South Korea</option>
        </select>
        <span className="hint">Used for streaming availability lookup</span>
      </div>

      <div className="form-group">
        <label>Preferred Quality</label>
        <select
          value={config.user.preferredQuality}
          onChange={(e) => secureConfigService.setUser({
            preferredQuality: e.target.value as '720p' | '1080p' | '4K'
          })}
        >
          <option value="720p">720p (HD)</option>
          <option value="1080p">1080p (Full HD)</option>
          <option value="4K">4K (Ultra HD)</option>
        </select>
      </div>

      <div className="form-group checkbox">
        <label>
          <input
            type="checkbox"
            checked={config.user.avoidAds}
            onChange={(e) => secureConfigService.setUser({ avoidAds: e.target.checked })}
          />
          Prefer ad-free options when available
        </label>
      </div>

      <div className="form-group">
        <label>Preferred Languages</label>
        <div className="language-chips">
          {['en', 'fr', 'de', 'es', 'it', 'ja', 'ko'].map((lang) => (
            <button
              key={lang}
              className={`chip ${config.user.preferredLanguages.includes(lang) ? 'selected' : ''}`}
              onClick={() => {
                const current = config.user.preferredLanguages;
                const updated = current.includes(lang)
                  ? current.filter(l => l !== lang)
                  : [...current, lang];
                secureConfigService.setUser({ preferredLanguages: updated });
              }}
            >
              {lang.toUpperCase()}
            </button>
          ))}
        </div>
      </div>
    </div>
  );

  return (
    <div className="unified-settings">
      <header className="settings-header">
        <h1>Settings</h1>
        {onClose && (
          <button className="close-btn" onClick={onClose}>
            ✕
          </button>
        )}
      </header>

      <div className="settings-layout">
        {renderNavigation()}

        <main className="settings-content">
          {activeSection === 'overview' && renderOverview()}
          {activeSection === 'tmdb' && renderTMDBSection()}
          {activeSection === 'nordvpn' && <NordVPNSettings onClose={() => setActiveSection('overview')} />}
          {activeSection === 'trakt' && renderTraktSection()}
          {activeSection === 'sync' && renderSyncSection()}
          {activeSection === 'preferences' && renderPreferencesSection()}
        </main>
      </div>
    </div>
  );
};

export default UnifiedSettings;
