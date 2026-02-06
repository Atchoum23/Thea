/**
 * Trakt OAuth Device Code Authentication Service
 *
 * Implements the device code flow for TV apps:
 * 1. Request device code from Trakt
 * 2. Display code + URL to user
 * 3. Poll for authorization
 * 4. Store access + refresh tokens
 *
 * Device code flow is ideal for TV apps where typing is difficult.
 *
 * @see https://trakt.docs.apiary.io/#reference/authentication-devices
 */

import { secureConfigService } from '../config/SecureConfigService';

// ============================================================
// TYPES
// ============================================================

export interface DeviceCode {
  device_code: string;
  user_code: string;
  verification_url: string;
  expires_in: number;
  interval: number;
}

export interface TraktTokens {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  created_at: number;
  token_type: string;
  scope: string;
}

export interface TraktUser {
  username: string;
  private: boolean;
  name: string;
  vip: boolean;
  vip_ep: boolean;
  ids: { slug: string };
  images?: {
    avatar?: { full: string };
  };
}

export type AuthState =
  | { status: 'idle' }
  | { status: 'requesting_code' }
  | { status: 'waiting_for_user'; deviceCode: DeviceCode; expiresAt: Date }
  | { status: 'polling' }
  | { status: 'success'; user: TraktUser }
  | { status: 'error'; error: string }
  | { status: 'expired' };

type AuthStateListener = (state: AuthState) => void;

// ============================================================
// CONSTANTS
// ============================================================

const TRAKT_API_URL = 'https://api.trakt.tv';
const STORAGE_KEY = 'thea_trakt_tokens';

// ============================================================
// SERVICE
// ============================================================

class TraktAuthService {
  private static instance: TraktAuthService;

  private tokens: TraktTokens | null = null;
  private user: TraktUser | null = null;
  private authState: AuthState = { status: 'idle' };
  private stateListeners: Set<AuthStateListener> = new Set();
  private pollInterval: ReturnType<typeof setInterval> | null = null;

  private constructor() {
    this.loadTokens();
  }

  static getInstance(): TraktAuthService {
    if (!TraktAuthService.instance) {
      TraktAuthService.instance = new TraktAuthService();
    }
    return TraktAuthService.instance;
  }

  // ============================================================
  // TOKEN MANAGEMENT
  // ============================================================

  private loadTokens(): void {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        this.tokens = JSON.parse(stored);
        // Validate token and fetch user
        this.validateAndRefreshToken();
      }
    } catch (error) {
      console.warn('TraktAuth: Failed to load tokens', error);
    }
  }

  private saveTokens(tokens: TraktTokens): void {
    this.tokens = tokens;
    localStorage.setItem(STORAGE_KEY, JSON.stringify(tokens));

    // Update SecureConfigService
    secureConfigService.setTrakt({
      accessToken: tokens.access_token,
      refreshToken: tokens.refresh_token,
    });
  }

  private clearTokens(): void {
    this.tokens = null;
    this.user = null;
    localStorage.removeItem(STORAGE_KEY);

    secureConfigService.setTrakt({
      accessToken: '',
      refreshToken: '',
    });
  }

  /**
   * Check if tokens are valid and refresh if needed
   */
  private async validateAndRefreshToken(): Promise<boolean> {
    if (!this.tokens) return false;

    // Check if token is expired (with 5 minute buffer)
    const expiresAt = (this.tokens.created_at + this.tokens.expires_in) * 1000;
    const isExpired = Date.now() > expiresAt - 5 * 60 * 1000;

    if (isExpired) {
      // Try to refresh
      const refreshed = await this.refreshToken();
      if (!refreshed) return false;
    }

    // Fetch user info to validate
    try {
      this.user = await this.fetchUser();
      this.setState({ status: 'success', user: this.user });
      return true;
    } catch (error) {
      console.warn('TraktAuth: Token validation failed', error);
      this.clearTokens();
      this.setState({ status: 'idle' });
      return false;
    }
  }

  /**
   * Refresh the access token
   */
  private async refreshToken(): Promise<boolean> {
    if (!this.tokens?.refresh_token) return false;

    const config = secureConfigService.getTrakt();
    if (!config.clientId || !config.clientSecret) {
      console.error('TraktAuth: Client ID and Secret required');
      return false;
    }

    try {
      const response = await fetch(`${TRAKT_API_URL}/oauth/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          refresh_token: this.tokens.refresh_token,
          client_id: config.clientId,
          client_secret: config.clientSecret,
          redirect_uri: 'urn:ietf:wg:oauth:2.0:oob',
          grant_type: 'refresh_token',
        }),
      });

      if (!response.ok) {
        throw new Error('Refresh token failed');
      }

      const tokens = await response.json() as TraktTokens;
      this.saveTokens(tokens);
      return true;
    } catch (error) {
      console.error('TraktAuth: Token refresh failed', error);
      this.clearTokens();
      return false;
    }
  }

  // ============================================================
  // DEVICE CODE FLOW
  // ============================================================

  /**
   * Start the device code authentication flow
   */
  async startDeviceAuth(): Promise<DeviceCode> {
    const config = secureConfigService.getTrakt();
    if (!config.clientId) {
      throw new Error('Trakt Client ID not configured');
    }

    this.setState({ status: 'requesting_code' });

    try {
      const response = await fetch(`${TRAKT_API_URL}/oauth/device/code`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          client_id: config.clientId,
        }),
      });

      if (!response.ok) {
        throw new Error(`Failed to get device code: ${response.status}`);
      }

      const deviceCode = await response.json() as DeviceCode;

      // Calculate expiration time
      const expiresAt = new Date(Date.now() + deviceCode.expires_in * 1000);

      this.setState({
        status: 'waiting_for_user',
        deviceCode,
        expiresAt,
      });

      // Start polling for authorization
      this.startPolling(deviceCode);

      return deviceCode;
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      this.setState({ status: 'error', error: message });
      throw error;
    }
  }

  /**
   * Poll for user authorization
   */
  private startPolling(deviceCode: DeviceCode): void {
    // Clear any existing poll
    this.stopPolling();

    const config = secureConfigService.getTrakt();
    if (!config.clientId || !config.clientSecret) {
      this.setState({ status: 'error', error: 'Client credentials not configured' });
      return;
    }

    const expiresAt = Date.now() + deviceCode.expires_in * 1000;
    const interval = deviceCode.interval * 1000; // Convert to ms

    this.pollInterval = setInterval(async () => {
      // Check if expired
      if (Date.now() > expiresAt) {
        this.stopPolling();
        this.setState({ status: 'expired' });
        return;
      }

      try {
        const response = await fetch(`${TRAKT_API_URL}/oauth/device/token`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            code: deviceCode.device_code,
            client_id: config.clientId,
            client_secret: config.clientSecret,
          }),
        });

        if (response.status === 200) {
          // Success!
          this.stopPolling();
          const tokens = await response.json() as TraktTokens;
          this.saveTokens(tokens);

          // Fetch user info
          this.user = await this.fetchUser();
          this.setState({ status: 'success', user: this.user });
        } else if (response.status === 400) {
          // Still waiting for user
          // Keep polling
        } else if (response.status === 404) {
          // Invalid device code
          this.stopPolling();
          this.setState({ status: 'error', error: 'Invalid device code' });
        } else if (response.status === 409) {
          // Code already used
          this.stopPolling();
          this.setState({ status: 'error', error: 'Code already used' });
        } else if (response.status === 410) {
          // Expired
          this.stopPolling();
          this.setState({ status: 'expired' });
        } else if (response.status === 418) {
          // User denied
          this.stopPolling();
          this.setState({ status: 'error', error: 'Authorization denied by user' });
        } else if (response.status === 429) {
          // Rate limited - slow down
          console.warn('TraktAuth: Rate limited, slowing down polling');
        }
      } catch (error) {
        console.warn('TraktAuth: Poll error', error);
        // Continue polling on network errors
      }
    }, interval);
  }

  /**
   * Stop polling
   */
  private stopPolling(): void {
    if (this.pollInterval) {
      clearInterval(this.pollInterval);
      this.pollInterval = null;
    }
  }

  /**
   * Cancel authentication
   */
  cancelAuth(): void {
    this.stopPolling();
    this.setState({ status: 'idle' });
  }

  // ============================================================
  // API HELPERS
  // ============================================================

  /**
   * Fetch current user info
   */
  private async fetchUser(): Promise<TraktUser> {
    const response = await this.authenticatedFetch('/users/me?extended=full');
    return await response.json() as TraktUser;
  }

  /**
   * Make an authenticated API request
   */
  async authenticatedFetch(endpoint: string, options: RequestInit = {}): Promise<Response> {
    if (!this.tokens) {
      throw new Error('Not authenticated');
    }

    const config = secureConfigService.getTrakt();

    const response = await fetch(`${TRAKT_API_URL}${endpoint}`, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': config.clientId,
        'Authorization': `Bearer ${this.tokens.access_token}`,
        ...options.headers,
      },
    });

    // Handle token expiration
    if (response.status === 401) {
      const refreshed = await this.refreshToken();
      if (refreshed) {
        // Retry the request
        return this.authenticatedFetch(endpoint, options);
      }
      throw new Error('Authentication expired');
    }

    return response;
  }

  // ============================================================
  // STATE MANAGEMENT
  // ============================================================

  private setState(state: AuthState): void {
    this.authState = state;
    for (const listener of this.stateListeners) {
      try {
        listener(state);
      } catch (error) {
        console.error('TraktAuth: State listener error', error);
      }
    }
  }

  getState(): AuthState {
    return this.authState;
  }

  onStateChange(listener: AuthStateListener): () => void {
    this.stateListeners.add(listener);
    // Immediately call with current state
    listener(this.authState);
    return () => this.stateListeners.delete(listener);
  }

  // ============================================================
  // PUBLIC API
  // ============================================================

  /**
   * Check if authenticated
   */
  isAuthenticated(): boolean {
    return this.tokens !== null && this.authState.status === 'success';
  }

  /**
   * Get current user
   */
  getUser(): TraktUser | null {
    return this.user;
  }

  /**
   * Get access token for API calls
   */
  getAccessToken(): string | null {
    return this.tokens?.access_token || null;
  }

  /**
   * Logout
   */
  async logout(): Promise<void> {
    this.stopPolling();

    // Revoke token if possible
    if (this.tokens) {
      const config = secureConfigService.getTrakt();
      try {
        await fetch(`${TRAKT_API_URL}/oauth/revoke`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            token: this.tokens.access_token,
            client_id: config.clientId,
            client_secret: config.clientSecret,
          }),
        });
      } catch (error) {
        console.warn('TraktAuth: Failed to revoke token', error);
      }
    }

    this.clearTokens();
    this.setState({ status: 'idle' });
  }

  /**
   * Scrobble (mark as watching)
   */
  async scrobbleStart(content: {
    type: 'movie' | 'episode';
    ids: { trakt?: number; imdb?: string; tmdb?: number; tvdb?: number };
    progress: number;
  }): Promise<void> {
    const body = content.type === 'movie'
      ? { movie: { ids: content.ids }, progress: content.progress }
      : { episode: { ids: content.ids }, progress: content.progress };

    await this.authenticatedFetch('/scrobble/start', {
      method: 'POST',
      body: JSON.stringify(body),
    });
  }

  /**
   * Scrobble pause
   */
  async scrobblePause(content: {
    type: 'movie' | 'episode';
    ids: { trakt?: number; imdb?: string; tmdb?: number; tvdb?: number };
    progress: number;
  }): Promise<void> {
    const body = content.type === 'movie'
      ? { movie: { ids: content.ids }, progress: content.progress }
      : { episode: { ids: content.ids }, progress: content.progress };

    await this.authenticatedFetch('/scrobble/pause', {
      method: 'POST',
      body: JSON.stringify(body),
    });
  }

  /**
   * Scrobble stop (marks as watched if > 80%)
   */
  async scrobbleStop(content: {
    type: 'movie' | 'episode';
    ids: { trakt?: number; imdb?: string; tmdb?: number; tvdb?: number };
    progress: number;
  }): Promise<void> {
    const body = content.type === 'movie'
      ? { movie: { ids: content.ids }, progress: content.progress }
      : { episode: { ids: content.ids }, progress: content.progress };

    await this.authenticatedFetch('/scrobble/stop', {
      method: 'POST',
      body: JSON.stringify(body),
    });
  }
}

export const traktAuthService = TraktAuthService.getInstance();
