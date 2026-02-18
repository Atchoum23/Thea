/**
 * NordVPN Settings Component
 *
 * Provides UI for:
 * 1. NordVPN account setup (access token or manual credentials)
 * 2. SmartDNS configuration wizard
 * 3. SOCKS5 proxy selection for downloads
 * 4. Connection testing
 */

import React, { useState, useEffect } from 'react';
import { nordVPNProxyService, ProxyServer, SmartDNSConfig } from '../../services/vpn/NordVPNProxyService';
import './NordVPNSettings.css';

interface NordVPNSettingsProps {
  onClose?: () => void;
}

type SetupStep = 'welcome' | 'auth' | 'smartdns' | 'proxy' | 'complete';

export const NordVPNSettings: React.FC<NordVPNSettingsProps> = ({ onClose }) => {
  const [currentStep, setCurrentStep] = useState<SetupStep>('welcome');
  const [isConfigured, setIsConfigured] = useState(false);
  const [smartDNSEnabled, setSmartDNSEnabled] = useState(false);
  const [selectedServer, setSelectedServer] = useState<ProxyServer | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Auth form state
  const [authMethod, setAuthMethod] = useState<'token' | 'manual'>('token');
  const [accessToken, setAccessToken] = useState('');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  // SmartDNS state
  const [smartDNSConfig, setSmartDNSConfig] = useState<SmartDNSConfig | null>(null);
  const [smartDNSStep, setSmartDNSStep] = useState(0);

  // Proxy state
  const [proxyServers, setProxyServers] = useState<ProxyServer[]>([]);
  const [selectedCountry, setSelectedCountry] = useState<string>('us');

  useEffect(() => {
    loadCurrentConfig();
  }, []);

  const loadCurrentConfig = () => {
    setIsConfigured(nordVPNProxyService.isConfigured());
    setSmartDNSEnabled(nordVPNProxyService.isSmartDNSEnabled());
    setSelectedServer(nordVPNProxyService.getSelectedServer());
    setSmartDNSConfig(nordVPNProxyService.getSmartDNSConfig());
    setProxyServers(nordVPNProxyService.getProxyServers());

    if (nordVPNProxyService.isConfigured()) {
      setCurrentStep('complete');
    }
  };

  const handleTokenAuth = async () => {
    if (!accessToken.trim()) {
      setError('Please enter your access token');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const credentials = await nordVPNProxyService.fetchCredentialsWithToken(accessToken.trim());
      if (credentials) {
        setIsConfigured(true);
        setCurrentStep('smartdns');
      } else {
        setError('Failed to fetch credentials. Please check your token.');
      }
    } catch (err) {
      setError('Authentication failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleManualAuth = () => {
    if (!username.trim() || !password.trim()) {
      setError('Please enter both username and password');
      return;
    }

    nordVPNProxyService.setCredentials({
      username: username.trim(),
      password: password.trim(),
    });

    setIsConfigured(true);
    setCurrentStep('smartdns');
  };

  const handleSmartDNSComplete = () => {
    nordVPNProxyService.setSmartDNSEnabled(true);
    setSmartDNSEnabled(true);
    setCurrentStep('proxy');
  };

  const handleSkipSmartDNS = () => {
    setCurrentStep('proxy');
  };

  const handleSelectProxy = (server: ProxyServer) => {
    nordVPNProxyService.selectServer(server);
    setSelectedServer(server);
  };

  const handleComplete = () => {
    setCurrentStep('complete');
    onClose?.();
  };

  const filteredServers = proxyServers.filter(s =>
    s.countryCode === selectedCountry
  );

  const countries = nordVPNProxyService.getAvailableCountries();

  // Render functions for each step
  const renderWelcome = () => (
    <div className="nordvpn-welcome">
      <div className="welcome-icon">🔐</div>
      <h2>NordVPN Setup</h2>
      <p>
        Set up NordVPN to unlock geo-restricted content and secure your downloads.
      </p>

      <div className="features-list">
        <div className="feature">
          <span className="icon">🌍</span>
          <div>
            <strong>SmartDNS</strong>
            <p>Watch Netflix US, BBC iPlayer, and more on your TV</p>
          </div>
        </div>
        <div className="feature">
          <span className="icon">⬇️</span>
          <div>
            <strong>Secure Downloads</strong>
            <p>Route torrents through NordVPN proxy servers</p>
          </div>
        </div>
        <div className="feature">
          <span className="icon">🔒</span>
          <div>
            <strong>Privacy</strong>
            <p>Hide your IP address when downloading content</p>
          </div>
        </div>
      </div>

      <button className="primary-btn" onClick={() => setCurrentStep('auth')}>
        Get Started
      </button>
    </div>
  );

  const renderAuth = () => (
    <div className="nordvpn-auth">
      <h2>Connect Your NordVPN Account</h2>

      <div className="auth-tabs">
        <button
          className={authMethod === 'token' ? 'active' : ''}
          onClick={() => setAuthMethod('token')}
        >
          Access Token (Recommended)
        </button>
        <button
          className={authMethod === 'manual' ? 'active' : ''}
          onClick={() => setAuthMethod('manual')}
        >
          Manual Credentials
        </button>
      </div>

      {authMethod === 'token' ? (
        <div className="auth-form">
          <p className="instructions">
            1. Go to{' '}
            <a
              href="https://my.nordaccount.com/dashboard/nordvpn/manual-configuration"
              target="_blank"
              rel="noopener noreferrer"
            >
              my.nordaccount.com
            </a>
            <br />
            2. Click "Generate Access Token"
            <br />
            3. Copy and paste the token below
          </p>

          <input
            type="password"
            placeholder="Enter your NordVPN access token"
            value={accessToken}
            onChange={(e) => setAccessToken(e.target.value)}
            className="token-input"
          />

          <button
            className="primary-btn"
            onClick={handleTokenAuth}
            disabled={loading}
          >
            {loading ? 'Authenticating...' : 'Connect Account'}
          </button>
        </div>
      ) : (
        <div className="auth-form">
          <p className="instructions">
            Enter your NordVPN service credentials (not your login email).
            <br />
            Find them at{' '}
            <a
              href="https://my.nordaccount.com/dashboard/nordvpn/manual-configuration"
              target="_blank"
              rel="noopener noreferrer"
            >
              my.nordaccount.com
            </a>
          </p>

          <input
            type="text"
            placeholder="Service username"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            className="credential-input"
          />

          <input
            type="password"
            placeholder="Service password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="credential-input"
          />

          <button className="primary-btn" onClick={handleManualAuth}>
            Save Credentials
          </button>
        </div>
      )}

      {error && <div className="error-message">{error}</div>}

      <button className="back-btn" onClick={() => setCurrentStep('welcome')}>
        ← Back
      </button>
    </div>
  );

  const renderSmartDNS = () => {
    if (!smartDNSConfig) return null;

    const steps = smartDNSConfig.setupInstructions;

    return (
      <div className="nordvpn-smartdns">
        <h2>Set Up SmartDNS</h2>
        <p>
          SmartDNS lets you access geo-restricted streaming apps like Netflix US,
          BBC iPlayer, and more - directly on your Samsung TV.
        </p>

        <div className="dns-info">
          <div className="dns-box">
            <label>Primary DNS</label>
            <code>{smartDNSConfig.primary}</code>
          </div>
          <div className="dns-box">
            <label>Secondary DNS</label>
            <code>{smartDNSConfig.secondary}</code>
          </div>
        </div>

        <div className="setup-steps">
          <h3>Setup Instructions</h3>
          <ol>
            {steps.map((step, index) => (
              <li
                key={index}
                className={smartDNSStep > index ? 'completed' : smartDNSStep === index ? 'current' : ''}
              >
                {step.replace(/^\d+\.\s*/, '')}
                {smartDNSStep === index && (
                  <button
                    className="step-btn"
                    onClick={() => setSmartDNSStep(index + 1)}
                  >
                    Done ✓
                  </button>
                )}
              </li>
            ))}
          </ol>
        </div>

        <div className="action-buttons">
          <button className="secondary-btn" onClick={handleSkipSmartDNS}>
            Skip for Now
          </button>
          <button
            className="primary-btn"
            onClick={handleSmartDNSComplete}
            disabled={smartDNSStep < steps.length}
          >
            I've Configured SmartDNS
          </button>
        </div>
      </div>
    );
  };

  const renderProxy = () => (
    <div className="nordvpn-proxy">
      <h2>Download Proxy (Optional)</h2>
      <p>
        Select a SOCKS5 proxy server for secure torrent downloads.
        Your downloads will appear to come from this location.
      </p>

      <div className="country-select">
        <label>Select Country</label>
        <select
          value={selectedCountry}
          onChange={(e) => setSelectedCountry(e.target.value)}
        >
          {countries.map((c) => (
            <option key={c.code} value={c.code}>
              {c.name} ({c.serverCount} servers)
            </option>
          ))}
        </select>
      </div>

      <div className="server-list">
        {filteredServers.map((server) => (
          <div
            key={server.hostname}
            className={`server-item ${selectedServer?.hostname === server.hostname ? 'selected' : ''}`}
            onClick={() => handleSelectProxy(server)}
          >
            <div className="server-info">
              <strong>{server.city || server.country}</strong>
              <span className="hostname">{server.hostname}</span>
            </div>
            <span className="port">:{server.port}</span>
            {selectedServer?.hostname === server.hostname && (
              <span className="checkmark">✓</span>
            )}
          </div>
        ))}
      </div>

      <div className="action-buttons">
        <button className="secondary-btn" onClick={handleComplete}>
          Skip Proxy Setup
        </button>
        <button
          className="primary-btn"
          onClick={handleComplete}
          disabled={!selectedServer}
        >
          Save & Continue
        </button>
      </div>
    </div>
  );

  const renderComplete = () => (
    <div className="nordvpn-complete">
      <div className="success-icon">✅</div>
      <h2>NordVPN Setup Complete</h2>

      <div className="status-cards">
        <div className={`status-card ${isConfigured ? 'active' : 'inactive'}`}>
          <span className="status-icon">{isConfigured ? '✓' : '✗'}</span>
          <div>
            <strong>Account</strong>
            <p>{isConfigured ? 'Connected' : 'Not configured'}</p>
          </div>
        </div>

        <div className={`status-card ${smartDNSEnabled ? 'active' : 'inactive'}`}>
          <span className="status-icon">{smartDNSEnabled ? '✓' : '○'}</span>
          <div>
            <strong>SmartDNS</strong>
            <p>{smartDNSEnabled ? 'Enabled on TV' : 'Not configured'}</p>
          </div>
          {!smartDNSEnabled && (
            <button
              className="configure-btn"
              onClick={() => setCurrentStep('smartdns')}
            >
              Configure
            </button>
          )}
        </div>

        <div className={`status-card ${selectedServer ? 'active' : 'inactive'}`}>
          <span className="status-icon">{selectedServer ? '✓' : '○'}</span>
          <div>
            <strong>Download Proxy</strong>
            <p>
              {selectedServer
                ? `${selectedServer.country} (${selectedServer.hostname})`
                : 'Not configured'}
            </p>
          </div>
          <button
            className="configure-btn"
            onClick={() => setCurrentStep('proxy')}
          >
            {selectedServer ? 'Change' : 'Configure'}
          </button>
        </div>
      </div>

      <div className="action-buttons">
        <button className="primary-btn" onClick={onClose}>
          Done
        </button>
      </div>
    </div>
  );

  return (
    <div className="nordvpn-settings">
      {currentStep === 'welcome' && renderWelcome()}
      {currentStep === 'auth' && renderAuth()}
      {currentStep === 'smartdns' && renderSmartDNS()}
      {currentStep === 'proxy' && renderProxy()}
      {currentStep === 'complete' && renderComplete()}
    </div>
  );
};

export default NordVPNSettings;
