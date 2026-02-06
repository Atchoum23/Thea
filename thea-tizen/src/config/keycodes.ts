/**
 * Samsung TV Remote Control Key Codes
 * These are the key codes used by Samsung Tizen TVs for remote control navigation
 */

export const TVKeys = {
  // Navigation keys
  UP: 38,
  DOWN: 40,
  LEFT: 37,
  RIGHT: 39,
  ENTER: 13,
  BACK: 10009,

  // Color buttons (for quick actions)
  RED: 403,      // Cancel / Delete
  GREEN: 404,    // Confirm / Check-in
  YELLOW: 405,   // Options menu
  BLUE: 406,     // Voice input / Info

  // Media controls
  PLAY: 415,
  PAUSE: 19,
  PLAY_PAUSE: 10252,
  STOP: 413,
  REWIND: 412,
  FAST_FORWARD: 417,

  // Voice
  VOICE: 10083,

  // Channel
  CHANNEL_UP: 427,
  CHANNEL_DOWN: 428,

  // Volume (usually handled by system, but can be captured)
  VOLUME_UP: 447,
  VOLUME_DOWN: 448,
  VOLUME_MUTE: 449,

  // Number keys (for PIN entry, quick navigation)
  NUM_0: 48,
  NUM_1: 49,
  NUM_2: 50,
  NUM_3: 51,
  NUM_4: 52,
  NUM_5: 53,
  NUM_6: 54,
  NUM_7: 55,
  NUM_8: 56,
  NUM_9: 57,

  // Additional Samsung keys
  EXIT: 10182,
  INFO: 457,
  MENU: 10133,
  SOURCE: 10072,
  GUIDE: 458,
  TOOLS: 10135,
  SEARCH: 10225,
} as const;

export type TVKeyCode = typeof TVKeys[keyof typeof TVKeys];

/**
 * Key names for Tizen InputDevice API registration
 * These must be registered before they can be captured
 */
export const TizenKeyNames = [
  'ColorF0Red',
  'ColorF1Green',
  'ColorF2Yellow',
  'ColorF3Blue',
  'MediaPlayPause',
  'MediaPlay',
  'MediaPause',
  'MediaStop',
  'MediaRewind',
  'MediaFastForward',
  'MediaTrackPrevious',
  'MediaTrackNext',
  'Info',
  'Exit',
  'Search',
  'Guide',
  'ChannelUp',
  'ChannelDown',
] as const;

/**
 * Register TV keys with Tizen InputDevice API
 * Call this on app initialization
 */
export function registerTVKeys(): void {
  // Check if running on Tizen
  if (typeof window !== 'undefined' && 'tizen' in window) {
    const tizen = (window as unknown as { tizen: TizenAPI }).tizen;

    if (tizen && tizen.tvinputdevice) {
      TizenKeyNames.forEach(keyName => {
        try {
          tizen.tvinputdevice!.registerKey(keyName);
        } catch (error) {
          console.warn(`Failed to register key: ${keyName}`, error);
        }
      });
      console.log('TV keys registered successfully');
    }
  } else {
    console.log('Not running on Tizen - TV keys not registered');
  }
}

/**
 * Unregister TV keys (call on app cleanup)
 */
export function unregisterTVKeys(): void {
  if (typeof window !== 'undefined' && 'tizen' in window) {
    const tizen = (window as unknown as { tizen: TizenAPI }).tizen;

    if (tizen && tizen.tvinputdevice) {
      TizenKeyNames.forEach(keyName => {
        try {
          tizen.tvinputdevice!.unregisterKey(keyName);
        } catch {
          // Ignore unregister errors
        }
      });
    }
  }
}

/**
 * Get human-readable name for a key code
 */
export function getKeyName(keyCode: number): string {
  const entry = Object.entries(TVKeys).find(([, code]) => code === keyCode);
  return entry ? entry[0] : `Unknown (${keyCode})`;
}

// Tizen API type declarations
interface TizenAPI {
  tvinputdevice?: {
    registerKey(keyName: string): void;
    unregisterKey(keyName: string): void;
    getSupportedKeys(): Array<{ name: string; code: number }>;
  };
  application?: {
    getCurrentApplication(): {
      exit(): void;
      hide(): void;
    };
  };
}

declare global {
  interface Window {
    tizen?: TizenAPI;
  }
}
