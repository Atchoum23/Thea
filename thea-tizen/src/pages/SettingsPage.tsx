/**
 * Settings Page
 * Configure API keys, Trakt connection, auto-download, and preferences
 */

import { useState } from 'react';
import { FocusContext, useFocusable } from '@noriginmedia/norigin-spatial-navigation';
import { FocusableCard, FocusableButton, FocusableList } from '../components/ui/FocusableCard';
import { ProviderRegistry } from '../services/ai/ProviderRegistry';
import { useTraktStore } from '../stores/traktStore';
import { STORAGE_KEYS } from '../config/constants';
import { AutoDownloadSettings } from '../components/settings/AutoDownloadSettings';

type SettingsSection = 'providers' | 'trakt' | 'autodownload' | 'sync' | 'about';

export function SettingsPage() {
  const { ref, focusKey } = useFocusable({
    focusable: false,
    saveLastFocusedChild: true,
  });

  const [activeSection, setActiveSection] = useState<SettingsSection>('providers');

  return (
    <FocusContext.Provider value={focusKey}>
      <div ref={ref} className="flex h-full">
        {/* Settings navigation */}
        <div className="w-64 bg-gray-900 p-6">
          <h1 className="text-2xl font-bold text-white mb-8">Settings</h1>
          <FocusableList>
            <SettingsNavItem
              label="AI Providers"
              icon="🤖"
              isActive={activeSection === 'providers'}
              onClick={() => setActiveSection('providers')}
            />
            <SettingsNavItem
              label="Trakt"
              icon="📺"
              isActive={activeSection === 'trakt'}
              onClick={() => setActiveSection('trakt')}
            />
            <SettingsNavItem
              label="Auto-Download"
              icon="⬇️"
              isActive={activeSection === 'autodownload'}
              onClick={() => setActiveSection('autodownload')}
            />
            <SettingsNavItem
              label="Sync"
              icon="☁️"
              isActive={activeSection === 'sync'}
              onClick={() => setActiveSection('sync')}
            />
            <SettingsNavItem
              label="About"
              icon="ℹ️"
              isActive={activeSection === 'about'}
              onClick={() => setActiveSection('about')}
            />
          </FocusableList>
        </div>

        {/* Settings content */}
        <div className="flex-1 p-8 overflow-y-auto">
          {activeSection === 'providers' && <ProvidersSection />}
          {activeSection === 'trakt' && <TraktSection />}
          {activeSection === 'autodownload' && <AutoDownloadSettings />}
          {activeSection === 'sync' && <SyncSection />}
          {activeSection === 'about' && <AboutSection />}
        </div>
      </div>
    </FocusContext.Provider>
  );
}

interface SettingsNavItemProps {
  label: string;
  icon: string;
  isActive: boolean;
  onClick: () => void;
}

function SettingsNavItem({ label, icon, isActive, onClick }: SettingsNavItemProps) {
  const { ref, focused } = useFocusable({
    onEnterPress: onClick,
  });

  return (
    <button
      ref={ref}
      onClick={onClick}
      className={`
        w-full flex items-center gap-3 px-4 py-3 rounded-lg text-left
        transition-all duration-200
        ${isActive ? 'bg-blue-600 text-white' : 'text-gray-300 hover:bg-gray-800'}
        ${focused ? 'ring-2 ring-white' : ''}
      `}
    >
      <span className="text-xl">{icon}</span>
      <span className="text-lg">{label}</span>
    </button>
  );
}

/**
 * AI Providers section
 */
function ProvidersSection() {
  const [editingProvider, setEditingProvider] = useState<string | null>(null);
  const [apiKeyInput, setApiKeyInput] = useState('');

  const providers = [
    {
      id: 'openrouter',
      name: 'OpenRouter',
      description: 'Access multiple AI models through a single API',
      storageKey: STORAGE_KEYS.API_KEYS.OPENROUTER,
    },
    {
      id: 'anthropic',
      name: 'Anthropic',
      description: 'Claude models directly',
      storageKey: STORAGE_KEYS.API_KEYS.ANTHROPIC,
    },
    {
      id: 'openai',
      name: 'OpenAI',
      description: 'GPT models',
      storageKey: STORAGE_KEYS.API_KEYS.OPENAI,
    },
  ];

  const handleSaveKey = (providerId: string, storageKey: string) => {
    if (apiKeyInput.trim()) {
      localStorage.setItem(storageKey, apiKeyInput);
      ProviderRegistry.configureProvider(providerId, apiKeyInput);
    }
    setEditingProvider(null);
    setApiKeyInput('');
  };

  const handleRemoveKey = (storageKey: string) => {
    localStorage.removeItem(storageKey);
    // Would need to update ProviderRegistry as well
  };

  return (
    <div>
      <h2 className="text-3xl font-bold text-white mb-2">AI Providers</h2>
      <p className="text-gray-400 mb-8">
        Configure your AI provider API keys. At least one is required.
      </p>

      <FocusableList className="gap-4">
        {providers.map((provider) => {
          const hasKey = !!localStorage.getItem(provider.storageKey);
          const isEditing = editingProvider === provider.id;

          return (
            <FocusableCard
              key={provider.id}
              className={`bg-gray-800 ${hasKey ? 'border-l-4 border-green-500' : ''}`}
            >
              <div className="flex justify-between items-start">
                <div>
                  <h3 className="text-xl font-semibold text-white">{provider.name}</h3>
                  <p className="text-gray-400">{provider.description}</p>
                  <div className="mt-2">
                    {hasKey ? (
                      <span className="text-green-400 text-sm">✓ Configured</span>
                    ) : (
                      <span className="text-yellow-400 text-sm">Not configured</span>
                    )}
                  </div>
                </div>

                {!isEditing && (
                  <FocusableButton
                    onClick={() => {
                      setEditingProvider(provider.id);
                      setApiKeyInput('');
                    }}
                    variant="secondary"
                    size="sm"
                  >
                    {hasKey ? 'Update' : 'Add Key'}
                  </FocusableButton>
                )}
              </div>

              {isEditing && (
                <div className="mt-4 pt-4 border-t border-gray-700">
                  <input
                    type="password"
                    value={apiKeyInput}
                    onChange={(e) => setApiKeyInput(e.target.value)}
                    placeholder="Enter API key..."
                    className="w-full bg-gray-900 text-white px-4 py-3 rounded-lg text-lg mb-4"
                    autoFocus
                  />
                  <div className="flex gap-3">
                    <FocusableButton
                      onClick={() => handleSaveKey(provider.id, provider.storageKey)}
                      disabled={!apiKeyInput.trim()}
                    >
                      Save
                    </FocusableButton>
                    <FocusableButton
                      onClick={() => setEditingProvider(null)}
                      variant="ghost"
                    >
                      Cancel
                    </FocusableButton>
                    {hasKey && (
                      <FocusableButton
                        onClick={() => handleRemoveKey(provider.storageKey)}
                        variant="danger"
                      >
                        Remove
                      </FocusableButton>
                    )}
                  </div>
                </div>
              )}
            </FocusableCard>
          );
        })}
      </FocusableList>
    </div>
  );
}

/**
 * Trakt section
 */
function TraktSection() {
  const { authStatus, user, startAuth, logout } = useTraktStore();
  const [clientId, setClientId] = useState(
    localStorage.getItem('thea_trakt_client_id') || ''
  );
  const [clientSecret, setClientSecret] = useState(
    localStorage.getItem('thea_trakt_client_secret') || ''
  );
  const [showCredentials, setShowCredentials] = useState(false);

  const handleSaveCredentials = () => {
    localStorage.setItem('thea_trakt_client_id', clientId);
    localStorage.setItem('thea_trakt_client_secret', clientSecret);
    useTraktStore.getState().initAuth(clientId, clientSecret);
    setShowCredentials(false);
  };

  const isAuthenticated = authStatus.status === 'authenticated';

  return (
    <div>
      <h2 className="text-3xl font-bold text-white mb-2">Trakt Integration</h2>
      <p className="text-gray-400 mb-8">
        Connect your Trakt account to track what you watch.
      </p>

      {/* Connection status */}
      <FocusableCard className="bg-gray-800 mb-6">
        <div className="flex justify-between items-center">
          <div>
            <h3 className="text-xl font-semibold text-white">Account</h3>
            {isAuthenticated && user ? (
              <p className="text-green-400">
                Connected as @{user.username}
                {user.vip && ' (VIP)'}
              </p>
            ) : (
              <p className="text-gray-400">Not connected</p>
            )}
          </div>
          {isAuthenticated ? (
            <FocusableButton onClick={logout} variant="danger">
              Disconnect
            </FocusableButton>
          ) : clientId && clientSecret ? (
            <FocusableButton onClick={startAuth}>
              Connect Account
            </FocusableButton>
          ) : null}
        </div>

        {/* Auth pending state */}
        {authStatus.status === 'pending' && (
          <div className="mt-4 pt-4 border-t border-gray-700 text-center">
            <p className="text-gray-300 mb-2">
              Go to <span className="text-blue-400">{authStatus.verificationUrl}</span>
            </p>
            <p className="text-3xl font-mono font-bold text-white">
              {authStatus.userCode}
            </p>
          </div>
        )}
      </FocusableCard>

      {/* API Credentials */}
      <FocusableCard className="bg-gray-800">
        <div className="flex justify-between items-center mb-4">
          <div>
            <h3 className="text-xl font-semibold text-white">API Credentials</h3>
            <p className="text-gray-400 text-sm">
              Create an app at trakt.tv/oauth/applications
            </p>
          </div>
          <FocusableButton
            onClick={() => setShowCredentials(!showCredentials)}
            variant="secondary"
            size="sm"
          >
            {showCredentials ? 'Hide' : 'Configure'}
          </FocusableButton>
        </div>

        {showCredentials && (
          <div className="space-y-4">
            <div>
              <label className="block text-gray-400 mb-2">Client ID</label>
              <input
                type="text"
                value={clientId}
                onChange={(e) => setClientId(e.target.value)}
                className="w-full bg-gray-900 text-white px-4 py-3 rounded-lg"
              />
            </div>
            <div>
              <label className="block text-gray-400 mb-2">Client Secret</label>
              <input
                type="password"
                value={clientSecret}
                onChange={(e) => setClientSecret(e.target.value)}
                className="w-full bg-gray-900 text-white px-4 py-3 rounded-lg"
              />
            </div>
            <FocusableButton onClick={handleSaveCredentials}>
              Save Credentials
            </FocusableButton>
          </div>
        )}
      </FocusableCard>
    </div>
  );
}

/**
 * Sync section
 */
function SyncSection() {
  return (
    <div>
      <h2 className="text-3xl font-bold text-white mb-2">iCloud Sync</h2>
      <p className="text-gray-400 mb-8">
        Sync conversations with your other Apple devices.
      </p>

      <FocusableCard className="bg-gray-800">
        <div className="text-center py-8">
          <div className="text-4xl mb-4">☁️</div>
          <h3 className="text-xl font-semibold text-white mb-2">
            Sync Bridge Required
          </h3>
          <p className="text-gray-400 max-w-md mx-auto">
            iCloud sync requires deploying a sync bridge service. This feature
            will be available in a future update.
          </p>
        </div>
      </FocusableCard>
    </div>
  );
}

/**
 * About section
 */
function AboutSection() {
  return (
    <div>
      <h2 className="text-3xl font-bold text-white mb-8">About THEA</h2>

      <div className="text-center mb-12">
        <div className="text-6xl mb-4">
          <span className="text-purple-500">T</span>
          <span className="text-blue-500">H</span>
          <span className="text-cyan-500">E</span>
          <span className="text-green-500">A</span>
        </div>
        <p className="text-xl text-gray-400">
          AI-Powered Assistant for Samsung TV
        </p>
        <p className="text-gray-500 mt-2">Version 1.0.0</p>
      </div>

      <FocusableList className="gap-4">
        <FocusableCard className="bg-gray-800">
          <h3 className="text-lg font-semibold text-white mb-2">Features</h3>
          <ul className="text-gray-400 space-y-1">
            <li>• AI chat with multiple providers</li>
            <li>• Trakt watch tracking & check-ins</li>
            <li>• Voice commands (Blue button)</li>
            <li>• Optimized for TV remote navigation</li>
          </ul>
        </FocusableCard>

        <FocusableCard className="bg-gray-800">
          <h3 className="text-lg font-semibold text-white mb-2">Remote Controls</h3>
          <div className="grid grid-cols-2 gap-4 text-gray-400">
            <div className="flex items-center gap-2">
              <span className="w-4 h-4 rounded-full bg-red-600" />
              <span>Cancel / Back</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="w-4 h-4 rounded-full bg-green-600" />
              <span>Confirm / Send</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="w-4 h-4 rounded-full bg-yellow-500" />
              <span>Options Menu</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="w-4 h-4 rounded-full bg-blue-600" />
              <span>Voice Input</span>
            </div>
          </div>
        </FocusableCard>
      </FocusableList>
    </div>
  );
}
