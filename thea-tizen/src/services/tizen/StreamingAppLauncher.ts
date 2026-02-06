/**
 * Samsung Tizen Streaming App Launcher
 *
 * Launches streaming apps on Samsung TV with the best available method.
 * Note: Deep linking to specific content is NOT supported by Samsung
 * for third-party apps like Netflix, Disney+, etc.
 *
 * We can:
 * - Launch the app
 * - Show a "Now playing on X" overlay with content info
 * - Let the user search within the app
 */

import { StreamingOption } from '../streaming/TMDBStreamingService';

export interface StreamingApp {
  id: string;
  name: string;
  // Samsung TV app IDs vary by TV year/region
  tizenAppIds: string[];
  // Icon for UI
  iconUrl?: string;
  // Can we deep link to content? (Usually no for major services)
  supportsDeepLink: boolean;
  // Search URL pattern (for web fallback)
  searchUrl?: string;
}

// Known Samsung TV app IDs
// These vary by TV model year and region - we try multiple
const STREAMING_APPS: StreamingApp[] = [
  {
    id: 'netflix',
    name: 'Netflix',
    tizenAppIds: ['11101200001', 'org.tizen.netflix-app', '3201907018807'],
    supportsDeepLink: false,
    searchUrl: 'https://www.netflix.com/search?q=',
  },
  {
    id: 'prime',
    name: 'Prime Video',
    tizenAppIds: ['3201512006785', 'org.tizen.ignition', '3201910019365'],
    supportsDeepLink: false,
    searchUrl: 'https://www.primevideo.com/search?phrase=',
  },
  {
    id: 'disney',
    name: 'Disney+',
    tizenAppIds: ['3201901017640', 'MCmYXNxgcu.DisneyPlus'],
    supportsDeepLink: false,
    searchUrl: 'https://www.disneyplus.com/search?q=',
  },
  {
    id: 'apple',
    name: 'Apple TV',
    tizenAppIds: ['3201807016597', 'com.apple.atve.samsung.webapp'],
    supportsDeepLink: false,
    searchUrl: 'https://tv.apple.com/search?term=',
  },
  {
    id: 'youtube',
    name: 'YouTube',
    tizenAppIds: ['111299001912', 'com.google.youtube.tv'],
    supportsDeepLink: true, // YouTube actually supports deep links!
    searchUrl: 'https://www.youtube.com/results?search_query=',
  },
  {
    id: 'plex',
    name: 'Plex',
    tizenAppIds: ['3201512006963', 'plex'],
    supportsDeepLink: true,
  },
  {
    id: 'hbo',
    name: 'Max (HBO)',
    tizenAppIds: ['3201601007230', '3201906018675'],
    supportsDeepLink: false,
  },
  {
    id: 'paramount',
    name: 'Paramount+',
    tizenAppIds: ['3201908019041'],
    supportsDeepLink: false,
  },
  {
    id: 'canal',
    name: 'Canal+',
    tizenAppIds: ['3201710015037', '3201807016582'],
    supportsDeepLink: false,
  },
  {
    id: 'canal_ch',
    name: 'Canal+ Switzerland',
    // Canal+ Switzerland app - includes HBO Max & Paramount+ content
    // Subscribed via Swisscom TV
    tizenAppIds: ['3201807016582', '3201710015037', 'vNYy4oCLix.canalplus'],
    supportsDeepLink: false,
    // Note: HBO Max and Paramount+ content accessible through this single app
    searchUrl: 'https://www.canalplus.ch/recherche/',
  },
  {
    id: 'swisscom',
    name: 'blue TV',
    tizenAppIds: ['3201803015934'], // Swisscom's own streaming
    supportsDeepLink: false,
    searchUrl: 'https://www.blue.ch/tv/',
  },
];

// Tizen Application API types (simplified)
declare const tizen: {
  application: {
    launch: (
      appId: string,
      successCallback?: () => void,
      errorCallback?: (error: Error) => void,
      appControl?: object
    ) => void;
    getAppsInfo: (
      successCallback: (apps: Array<{ id: string; name: string }>) => void,
      errorCallback?: (error: Error) => void
    ) => void;
  };
};

class StreamingAppLauncher {
  private static instance: StreamingAppLauncher;
  private installedApps: Set<string> = new Set();
  private initialized = false;

  private constructor() {}

  static getInstance(): StreamingAppLauncher {
    if (!StreamingAppLauncher.instance) {
      StreamingAppLauncher.instance = new StreamingAppLauncher();
    }
    return StreamingAppLauncher.instance;
  }

  /**
   * Initialize and detect installed apps
   */
  async initialize(): Promise<void> {
    if (this.initialized) return;

    // Check if running on Tizen
    if (typeof tizen === 'undefined') {
      console.log('StreamingAppLauncher: Not running on Tizen');
      this.initialized = true;
      return;
    }

    return new Promise((resolve) => {
      try {
        tizen.application.getAppsInfo(
          (apps) => {
            for (const app of apps) {
              this.installedApps.add(app.id);
            }
            console.log(`StreamingAppLauncher: Found ${this.installedApps.size} installed apps`);
            this.initialized = true;
            resolve();
          },
          (error) => {
            console.error('Failed to get installed apps:', error);
            this.initialized = true;
            resolve();
          }
        );
      } catch (error) {
        console.error('Tizen API error:', error);
        this.initialized = true;
        resolve();
      }
    });
  }

  /**
   * Get app info by our internal ID
   */
  getApp(appId: string): StreamingApp | undefined {
    return STREAMING_APPS.find(app => app.id === appId);
  }

  /**
   * Get app by TMDB provider ID
   * Note: For Switzerland, HBO Max (384/1899) and Paramount+ (531) are accessed
   * through Canal+ Switzerland app via Swisscom TV subscription
   */
  getAppByProviderId(providerId: number, region: string = 'CH'): StreamingApp | undefined {
    // Switzerland-specific: HBO Max & Paramount+ are bundled in Canal+ Switzerland
    if (region === 'CH') {
      const swissProviderMap: Record<number, string> = {
        8: 'netflix',
        9: 'prime',
        10: 'prime',
        337: 'disney',
        2: 'apple',
        350: 'apple',
        192: 'youtube',
        3: 'youtube',
        384: 'canal_ch',   // HBO Max → Canal+ Switzerland
        1899: 'canal_ch',  // Max → Canal+ Switzerland
        531: 'canal_ch',   // Paramount+ → Canal+ Switzerland
        381: 'canal_ch',   // Canal+ → Canal+ Switzerland
        1773: 'canal_ch',  // Canal+ Séries → Canal+ Switzerland
      };
      const appId = swissProviderMap[providerId];
      if (appId) return this.getApp(appId);
    }

    // Default provider mapping for other regions
    const providerMap: Record<number, string> = {
      8: 'netflix',
      9: 'prime',
      10: 'prime',
      337: 'disney',
      2: 'apple',
      350: 'apple',
      192: 'youtube',
      3: 'youtube',
      384: 'hbo',
      1899: 'hbo',
      531: 'paramount',
      381: 'canal',
    };

    const appId = providerMap[providerId];
    return appId ? this.getApp(appId) : undefined;
  }

  /**
   * Check if content on a provider is accessible via bundled service
   * E.g., HBO Max content in CH is accessible via Canal+ Switzerland
   */
  getBundledAccessInfo(providerId: number, region: string = 'CH'): {
    accessible: boolean;
    viaApp?: StreamingApp;
    originalProvider: string;
    note?: string;
  } | null {
    if (region !== 'CH') return null;

    const bundledProviders: Record<number, { name: string; note: string }> = {
      384: { name: 'HBO Max', note: 'Included with Canal+ Switzerland via Swisscom TV' },
      1899: { name: 'Max', note: 'Included with Canal+ Switzerland via Swisscom TV' },
      531: { name: 'Paramount+', note: 'Included with Canal+ Switzerland via Swisscom TV' },
    };

    const bundled = bundledProviders[providerId];
    if (bundled) {
      return {
        accessible: true,
        viaApp: this.getApp('canal_ch'),
        originalProvider: bundled.name,
        note: bundled.note,
      };
    }

    return null;
  }

  /**
   * Check if an app is installed
   */
  isAppInstalled(appId: string): boolean {
    const app = this.getApp(appId);
    if (!app) return false;

    return app.tizenAppIds.some(id => this.installedApps.has(id));
  }

  /**
   * Find the correct Tizen app ID for an app
   */
  private findInstalledAppId(app: StreamingApp): string | null {
    for (const tizenId of app.tizenAppIds) {
      if (this.installedApps.has(tizenId)) {
        return tizenId;
      }
    }
    // If not found, try the first one anyway (might work)
    return app.tizenAppIds[0];
  }

  /**
   * Launch a streaming app
   */
  async launchApp(appId: string): Promise<{ success: boolean; error?: string }> {
    const app = this.getApp(appId);
    if (!app) {
      return { success: false, error: 'Unknown app' };
    }

    if (typeof tizen === 'undefined') {
      // Not on Tizen - open web URL if available
      if (app.searchUrl) {
        window.open(app.searchUrl.replace(/\?.*$/, ''), '_blank');
        return { success: true };
      }
      return { success: false, error: 'Not running on Samsung TV' };
    }

    const tizenAppId = this.findInstalledAppId(app);
    if (!tizenAppId) {
      return { success: false, error: 'App not installed' };
    }

    return new Promise((resolve) => {
      try {
        tizen.application.launch(
          tizenAppId,
          () => {
            console.log(`Launched ${app.name}`);
            resolve({ success: true });
          },
          (error) => {
            console.error(`Failed to launch ${app.name}:`, error);
            resolve({ success: false, error: error.message });
          }
        );
      } catch (error) {
        resolve({
          success: false,
          error: error instanceof Error ? error.message : 'Launch failed',
        });
      }
    });
  }

  /**
   * Launch app for a specific streaming option
   * Shows content info since we can't deep link
   */
  async launchForContent(
    option: StreamingOption,
    contentTitle: string
  ): Promise<{ success: boolean; message: string }> {
    const app = this.getAppByProviderId(option.providerId);

    if (!app) {
      return {
        success: false,
        message: `Unknown streaming service: ${option.providerName}`,
      };
    }

    const result = await this.launchApp(app.id);

    if (result.success) {
      return {
        success: true,
        message: `Opened ${app.name}. Search for: "${contentTitle}"`,
      };
    }

    // Fallback: provide search URL
    if (app.searchUrl) {
      return {
        success: true,
        message: `Open on your phone: ${app.searchUrl}${encodeURIComponent(contentTitle)}`,
      };
    }

    return {
      success: false,
      message: result.error || 'Failed to open app',
    };
  }

  /**
   * Get all available streaming apps
   */
  getAvailableApps(): StreamingApp[] {
    return STREAMING_APPS.filter(app => this.isAppInstalled(app.id));
  }

  /**
   * Get all streaming apps (including not installed)
   */
  getAllApps(): StreamingApp[] {
    return [...STREAMING_APPS];
  }
}

export const streamingAppLauncher = StreamingAppLauncher.getInstance();
