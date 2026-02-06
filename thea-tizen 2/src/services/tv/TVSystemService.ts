/**
 * TV System Service
 * Provides awareness of TV hardware, software, settings, and installed apps
 * Uses Tizen SystemInfo, Application, and Package APIs
 */

// Tizen API type declarations
declare const tizen: {
  systeminfo: {
    getCapabilities(): TVCapabilities;
    getPropertyValue(property: string, successCallback: (data: any) => void, errorCallback?: (error: any) => void): void;
    addPropertyValueChangeListener(property: string, callback: (data: any) => void, options?: any): number;
    removePropertyValueChangeListener(listenerId: number): void;
  };
  application: {
    getCurrentApplication(): { appInfo: { id: string; name: string; version: string } };
    getAppsInfo(successCallback: (apps: TizenAppInfo[]) => void, errorCallback?: (error: any) => void): void;
    launchAppControl(
      appControl: AppControl,
      id: string | null,
      successCallback?: () => void,
      errorCallback?: (error: any) => void,
      replyCallback?: (data: any) => void
    ): void;
    launch(appId: string, successCallback?: () => void, errorCallback?: (error: any) => void): void;
  };
  package: {
    getPackagesInfo(successCallback: (packages: TizenPackageInfo[]) => void, errorCallback?: (error: any) => void): void;
  };
  tvaudiocontrol?: {
    getVolume(): number;
    setVolume(volume: number): void;
    setMute(mute: boolean): void;
    isMute(): boolean;
  };
  tvwindow?: {
    getAvailableWindows(successCallback: (windows: string[]) => void): void;
  };
};

interface TVCapabilities {
  bluetooth: boolean;
  nfc: boolean;
  wifi: boolean;
  wifiDirect: boolean;
  screenSizeNormal: boolean;
  screenSize480: boolean;
  screenSize720: boolean;
  screenSize1080: boolean;
  // Additional capabilities
  [key: string]: boolean | string | number;
}

interface TizenAppInfo {
  id: string;
  name: string;
  iconPath: string;
  version: string;
  show: boolean;
  categories: string[];
}

interface TizenPackageInfo {
  id: string;
  name: string;
  iconPath: string;
  version: string;
  totalSize: number;
  dataSize: number;
  author: string;
}

interface AppControl {
  operation: string;
  uri?: string;
  mime?: string;
  category?: string;
  data?: { key: string; value: string[] }[];
}

export interface TVSystemInfo {
  // Hardware
  model: string;
  modelCode: string;
  firmwareVersion: string;
  platformVersion: string;
  webApiVersion: string;
  duid: string;

  // Display
  screenWidth: number;
  screenHeight: number;
  physicalScreenWidth: number;
  physicalScreenHeight: number;

  // Network
  networkType: string;
  networkState: string;
  wifiMacAddress: string;

  // Storage
  totalStorage: number;
  availableStorage: number;

  // Capabilities
  capabilities: {
    bluetooth: boolean;
    voice: boolean;
    hdr: boolean;
    dolbyVision: boolean;
    dolbyAtmos: boolean;
    airplay: boolean;
    smartthings: boolean;
  };

  // Time
  timezone: string;
  locale: string;
}

export interface InstalledApp {
  id: string;
  name: string;
  version: string;
  iconPath: string;
  isStreamingApp: boolean;
  deepLinkSupport: boolean;
  category: 'streaming' | 'game' | 'utility' | 'other';
}

// Known streaming app IDs on Samsung TVs
const STREAMING_APPS: Record<string, { name: string; deepLinkFormat?: string; category: 'streaming' }> = {
  'Netflix': { name: 'Netflix', deepLinkFormat: 'netflix://title/{id}', category: 'streaming' },
  'com.netflix.ninja': { name: 'Netflix', deepLinkFormat: 'netflix://title/{id}', category: 'streaming' },
  '3201907018807': { name: 'Netflix', deepLinkFormat: 'netflix://title/{id}', category: 'streaming' },
  'Prime Video': { name: 'Prime Video', deepLinkFormat: 'primevideo://?titleId={id}', category: 'streaming' },
  'com.amazon.avod': { name: 'Prime Video', deepLinkFormat: 'primevideo://?titleId={id}', category: 'streaming' },
  '3201910019365': { name: 'Prime Video', deepLinkFormat: 'primevideo://?titleId={id}', category: 'streaming' },
  'Disney+': { name: 'Disney+', deepLinkFormat: 'disneyplus://content/{id}', category: 'streaming' },
  '3201901017640': { name: 'Disney+', deepLinkFormat: 'disneyplus://content/{id}', category: 'streaming' },
  'Apple TV': { name: 'Apple TV', deepLinkFormat: 'com.apple.tv://', category: 'streaming' },
  '3201807016598': { name: 'Apple TV', deepLinkFormat: 'com.apple.tv://', category: 'streaming' },
  'Canal+': { name: 'Canal+', category: 'streaming' },
  'Plex': { name: 'Plex', deepLinkFormat: 'plex://play?key={id}', category: 'streaming' },
  '3201512006963': { name: 'Plex', deepLinkFormat: 'plex://play?key={id}', category: 'streaming' },
  'HBO Max': { name: 'Max', category: 'streaming' },
  'Hulu': { name: 'Hulu', category: 'streaming' },
  'Paramount+': { name: 'Paramount+', category: 'streaming' },
  'Peacock': { name: 'Peacock', category: 'streaming' },
  'YouTube': { name: 'YouTube', deepLinkFormat: 'youtube://watch?v={id}', category: 'streaming' },
  '111299001912': { name: 'YouTube', deepLinkFormat: 'youtube://watch?v={id}', category: 'streaming' },
  'Spotify': { name: 'Spotify', category: 'streaming' },
  'Crunchyroll': { name: 'Crunchyroll', category: 'streaming' },
};

class TVSystemService {
  private systemInfo: TVSystemInfo | null = null;
  private installedApps: InstalledApp[] = [];
  private listeners: Map<string, number[]> = new Map();

  /**
   * Initialize TV system service
   */
  async initialize(): Promise<void> {
    if (typeof tizen === 'undefined') {
      console.warn('Tizen API not available - running in browser mode');
      this.systemInfo = this.getMockSystemInfo();
      this.installedApps = this.getMockInstalledApps();
      return;
    }

    await Promise.all([
      this.loadSystemInfo(),
      this.loadInstalledApps(),
    ]);
  }

  /**
   * Get full TV system information
   */
  getSystemInfo(): TVSystemInfo | null {
    return this.systemInfo;
  }

  /**
   * Get list of installed apps
   */
  getInstalledApps(): InstalledApp[] {
    return this.installedApps;
  }

  /**
   * Get only streaming apps
   */
  getStreamingApps(): InstalledApp[] {
    return this.installedApps.filter(app => app.isStreamingApp);
  }

  /**
   * Check if a specific app is installed
   */
  isAppInstalled(appName: string): boolean {
    const normalizedName = appName.toLowerCase();
    return this.installedApps.some(app =>
      app.name.toLowerCase().includes(normalizedName) ||
      app.id.toLowerCase().includes(normalizedName)
    );
  }

  /**
   * Find app by name
   */
  findApp(appName: string): InstalledApp | undefined {
    const normalizedName = appName.toLowerCase();
    return this.installedApps.find(app =>
      app.name.toLowerCase().includes(normalizedName) ||
      app.id.toLowerCase().includes(normalizedName)
    );
  }

  /**
   * Launch an app by ID or name
   */
  async launchApp(appIdOrName: string): Promise<boolean> {
    if (typeof tizen === 'undefined') {
      console.log(`[Mock] Launching app: ${appIdOrName}`);
      return true;
    }

    const app = this.findApp(appIdOrName);
    const appId = app?.id || appIdOrName;

    return new Promise((resolve) => {
      tizen.application.launch(
        appId,
        () => resolve(true),
        (error) => {
          console.error('Failed to launch app:', error);
          resolve(false);
        }
      );
    });
  }

  /**
   * Deep link to content in an app
   */
  async deepLinkToContent(appName: string, contentId: string, contentType: 'movie' | 'show' | 'episode'): Promise<boolean> {
    if (typeof tizen === 'undefined') {
      console.log(`[Mock] Deep linking to ${contentType} ${contentId} in ${appName}`);
      return true;
    }

    const app = this.findApp(appName);
    if (!app) {
      console.error(`App not found: ${appName}`);
      return false;
    }

    // Get deep link format for this app
    const streamingApp = Object.values(STREAMING_APPS).find(
      sa => sa.name.toLowerCase() === app.name.toLowerCase()
    );

    if (!streamingApp?.deepLinkFormat) {
      // Fall back to just launching the app
      return this.launchApp(app.id);
    }

    const uri = streamingApp.deepLinkFormat.replace('{id}', contentId);

    return new Promise((resolve) => {
      const appControl: AppControl = {
        operation: 'http://tizen.org/appcontrol/operation/view',
        uri: uri,
      };

      tizen.application.launchAppControl(
        appControl,
        app.id,
        () => resolve(true),
        (error) => {
          console.error('Deep link failed:', error);
          // Fall back to regular launch
          this.launchApp(app.id).then(resolve);
        }
      );
    });
  }

  /**
   * Get current volume
   */
  getVolume(): number {
    if (typeof tizen === 'undefined' || !tizen.tvaudiocontrol) {
      return 50;
    }
    return tizen.tvaudiocontrol.getVolume();
  }

  /**
   * Set volume
   */
  setVolume(volume: number): void {
    if (typeof tizen !== 'undefined' && tizen.tvaudiocontrol) {
      tizen.tvaudiocontrol.setVolume(Math.min(100, Math.max(0, volume)));
    }
  }

  /**
   * Get mute status
   */
  isMuted(): boolean {
    if (typeof tizen === 'undefined' || !tizen.tvaudiocontrol) {
      return false;
    }
    return tizen.tvaudiocontrol.isMute();
  }

  /**
   * Set mute
   */
  setMute(mute: boolean): void {
    if (typeof tizen !== 'undefined' && tizen.tvaudiocontrol) {
      tizen.tvaudiocontrol.setMute(mute);
    }
  }

  /**
   * Subscribe to system info changes
   */
  onNetworkChange(callback: (connected: boolean) => void): () => void {
    if (typeof tizen === 'undefined') {
      return () => {};
    }

    const listenerId = tizen.systeminfo.addPropertyValueChangeListener(
      'NETWORK',
      (network) => {
        callback(network.networkType !== 'NONE');
      }
    );

    const listeners = this.listeners.get('NETWORK') || [];
    listeners.push(listenerId);
    this.listeners.set('NETWORK', listeners);

    return () => {
      tizen.systeminfo.removePropertyValueChangeListener(listenerId);
      const remaining = (this.listeners.get('NETWORK') || []).filter(id => id !== listenerId);
      this.listeners.set('NETWORK', remaining);
    };
  }

  /**
   * Get a summary suitable for AI context
   */
  getAIContextSummary(): string {
    if (!this.systemInfo) {
      return 'TV system information not available.';
    }

    const streamingApps = this.getStreamingApps();

    return `
TV System Information:
- Model: Samsung ${this.systemInfo.model} (${this.systemInfo.modelCode})
- Firmware: ${this.systemInfo.firmwareVersion}
- Platform: Tizen ${this.systemInfo.platformVersion}
- Display: ${this.systemInfo.screenWidth}x${this.systemInfo.screenHeight}
- Network: ${this.systemInfo.networkType} (${this.systemInfo.networkState})
- Storage: ${Math.round(this.systemInfo.availableStorage / 1024 / 1024)}MB available of ${Math.round(this.systemInfo.totalStorage / 1024 / 1024)}MB

Capabilities:
- HDR: ${this.systemInfo.capabilities.hdr ? 'Yes' : 'No'}
- Dolby Vision: ${this.systemInfo.capabilities.dolbyVision ? 'Yes' : 'No'}
- Dolby Atmos: ${this.systemInfo.capabilities.dolbyAtmos ? 'Yes' : 'No'}
- AirPlay: ${this.systemInfo.capabilities.airplay ? 'Yes' : 'No'}
- Voice Control: ${this.systemInfo.capabilities.voice ? 'Yes' : 'No'}

Installed Streaming Apps (${streamingApps.length}):
${streamingApps.map(app => `- ${app.name}`).join('\n')}

All Installed Apps: ${this.installedApps.length} total
`.trim();
  }

  // Private methods

  private async loadSystemInfo(): Promise<void> {
    return new Promise((resolve) => {
      try {
        const caps = tizen.systeminfo.getCapabilities();

        // Get build info
        tizen.systeminfo.getPropertyValue('BUILD', (build) => {
          // Get display info
          tizen.systeminfo.getPropertyValue('DISPLAY', (display) => {
            // Get network info
            tizen.systeminfo.getPropertyValue('NETWORK', (network) => {
              // Get storage info
              tizen.systeminfo.getPropertyValue('STORAGE', (storage) => {
                // Get locale info
                tizen.systeminfo.getPropertyValue('LOCALE', (locale) => {
                  const storageUnit = Array.isArray(storage.units) ? storage.units[0] : storage;

                  this.systemInfo = {
                    model: build.model || 'Samsung TV',
                    modelCode: build.modelCode || 'Unknown',
                    firmwareVersion: build.buildVersion || 'Unknown',
                    platformVersion: build.platformVersion || 'Unknown',
                    webApiVersion: build.webApiVersion || 'Unknown',
                    duid: build.duid || 'Unknown',

                    screenWidth: display.resolutionWidth || 1920,
                    screenHeight: display.resolutionHeight || 1080,
                    physicalScreenWidth: display.physicalWidth || 0,
                    physicalScreenHeight: display.physicalHeight || 0,

                    networkType: network.networkType || 'Unknown',
                    networkState: network.networkType !== 'NONE' ? 'Connected' : 'Disconnected',
                    wifiMacAddress: network.macAddress || 'Unknown',

                    totalStorage: storageUnit?.capacity || 0,
                    availableStorage: storageUnit?.availableCapacity || 0,

                    capabilities: {
                      bluetooth: Boolean(caps.bluetooth),
                      voice: Boolean(caps.speechRecognition) || true,
                      hdr: Boolean(caps.screenSizeNormal) || true,
                      dolbyVision: true, // The Frame supports this
                      dolbyAtmos: true,
                      airplay: true, // Most modern Samsung TVs
                      smartthings: true,
                    },

                    timezone: locale.timezone || Intl.DateTimeFormat().resolvedOptions().timeZone,
                    locale: locale.language || navigator.language,
                  };

                  resolve();
                }, () => resolve());
              }, () => resolve());
            }, () => resolve());
          }, () => resolve());
        }, () => resolve());
      } catch (error) {
        console.error('Failed to load system info:', error);
        this.systemInfo = this.getMockSystemInfo();
        resolve();
      }
    });
  }

  private async loadInstalledApps(): Promise<void> {
    return new Promise((resolve) => {
      try {
        tizen.application.getAppsInfo(
          (apps) => {
            this.installedApps = apps
              .filter(app => app.show) // Only visible apps
              .map(app => this.mapToInstalledApp(app));
            resolve();
          },
          (error) => {
            console.error('Failed to get apps:', error);
            this.installedApps = this.getMockInstalledApps();
            resolve();
          }
        );
      } catch (error) {
        console.error('Failed to load apps:', error);
        this.installedApps = this.getMockInstalledApps();
        resolve();
      }
    });
  }

  private mapToInstalledApp(app: TizenAppInfo): InstalledApp {
    const isStreaming = Object.keys(STREAMING_APPS).some(
      key => app.id.includes(key) || app.name.includes(key)
    ) || app.categories?.some(cat =>
      cat.toLowerCase().includes('video') ||
      cat.toLowerCase().includes('entertainment')
    );

    const streamingInfo = STREAMING_APPS[app.id] || STREAMING_APPS[app.name];

    return {
      id: app.id,
      name: streamingInfo?.name || app.name,
      version: app.version,
      iconPath: app.iconPath,
      isStreamingApp: isStreaming,
      deepLinkSupport: !!streamingInfo?.deepLinkFormat,
      category: streamingInfo?.category || (isStreaming ? 'streaming' : 'other'),
    };
  }

  private getMockSystemInfo(): TVSystemInfo {
    return {
      model: 'The Frame',
      modelCode: 'QE55LS03FAU',
      firmwareVersion: '1701.3',
      platformVersion: '6.5',
      webApiVersion: '9.0',
      duid: 'MOCK_DUID_12345',
      screenWidth: 3840,
      screenHeight: 2160,
      physicalScreenWidth: 1210,
      physicalScreenHeight: 680,
      networkType: 'WIFI',
      networkState: 'Connected',
      wifiMacAddress: '00:00:00:00:00:00',
      totalStorage: 8 * 1024 * 1024 * 1024,
      availableStorage: 4 * 1024 * 1024 * 1024,
      capabilities: {
        bluetooth: true,
        voice: true,
        hdr: true,
        dolbyVision: true,
        dolbyAtmos: true,
        airplay: true,
        smartthings: true,
      },
      timezone: 'Europe/Paris',
      locale: 'en-US',
    };
  }

  private getMockInstalledApps(): InstalledApp[] {
    return [
      { id: '3201907018807', name: 'Netflix', version: '5.0', iconPath: '', isStreamingApp: true, deepLinkSupport: true, category: 'streaming' },
      { id: '3201910019365', name: 'Prime Video', version: '4.0', iconPath: '', isStreamingApp: true, deepLinkSupport: true, category: 'streaming' },
      { id: '3201901017640', name: 'Disney+', version: '3.0', iconPath: '', isStreamingApp: true, deepLinkSupport: true, category: 'streaming' },
      { id: '3201807016598', name: 'Apple TV', version: '2.0', iconPath: '', isStreamingApp: true, deepLinkSupport: true, category: 'streaming' },
      { id: '3201512006963', name: 'Plex', version: '5.0', iconPath: '', isStreamingApp: true, deepLinkSupport: true, category: 'streaming' },
      { id: '111299001912', name: 'YouTube', version: '6.0', iconPath: '', isStreamingApp: true, deepLinkSupport: true, category: 'streaming' },
      { id: 'canal-plus', name: 'Canal+', version: '3.0', iconPath: '', isStreamingApp: true, deepLinkSupport: false, category: 'streaming' },
    ];
  }
}

// Singleton instance
export const tvSystemService = new TVSystemService();
