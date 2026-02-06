/**
 * Home Assistant Integration Service
 *
 * Integrates with Home Assistant for ambient automation:
 * - Dim lights when playback starts
 * - Restore lights when paused/stopped
 * - Sync light colors with content (ambient mode)
 * - Control other devices (TV power, sound system)
 *
 * Uses Home Assistant REST API and webhooks.
 *
 * @see https://www.home-assistant.io/integrations/api/
 * @see https://www.kyleniewiada.org/blog/2018/10/dimming-lights-with-plex-and-homeassistant/
 */

// ============================================================
// TYPES
// ============================================================

export interface HomeAssistantConfig {
  url: string;
  accessToken: string;
  enabled: boolean;
  // Automation settings
  dimOnPlay: boolean;
  restoreOnPause: boolean;
  restoreOnStop: boolean;
  // Target lights
  targetLights: string[]; // Entity IDs like 'light.living_room'
  // Brightness levels (0-255)
  playingBrightness: number;
  pausedBrightness: number;
  stoppedBrightness: number;
  // Transition time in seconds
  transitionTime: number;
}

export interface HAState {
  entity_id: string;
  state: string;
  attributes: Record<string, any>;
  last_changed: string;
  last_updated: string;
}

export interface HALight extends HAState {
  attributes: {
    brightness?: number;
    color_temp?: number;
    rgb_color?: [number, number, number];
    hs_color?: [number, number];
    effect?: string;
    friendly_name?: string;
    supported_color_modes?: string[];
  };
}

export interface HAScene {
  entity_id: string;
  name: string;
}

export interface MediaState {
  state: 'playing' | 'paused' | 'stopped' | 'idle';
  title?: string;
  mediaType?: 'movie' | 'episode';
  thumbnail?: string;
}

// ============================================================
// CONSTANTS
// ============================================================

const CONFIG_KEY = 'thea_homeassistant_config';
const SAVED_STATES_KEY = 'thea_ha_saved_states';

const DEFAULT_CONFIG: HomeAssistantConfig = {
  url: '',
  accessToken: '',
  enabled: false,
  dimOnPlay: true,
  restoreOnPause: true,
  restoreOnStop: true,
  targetLights: [],
  playingBrightness: 25, // 10%
  pausedBrightness: 128, // 50%
  stoppedBrightness: 255, // 100%
  transitionTime: 2,
};

// ============================================================
// SERVICE
// ============================================================

class HomeAssistantService {
  private static instance: HomeAssistantService;

  private config: HomeAssistantConfig;
  private savedLightStates: Map<string, HALight> = new Map();
  private currentMediaState: MediaState = { state: 'idle' };

  private constructor() {
    this.config = this.loadConfig();
    this.loadSavedStates();
  }

  static getInstance(): HomeAssistantService {
    if (!HomeAssistantService.instance) {
      HomeAssistantService.instance = new HomeAssistantService();
    }
    return HomeAssistantService.instance;
  }

  // ============================================================
  // CONFIGURATION
  // ============================================================

  private loadConfig(): HomeAssistantConfig {
    try {
      const saved = localStorage.getItem(CONFIG_KEY);
      if (saved) {
        return { ...DEFAULT_CONFIG, ...JSON.parse(saved) };
      }
    } catch { /* ignore */ }
    return { ...DEFAULT_CONFIG };
  }

  saveConfig(config: Partial<HomeAssistantConfig>): void {
    this.config = { ...this.config, ...config };
    localStorage.setItem(CONFIG_KEY, JSON.stringify(this.config));
  }

  getConfig(): HomeAssistantConfig {
    return { ...this.config };
  }

  // ============================================================
  // CONNECTION
  // ============================================================

  /**
   * Test connection to Home Assistant
   */
  async testConnection(): Promise<{ success: boolean; version?: string; error?: string }> {
    if (!this.config.url || !this.config.accessToken) {
      return { success: false, error: 'Not configured' };
    }

    try {
      const response = await this.fetch('/api/');
      const data = await response.json() as { message: string };
      return { success: true, version: data.message };
    } catch (error) {
      return { success: false, error: error instanceof Error ? error.message : 'Unknown error' };
    }
  }

  /**
   * Make an authenticated request to Home Assistant
   */
  private async fetch(endpoint: string, options: RequestInit = {}): Promise<Response> {
    const url = `${this.config.url}${endpoint}`;
    const response = await fetch(url, {
      ...options,
      headers: {
        'Authorization': `Bearer ${this.config.accessToken}`,
        'Content-Type': 'application/json',
        ...options.headers,
      },
    });

    if (!response.ok) {
      throw new Error(`Home Assistant API error: ${response.status}`);
    }

    return response;
  }

  // ============================================================
  // ENTITIES
  // ============================================================

  /**
   * Get all light entities
   */
  async getLights(): Promise<HALight[]> {
    const response = await this.fetch('/api/states');
    const states = await response.json() as HAState[];
    return states.filter(s => s.entity_id.startsWith('light.')) as HALight[];
  }

  /**
   * Get a specific entity state
   */
  async getState(entityId: string): Promise<HAState> {
    const response = await this.fetch(`/api/states/${entityId}`);
    return await response.json() as HAState;
  }

  /**
   * Get all scenes
   */
  async getScenes(): Promise<HAScene[]> {
    const response = await this.fetch('/api/states');
    const states = await response.json() as HAState[];
    return states
      .filter(s => s.entity_id.startsWith('scene.'))
      .map(s => ({
        entity_id: s.entity_id,
        name: s.attributes.friendly_name || s.entity_id,
      }));
  }

  // ============================================================
  // LIGHT CONTROL
  // ============================================================

  /**
   * Turn on a light with optional brightness/color
   */
  async turnOnLight(entityId: string, options?: {
    brightness?: number;
    rgbColor?: [number, number, number];
    colorTemp?: number;
    transition?: number;
  }): Promise<void> {
    const data: Record<string, any> = { entity_id: entityId };

    if (options?.brightness !== undefined) data.brightness = options.brightness;
    if (options?.rgbColor) data.rgb_color = options.rgbColor;
    if (options?.colorTemp) data.color_temp = options.colorTemp;
    if (options?.transition !== undefined) data.transition = options.transition;

    await this.fetch('/api/services/light/turn_on', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  /**
   * Turn off a light
   */
  async turnOffLight(entityId: string, transition?: number): Promise<void> {
    const data: Record<string, any> = { entity_id: entityId };
    if (transition !== undefined) data.transition = transition;

    await this.fetch('/api/services/light/turn_off', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  /**
   * Set brightness for multiple lights
   */
  async setLightsBrightness(brightness: number, transition?: number): Promise<void> {
    for (const entityId of this.config.targetLights) {
      try {
        if (brightness === 0) {
          await this.turnOffLight(entityId, transition ?? this.config.transitionTime);
        } else {
          await this.turnOnLight(entityId, {
            brightness,
            transition: transition ?? this.config.transitionTime,
          });
        }
      } catch (error) {
        console.warn(`HomeAssistant: Failed to control ${entityId}`, error);
      }
    }
  }

  /**
   * Activate a scene
   */
  async activateScene(sceneId: string): Promise<void> {
    await this.fetch('/api/services/scene/turn_on', {
      method: 'POST',
      body: JSON.stringify({ entity_id: sceneId }),
    });
  }

  // ============================================================
  // MEDIA AUTOMATION
  // ============================================================

  /**
   * Handle media playback state change
   * Call this when Plex/content starts, pauses, or stops
   */
  async handleMediaStateChange(newState: MediaState): Promise<void> {
    if (!this.config.enabled) return;

    const previousState = this.currentMediaState;
    this.currentMediaState = newState;

    console.log(`HomeAssistant: Media state changed from ${previousState.state} to ${newState.state}`);

    // Only act if state actually changed
    if (previousState.state === newState.state) return;

    switch (newState.state) {
      case 'playing':
        if (this.config.dimOnPlay) {
          // Save current light states before dimming
          await this.saveLightStates();
          // Dim lights
          await this.setLightsBrightness(this.config.playingBrightness);
        }
        break;

      case 'paused':
        if (this.config.restoreOnPause) {
          // Partially restore lights
          await this.setLightsBrightness(this.config.pausedBrightness);
        }
        break;

      case 'stopped':
      case 'idle':
        if (this.config.restoreOnStop) {
          // Fully restore lights to saved state
          await this.restoreLightStates();
        }
        break;
    }
  }

  /**
   * Save current light states
   */
  private async saveLightStates(): Promise<void> {
    this.savedLightStates.clear();

    for (const entityId of this.config.targetLights) {
      try {
        const state = await this.getState(entityId) as HALight;
        this.savedLightStates.set(entityId, state);
      } catch (error) {
        console.warn(`HomeAssistant: Failed to save state for ${entityId}`, error);
      }
    }

    this.persistSavedStates();
  }

  /**
   * Restore saved light states
   */
  private async restoreLightStates(): Promise<void> {
    for (const [entityId, savedState] of this.savedLightStates) {
      try {
        if (savedState.state === 'off') {
          await this.turnOffLight(entityId, this.config.transitionTime);
        } else {
          await this.turnOnLight(entityId, {
            brightness: savedState.attributes.brightness || 255,
            rgbColor: savedState.attributes.rgb_color,
            colorTemp: savedState.attributes.color_temp,
            transition: this.config.transitionTime,
          });
        }
      } catch (error) {
        console.warn(`HomeAssistant: Failed to restore ${entityId}`, error);
      }
    }

    this.savedLightStates.clear();
    this.persistSavedStates();
  }

  private persistSavedStates(): void {
    try {
      const data = Array.from(this.savedLightStates.entries());
      localStorage.setItem(SAVED_STATES_KEY, JSON.stringify(data));
    } catch { /* ignore */ }
  }

  private loadSavedStates(): void {
    try {
      const saved = localStorage.getItem(SAVED_STATES_KEY);
      if (saved) {
        const data = JSON.parse(saved) as Array<[string, HALight]>;
        this.savedLightStates = new Map(data);
      }
    } catch { /* ignore */ }
  }

  // ============================================================
  // AMBIENT LIGHTING
  // ============================================================

  /**
   * Extract dominant color from an image for ambient lighting
   * (Would need to use a canvas or external service)
   */
  async setAmbientFromImage(imageUrl: string): Promise<void> {
    // For now, use a neutral warm color
    // In a real implementation, extract colors from the movie poster/backdrop
    const warmWhite: [number, number, number] = [255, 180, 107];

    for (const entityId of this.config.targetLights) {
      try {
        await this.turnOnLight(entityId, {
          brightness: this.config.playingBrightness,
          rgbColor: warmWhite,
          transition: this.config.transitionTime,
        });
      } catch (error) {
        console.warn(`HomeAssistant: Failed to set ambient for ${entityId}`, error);
      }
    }
  }

  // ============================================================
  // WEBHOOKS
  // ============================================================

  /**
   * Create a webhook trigger URL for external integrations
   * (Plex, Tautulli, etc. can call this)
   */
  getWebhookUrl(action: 'play' | 'pause' | 'stop'): string | null {
    const syncBridge = localStorage.getItem('thea_sync_bridge_url');
    if (!syncBridge) return null;

    return `${syncBridge}/webhooks/homeassistant?action=${action}`;
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  /**
   * Quick action: Movie mode (dim all lights)
   */
  async activateMovieMode(): Promise<void> {
    await this.setLightsBrightness(this.config.playingBrightness);
  }

  /**
   * Quick action: Pause mode (partially restore)
   */
  async activatePauseMode(): Promise<void> {
    await this.setLightsBrightness(this.config.pausedBrightness);
  }

  /**
   * Quick action: Normal mode (full brightness)
   */
  async deactivateMovieMode(): Promise<void> {
    await this.setLightsBrightness(255);
  }
}

export const homeAssistantService = HomeAssistantService.getInstance();
