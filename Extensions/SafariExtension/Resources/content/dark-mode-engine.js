(function() {
  'use strict';

  var STYLE_ID = 'thea-dark-mode-styles';
  var enabled = false;
  var currentTheme = 'midnight';
  var systemDarkModeQuery = null;
  var syncWithSystem = false;

  function init() {
    browser.storage.local.get(['darkModeEnabled', 'darkModeTheme', 'darkModeSyncSystem', 'darkModePerSite']).then(function(data) {
      currentTheme = data.darkModeTheme || 'midnight';
      syncWithSystem = data.darkModeSyncSystem || false;
      var perSite = data.darkModePerSite || {};
      var hostname = window.location.hostname;

      if (isNativeDarkModeSite(hostname)) return;

      var siteEnabled = perSite[hostname];
      if (typeof siteEnabled === 'boolean') {
        if (siteEnabled) applyTheme(currentTheme);
        enabled = siteEnabled;
      } else if (data.darkModeEnabled) {
        applyTheme(currentTheme);
        enabled = true;
      }

      setupSystemListener();
    }).catch(function() {});
  }

  function setupSystemListener() {
    if (systemDarkModeQuery) return;
    systemDarkModeQuery = window.matchMedia('(prefers-color-scheme: dark)');
    systemDarkModeQuery.addEventListener('change', function(e) {
      if (syncWithSystem) {
        handleSystemDarkModeChange(e.matches);
      }
    });
  }

  function handleSystemDarkModeChange(isDark) {
    if (isDark && !enabled) {
      applyTheme(currentTheme);
      enabled = true;
    } else if (!isDark && enabled) {
      removeTheme();
      enabled = false;
    }
  }

  function applyTheme(themeName) {
    var themes = window.TheaModules.DarkModeThemes.THEMES;
    var theme = themes[themeName];
    if (!theme) {
      theme = themes.midnight;
      themeName = 'midnight';
    }
    currentTheme = themeName;

    removeTheme();

    var css = [
      '/* Thea Dark Mode - ' + theme.name + ' */',
      'html, body {',
      '  background-color: ' + theme.bg + ' !important;',
      '  color: ' + theme.text + ' !important;',
      '}',
      '',
      '*, *::before, *::after {',
      '  border-color: ' + theme.border + ' !important;',
      '}',
      '',
      'body, main, article, section, div, aside, nav, header, footer, form, fieldset,',
      'table, thead, tbody, tfoot, tr, td, th, ul, ol, li, dl, dt, dd, details, summary,',
      'dialog, .card, .panel, .container, .wrapper, .content, .sidebar, .modal, .dropdown-menu,',
      '.popover, .tooltip, [class*="card"], [class*="panel"], [class*="container"] {',
      '  background-color: ' + theme.bg + ' !important;',
      '  color: ' + theme.text + ' !important;',
      '}',
      '',
      'p, span, label, h1, h2, h3, h4, h5, h6, strong, em, b, i, u,',
      'blockquote, figcaption, caption, legend, small, sub, sup {',
      '  color: ' + theme.text + ' !important;',
      '}',
      '',
      'a, a:visited { color: ' + theme.link + ' !important; }',
      'a:hover { color: ' + theme.accent + ' !important; }',
      '',
      'input, textarea, select, button {',
      '  background-color: ' + theme.surface + ' !important;',
      '  color: ' + theme.text + ' !important;',
      '  border-color: ' + theme.border + ' !important;',
      '}',
      '',
      'input::placeholder, textarea::placeholder {',
      '  color: ' + theme.textSec + ' !important;',
      '}',
      '',
      'pre, code, kbd, samp {',
      '  background-color: ' + theme.surface + ' !important;',
      '  color: ' + theme.text + ' !important;',
      '}',
      '',
      'hr { border-color: ' + theme.border + ' !important; background-color: ' + theme.border + ' !important; }',
      '',
      'table, th, td { border-color: ' + theme.border + ' !important; }',
      'th { background-color: ' + theme.surface + ' !important; }',
      '',
      'img, video, picture, canvas, svg:not([class*="icon"]) {',
      '  filter: brightness(' + theme.imgBrightness + ') !important;',
      '}',
      '',
      '::selection {',
      '  background-color: ' + theme.accent + ' !important;',
      '  color: #ffffff !important;',
      '}',
      '',
      '::-webkit-scrollbar { width: 10px; height: 10px; }',
      '::-webkit-scrollbar-track { background: ' + theme.bg + '; }',
      '::-webkit-scrollbar-thumb { background: ' + theme.border + '; border-radius: 5px; }',
      '::-webkit-scrollbar-thumb:hover { background: ' + theme.textSec + '; }',
      '',
      '/* Skip Thea UI elements */',
      '[class^="thea-"], [id^="thea-"] {',
      '  all: revert !important;',
      '}',
      '',
      '/* Preserve syntax highlighting in code blocks */',
      '.highlight span, .hljs span, .prism-code span, .shiki span {',
      '  color: inherit !important;',
      '}',
      '',
      '/* Secondary text */',
      '.text-muted, .text-secondary, .text-gray, .secondary,',
      '[class*="muted"], [class*="secondary"], [class*="subtle"],',
      'time, .timestamp, .date, .meta, .caption, .footnote {',
      '  color: ' + theme.textSec + ' !important;',
      '}',
      '',
      '/* Surface elements */',
      '.dropdown-menu, .menu, .popup, .popover, .tooltip,',
      '[class*="dropdown"], [class*="popup"], [class*="tooltip"],',
      '[class*="modal"], [role="dialog"], [role="menu"], [role="listbox"] {',
      '  background-color: ' + theme.surface + ' !important;',
      '  border-color: ' + theme.border + ' !important;',
      '}',
      '',
      '/* Hover states */',
      'a:hover, button:hover, [role="button"]:hover {',
      '  background-color: ' + theme.surface + ' !important;',
      '}',
      '',
      '/* Focus outlines */',
      ':focus-visible {',
      '  outline-color: ' + theme.accent + ' !important;',
      '}'
    ].join('\n');

    var style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = css;
    document.head.appendChild(style);
    enabled = true;

    adjustImages(theme.imgBrightness);
  }

  function removeTheme() {
    var existing = document.getElementById(STYLE_ID);
    if (existing) existing.parentNode.removeChild(existing);
    enabled = false;
    adjustImages(1.0);
  }

  function toggleDarkMode(shouldEnable) {
    if (shouldEnable && !enabled) {
      applyTheme(currentTheme);
    } else if (!shouldEnable && enabled) {
      removeTheme();
    }
    enabled = shouldEnable;

    var hostname = window.location.hostname;
    browser.storage.local.get(['darkModePerSite']).then(function(data) {
      var perSite = data.darkModePerSite || {};
      perSite[hostname] = shouldEnable;
      browser.storage.local.set({
        darkModeEnabled: shouldEnable,
        darkModePerSite: perSite
      });
    }).catch(function() {});
  }

  function setTheme(themeName) {
    var themes = window.TheaModules.DarkModeThemes.THEMES;
    if (!themes[themeName]) return;
    currentTheme = themeName;
    if (enabled) {
      applyTheme(themeName);
    }
    browser.storage.local.set({ darkModeTheme: themeName }).catch(function() {});
  }

  function adjustImages(brightness) {
    var images = document.querySelectorAll('img, video, picture');
    images.forEach(function(img) {
      if (brightness < 1) {
        img.style.filter = 'brightness(' + brightness + ')';
      } else {
        img.style.filter = '';
      }
    });
  }

  function isNativeDarkModeSite(hostname) {
    var skipSites = window.TheaModules.DarkModeThemes.DARK_MODE_SKIP_SITES;
    return skipSites.some(function(site) {
      return hostname === site || hostname.endsWith('.' + site);
    });
  }

  browser.runtime.onMessage.addListener(function(message) {
    if (message.type === 'darkModeToggle') {
      toggleDarkMode(message.enabled);
    } else if (message.type === 'darkModeSetTheme') {
      setTheme(message.theme);
    }
  });

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.DarkModeEngine = {
    init: init,
    applyTheme: applyTheme,
    removeTheme: removeTheme,
    toggleDarkMode: toggleDarkMode,
    setTheme: setTheme,
    isNativeDarkModeSite: isNativeDarkModeSite,
    isEnabled: function() { return enabled; },
    getCurrentTheme: function() { return currentTheme; }
  };
})();
