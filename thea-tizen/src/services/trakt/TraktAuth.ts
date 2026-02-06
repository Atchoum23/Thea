/**
 * Trakt OAuth Device Flow Authentication
 * Optimized for TV - no keyboard needed
 */

import type { TraktTokens, TraktDeviceCode } from '../../types/trakt';
import { API_URLS, TRAKT_CONFIG, STORAGE_KEYS } from '../../config/constants';

export type AuthStatus =
  | { status: 'idle' }
  | { status: 'pending'; userCode: string; verificationUrl: string }
  | { status: 'polling' }
  | { status: 'authenticated'; tokens: TraktTokens }
  | { status: 'error'; error: string }
  | { status: 'expired' }
  | { status: 'denied' };

export type AuthStatusListener = (status: AuthStatus) => void;

/**
 * Trakt Device OAuth Authentication
 */
class TraktAuthClass {
  private clientId: string = '';
  private clientSecret: string = '';
  private deviceCode: string | null = null;
  private pollInterval: number = TRAKT_CONFIG.POLL_INTERVAL;
  private pollTimer: ReturnType<typeof setInterval> | null = null;
  private statusListeners: Set<AuthStatusListener> = new Set();
  private currentStatus: AuthStatus = { status: 'idle' };

  /**
   * Configure client credentials
   */
  configure(clientId: string, clientSecret: string): void {
    this.clientId = clientId;
    this.clientSecret = clientSecret;
  }

  /**
   * Subscribe to auth status changes
   */
  subscribe(listener: AuthStatusListener): () => void {
    this.statusListeners.add(listener);
    listener(this.currentStatus);
    return () => this.statusListeners.delete(listener);
  }

  private updateStatus(status: AuthStatus): void {
    this.currentStatus = status;
    this.statusListeners.forEach(listener => listener(status));
  }

  /**
   * Start the device authentication flow
   * Returns a user code to display on TV
   */
  async startDeviceAuth(): Promise<TraktDeviceCode> {
    if (!this.clientId) {
      throw new Error('Trakt client ID not configured');
    }

    const response = await fetch(`${API_URLS.TRAKT}/oauth/device/code`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        client_id: this.clientId,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Failed to start device auth: ${error}`);
    }

    const data = await response.json();

    const deviceCode: TraktDeviceCode = {
      deviceCode: data.device_code,
      userCode: data.user_code,
      verificationUrl: data.verification_url,
      expiresIn: data.expires_in,
      interval: data.interval,
    };

    this.deviceCode = deviceCode.deviceCode;
    this.pollInterval = deviceCode.interval;

    this.updateStatus({
      status: 'pending',
      userCode: deviceCode.userCode,
      verificationUrl: deviceCode.verificationUrl,
    });

    // Start polling for token
    this.startPolling();

    return deviceCode;
  }

  /**
   * Start polling for device token
   */
  private startPolling(): void {
    this.stopPolling();

    this.pollTimer = setInterval(async () => {
      await this.pollForToken();
    }, this.pollInterval * 1000);
  }

  /**
   * Stop polling
   */
  private stopPolling(): void {
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
      this.pollTimer = null;
    }
  }

  /**
   * Poll for device token
   */
  private async pollForToken(): Promise<void> {
    if (!this.deviceCode || !this.clientId || !this.clientSecret) {
      this.stopPolling();
      return;
    }

    this.updateStatus({ status: 'polling' });

    try {
      const response = await fetch(`${API_URLS.TRAKT}/oauth/device/token`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          code: this.deviceCode,
          client_id: this.clientId,
          client_secret: this.clientSecret,
        }),
      });

      switch (response.status) {
        case 200: {
          // Success!
          const data = await response.json();
          const tokens: TraktTokens = {
            accessToken: data.access_token,
            refreshToken: data.refresh_token,
            expiresAt: Date.now() + data.expires_in * 1000,
            createdAt: data.created_at * 1000,
            tokenType: 'Bearer',
          };

          this.saveTokens(tokens);
          this.stopPolling();
          this.deviceCode = null;
          this.updateStatus({ status: 'authenticated', tokens });
          break;
        }

        case 400:
          // Still pending, continue polling
          break;

        case 404:
          // Invalid device code
          this.stopPolling();
          this.updateStatus({ status: 'error', error: 'Invalid device code' });
          break;

        case 409:
          // Already used
          this.stopPolling();
          this.updateStatus({
            status: 'error',
            error: 'Code already used',
          });
          break;

        case 410:
          // Expired
          this.stopPolling();
          this.updateStatus({ status: 'expired' });
          break;

        case 418:
          // Denied by user
          this.stopPolling();
          this.updateStatus({ status: 'denied' });
          break;

        case 429:
          // Rate limited - slow down
          this.pollInterval = Math.min(this.pollInterval * 2, 30);
          break;

        default:
          this.stopPolling();
          this.updateStatus({
            status: 'error',
            error: `Unexpected status: ${response.status}`,
          });
      }
    } catch (error) {
      // Network error - continue polling
      console.warn('Trakt poll error:', error);
    }
  }

  /**
   * Cancel authentication
   */
  cancel(): void {
    this.stopPolling();
    this.deviceCode = null;
    this.updateStatus({ status: 'idle' });
  }

  /**
   * Get stored tokens
   */
  getTokens(): TraktTokens | null {
    try {
      const stored = localStorage.getItem(STORAGE_KEYS.API_KEYS.TRAKT_ACCESS);
      if (!stored) return null;

      const tokens = JSON.parse(stored) as TraktTokens;

      // Check if tokens are expired
      if (tokens.expiresAt < Date.now() + TRAKT_CONFIG.TOKEN_REFRESH_BUFFER) {
        // Tokens expired or expiring soon - need refresh
        return null;
      }

      return tokens;
    } catch {
      return null;
    }
  }

  /**
   * Save tokens to storage
   */
  private saveTokens(tokens: TraktTokens): void {
    localStorage.setItem(
      STORAGE_KEYS.API_KEYS.TRAKT_ACCESS,
      JSON.stringify(tokens)
    );
    localStorage.setItem(
      STORAGE_KEYS.API_KEYS.TRAKT_REFRESH,
      tokens.refreshToken
    );
  }

  /**
   * Clear stored tokens (logout)
   */
  logout(): void {
    localStorage.removeItem(STORAGE_KEYS.API_KEYS.TRAKT_ACCESS);
    localStorage.removeItem(STORAGE_KEYS.API_KEYS.TRAKT_REFRESH);
    this.updateStatus({ status: 'idle' });
  }

  /**
   * Refresh tokens
   */
  async refreshTokens(): Promise<TraktTokens | null> {
    const refreshToken = localStorage.getItem(
      STORAGE_KEYS.API_KEYS.TRAKT_REFRESH
    );

    if (!refreshToken || !this.clientId || !this.clientSecret) {
      return null;
    }

    try {
      const response = await fetch(`${API_URLS.TRAKT}/oauth/token`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          refresh_token: refreshToken,
          client_id: this.clientId,
          client_secret: this.clientSecret,
          redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
          grant_type: 'refresh_token',
        }),
      });

      if (!response.ok) {
        // Refresh failed - need to re-authenticate
        this.logout();
        return null;
      }

      const data = await response.json();
      const tokens: TraktTokens = {
        accessToken: data.access_token,
        refreshToken: data.refresh_token,
        expiresAt: Date.now() + data.expires_in * 1000,
        createdAt: data.created_at * 1000,
        tokenType: 'Bearer',
      };

      this.saveTokens(tokens);
      this.updateStatus({ status: 'authenticated', tokens });
      return tokens;
    } catch {
      return null;
    }
  }

  /**
   * Check if authenticated
   */
  get isAuthenticated(): boolean {
    return this.getTokens() !== null;
  }

  /**
   * Get valid access token (refreshing if needed)
   */
  async getValidAccessToken(): Promise<string | null> {
    let tokens = this.getTokens();

    if (!tokens) {
      // Try to refresh
      tokens = await this.refreshTokens();
    }

    return tokens?.accessToken || null;
  }
}

// Export singleton
export const TraktAuth = new TraktAuthClass();
