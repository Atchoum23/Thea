/**
 * SmartDNS Status Widget
 *
 * Shows current SmartDNS status on the home screen:
 * - ✅ Green: SmartDNS active and IP matches
 * - ⚠️ Yellow: IP changed, needs re-activation
 * - ❌ Red: Not configured
 *
 * Tapping opens quick actions or full settings.
 */

import React, { useState, useEffect } from 'react';
import { ipMonitorService, IPChangeAlert } from '../../services/vpn/IPMonitorService';
import { nordVPNProxyService } from '../../services/vpn/NordVPNProxyService';
import './SmartDNSStatusWidget.css';

interface SmartDNSStatusWidgetProps {
  onOpenSettings?: () => void;
  compact?: boolean;
}

export const SmartDNSStatusWidget: React.FC<SmartDNSStatusWidgetProps> = ({
  onOpenSettings,
  compact = false,
}) => {
  const [status, setStatus] = useState(ipMonitorService.getSmartDNSStatus());
  const [showAlert, setShowAlert] = useState(false);
  const [alertMessage, setAlertMessage] = useState<string | null>(null);
  const [checking, setChecking] = useState(false);

  useEffect(() => {
    // Update status periodically
    const updateStatus = () => {
      setStatus(ipMonitorService.getSmartDNSStatus());
    };

    updateStatus();
    const interval = setInterval(updateStatus, 30000); // Every 30 seconds

    // Subscribe to IP changes
    const unsubscribe = ipMonitorService.onIPChange((alert: IPChangeAlert) => {
      if (alert.smartDNSAffected) {
        setShowAlert(true);
        setAlertMessage(
          `Your IP changed from ${alert.previousIP} to ${alert.currentIP}. ` +
          `SmartDNS needs to be re-activated.`
        );
      }
      updateStatus();
    });

    return () => {
      clearInterval(interval);
      unsubscribe();
    };
  }, []);

  const handleRefresh = async () => {
    setChecking(true);
    await ipMonitorService.forceCheck();
    setStatus(ipMonitorService.getSmartDNSStatus());
    setChecking(false);
  };

  const handleOpenActivation = () => {
    // On TV, we can't open URLs directly, but we can show the URL
    const config = nordVPNProxyService.getSmartDNSConfig();
    setAlertMessage(
      `To re-activate SmartDNS:\n\n` +
      `1. On your phone/computer, go to:\n` +
      `   my.nordaccount.com/dashboard/nordvpn/smartdns\n\n` +
      `2. Click "Activate SmartDNS"\n\n` +
      `Your DNS servers:\n` +
      `Primary: ${config.primary}\n` +
      `Secondary: ${config.secondary}`
    );
    setShowAlert(true);
  };

  const getStatusColor = (): string => {
    if (!status.enabled) return 'status-disabled';
    if (!status.activatedIP) return 'status-warning';
    if (status.valid) return 'status-active';
    return 'status-error';
  };

  const getStatusIcon = (): string => {
    if (!status.enabled) return '○';
    if (!status.activatedIP) return '⚠️';
    if (status.valid) return '✓';
    return '⚠️';
  };

  if (compact) {
    return (
      <button
        className={`smartdns-widget-compact ${getStatusColor()}`}
        onClick={status.valid ? handleRefresh : handleOpenActivation}
        disabled={checking}
      >
        <span className="status-icon">{checking ? '↻' : getStatusIcon()}</span>
        <span className="status-label">SmartDNS</span>
      </button>
    );
  }

  return (
    <div className={`smartdns-widget ${getStatusColor()}`}>
      <div className="widget-header">
        <span className="status-icon">{getStatusIcon()}</span>
        <h3>SmartDNS</h3>
        <button
          className="refresh-btn"
          onClick={handleRefresh}
          disabled={checking}
          aria-label="Refresh IP"
        >
          {checking ? '↻' : '⟳'}
        </button>
      </div>

      <div className="widget-body">
        <p className="status-message">{status.message}</p>

        {status.currentIP && (
          <p className="ip-info">
            Current IP: <code>{status.currentIP}</code>
          </p>
        )}

        {!status.valid && status.activatedIP && (
          <p className="activated-ip">
            Activated for: <code>{status.activatedIP}</code>
          </p>
        )}
      </div>

      <div className="widget-actions">
        {!status.valid && (
          <button className="action-btn primary" onClick={handleOpenActivation}>
            Re-activate SmartDNS
          </button>
        )}
        {onOpenSettings && (
          <button className="action-btn secondary" onClick={onOpenSettings}>
            Settings
          </button>
        )}
      </div>

      {/* Alert Modal */}
      {showAlert && alertMessage && (
        <div className="alert-overlay" onClick={() => setShowAlert(false)}>
          <div className="alert-modal" onClick={(e) => e.stopPropagation()}>
            <h4>SmartDNS Alert</h4>
            <pre className="alert-message">{alertMessage}</pre>
            <button className="alert-close" onClick={() => setShowAlert(false)}>
              Got it
            </button>
          </div>
        </div>
      )}
    </div>
  );
};

export default SmartDNSStatusWidget;
