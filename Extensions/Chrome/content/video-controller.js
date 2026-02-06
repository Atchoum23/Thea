/**
 * Thea Video Speed Controller
 *
 * Inspired by: Vidimote, Accelerate, Video Speed Controller
 *
 * Features:
 * - Playback speed control (0.1x - 16x) with 0.05x precision
 * - Persistent default speed per-site and global
 * - Keyboard shortcuts (fully customizable)
 * - On-video overlay with speed indicator
 * - Jump forward/backward with configurable intervals
 * - Picture-in-Picture support
 * - Adjusted time remaining display
 * - Length-based auto-speed rules
 * - AirPlay/Cast detection
 */

(function() {
  'use strict';

  // ============================================================================
  // Configuration
  // ============================================================================

  const DEFAULT_CONFIG = {
    enabled: true,
    defaultSpeed: 1.0,
    minSpeed: 0.1,
    maxSpeed: 16.0,
    speedStep: 0.1,
    fineSpeedStep: 0.05,
    jumpForward: 10,
    jumpBackward: 10,
    showOverlay: true,
    overlayPosition: 'top-left',
    overlayTimeout: 2000,
    rememberSpeed: true,
    siteSpeedPrefs: {},
    // Length-based rules (Speed Player feature)
    autoSpeedRules: [],
    // Keyboard shortcuts
    shortcuts: {
      speedUp: 'KeyD',
      speedDown: 'KeyS',
      resetSpeed: 'KeyR',
      toggleDouble: 'KeyA',
      showSpeed: 'KeyV',
      togglePiP: 'KeyP',
      jumpForward: 'ArrowRight',
      jumpBackward: 'ArrowLeft',
      togglePlay: 'Space',
      mute: 'KeyM',
      fullscreen: 'KeyF',
      fineSpeedUp: null,
      fineSpeedDown: null
    }
  };

  let config = { ...DEFAULT_CONFIG };
  let activeVideo = null;
  let overlayElement = null;
  let controlBarElement = null;
  let overlayTimer = null;
  let previousSpeed = 1.0;
  let isControlBarVisible = false;

  // ============================================================================
  // Initialization
  // ============================================================================

  async function init() {
    await loadConfig();
    if (!config.enabled) return;

    injectStyles();
    observeVideos();
    setupKeyboardShortcuts();
    processExistingVideos();
  }

  async function loadConfig() {
    try {
      const response = await chrome.runtime.sendMessage({ type: 'getVideoConfig' });
      if (response?.success && response.data) {
        config = { ...DEFAULT_CONFIG, ...response.data };
      }
    } catch (e) {
      // Use defaults
    }
  }

  // ============================================================================
  // Video Detection & Enhancement
  // ============================================================================

  function processExistingVideos() {
    const videos = document.querySelectorAll('video');
    videos.forEach(enhanceVideo);
  }

  function observeVideos() {
    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (node.nodeType !== Node.ELEMENT_NODE) continue;
          if (node.tagName === 'VIDEO') {
            enhanceVideo(node);
          }
          const videos = node.querySelectorAll?.('video') || [];
          videos.forEach(enhanceVideo);
        }
      }
    });

    observer.observe(document.documentElement, {
      childList: true,
      subtree: true
    });
  }

  function enhanceVideo(video) {
    if (video.dataset.theaEnhanced === 'true') return;
    video.dataset.theaEnhanced = 'true';

    // Set as active video
    activeVideo = video;

    // Apply saved speed
    const domain = window.location.hostname;
    const savedSpeed = config.siteSpeedPrefs[domain] || config.defaultSpeed;
    if (savedSpeed !== 1.0) {
      video.playbackRate = savedSpeed;
    }

    // Apply length-based auto-speed rules
    video.addEventListener('loadedmetadata', () => {
      applyAutoSpeedRules(video);
    });

    // Track active video on play
    video.addEventListener('play', () => {
      activeVideo = video;
    });

    // Create overlay for this video
    if (config.showOverlay) {
      createVideoOverlay(video);
    }

    // Create control bar
    createControlBar(video);
  }

  // ============================================================================
  // Auto Speed Rules (inspired by Speed Player)
  // ============================================================================

  function applyAutoSpeedRules(video) {
    if (!config.autoSpeedRules.length) return;
    const duration = video.duration;
    if (!isFinite(duration)) return;

    for (const rule of config.autoSpeedRules) {
      if (duration >= (rule.minDuration || 0) && duration <= (rule.maxDuration || Infinity)) {
        video.playbackRate = rule.speed;
        showSpeedOverlay(video, rule.speed, `Auto: ${rule.name || 'Rule applied'}`);
        break;
      }
    }
  }

  // ============================================================================
  // Speed Control
  // ============================================================================

  function setSpeed(video, speed) {
    const clampedSpeed = Math.max(config.minSpeed, Math.min(config.maxSpeed, speed));
    const roundedSpeed = Math.round(clampedSpeed * 100) / 100;
    video.playbackRate = roundedSpeed;

    // Save per-site if enabled
    if (config.rememberSpeed) {
      const domain = window.location.hostname;
      config.siteSpeedPrefs[domain] = roundedSpeed;
      saveConfig();
    }

    showSpeedOverlay(video, roundedSpeed);
    updateControlBar(video);
    return roundedSpeed;
  }

  function increaseSpeed(video, step) {
    return setSpeed(video, video.playbackRate + (step || config.speedStep));
  }

  function decreaseSpeed(video, step) {
    return setSpeed(video, video.playbackRate - (step || config.speedStep));
  }

  function resetSpeed(video) {
    previousSpeed = video.playbackRate;
    return setSpeed(video, 1.0);
  }

  function toggleDoubleSpeed(video) {
    if (Math.abs(video.playbackRate - 2.0) < 0.01) {
      return setSpeed(video, previousSpeed || 1.0);
    }
    previousSpeed = video.playbackRate;
    return setSpeed(video, 2.0);
  }

  // ============================================================================
  // Video Navigation
  // ============================================================================

  function jumpForward(video, seconds) {
    video.currentTime = Math.min(video.duration, video.currentTime + (seconds || config.jumpForward));
    showOverlayMessage(video, `+${seconds || config.jumpForward}s`);
  }

  function jumpBackward(video, seconds) {
    video.currentTime = Math.max(0, video.currentTime - (seconds || config.jumpBackward));
    showOverlayMessage(video, `-${seconds || config.jumpBackward}s`);
  }

  function togglePlay(video) {
    if (video.paused) {
      video.play();
    } else {
      video.pause();
    }
  }

  function toggleMute(video) {
    video.muted = !video.muted;
    showOverlayMessage(video, video.muted ? 'Muted' : 'Unmuted');
  }

  // ============================================================================
  // Picture-in-Picture
  // ============================================================================

  async function togglePiP(video) {
    try {
      if (document.pictureInPictureElement === video) {
        await document.exitPictureInPicture();
        showOverlayMessage(video, 'PiP Off');
      } else {
        await video.requestPictureInPicture();
        showOverlayMessage(video, 'PiP On');
      }
    } catch (e) {
      console.log('PiP not supported:', e);
    }
  }

  function toggleFullscreen(video) {
    const container = video.closest('[class*="player"]') || video.parentElement;
    if (document.fullscreenElement) {
      document.exitFullscreen();
    } else {
      (container || video).requestFullscreen?.();
    }
  }

  // ============================================================================
  // Speed Overlay (brief indicator)
  // ============================================================================

  function showSpeedOverlay(video, speed, label) {
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
    }, config.overlayTimeout);
  }

  function showOverlayMessage(video, message) {
    showSpeedOverlay(video, 0, message);
  }

  // ============================================================================
  // Control Bar (persistent, hover-activated)
  // ============================================================================

  function createControlBar(video) {
    const container = getVideoContainer(video);
    if (!container || container.querySelector('.thea-video-controls')) return;

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
        <button class="thea-vc-btn" data-action="jump-back" title="Jump back (←)">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="11 17 6 12 11 7"/><line x1="6" y1="12" x2="20" y2="12"/>
          </svg>
        </button>
        <button class="thea-vc-btn" data-action="play-pause" title="Play/Pause">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
            <polygon points="5 3 19 12 5 21 5 3"/>
          </svg>
        </button>
        <button class="thea-vc-btn" data-action="jump-fwd" title="Jump forward (→)">
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

    bar.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-action]');
      if (!btn) return;
      e.stopPropagation();
      e.preventDefault();

      switch (btn.dataset.action) {
        case 'speed-up': increaseSpeed(video); break;
        case 'speed-down': decreaseSpeed(video); break;
        case 'jump-back': jumpBackward(video); break;
        case 'jump-fwd': jumpForward(video); break;
        case 'play-pause': togglePlay(video); break;
        case 'reset': resetSpeed(video); break;
        case 'double': toggleDoubleSpeed(video); break;
        case 'pip': togglePiP(video); break;
      }
    });

    container.style.position = container.style.position || 'relative';
    container.appendChild(bar);

    // Show on hover
    container.addEventListener('mouseenter', () => {
      bar.classList.add('thea-vc-visible');
    });
    container.addEventListener('mouseleave', () => {
      bar.classList.remove('thea-vc-visible');
    });

    // Update time remaining
    video.addEventListener('timeupdate', () => {
      updateTimeDisplay(video, bar);
    });

    updateControlBar(video);
  }

  function updateControlBar(video) {
    const container = getVideoContainer(video);
    if (!container) return;
    const bar = container.querySelector('.thea-video-controls');
    if (!bar) return;

    const speedDisplay = bar.querySelector('.thea-vc-speed');
    if (speedDisplay) {
      speedDisplay.textContent = `${video.playbackRate.toFixed(2)}x`;
    }
  }

  function updateTimeDisplay(video, bar) {
    const timeEl = bar.querySelector('.thea-vc-time');
    if (!timeEl || !isFinite(video.duration)) return;

    const remaining = video.duration - video.currentTime;
    // Actual time remaining at current speed (Vidimote feature)
    const adjustedRemaining = remaining / video.playbackRate;
    timeEl.textContent = formatTime(adjustedRemaining);
    timeEl.title = `Remaining at ${video.playbackRate.toFixed(2)}x speed`;
  }

  // ============================================================================
  // Keyboard Shortcuts
  // ============================================================================

  function setupKeyboardShortcuts() {
    document.addEventListener('keydown', (e) => {
      if (!activeVideo) return;
      if (isInputFocused(e)) return;

      const code = e.code;
      const shortcuts = config.shortcuts;

      switch (code) {
        case shortcuts.speedUp:
          e.preventDefault();
          increaseSpeed(activeVideo, e.shiftKey ? config.fineSpeedStep : config.speedStep);
          break;
        case shortcuts.speedDown:
          e.preventDefault();
          decreaseSpeed(activeVideo, e.shiftKey ? config.fineSpeedStep : config.speedStep);
          break;
        case shortcuts.resetSpeed:
          e.preventDefault();
          resetSpeed(activeVideo);
          break;
        case shortcuts.toggleDouble:
          e.preventDefault();
          toggleDoubleSpeed(activeVideo);
          break;
        case shortcuts.showSpeed:
          e.preventDefault();
          showSpeedOverlay(activeVideo, activeVideo.playbackRate);
          break;
        case shortcuts.togglePiP:
          e.preventDefault();
          togglePiP(activeVideo);
          break;
        case shortcuts.jumpForward:
          if (!e.metaKey && !e.ctrlKey) {
            e.preventDefault();
            jumpForward(activeVideo, e.shiftKey ? 30 : config.jumpForward);
          }
          break;
        case shortcuts.jumpBackward:
          if (!e.metaKey && !e.ctrlKey) {
            e.preventDefault();
            jumpBackward(activeVideo, e.shiftKey ? 30 : config.jumpBackward);
          }
          break;
        case shortcuts.togglePlay:
          if (e.target === document.body || e.target === document.documentElement) {
            e.preventDefault();
            togglePlay(activeVideo);
          }
          break;
        case shortcuts.mute:
          e.preventDefault();
          toggleMute(activeVideo);
          break;
        case shortcuts.fullscreen:
          if (!e.metaKey && !e.ctrlKey) {
            e.preventDefault();
            toggleFullscreen(activeVideo);
          }
          break;
      }
    });
  }

  // ============================================================================
  // Utility Functions
  // ============================================================================

  function getVideoContainer(video) {
    // Try to find a meaningful container
    return video.closest('[class*="player"]') ||
           video.closest('[class*="video"]') ||
           video.closest('[id*="player"]') ||
           video.parentElement;
  }

  function isInputFocused(e) {
    const tag = e.target.tagName;
    return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' ||
           e.target.isContentEditable || e.target.closest('[contenteditable]');
  }

  function formatTime(seconds) {
    if (!isFinite(seconds) || seconds < 0) return '--:--';
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = Math.floor(seconds % 60);
    if (h > 0) return `-${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
    return `-${m}:${String(s).padStart(2, '0')}`;
  }

  async function saveConfig() {
    try {
      await chrome.runtime.sendMessage({
        type: 'saveVideoConfig',
        data: { siteSpeedPrefs: config.siteSpeedPrefs }
      });
    } catch (e) {
      // Silently fail
    }
  }

  function createVideoOverlay(video) {
    // Overlay is created on-demand in showSpeedOverlay
  }

  // ============================================================================
  // Styles
  // ============================================================================

  function injectStyles() {
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
  // Initialize
  // ============================================================================

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
