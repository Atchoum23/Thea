(function() {
  'use strict';

  var OVERLAY_CLASS = 'thea-video-speed-overlay';
  var CONTROL_BAR_CLASS = 'thea-video-control-bar';
  var THEA_GRADIENT = 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)';
  var hideTimer = null;

  function injectStyles() {
    if (document.getElementById('thea-video-controller-styles')) return;
    var style = document.createElement('style');
    style.id = 'thea-video-controller-styles';
    style.textContent = [
      '.' + OVERLAY_CLASS + ' {',
      '  position: absolute; top: 12px; left: 12px; z-index: 2147483630;',
      '  padding: 6px 14px; border-radius: 8px;',
      '  background: rgba(0, 0, 0, 0.75); backdrop-filter: blur(8px);',
      '  color: #fff; font-family: -apple-system, BlinkMacSystemFont, sans-serif;',
      '  font-size: 14px; font-weight: 600; pointer-events: none;',
      '  opacity: 0; transition: opacity 0.2s ease;',
      '  display: flex; align-items: center; gap: 6px;',
      '}',
      '.' + OVERLAY_CLASS + '.thea-visible { opacity: 1; }',
      '.' + OVERLAY_CLASS + ' .thea-speed-value {',
      '  background: ' + THEA_GRADIENT + '; -webkit-background-clip: text;',
      '  -webkit-text-fill-color: transparent; font-size: 16px;',
      '}',
      '',
      '.' + CONTROL_BAR_CLASS + ' {',
      '  position: absolute; bottom: 60px; left: 50%; transform: translateX(-50%);',
      '  z-index: 2147483631; display: flex; align-items: center; gap: 4px;',
      '  padding: 6px 10px; border-radius: 10px;',
      '  background: rgba(0, 0, 0, 0.8); backdrop-filter: blur(12px);',
      '  opacity: 0; transition: opacity 0.25s ease; pointer-events: auto;',
      '}',
      '.' + CONTROL_BAR_CLASS + '.thea-visible { opacity: 1; }',
      '.' + CONTROL_BAR_CLASS + ' button {',
      '  background: none; border: none; color: #ccc; cursor: pointer;',
      '  font-family: -apple-system, sans-serif; font-size: 13px;',
      '  padding: 5px 10px; border-radius: 6px; transition: all 0.15s ease;',
      '  white-space: nowrap;',
      '}',
      '.' + CONTROL_BAR_CLASS + ' button:hover {',
      '  background: rgba(255,255,255,0.15); color: #fff;',
      '}',
      '.' + CONTROL_BAR_CLASS + ' button.thea-active {',
      '  background: ' + THEA_GRADIENT + '; color: #fff;',
      '}',
      '.' + CONTROL_BAR_CLASS + ' .thea-divider {',
      '  width: 1px; height: 20px; background: rgba(255,255,255,0.2); margin: 0 4px;',
      '}',
      '.' + CONTROL_BAR_CLASS + ' .thea-speed-display {',
      '  font-size: 14px; font-weight: 700; min-width: 40px; text-align: center;',
      '  color: #fff; padding: 0 6px;',
      '}',
      '',
      '.thea-pip-indicator {',
      '  position: fixed; bottom: 80px; right: 20px; z-index: 2147483640;',
      '  padding: 8px 16px; border-radius: 8px;',
      '  background: rgba(0,0,0,0.8); backdrop-filter: blur(8px);',
      '  color: #fff; font-family: -apple-system, sans-serif; font-size: 13px;',
      '  opacity: 0; transition: opacity 0.3s ease;',
      '}',
      '.thea-pip-indicator.thea-visible { opacity: 1; }'
    ].join('\n');
    document.head.appendChild(style);
  }

  function createSpeedOverlay(video) {
    injectStyles();
    var wrapper = ensureWrapper(video);

    var overlay = document.createElement('div');
    overlay.className = OVERLAY_CLASS;
    overlay.innerHTML =
      '<span style="opacity: 0.7;">Speed</span> ' +
      '<span class="thea-speed-value">1.0x</span>';
    wrapper.appendChild(overlay);

    return overlay;
  }

  function createControlBar(video) {
    injectStyles();
    var wrapper = ensureWrapper(video);

    var bar = document.createElement('div');
    bar.className = CONTROL_BAR_CLASS;

    var speeds = [0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3];
    var btnRewind = createButton('\u23EA 10s', 'Rewind 10s');
    var btnSlower = createButton('\u25C0', 'Slower');
    var speedDisplay = document.createElement('span');
    speedDisplay.className = 'thea-speed-display';
    speedDisplay.textContent = '1.0x';
    var btnFaster = createButton('\u25B6', 'Faster');
    var btnAdvance = createButton('10s \u23E9', 'Advance 10s');
    var divider1 = createDivider();
    var btnPiP = createButton('PiP', 'Picture in Picture');
    var divider2 = createDivider();

    bar.appendChild(btnRewind);
    bar.appendChild(btnSlower);
    bar.appendChild(speedDisplay);
    bar.appendChild(btnFaster);
    bar.appendChild(btnAdvance);
    bar.appendChild(divider1);

    speeds.forEach(function(s) {
      var presetBtn = createButton(s + 'x', 'Set speed to ' + s + 'x');
      presetBtn.setAttribute('data-speed', s);
      if (s === 1) presetBtn.classList.add('thea-active');
      presetBtn.addEventListener('click', function(e) {
        e.stopPropagation();
        var vc = window.TheaModules.VideoController;
        if (vc) vc.setSpeed(video, s);
        bar.querySelectorAll('[data-speed]').forEach(function(b) {
          b.classList.toggle('thea-active', parseFloat(b.getAttribute('data-speed')) === s);
        });
        speedDisplay.textContent = s.toFixed(s % 1 === 0 ? 1 : 2) + 'x';
      });
      bar.appendChild(presetBtn);
    });

    bar.appendChild(divider2);
    bar.appendChild(btnPiP);

    btnRewind.addEventListener('click', function(e) {
      e.stopPropagation();
      video.currentTime = Math.max(0, video.currentTime - 10);
    });

    btnAdvance.addEventListener('click', function(e) {
      e.stopPropagation();
      video.currentTime = Math.min(video.duration || Infinity, video.currentTime + 10);
    });

    btnSlower.addEventListener('click', function(e) {
      e.stopPropagation();
      var newSpeed = Math.max(0.25, video.playbackRate - 0.25);
      var vc = window.TheaModules.VideoController;
      if (vc) vc.setSpeed(video, newSpeed);
      speedDisplay.textContent = newSpeed.toFixed(newSpeed % 1 === 0 ? 1 : 2) + 'x';
      updateActivePreset(bar, newSpeed);
    });

    btnFaster.addEventListener('click', function(e) {
      e.stopPropagation();
      var newSpeed = Math.min(16, video.playbackRate + 0.25);
      var vc = window.TheaModules.VideoController;
      if (vc) vc.setSpeed(video, newSpeed);
      speedDisplay.textContent = newSpeed.toFixed(newSpeed % 1 === 0 ? 1 : 2) + 'x';
      updateActivePreset(bar, newSpeed);
    });

    btnPiP.addEventListener('click', function(e) {
      e.stopPropagation();
      var vc = window.TheaModules.VideoController;
      if (vc) vc.togglePiP(video);
    });

    wrapper.appendChild(bar);

    wrapper.addEventListener('mouseenter', function() { showOverlay(bar); });
    wrapper.addEventListener('mouseleave', function() { hideOverlay(bar); });

    bar._speedDisplay = speedDisplay;
    return bar;
  }

  function updateActivePreset(bar, speed) {
    bar.querySelectorAll('[data-speed]').forEach(function(b) {
      b.classList.toggle('thea-active', parseFloat(b.getAttribute('data-speed')) === speed);
    });
  }

  function updateSpeedDisplay(overlay, speed) {
    if (!overlay) return;
    var valueEl = overlay.querySelector('.thea-speed-value');
    if (valueEl) {
      valueEl.textContent = speed.toFixed(speed % 1 === 0 ? 1 : 2) + 'x';
    }
  }

  function showOverlay(overlay) {
    if (hideTimer) clearTimeout(hideTimer);
    overlay.classList.add('thea-visible');
  }

  function hideOverlay(overlay, delay) {
    if (typeof delay === 'undefined') delay = 1500;
    if (hideTimer) clearTimeout(hideTimer);
    hideTimer = setTimeout(function() {
      overlay.classList.remove('thea-visible');
    }, delay);
  }

  function createPiPIndicator() {
    injectStyles();
    var indicator = document.createElement('div');
    indicator.className = 'thea-pip-indicator';
    indicator.textContent = 'Picture-in-Picture active';
    document.body.appendChild(indicator);
    return indicator;
  }

  function ensureWrapper(video) {
    var parent = video.parentElement;
    if (parent && parent.classList.contains('thea-video-wrapper')) return parent;

    var wrapper = document.createElement('div');
    wrapper.className = 'thea-video-wrapper';
    wrapper.style.cssText = 'position: relative; display: inline-block;';
    video.parentNode.insertBefore(wrapper, video);
    wrapper.appendChild(video);
    return wrapper;
  }

  function createButton(text, title) {
    var btn = document.createElement('button');
    btn.textContent = text;
    btn.title = title || text;
    return btn;
  }

  function createDivider() {
    var div = document.createElement('span');
    div.className = 'thea-divider';
    return div;
  }

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.VideoControllerUI = {
    createSpeedOverlay: createSpeedOverlay,
    createControlBar: createControlBar,
    updateSpeedDisplay: updateSpeedDisplay,
    showOverlay: showOverlay,
    hideOverlay: hideOverlay,
    createPiPIndicator: createPiPIndicator
  };
})();
