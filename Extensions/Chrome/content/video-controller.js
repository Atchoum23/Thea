/**
 * Thea Video Speed Controller - Logic Module
 *
 * Speed control logic, keyboard shortcuts (S/D/R/Z/X/A),
 * per-site memory, PiP, MutationObserver.
 *
 * Depends on: video-controller-ui.js (loaded before this file)
 */

(function() {
  'use strict';

  window.TheaModules = window.TheaModules || {};
  const UI = window.TheaModules.videoUI;

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
    autoSpeedRules: [],
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
  let previousSpeed = 1.0;

  // ============================================================================
  // Initialization
  // ============================================================================

  async function init() {
    await loadConfig();
    if (!config.enabled) return;

    UI.injectVideoStyles();
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

    // Create overlay for this video (on-demand)
    // Create control bar
    createControlBar(video);
  }

  // ============================================================================
  // Auto Speed Rules
  // ============================================================================

  function applyAutoSpeedRules(video) {
    if (!config.autoSpeedRules.length) return;
    const duration = video.duration;
    if (!isFinite(duration)) return;

    for (const rule of config.autoSpeedRules) {
      if (duration >= (rule.minDuration || 0) && duration <= (rule.maxDuration || Infinity)) {
        video.playbackRate = rule.speed;
        UI.showSpeedOverlay(video, rule.speed, `Auto: ${rule.name || 'Rule applied'}`, config);
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

    if (config.rememberSpeed) {
      const domain = window.location.hostname;
      config.siteSpeedPrefs[domain] = roundedSpeed;
      saveConfig();
    }

    UI.showSpeedOverlay(video, roundedSpeed, null, config);

    const container = UI.getVideoContainer(video);
    if (container) {
      const bar = container.querySelector('.thea-video-controls');
      if (bar) UI.updateSpeedDisplay(bar, roundedSpeed);
    }

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
    UI.showOverlayMessage(video, `+${seconds || config.jumpForward}s`, config);
  }

  function jumpBackward(video, seconds) {
    video.currentTime = Math.max(0, video.currentTime - (seconds || config.jumpBackward));
    UI.showOverlayMessage(video, `-${seconds || config.jumpBackward}s`, config);
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
    UI.showOverlayMessage(video, video.muted ? 'Muted' : 'Unmuted', config);
  }

  // ============================================================================
  // Picture-in-Picture
  // ============================================================================

  async function togglePiP(video) {
    try {
      if (document.pictureInPictureElement === video) {
        await document.exitPictureInPicture();
        UI.showOverlayMessage(video, 'PiP Off', config);
      } else {
        await video.requestPictureInPicture();
        UI.showOverlayMessage(video, 'PiP On', config);
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
  // Control Bar
  // ============================================================================

  function createControlBar(video) {
    const container = UI.getVideoContainer(video);
    if (!container || container.querySelector('.thea-video-controls')) return;

    const bar = UI.buildControlBar();

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
      UI.updateTimeDisplay(video, bar);
    });

    UI.updateSpeedDisplay(bar, video.playbackRate);
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
          UI.showSpeedOverlay(activeVideo, activeVideo.playbackRate, null, config);
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

  function isInputFocused(e) {
    const tag = e.target.tagName;
    return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' ||
           e.target.isContentEditable || e.target.closest('[contenteditable]');
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

  // ============================================================================
  // Initialize
  // ============================================================================

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
