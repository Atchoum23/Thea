/**
 * Thea Video Speed Controller - UI Module
 *
 * Speed overlay DOM, control bar construction, visual elements, styles.
 */

(function() {
  'use strict';

  window.TheaModules = window.TheaModules || {};

  // ============================================================================
  // Styles
  // ============================================================================

  function injectVideoStyles() {
    if (document.getElementById('thea-video-controller-styles')) return;

    const style = document.createElement('style');
    style.id = 'thea-video-controller-styles';
    style.textContent = `
      /* Speed Overlay */
      .thea-speed-overlay {
        position: absolute;
        top: 12px;
        left: 12px;
        background: rgba(0, 0, 0, 0.75);
        color: #fff;
        padding: 6px 14px;
        border-radius: 6px;
        font-family: -apple-system, BlinkMacSystemFont, 'SF Mono', 'Menlo', monospace;
        font-size: 15px;
        font-weight: 600;
        z-index: 2147483646;
        pointer-events: none;
        opacity: 0;
        transform: translateY(-4px);
        transition: opacity 0.15s ease, transform 0.15s ease;
        backdrop-filter: blur(8px);
        -webkit-backdrop-filter: blur(8px);
      }
      .thea-speed-overlay-visible {
        opacity: 1;
        transform: translateY(0);
      }

      /* Video Control Bar */
      .thea-video-controls {
        position: absolute;
        bottom: 60px;
        left: 50%;
        transform: translateX(-50%);
        background: rgba(20, 20, 20, 0.85);
        border-radius: 10px;
        padding: 6px 10px;
        z-index: 2147483646;
        opacity: 0;
        transform: translateX(-50%) translateY(8px);
        transition: opacity 0.2s ease, transform 0.2s ease;
        pointer-events: none;
        backdrop-filter: blur(12px);
        -webkit-backdrop-filter: blur(12px);
        border: 1px solid rgba(255, 255, 255, 0.1);
      }
      .thea-video-controls.thea-vc-visible {
        opacity: 1;
        transform: translateX(-50%) translateY(0);
        pointer-events: auto;
      }

      .thea-vc-row {
        display: flex;
        align-items: center;
        gap: 4px;
        white-space: nowrap;
      }

      .thea-vc-btn {
        background: transparent;
        border: none;
        color: #e0e0e0;
        cursor: pointer;
        padding: 5px 8px;
        border-radius: 6px;
        font-size: 12px;
        font-weight: 600;
        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
        display: flex;
        align-items: center;
        justify-content: center;
        min-width: 28px;
        height: 28px;
        transition: background 0.1s, color 0.1s;
      }
      .thea-vc-btn:hover {
        background: rgba(255, 255, 255, 0.15);
        color: #fff;
      }
      .thea-vc-btn:active {
        background: rgba(255, 255, 255, 0.25);
      }

      .thea-vc-speed {
        color: #4fc3f7;
        font-size: 13px;
        font-weight: 700;
        font-family: -apple-system, BlinkMacSystemFont, 'SF Mono', monospace;
        min-width: 48px;
        text-align: center;
        user-select: none;
      }

      .thea-vc-divider {
        width: 1px;
        height: 18px;
        background: rgba(255, 255, 255, 0.15);
        margin: 0 2px;
      }

      .thea-vc-time {
        color: #a0aec0;
        font-size: 11px;
        font-family: -apple-system, BlinkMacSystemFont, 'SF Mono', monospace;
        margin-left: 4px;
        min-width: 50px;
        text-align: right;
      }
    `;
    document.head.appendChild(style);
  }

  // ============================================================================
  // Speed Overlay
  // ============================================================================

  let overlayTimer = null;

  function showSpeedOverlay(video, speed, label, config) {
    const container = getVideoContainer(video);
    if (!container) return;

    let overlay = container.querySelector('.thea-speed-overlay');
    if (!overlay) {
      overlay = document.createElement('div');
      overlay.className = 'thea-speed-overlay';
      container.style.position = container.style.position || 'relative';
      container.appendChild(overlay);
    }

    overlay.textContent = label || `${speed.toFixed(2)}x`;
    overlay.classList.add('thea-speed-overlay-visible');

    clearTimeout(overlayTimer);
    overlayTimer = setTimeout(() => {
      overlay.classList.remove('thea-speed-overlay-visible');
    }, config?.overlayTimeout || 2000);
  }

  function showOverlayMessage(video, message, config) {
    showSpeedOverlay(video, 0, message, config);
  }

  // ============================================================================
  // Control Bar Construction
  // ============================================================================

  function buildControlBar() {
    const bar = document.createElement('div');
    bar.className = 'thea-video-controls';
    bar.innerHTML = `
      <div class="thea-vc-row">
        <button class="thea-vc-btn" data-action="speed-down" title="Slow down (S)">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <line x1="5" y1="12" x2="19" y2="12"/>
          </svg>
        </button>
        <span class="thea-vc-speed" title="Current speed">1.00x</span>
        <button class="thea-vc-btn" data-action="speed-up" title="Speed up (D)">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
          </svg>
        </button>
        <span class="thea-vc-divider"></span>
        <button class="thea-vc-btn" data-action="jump-back" title="Jump back">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="11 17 6 12 11 7"/><line x1="6" y1="12" x2="20" y2="12"/>
          </svg>
        </button>
        <button class="thea-vc-btn" data-action="play-pause" title="Play/Pause">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
            <polygon points="5 3 19 12 5 21 5 3"/>
          </svg>
        </button>
        <button class="thea-vc-btn" data-action="jump-fwd" title="Jump forward">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="13 17 18 12 13 7"/><line x1="4" y1="12" x2="18" y2="12"/>
          </svg>
        </button>
        <span class="thea-vc-divider"></span>
        <button class="thea-vc-btn" data-action="reset" title="Reset to 1x (R)">1x</button>
        <button class="thea-vc-btn" data-action="double" title="Toggle 2x (A)">2x</button>
        <span class="thea-vc-divider"></span>
        <button class="thea-vc-btn" data-action="pip" title="Picture-in-Picture (P)">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <rect x="2" y="3" width="20" height="14" rx="2"/><rect x="11" y="9" width="10" height="7" rx="1" fill="currentColor" opacity="0.3"/>
          </svg>
        </button>
        <span class="thea-vc-time"></span>
      </div>
    `;

    return bar;
  }

  // ============================================================================
  // Control Bar Updates
  // ============================================================================

  function updateSpeedDisplay(bar, speed) {
    const speedDisplay = bar.querySelector('.thea-vc-speed');
    if (speedDisplay) {
      speedDisplay.textContent = `${speed.toFixed(2)}x`;
    }
  }

  function updateTimeDisplay(video, bar) {
    const timeEl = bar.querySelector('.thea-vc-time');
    if (!timeEl || !isFinite(video.duration)) return;

    const remaining = video.duration - video.currentTime;
    const adjustedRemaining = remaining / video.playbackRate;
    timeEl.textContent = formatTime(adjustedRemaining);
    timeEl.title = `Remaining at ${video.playbackRate.toFixed(2)}x speed`;
  }

  // ============================================================================
  // Utility Functions
  // ============================================================================

  function getVideoContainer(video) {
    return video.closest('[class*="player"]') ||
           video.closest('[class*="video"]') ||
           video.closest('[id*="player"]') ||
           video.parentElement;
  }

  function formatTime(seconds) {
    if (!isFinite(seconds) || seconds < 0) return '--:--';
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = Math.floor(seconds % 60);
    if (h > 0) return `-${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
    return `-${m}:${String(s).padStart(2, '0')}`;
  }

  // ============================================================================
  // Export to shared namespace
  // ============================================================================

  window.TheaModules.videoUI = {
    injectVideoStyles,
    showSpeedOverlay,
    showOverlayMessage,
    buildControlBar,
    updateSpeedDisplay,
    updateTimeDisplay,
    getVideoContainer,
    formatTime
  };

})();
