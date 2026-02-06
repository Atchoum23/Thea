/**
 * SmartDNS Auto Helper
 *
 * Provides semi-automatic SmartDNS re-activation when IP changes:
 * 1. Detects IP change via IPMonitorService
 * 2. Sends notification to Mac via sync-bridge
 * 3. Mac helper opens the activation URL automatically
 * 4. User just clicks "Activate" on the NordVPN page
 *
 * This reduces the re-activation process from:
 * - Manual: Notice problem → Open browser → Navigate → Login → Find SmartDNS → Activate
 * - With helper: See notification → Click Activate (page already open)
 */

import { ipMonitorService, IPChangeAlert } from './IPMonitorService';
import { secureConfigService } from '../config/SecureConfigService';

const SMARTDNS_ACTIVATION_URL = 'https://my.nordaccount.com/dashboard/nordvpn/smartdns/';

interface MacNotification {
  type: 'smartdns_ip_changed';
  title: string;
  message: string;
  actions: {
    openUrl?: string;
    runAppleScript?: string;
  };
  previousIP: string;
  currentIP: string;
  timestamp: number;
}

class SmartDNSAutoHelper {
  private static instance: SmartDNSAutoHelper;
  private initialized = false;

  private constructor() {}

  static getInstance(): SmartDNSAutoHelper {
    if (!SmartDNSAutoHelper.instance) {
      SmartDNSAutoHelper.instance = new SmartDNSAutoHelper();
    }
    return SmartDNSAutoHelper.instance;
  }

  /**
   * Initialize the auto helper
   * Call this on app startup
   */
  initialize(): void {
    if (this.initialized) return;

    // Subscribe to IP changes
    ipMonitorService.onIPChange((alert) => {
      if (alert.smartDNSAffected) {
        this.handleIPChange(alert);
      }
    });

    this.initialized = true;
    console.log('SmartDNS Auto Helper initialized');
  }

  /**
   * Handle IP change event
   */
  private async handleIPChange(alert: IPChangeAlert): Promise<void> {
    console.warn(`🌐 IP changed: ${alert.previousIP} → ${alert.currentIP}`);
    console.warn('SmartDNS needs re-activation!');

    // 1. Show local notification on TV
    this.showTVNotification(alert);

    // 2. Send notification to Mac via sync-bridge
    await this.notifyMac(alert);
  }

  /**
   * Show notification on Samsung TV
   */
  private showTVNotification(alert: IPChangeAlert): void {
    // On Tizen, we'd use tizen.application.getCurrentApplication().getRequestedAppControl()
    // For now, we'll dispatch a custom event that the UI can listen to
    const event = new CustomEvent('smartdns-ip-changed', {
      detail: {
        previousIP: alert.previousIP,
        currentIP: alert.currentIP,
        activationUrl: SMARTDNS_ACTIVATION_URL,
      },
    });
    window.dispatchEvent(event);
  }

  /**
   * Send notification to Mac via sync-bridge
   * The Mac helper will open the activation URL automatically
   */
  private async notifyMac(alert: IPChangeAlert): Promise<void> {
    const syncConfig = secureConfigService.getSyncBridge();

    if (!syncConfig.url || !syncConfig.deviceToken) {
      console.warn('Sync bridge not configured - cannot notify Mac');
      return;
    }

    const notification: MacNotification = {
      type: 'smartdns_ip_changed',
      title: '🌐 SmartDNS IP Changed',
      message: `Your IP changed from ${alert.previousIP} to ${alert.currentIP}. SmartDNS needs re-activation.`,
      actions: {
        openUrl: SMARTDNS_ACTIVATION_URL,
        // AppleScript to show notification AND open URL
        runAppleScript: `
          display notification "Your IP changed to ${alert.currentIP}. Click Activate on the page that opens." with title "SmartDNS Re-activation Required" sound name "Ping"
          delay 1
          open location "${SMARTDNS_ACTIVATION_URL}"
        `,
      },
      previousIP: alert.previousIP,
      currentIP: alert.currentIP,
      timestamp: Date.now(),
    };

    try {
      const response = await fetch(`${syncConfig.url}/notifications/push`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Device-Token': syncConfig.deviceToken,
        },
        body: JSON.stringify(notification),
      });

      if (response.ok) {
        console.log('Mac notification sent successfully');
      } else {
        console.error('Failed to send Mac notification:', response.status);
      }
    } catch (error) {
      console.error('Error sending Mac notification:', error);
    }
  }

  /**
   * Manually trigger re-activation reminder
   * (for use when user clicks a "Re-activate SmartDNS" button)
   */
  async triggerReactivation(): Promise<void> {
    const currentIP = ipMonitorService.getCurrentIP();
    const activatedIP = secureConfigService.getNordVPN().smartDNSActivatedIP;

    const alert: IPChangeAlert = {
      previousIP: activatedIP || 'unknown',
      currentIP: currentIP || 'unknown',
      timestamp: Date.now(),
      smartDNSAffected: true,
      activationUrl: SMARTDNS_ACTIVATION_URL,
    };

    await this.notifyMac(alert);
  }

  /**
   * Update the activated IP after user confirms re-activation
   */
  updateActivatedIP(newIP: string): void {
    secureConfigService.setNordVPN({
      smartDNSActivatedIP: newIP,
    });
    console.log(`SmartDNS activated IP updated to: ${newIP}`);
  }

  /**
   * Check if SmartDNS re-activation is needed
   */
  needsReactivation(): boolean {
    return !ipMonitorService.isSmartDNSIPValid();
  }

  /**
   * Get current status
   */
  getStatus(): {
    needsReactivation: boolean;
    currentIP: string | null;
    activatedIP: string | null;
    activationUrl: string;
  } {
    return {
      needsReactivation: this.needsReactivation(),
      currentIP: ipMonitorService.getCurrentIP(),
      activatedIP: secureConfigService.getNordVPN().smartDNSActivatedIP || null,
      activationUrl: SMARTDNS_ACTIVATION_URL,
    };
  }
}

export const smartDNSAutoHelper = SmartDNSAutoHelper.getInstance();

/**
 * Mac-side helper script (to be run on Mac)
 *
 * This script should be set up as a LaunchAgent or run by the Thea Mac app
 * to poll for notifications and execute actions.
 *
 * Example LaunchAgent plist:
 * ~/Library/LaunchAgents/com.thea.smartdns-helper.plist
 *
 * The script polls sync-bridge for notifications and executes AppleScript
 * to open URLs and show native macOS notifications.
 */
export const MAC_HELPER_SCRIPT = `#!/bin/bash
# Thea SmartDNS Helper for Mac
# Polls sync-bridge for IP change notifications and opens activation URL

SYNC_BRIDGE_URL="YOUR_SYNC_BRIDGE_URL"
DEVICE_TOKEN="YOUR_DEVICE_TOKEN"

while true; do
  # Poll for notifications
  RESPONSE=$(curl -s -H "X-Device-Token: $DEVICE_TOKEN" "$SYNC_BRIDGE_URL/notifications?since=$(date -v-5M +%s000)")

  # Check for smartdns_ip_changed notifications
  if echo "$RESPONSE" | grep -q "smartdns_ip_changed"; then
    # Extract the AppleScript and run it
    osascript -e 'display notification "Your IP changed. SmartDNS needs re-activation." with title "Thea" sound name "Ping"'
    sleep 1
    open "https://my.nordaccount.com/dashboard/nordvpn/smartdns/"
  fi

  sleep 60  # Check every minute
done
`;
