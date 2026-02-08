(function() {
  'use strict';

  var UI = null;
  var enabled = false;
  var videoMap = new WeakMap();
  var observer = null;
  var pipIndicator = null;
  var overlayVisible = true;

  var SPEED_PRESETS = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3];
  var DEFAULT_SPEED = 1.0;
  var MIN_SPEED = 0.25;
  var MAX_SPEED = 16;
  var STEP = 0.25;

  var AUTO_SPEED_RULES = [
    { maxDuration: 60, speed: 1.0 },
    { maxDuration: 300, speed: 1.25 },
    { maxDuration: 1800, speed: 1.5 },
    { maxDuration: Infinity, speed: 1.75 }
  ];

  function init() {
    UI = window.TheaModules.VideoControllerUI;
    if (!UI) return;

    enabled = true;
    var videos = document.querySelectorAll('video');
    videos.forEach(function(video) { attachToVideo(video); });
    observeNewVideos();
    setupKeyboardShortcuts();
  }

  function attachToVideo(video) {
    if (videoMap.has(video)) return;

    var overlay = UI.createSpeedOverlay(video);
    var controlBar = UI.createControlBar(video);

    var state = {
      overlay: overlay,
      controlBar: controlBar,
      speed: DEFAULT_SPEED
    };
    videoMap.set(video, state);

    loadSiteSpeed().then(function(savedSpeed) {
      if (savedSpeed && savedSpeed !== DEFAULT_SPEED) {
        setSpeed(video, savedSpeed);
      }
    });

    video.addEventListener('loadedmetadata', function() {
      applyAutoSpeedRules(video);
    });

    video.addEventListener('enterpictureinpicture', function() {
      showPiPIndicator();
    });
    video.addEventListener('leavepictureinpicture', function() {
      hidePiPIndicator();
    });

    video.addEventListener('play', function() {
      UI.showOverlay(overlay);
      UI.hideOverlay(overlay, 2000);
    });
  }

  function setSpeed(video, speed) {
    speed = Math.max(MIN_SPEED, Math.min(MAX_SPEED, speed));
    video.playbackRate = speed;

    var state = videoMap.get(video);
    if (state) {
      state.speed = speed;
      UI.updateSpeedDisplay(state.overlay, speed);

      if (overlayVisible) {
        UI.showOverlay(state.overlay);
        UI.hideOverlay(state.overlay, 1500);
      }

      if (state.controlBar && state.controlBar._speedDisplay) {
        state.controlBar._speedDisplay.textContent =
          speed.toFixed(speed % 1 === 0 ? 1 : 2) + 'x';
      }
    }

    saveSiteSpeed(speed);

    var notify = window.TheaModules.Notification;
    if (notify && speed !== DEFAULT_SPEED) {
      notify.showNotification('Video Speed', speed + 'x playback', 1500);
    }
  }

  function getSpeed(video) {
    var state = videoMap.get(video);
    return state ? state.speed : video.playbackRate;
  }

  function getActiveVideo() {
    var videos = document.querySelectorAll('video');
    for (var i = 0; i < videos.length; i++) {
      if (!videos[i].paused) return videos[i];
    }
    return videos.length > 0 ? videos[0] : null;
  }

  function setupKeyboardShortcuts() {
    document.addEventListener('keydown', function(e) {
      if (!enabled) return;
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' ||
          e.target.isContentEditable) return;
      if (e.metaKey || e.ctrlKey || e.altKey) return;

      var video = getActiveVideo();
      if (!video) return;

      var handled = true;
      switch (e.key.toLowerCase()) {
        case 's':
          setSpeed(video, Math.max(MIN_SPEED, video.playbackRate - STEP));
          break;
        case 'd':
          setSpeed(video, Math.min(MAX_SPEED, video.playbackRate + STEP));
          break;
        case 'r':
          setSpeed(video, DEFAULT_SPEED);
          break;
        case 'z':
          video.currentTime = Math.min(video.duration || Infinity, video.currentTime + 10);
          break;
        case 'x':
          video.currentTime = Math.max(0, video.currentTime - 10);
          break;
        case 'a':
          if (video.playbackRate === 2) {
            setSpeed(video, DEFAULT_SPEED);
          } else {
            setSpeed(video, 2);
          }
          break;
        case 'v':
          overlayVisible = !overlayVisible;
          var state = videoMap.get(video);
          if (state) {
            if (overlayVisible) {
              UI.showOverlay(state.overlay);
              UI.hideOverlay(state.overlay, 2000);
            } else {
              state.overlay.classList.remove('thea-visible');
            }
          }
          break;
        case 'p':
          togglePiP(video);
          break;
        case ' ':
          if (video.paused) {
            video.play();
          } else {
            video.pause();
          }
          break;
        case 'arrowleft':
          video.currentTime = Math.max(0, video.currentTime - 5);
          break;
        case 'arrowright':
          video.currentTime = Math.min(video.duration || Infinity, video.currentTime + 5);
          break;
        case 'arrowup':
          video.volume = Math.min(1, video.volume + 0.1);
          break;
        case 'arrowdown':
          video.volume = Math.max(0, video.volume - 0.1);
          break;
        default:
          handled = false;
      }

      if (handled) {
        e.preventDefault();
        e.stopPropagation();
      }
    });
  }

  function observeNewVideos() {
    if (observer) observer.disconnect();
    observer = new MutationObserver(function(mutations) {
      if (!enabled) return;
      mutations.forEach(function(mutation) {
        mutation.addedNodes.forEach(function(node) {
          if (node.nodeType !== Node.ELEMENT_NODE) return;
          if (node.tagName === 'VIDEO') {
            attachToVideo(node);
          }
          var nested = node.querySelectorAll ? node.querySelectorAll('video') : [];
          nested.forEach(function(v) { attachToVideo(v); });
        });
      });
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  function togglePiP(video) {
    if (!video) return;
    if (document.pictureInPictureElement === video) {
      document.exitPictureInPicture().catch(function() {});
    } else if (document.pictureInPictureEnabled) {
      video.requestPictureInPicture().catch(function() {});
    }
  }

  function showPiPIndicator() {
    if (!pipIndicator) {
      pipIndicator = UI.createPiPIndicator();
    }
    pipIndicator.classList.add('thea-visible');
  }

  function hidePiPIndicator() {
    if (pipIndicator) {
      pipIndicator.classList.remove('thea-visible');
    }
  }

  function applyAutoSpeedRules(video) {
    if (!video.duration || isNaN(video.duration)) return;

    loadSiteSpeed().then(function(savedSpeed) {
      if (savedSpeed) return;

      for (var i = 0; i < AUTO_SPEED_RULES.length; i++) {
        if (video.duration <= AUTO_SPEED_RULES[i].maxDuration) {
          if (AUTO_SPEED_RULES[i].speed !== DEFAULT_SPEED) {
            setSpeed(video, AUTO_SPEED_RULES[i].speed);
          }
          break;
        }
      }
    });
  }

  function saveSiteSpeed(speed) {
    var hostname = window.location.hostname;
    browser.storage.local.get(['videoSpeedPerSite']).then(function(data) {
      var perSite = data.videoSpeedPerSite || {};
      perSite[hostname] = speed;
      browser.storage.local.set({ videoSpeedPerSite: perSite });
    }).catch(function() {});
  }

  function loadSiteSpeed() {
    var hostname = window.location.hostname;
    return browser.storage.local.get(['videoSpeedPerSite']).then(function(data) {
      var perSite = data.videoSpeedPerSite || {};
      return perSite[hostname] || null;
    }).catch(function() { return null; });
  }

  function destroy() {
    enabled = false;
    if (observer) {
      observer.disconnect();
      observer = null;
    }
    hidePiPIndicator();
  }

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.VideoController = {
    init: init,
    setSpeed: setSpeed,
    getSpeed: getSpeed,
    togglePiP: togglePiP,
    isEnabled: function() { return enabled; },
    destroy: destroy
  };
})();
