/**
 * Samsung TV Remote Control Hook
 * Handles all TV remote button interactions
 */

import { useEffect, useCallback, useRef } from 'react';
import { TVKeys, getKeyName } from '../config/keycodes';

export type TVKeyHandler = (keyCode: number, keyName: string) => boolean | void;

export interface TVRemoteHandlers {
  onUp?: () => void;
  onDown?: () => void;
  onLeft?: () => void;
  onRight?: () => void;
  onEnter?: () => void;
  onBack?: () => void;
  onRed?: () => void;
  onGreen?: () => void;
  onYellow?: () => void;
  onBlue?: () => void;
  onPlay?: () => void;
  onPause?: () => void;
  onStop?: () => void;
  onVoice?: () => void;
  onNumber?: (num: number) => void;
  onAny?: TVKeyHandler;
}

/**
 * Hook for handling Samsung TV remote control
 */
export function useTVRemote(handlers: TVRemoteHandlers, enabled = true): void {
  const handlersRef = useRef(handlers);
  handlersRef.current = handlers;

  const handleKeyDown = useCallback((event: KeyboardEvent) => {
    if (!enabled) return;

    const keyCode = event.keyCode;
    const keyName = getKeyName(keyCode);
    const h = handlersRef.current;

    // Check if custom handler wants to stop propagation
    if (h.onAny?.(keyCode, keyName) === false) {
      return;
    }

    // Prevent default for handled keys
    let handled = true;

    switch (keyCode) {
      // Navigation
      case TVKeys.UP:
        h.onUp?.();
        break;
      case TVKeys.DOWN:
        h.onDown?.();
        break;
      case TVKeys.LEFT:
        h.onLeft?.();
        break;
      case TVKeys.RIGHT:
        h.onRight?.();
        break;
      case TVKeys.ENTER:
        h.onEnter?.();
        break;
      case TVKeys.BACK:
        h.onBack?.();
        break;

      // Color buttons
      case TVKeys.RED:
        h.onRed?.();
        break;
      case TVKeys.GREEN:
        h.onGreen?.();
        break;
      case TVKeys.YELLOW:
        h.onYellow?.();
        break;
      case TVKeys.BLUE:
        h.onBlue?.();
        break;

      // Media controls
      case TVKeys.PLAY:
      case TVKeys.PLAY_PAUSE:
        h.onPlay?.();
        break;
      case TVKeys.PAUSE:
        h.onPause?.();
        break;
      case TVKeys.STOP:
        h.onStop?.();
        break;

      // Voice
      case TVKeys.VOICE:
        h.onVoice?.();
        break;

      // Number keys
      case TVKeys.NUM_0:
      case TVKeys.NUM_1:
      case TVKeys.NUM_2:
      case TVKeys.NUM_3:
      case TVKeys.NUM_4:
      case TVKeys.NUM_5:
      case TVKeys.NUM_6:
      case TVKeys.NUM_7:
      case TVKeys.NUM_8:
      case TVKeys.NUM_9:
        h.onNumber?.(keyCode - TVKeys.NUM_0);
        break;

      default:
        handled = false;
    }

    if (handled) {
      event.preventDefault();
      event.stopPropagation();
    }
  }, [enabled]);

  useEffect(() => {
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [handleKeyDown]);
}

/**
 * Hook for handling back button with exit confirmation
 */
export function useTVBackHandler(
  onBack?: () => void,
  exitOnDoubleBack = true
): void {
  const lastBackTime = useRef(0);
  const DOUBLE_BACK_THRESHOLD = 2000; // 2 seconds

  useTVRemote({
    onBack: () => {
      if (onBack) {
        onBack();
        return;
      }

      // Default: exit on double-back
      if (exitOnDoubleBack) {
        const now = Date.now();
        if (now - lastBackTime.current < DOUBLE_BACK_THRESHOLD) {
          // Exit app
          if (window.tizen?.application) {
            window.tizen.application.getCurrentApplication().exit();
          }
        } else {
          lastBackTime.current = now;
          // Could show "Press back again to exit" toast
        }
      }
    },
  });
}

/**
 * Hook for voice button activation
 */
export function useTVVoice(onVoiceActivate: () => void): void {
  useTVRemote({
    onVoice: onVoiceActivate,
    onBlue: onVoiceActivate, // Blue button also triggers voice
  });
}

/**
 * Hook for color button shortcuts
 */
export function useTVColorButtons(handlers: {
  red?: () => void;
  green?: () => void;
  yellow?: () => void;
  blue?: () => void;
}): void {
  useTVRemote({
    onRed: handlers.red,
    onGreen: handlers.green,
    onYellow: handlers.yellow,
    onBlue: handlers.blue,
  });
}
