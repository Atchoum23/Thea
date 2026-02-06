/**
 * IP Monitor Service
 *
 * Monitors your public IP address and alerts when it changes.
 * This is critical for SmartDNS which is tied to a specific IP.
 *
 * Features:
 * - Periodic IP checking
 * - Alert when IP changes (SmartDNS needs re-activation)
 * - Direct link to NordVPN SmartDNS activation page
 * - IP history tracking
 */

import { secureConfigService } from '../config/SecureConfigService';

export interface IPCheckResult {
  ip: string;
  country: string;
  countryCode: string;
  city?: string;
  isp?: string;
  timestamp: number;
}

export interface IPChangeAlert {
  previousIP: string;
  currentIP: string;
  timestamp: number;
  smartDNSAffected: boolean;
  activationUrl: string;
}

type IPChangeCallback = (alert: IPChangeAlert) => void;

class IPMonitorService {
  private static instance: IPMonitorService;
  private currentIP: string | null = null;
  private lastCheck: number = 0;
  private checkInterval: ReturnType<typeof setInterval> | null = null;
  private listeners: Set<IPChangeCallback> = new Set();
  private ipHistory: IPCheckResult[] = [];

  // Check every 15 minutes by default
  private readonly CHECK_INTERVAL_MS = 15 * 60 * 1000;
  private readonly STORAGE_KEY = 'thea_ip_monitor';

  private constructor() {
    this.loadState();
    this.startMonitoring();
  }

  static getInstance(): IPMonitorService {
    if (!IPMonitorService.instance) {
      IPMonitorService.instance = new IPMonitorService();
    }
    return IPMonitorService.instance;
  }

  /**
   * Load saved state from localStorage
   */
  private loadState(): void {
    try {
      const saved = localStorage.getItem(this.STORAGE_KEY);
      if (saved) {
        const state = JSON.parse(saved);
        this.currentIP = state.currentIP;
        this.lastCheck = state.lastCheck || 0;
        this.ipHistory = state.ipHistory || [];
      }
    } catch (error) {
      console.warn('Failed to load IP monitor state:', error);
    }
  }

  /**
   * Save state to localStorage
   */
  private saveState(): void {
    try {
      localStorage.setItem(this.STORAGE_KEY, JSON.stringify({
        currentIP: this.currentIP,
        lastCheck: this.lastCheck,
        ipHistory: this.ipHistory.slice(-50), // Keep last 50 entries
      }));
    } catch (error) {
      console.warn('Failed to save IP monitor state:', error);
    }
  }

  /**
   * Start periodic IP monitoring
   */
  startMonitoring(): void {
    if (this.checkInterval) {
      return; // Already monitoring
    }

    // Initial check
    this.checkIP();

    // Periodic checks
    this.checkInterval = setInterval(() => {
      this.checkIP();
    }, this.CHECK_INTERVAL_MS);
  }

  /**
   * Stop IP monitoring
   */
  stopMonitoring(): void {
    if (this.checkInterval) {
      clearInterval(this.checkInterval);
      this.checkInterval = null;
    }
  }

  /**
   * Check current public IP
   * Uses IPv4-specific endpoint since SmartDNS only works with IPv4
   */
  async checkIP(): Promise<IPCheckResult | null> {
    try {
      // First, get IPv4 address specifically (SmartDNS only works with IPv4)
      // This ensures we get IPv4 even if the device prefers IPv6
      let ipv4: string | null = null;
      try {
        const ipv4Response = await fetch('https://ipv4.icanhazip.com/', {
          signal: AbortSignal.timeout(5000),
        });
        if (ipv4Response.ok) {
          ipv4 = (await ipv4Response.text()).trim();
        }
      } catch {
        // Fallback to ipapi.co if icanhazip fails
      }

      // Get detailed info from ipapi.co
      const response = await fetch('https://ipapi.co/json/', {
        signal: AbortSignal.timeout(10000),
      });

      if (!response.ok) {
        throw new Error(`IP check failed: ${response.status}`);
      }

      const data = await response.json() as {
        ip: string;
        country_name: string;
        country_code: string;
        city?: string;
        org?: string;
      };

      // Use the explicit IPv4 address if we got one
      const finalIP = ipv4 || data.ip;

      const result: IPCheckResult = {
        ip: finalIP,
        country: data.country_name,
        countryCode: data.country_code,
        city: data.city,
        isp: data.org,
        timestamp: Date.now(),
      };

      // Check if IP changed
      const previousIP = this.currentIP;
      if (previousIP && previousIP !== result.ip) {
        this.handleIPChange(previousIP, result.ip);
      }

      // Update state
      this.currentIP = result.ip;
      this.lastCheck = Date.now();
      this.ipHistory.push(result);
      this.saveState();

      return result;
    } catch (error) {
      console.error('IP check failed:', error);
      return null;
    }
  }

  /**
   * Handle IP address change
   */
  private handleIPChange(previousIP: string, currentIP: string): void {
    const nordvpnConfig = secureConfigService.getNordVPN();
    const activatedIP = nordvpnConfig.smartDNSActivatedIP;

    const alert: IPChangeAlert = {
      previousIP,
      currentIP,
      timestamp: Date.now(),
      smartDNSAffected: !!activatedIP && activatedIP !== currentIP,
      activationUrl: 'https://my.nordaccount.com/dashboard/nordvpn/smartdns/',
    };

    // Notify all listeners
    for (const listener of this.listeners) {
      try {
        listener(alert);
      } catch (error) {
        console.error('IP change listener error:', error);
      }
    }

    // If SmartDNS is affected, update config to mark it as needing re-activation
    if (alert.smartDNSAffected) {
      console.warn(`⚠️ Your IP changed from ${previousIP} to ${currentIP}`);
      console.warn('SmartDNS was activated for a different IP and may not work.');
      console.warn(`Re-activate at: ${alert.activationUrl}`);
    }
  }

  /**
   * Subscribe to IP change alerts
   */
  onIPChange(callback: IPChangeCallback): () => void {
    this.listeners.add(callback);
    return () => this.listeners.delete(callback);
  }

  /**
   * Get current IP address
   */
  getCurrentIP(): string | null {
    return this.currentIP;
  }

  /**
   * Get last check timestamp
   */
  getLastCheckTime(): number {
    return this.lastCheck;
  }

  /**
   * Get IP history
   */
  getIPHistory(): IPCheckResult[] {
    return [...this.ipHistory];
  }

  /**
   * Check if current IP matches SmartDNS activated IP
   */
  isSmartDNSIPValid(): boolean {
    const activatedIP = secureConfigService.getNordVPN().smartDNSActivatedIP;
    if (!activatedIP) {
      return false; // Not configured
    }
    if (!this.currentIP) {
      return true; // Unknown, assume valid
    }
    return this.currentIP === activatedIP;
  }

  /**
   * Get SmartDNS status
   */
  getSmartDNSStatus(): {
    enabled: boolean;
    activatedIP: string | null;
    currentIP: string | null;
    valid: boolean;
    message: string;
  } {
    const config = secureConfigService.getNordVPN();
    const activatedIP = config.smartDNSActivatedIP || null;
    const currentIP = this.currentIP;
    const valid = this.isSmartDNSIPValid();

    let message: string;
    if (!config.smartDNSEnabled) {
      message = 'SmartDNS is not enabled';
    } else if (!activatedIP) {
      message = 'SmartDNS needs to be activated at my.nordaccount.com';
    } else if (!currentIP) {
      message = 'Checking IP address...';
    } else if (valid) {
      message = `SmartDNS active for ${activatedIP}`;
    } else {
      message = `IP changed! Re-activate SmartDNS (was ${activatedIP}, now ${currentIP})`;
    }

    return {
      enabled: config.smartDNSEnabled,
      activatedIP,
      currentIP,
      valid,
      message,
    };
  }

  /**
   * Force an immediate IP check
   */
  async forceCheck(): Promise<IPCheckResult | null> {
    return this.checkIP();
  }
}

export const ipMonitorService = IPMonitorService.getInstance();
