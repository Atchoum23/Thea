/**
 * Service Configuration Panel
 *
 * Interactive UI for configuring all Thea services.
 * TV-optimized with spatial navigation support.
 */

import React, { useState, useCallback } from 'react';
import { useFocusable, FocusContext } from '@noriginmedia/norigin-spatial-navigation';
import {
  SERVICE_CONFIGURATIONS,
  ServiceConfig,
  ConfigField,
  getConfigurationSummary,
} from '../../services/config/ServiceConfigurationGuide';
import { secureConfigService } from '../../services/config/SecureConfigService';
import './ServiceConfigPanel.css';

interface ServiceConfigPanelProps {
  onClose?: () => void;
}

export const ServiceConfigPanel: React.FC<ServiceConfigPanelProps> = ({ onClose }) => {
  const [selectedService, setSelectedService] = useState<ServiceConfig | null>(null);
  const [formValues, setFormValues] = useState<Record<string, any>>({});
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  const { ref, focusKey } = useFocusable({
    focusable: true,
    saveLastFocusedChild: true,
  });

  const summary = getConfigurationSummary();

  // Load current values when selecting a service
  const handleSelectService = useCallback((service: ServiceConfig) => {
    setSelectedService(service);
    setMessage(null);

    // Load existing values from SecureConfigService
    const currentValues: Record<string, any> = {};

    switch (service.id) {
      case 'plex': {
        const plexConfig = secureConfigService.getPlex();
        currentValues.serverUrl = plexConfig.serverUrl;
        currentValues.token = plexConfig.token;
        break;
      }
      case 'trakt': {
        const traktConfig = secureConfigService.getTrakt();
        currentValues.clientId = traktConfig.clientId;
        currentValues.clientSecret = traktConfig.clientSecret;
        break;
      }
      case 'tmdb': {
        const tmdbConfig = secureConfigService.getTMDB();
        currentValues.apiKey = tmdbConfig.apiKey;
        currentValues.accessToken = tmdbConfig.accessToken;
        break;
      }
      case 'nordvpn': {
        const nordConfig = secureConfigService.getNordVPN();
        currentValues.serviceUsername = nordConfig.serviceUsername;
        currentValues.servicePassword = nordConfig.servicePassword;
        currentValues.smartDNSPrimary = nordConfig.smartDNSPrimary;
        currentValues.smartDNSSecondary = nordConfig.smartDNSSecondary;
        currentValues.activatedIP = nordConfig.smartDNSActivatedIP;
        break;
      }
      case 'syncBridge': {
        const syncConfig = secureConfigService.getSyncBridge();
        currentValues.url = syncConfig.url;
        currentValues.deviceToken = syncConfig.deviceToken;
        break;
      }
      case 'qualityPrefs':
        // Load from TorrentQualityService
        try {
          const saved = localStorage.getItem('thea_quality_prefs');
          if (saved) {
            Object.assign(currentValues, JSON.parse(saved));
          }
        } catch { /* ignore */ }
        break;
      case 'episodeMonitor':
        // Load from EpisodeMonitorService
        try {
          const saved = localStorage.getItem('thea_episode_monitor_config');
          if (saved) {
            Object.assign(currentValues, JSON.parse(saved));
          }
        } catch { /* ignore */ }
        break;
    }

    setFormValues(currentValues);
  }, []);

  const handleFieldChange = useCallback((key: string, value: any) => {
    setFormValues(prev => ({ ...prev, [key]: value }));
  }, []);

  const handleSave = useCallback(async () => {
    if (!selectedService) return;

    setSaving(true);
    setMessage(null);

    try {
      // Save to appropriate service
      switch (selectedService.id) {
        case 'plex':
          secureConfigService.setPlex({
            serverUrl: formValues.serverUrl,
            token: formValues.token,
          });
          break;
        case 'trakt':
          secureConfigService.setTrakt({
            clientId: formValues.clientId,
            clientSecret: formValues.clientSecret,
          });
          break;
        case 'tmdb':
          secureConfigService.setTMDB({
            apiKey: formValues.apiKey,
            accessToken: formValues.accessToken,
          });
          break;
        case 'nordvpn':
          secureConfigService.setNordVPN({
            serviceUsername: formValues.serviceUsername,
            servicePassword: formValues.servicePassword,
            smartDNSPrimary: formValues.smartDNSPrimary,
            smartDNSSecondary: formValues.smartDNSSecondary,
            smartDNSActivatedIP: formValues.activatedIP,
          });
          break;
        case 'syncBridge':
          secureConfigService.setSyncBridge({
            url: formValues.url,
            deviceToken: formValues.deviceToken,
          });
          break;
        case 'qualityPrefs':
          localStorage.setItem('thea_quality_prefs', JSON.stringify(formValues));
          break;
        case 'episodeMonitor':
          localStorage.setItem('thea_episode_monitor_config', JSON.stringify(formValues));
          break;
      }

      setMessage({ type: 'success', text: `${selectedService.name} saved successfully!` });
    } catch (error) {
      setMessage({
        type: 'error',
        text: error instanceof Error ? error.message : 'Failed to save',
      });
    } finally {
      setSaving(false);
    }
  }, [selectedService, formValues]);

  const handleTestConnection = useCallback(async () => {
    if (!selectedService) return;

    setMessage({ type: 'success', text: 'Testing connection...' });

    try {
      switch (selectedService.id) {
        case 'plex': {
          const plexResponse = await fetch(`${formValues.serverUrl}/identity`, {
            headers: { 'X-Plex-Token': formValues.token },
          });
          if (!plexResponse.ok) throw new Error('Failed to connect to Plex');
          setMessage({ type: 'success', text: 'Connected to Plex successfully!' });
          break;
        }

        case 'trakt': {
          const traktResponse = await fetch('https://api.trakt.tv/users/settings', {
            headers: {
              'Content-Type': 'application/json',
              'trakt-api-key': formValues.clientId,
              'trakt-api-version': '2',
            },
          });
          if (!traktResponse.ok) throw new Error('Invalid Trakt credentials');
          setMessage({ type: 'success', text: 'Trakt credentials valid!' });
          break;
        }

        case 'syncBridge': {
          const bridgeResponse = await fetch(`${formValues.url}/health`);
          if (!bridgeResponse.ok) throw new Error('Bridge not responding');
          setMessage({ type: 'success', text: 'Sync Bridge is online!' });
          break;
        }

        default:
          setMessage({ type: 'error', text: 'Connection test not available for this service' });
      }
    } catch (error) {
      setMessage({
        type: 'error',
        text: error instanceof Error ? error.message : 'Connection test failed',
      });
    }
  }, [selectedService, formValues]);

  return (
    <FocusContext.Provider value={focusKey}>
      <div ref={ref} className="service-config-panel">
        {/* Header */}
        <div className="config-header">
          <h1>Service Configuration</h1>
          <div className="config-summary">
            <span className="configured">{summary.configured} configured</span>
            <span className="partial">{summary.partial} partial</span>
            <span className="not-configured">{summary.notConfigured} pending</span>
          </div>
        </div>

        <div className="config-content">
          {/* Service List */}
          <div className="service-list">
            {SERVICE_CONFIGURATIONS.map(service => (
              <ServiceListItem
                key={service.id}
                service={service}
                selected={selectedService?.id === service.id}
                onSelect={() => handleSelectService(service)}
              />
            ))}
          </div>

          {/* Configuration Form */}
          <div className="config-form-container">
            {selectedService ? (
              <div className="config-form">
                <h2>{selectedService.name}</h2>
                <p className="service-description">{selectedService.description}</p>

                {/* Setup Instructions */}
                {selectedService.setupInstructions && (
                  <div className="setup-instructions">
                    <h3>Setup Steps:</h3>
                    <ol>
                      {selectedService.setupInstructions.map((step, i) => (
                        <li key={i}>{step}</li>
                      ))}
                    </ol>
                  </div>
                )}

                {/* Required Fields */}
                {selectedService.required.length > 0 && (
                  <div className="field-section">
                    <h3>Required</h3>
                    {selectedService.required.map(field => (
                      <ConfigFormField
                        key={field.key}
                        field={field}
                        value={formValues[field.key] || ''}
                        onChange={value => handleFieldChange(field.key, value)}
                      />
                    ))}
                  </div>
                )}

                {/* Optional Fields */}
                {selectedService.optional.length > 0 && (
                  <div className="field-section">
                    <h3>Optional</h3>
                    {selectedService.optional.map(field => (
                      <ConfigFormField
                        key={field.key}
                        field={field}
                        value={formValues[field.key] || ''}
                        onChange={value => handleFieldChange(field.key, value)}
                      />
                    ))}
                  </div>
                )}

                {/* Message */}
                {message && (
                  <div className={`config-message ${message.type}`}>
                    {message.text}
                  </div>
                )}

                {/* Actions */}
                <div className="config-actions">
                  <FocusableButton
                    label="Save"
                    onClick={handleSave}
                    disabled={saving}
                    primary
                  />
                  <FocusableButton
                    label="Test Connection"
                    onClick={handleTestConnection}
                    disabled={saving}
                  />
                </div>
              </div>
            ) : (
              <div className="no-selection">
                <p>Select a service to configure</p>
              </div>
            )}
          </div>
        </div>

        {/* Bottom Hints */}
        <div className="config-hints">
          <span className="hint"><span className="key">RED</span> Cancel</span>
          <span className="hint"><span className="key">GREEN</span> Save</span>
          <span className="hint"><span className="key">YELLOW</span> Test</span>
          <span className="hint"><span className="key">BLUE</span> Help</span>
        </div>
      </div>
    </FocusContext.Provider>
  );
};

// ============================================================
// Sub-components
// ============================================================

interface ServiceListItemProps {
  service: ServiceConfig;
  selected: boolean;
  onSelect: () => void;
}

const ServiceListItem: React.FC<ServiceListItemProps> = ({
  service,
  selected,
  onSelect,
}) => {
  const { ref, focused } = useFocusable({
    onEnterPress: onSelect,
  });

  const statusIcon = {
    configured: '✓',
    partial: '◐',
    not_configured: '○',
  }[service.status];

  const statusClass = service.status.replace('_', '-');

  return (
    <div
      ref={ref}
      className={`service-list-item ${focused ? 'focused' : ''} ${selected ? 'selected' : ''}`}
      onClick={onSelect}
    >
      <span className={`status-icon ${statusClass}`}>{statusIcon}</span>
      <span className="service-name">{service.name}</span>
      <span className="setup-method">{service.setupMethod}</span>
    </div>
  );
};

interface ConfigFormFieldProps {
  field: ConfigField;
  value: any;
  onChange: (value: any) => void;
}

const ConfigFormField: React.FC<ConfigFormFieldProps> = ({
  field,
  value,
  onChange,
}) => {
  const { ref, focused } = useFocusable();

  const renderInput = () => {
    switch (field.type) {
      case 'boolean':
        return (
          <label className="toggle-switch">
            <input
              type="checkbox"
              checked={value || false}
              onChange={e => onChange(e.target.checked)}
            />
            <span className="toggle-slider"></span>
          </label>
        );

      case 'select':
        return (
          <select value={value || ''} onChange={e => onChange(e.target.value)}>
            <option value="">Select...</option>
            {field.options?.map(opt => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
        );

      case 'number':
        return (
          <input
            type="number"
            value={value || ''}
            onChange={e => onChange(parseInt(e.target.value, 10))}
            min={field.validation?.min}
            max={field.validation?.max}
            placeholder={field.placeholder}
          />
        );

      case 'password':
        return (
          <input
            type="password"
            value={value || ''}
            onChange={e => onChange(e.target.value)}
            placeholder={field.placeholder}
          />
        );

      default:
        return (
          <input
            type={field.type === 'url' ? 'url' : 'text'}
            value={value || ''}
            onChange={e => onChange(e.target.value)}
            placeholder={field.placeholder}
          />
        );
    }
  };

  return (
    <div ref={ref} className={`form-field ${focused ? 'focused' : ''}`}>
      <label>{field.label}</label>
      {renderInput()}
      {field.hint && <span className="field-hint">{field.hint}</span>}
    </div>
  );
};

interface FocusableButtonProps {
  label: string;
  onClick: () => void;
  disabled?: boolean;
  primary?: boolean;
}

const FocusableButton: React.FC<FocusableButtonProps> = ({
  label,
  onClick,
  disabled,
  primary,
}) => {
  const { ref, focused } = useFocusable({
    onEnterPress: () => !disabled && onClick(),
  });

  return (
    <button
      ref={ref}
      className={`config-button ${focused ? 'focused' : ''} ${primary ? 'primary' : ''}`}
      onClick={() => !disabled && onClick()}
      disabled={disabled}
    >
      {label}
    </button>
  );
};

export default ServiceConfigPanel;
