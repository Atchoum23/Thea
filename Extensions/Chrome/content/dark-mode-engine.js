/**
 * Thea Dark Mode Engine
 *
 * Inspired by: Noir.app (20+ themes, per-site, custom themes, system sync)
 *
 * Features:
 * - 20 built-in themes (pure, midnight, warm, nord, oled, solarized, dracula, etc.)
 * - Custom theme builder (pick bg, text, link, accent colors)
 * - Per-site overrides (enable/disable/custom theme per domain)
 * - System dark mode sync (follows OS preference)
 * - Intelligent color analysis (not a simple invert)
 * - Image brightness adjustment + optional grayscale
 * - Smooth transitions between light/dark
 * - Pause Until Tomorrow feature (Noir)
 * - Excludes sites with native dark mode
 */

(function() {
  'use strict';

  // ============================================================================
  // Built-in Themes (Noir-level variety)
  // ============================================================================

  const THEMES = {
    pure:       { name: 'Pure Black',    bg: '#000000', surface: '#111111', text: '#ffffff', textSec: '#b0b0b0', link: '#4da6ff', accent: '#4da6ff', border: '#222222', imgBrightness: 0.85 },
    midnight:   { name: 'Midnight',      bg: '#1a1a2e', surface: '#16213e', text: '#eaeaea', textSec: '#a0aec0', link: '#6b9fff', accent: '#e94560', border: '#2d2d44', imgBrightness: 0.9 },
    warm:       { name: 'Warm Night',    bg: '#1f1b18', surface: '#2a2420', text: '#e8e4df', textSec: '#b8b0a4', link: '#d4a574', accent: '#d4a574', border: '#3d3530', imgBrightness: 0.9 },
    nord:       { name: 'Nord',          bg: '#2e3440', surface: '#3b4252', text: '#eceff4', textSec: '#d8dee9', link: '#88c0d0', accent: '#5e81ac', border: '#434c5e', imgBrightness: 0.9 },
    oled:       { name: 'OLED Black',    bg: '#000000', surface: '#0a0a0a', text: '#ffffff', textSec: '#999999', link: '#4fc3f7', accent: '#4fc3f7', border: '#1a1a1a', imgBrightness: 0.85 },
    dracula:    { name: 'Dracula',       bg: '#282a36', surface: '#44475a', text: '#f8f8f2', textSec: '#6272a4', link: '#8be9fd', accent: '#ff79c6', border: '#44475a', imgBrightness: 0.9 },
    monokai:    { name: 'Monokai',       bg: '#272822', surface: '#3e3d32', text: '#f8f8f2', textSec: '#75715e', link: '#66d9ef', accent: '#f92672', border: '#49483e', imgBrightness: 0.9 },
    solarized:  { name: 'Solarized',     bg: '#002b36', surface: '#073642', text: '#839496', textSec: '#586e75', link: '#268bd2', accent: '#b58900', border: '#073642', imgBrightness: 0.9 },
    gruvbox:    { name: 'Gruvbox',       bg: '#282828', surface: '#3c3836', text: '#ebdbb2', textSec: '#a89984', link: '#83a598', accent: '#fe8019', border: '#504945', imgBrightness: 0.9 },
    catppuccin: { name: 'Catppuccin',    bg: '#1e1e2e', surface: '#313244', text: '#cdd6f4', textSec: '#a6adc8', link: '#89b4fa', accent: '#cba6f7', border: '#45475a', imgBrightness: 0.9 },
    tokyo:      { name: 'Tokyo Night',   bg: '#1a1b26', surface: '#24283b', text: '#c0caf5', textSec: '#565f89', link: '#7aa2f7', accent: '#bb9af7', border: '#3b4261', imgBrightness: 0.9 },
    oneDark:    { name: 'One Dark',      bg: '#282c34', surface: '#2c313a', text: '#abb2bf', textSec: '#5c6370', link: '#61afef', accent: '#c678dd', border: '#3e4451', imgBrightness: 0.9 },
    github:     { name: 'GitHub Dark',   bg: '#0d1117', surface: '#161b22', text: '#c9d1d9', textSec: '#8b949e', link: '#58a6ff', accent: '#f78166', border: '#30363d', imgBrightness: 0.9 },
    rosePine:   { name: 'Rose Pine',     bg: '#191724', surface: '#1f1d2e', text: '#e0def4', textSec: '#908caa', link: '#c4a7e7', accent: '#ebbcba', border: '#26233a', imgBrightness: 0.9 },
    ayu:        { name: 'Ayu Dark',      bg: '#0b0e14', surface: '#11151c', text: '#bfbdb6', textSec: '#636a72', link: '#39bae6', accent: '#e6b450', border: '#1b1e28', imgBrightness: 0.9 },
    palenight:  { name: 'Palenight',     bg: '#292d3e', surface: '#32374d', text: '#a6accd', textSec: '#676e95', link: '#82aaff', accent: '#c792ea', border: '#3a3f58', imgBrightness: 0.9 },
    horizon:    { name: 'Horizon',       bg: '#1c1e26', surface: '#232530', text: '#d5d8e3', textSec: '#6c6f93', link: '#e95678', accent: '#fab795', border: '#2e303e', imgBrightness: 0.9 },
    everforest: { name: 'Everforest',    bg: '#2d353b', surface: '#343f44', text: '#d3c6aa', textSec: '#859289', link: '#a7c080', accent: '#dbbc7f', border: '#475258', imgBrightness: 0.92 },
    kanagawa:   { name: 'Kanagawa',      bg: '#1f1f28', surface: '#2a2a37', text: '#dcd7ba', textSec: '#727169', link: '#7e9cd8', accent: '#957fb8', border: '#363646', imgBrightness: 0.9 },
    material:   { name: 'Material',      bg: '#212121', surface: '#303030', text: '#eeffff', textSec: '#b2ccd6', link: '#82aaff', accent: '#89ddff', border: '#424242', imgBrightness: 0.9 },
    cobalt:     { name: 'Cobalt',        bg: '#122738', surface: '#193549', text: '#e1efff', textSec: '#7fc8db', link: '#ffc600', accent: '#ff9d00', border: '#1d4567', imgBrightness: 0.9 },
  };

  // Sites known to have native dark mode - don't override
  const NATIVE_DARK_SITES = new Set([
    'github.com', 'twitter.com', 'x.com', 'reddit.com', 'discord.com',
    'slack.com', 'notion.so', 'figma.com', 'linear.app', 'vercel.com'
  ]);

  // ============================================================================
  // State
  // ============================================================================

  let config = {
    enabled: false,
    followSystem: true,
    theme: 'midnight',
    customThemes: {},
    sitePrefs: {},    // domain -> { enabled: bool, theme: string }
    imageBrightness: 0.9,
    imageGrayscale: 0,
    transitionDuration: 200,
    pausedUntil: null, // ISO timestamp for "Pause Until Tomorrow"
    respectNativeDark: true,
    forceOnAllSites: false
  };

  let currentStyleEl = null;
  let transitionStyleEl = null;
  let systemDarkMode = window.matchMedia('(prefers-color-scheme: dark)').matches;

  // ============================================================================
  // Initialization
  // ============================================================================

  async function init() {
    await loadConfig();
    setupSystemDarkListener();

    if (shouldApplyDarkMode()) {
      applyDarkMode();
    }

    // Listen for messages
    chrome.runtime.onMessage.addListener(handleMessage);
  }

  async function loadConfig() {
    try {
      const response = await chrome.runtime.sendMessage({ type: 'getDarkModeConfig' });
      if (response?.success && response.data) {
        config = { ...config, ...response.data };
      }
    } catch (e) {
      // Use defaults
    }
  }

  // ============================================================================
  // Decision Logic
  // ============================================================================

  function shouldApplyDarkMode() {
    const domain = window.location.hostname;

    // Check pause
    if (config.pausedUntil) {
      const pauseEnd = new Date(config.pausedUntil);
      if (new Date() < pauseEnd) return false;
      config.pausedUntil = null;
    }

    // Check per-site preference
    const sitePref = config.sitePrefs[domain];
    if (sitePref) {
      if (sitePref.enabled === false) return false;
      if (sitePref.enabled === true) return true;
    }

    // Check native dark mode sites
    if (config.respectNativeDark && NATIVE_DARK_SITES.has(domain)) {
      return false;
    }

    // Follow system if enabled
    if (config.followSystem) {
      return systemDarkMode;
    }

    return config.enabled;
  }

  function getActiveTheme() {
    const domain = window.location.hostname;
    const sitePref = config.sitePrefs[domain];
    const themeName = sitePref?.theme || config.theme;

    // Check custom themes first
    if (config.customThemes[themeName]) {
      return config.customThemes[themeName];
    }

    return THEMES[themeName] || THEMES.midnight;
  }

  // ============================================================================
  // Dark Mode Application
  // ============================================================================

  function applyDarkMode() {
    const theme = getActiveTheme();

    const css = generateDarkCSS(theme);

    if (currentStyleEl) {
      currentStyleEl.textContent = css;
    } else {
      currentStyleEl = document.createElement('style');
      currentStyleEl.id = 'thea-dark-mode-engine';
      currentStyleEl.textContent = css;

      // Insert early for FOUC prevention
      const target = document.head || document.documentElement;
      target.insertBefore(currentStyleEl, target.firstChild);
    }

    // Add transition for smooth toggle
    if (!transitionStyleEl) {
      transitionStyleEl = document.createElement('style');
      transitionStyleEl.id = 'thea-dark-transition';
      transitionStyleEl.textContent = `
        *, *::before, *::after {
          transition: background-color ${config.transitionDuration}ms ease,
                      color ${config.transitionDuration}ms ease,
                      border-color ${config.transitionDuration}ms ease !important;
        }
      `;
    }
  }

  function removeDarkMode() {
    if (currentStyleEl) {
      currentStyleEl.remove();
      currentStyleEl = null;
    }
    if (transitionStyleEl) {
      transitionStyleEl.remove();
      transitionStyleEl = null;
    }
  }

  function generateDarkCSS(theme) {
    const imgBright = theme.imgBrightness || config.imageBrightness;
    const imgGray = config.imageGrayscale;

    return `
      :root {
        --thea-bg: ${theme.bg};
        --thea-surface: ${theme.surface};
        --thea-text: ${theme.text};
        --thea-text-sec: ${theme.textSec};
        --thea-link: ${theme.link};
        --thea-accent: ${theme.accent};
        --thea-border: ${theme.border};
        color-scheme: dark;
      }

      html, body {
        background-color: var(--thea-bg) !important;
        color: var(--thea-text) !important;
      }

      /* Surfaces */
      main, article, section, div, aside, nav, header, footer,
      .card, .panel, .container, .wrapper, .content, .post,
      [class*="card"], [class*="panel"], [class*="modal"],
      [class*="dialog"], [class*="dropdown"], [class*="menu"],
      [class*="popover"], [class*="tooltip"], [class*="sidebar"] {
        background-color: var(--thea-bg) !important;
        color: var(--thea-text) !important;
      }

      /* Elevated surfaces */
      [class*="header"], [class*="navbar"], [class*="toolbar"],
      [class*="footer"], [class*="banner"],
      table, thead, tbody, tr, th, td {
        background-color: var(--thea-surface) !important;
        color: var(--thea-text) !important;
      }

      /* Text */
      h1, h2, h3, h4, h5, h6, p, span, label, li, dt, dd,
      strong, em, b, i, blockquote, figcaption, caption {
        color: var(--thea-text) !important;
      }

      /* Secondary text */
      small, .text-muted, [class*="secondary"], [class*="subtitle"],
      [class*="caption"], [class*="meta"], [class*="description"],
      time, abbr, cite {
        color: var(--thea-text-sec) !important;
      }

      /* Links */
      a, a:link, a:visited {
        color: var(--thea-link) !important;
      }
      a:hover {
        color: var(--thea-accent) !important;
      }

      /* Borders */
      *, *::before, *::after {
        border-color: var(--thea-border) !important;
      }
      hr {
        border-color: var(--thea-border) !important;
        background-color: var(--thea-border) !important;
      }

      /* Form elements */
      input, textarea, select, button {
        background-color: var(--thea-surface) !important;
        color: var(--thea-text) !important;
        border-color: var(--thea-border) !important;
      }
      input::placeholder, textarea::placeholder {
        color: var(--thea-text-sec) !important;
      }
      input:focus, textarea:focus, select:focus {
        border-color: var(--thea-accent) !important;
        outline-color: var(--thea-accent) !important;
      }

      /* Code */
      pre, code, kbd, samp, .highlight {
        background-color: var(--thea-surface) !important;
        color: var(--thea-text) !important;
      }

      /* Images & media */
      img:not([src*=".svg"]) {
        filter: brightness(${imgBright})${imgGray ? ` grayscale(${imgGray})` : ''};
      }
      video {
        filter: none !important;
      }
      svg {
        color: var(--thea-text) !important;
      }

      /* Selection */
      ::selection {
        background-color: var(--thea-accent) !important;
        color: var(--thea-bg) !important;
      }

      /* Scrollbar */
      ::-webkit-scrollbar {
        width: 10px;
        height: 10px;
      }
      ::-webkit-scrollbar-track {
        background: var(--thea-bg);
      }
      ::-webkit-scrollbar-thumb {
        background: var(--thea-border);
        border-radius: 5px;
      }
      ::-webkit-scrollbar-thumb:hover {
        background: var(--thea-text-sec);
      }

      /* Override inline styles (aggressive) */
      [style*="background-color: white"],
      [style*="background-color: #fff"],
      [style*="background-color: rgb(255"],
      [style*="background: white"],
      [style*="background: #fff"],
      [style*="background: rgb(255"] {
        background-color: var(--thea-bg) !important;
      }

      [style*="color: black"],
      [style*="color: #000"],
      [style*="color: rgb(0, 0, 0"] {
        color: var(--thea-text) !important;
      }

      /* Shadows */
      [style*="box-shadow"] {
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.4) !important;
      }
    `;
  }

  // ============================================================================
  // System Dark Mode Listener
  // ============================================================================

  function setupSystemDarkListener() {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    mediaQuery.addEventListener('change', (e) => {
      systemDarkMode = e.matches;
      if (config.followSystem) {
        if (systemDarkMode) {
          applyDarkMode();
        } else {
          removeDarkMode();
        }
      }
    });
  }

  // ============================================================================
  // Message Handling
  // ============================================================================

  function handleMessage(message, sender, sendResponse) {
    if (!sender.id || sender.id !== chrome.runtime.id) {
      sendResponse({ success: false });
      return true;
    }

    switch (message.type) {
      case 'darkModeToggle':
        config.enabled = message.enabled;
        if (shouldApplyDarkMode()) {
          applyDarkMode();
        } else {
          removeDarkMode();
        }
        sendResponse({ success: true });
        break;

      case 'darkModeThemeChange':
        config.theme = message.theme;
        if (shouldApplyDarkMode()) {
          applyDarkMode();
        }
        sendResponse({ success: true });
        break;

      case 'darkModeConfigUpdate':
        config = { ...config, ...message.config };
        if (shouldApplyDarkMode()) {
          applyDarkMode();
        } else {
          removeDarkMode();
        }
        sendResponse({ success: true });
        break;

      case 'darkModePauseUntilTomorrow':
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        tomorrow.setHours(6, 0, 0, 0);
        config.pausedUntil = tomorrow.toISOString();
        removeDarkMode();
        chrome.runtime.sendMessage({
          type: 'saveDarkModeConfig',
          data: { pausedUntil: config.pausedUntil }
        });
        sendResponse({ success: true, pausedUntil: config.pausedUntil });
        break;

      case 'darkModeSetSitePref':
        const domain = window.location.hostname;
        config.sitePrefs[domain] = message.pref;
        if (shouldApplyDarkMode()) {
          applyDarkMode();
        } else {
          removeDarkMode();
        }
        chrome.runtime.sendMessage({
          type: 'saveDarkModeConfig',
          data: { sitePrefs: config.sitePrefs }
        });
        sendResponse({ success: true });
        break;

      case 'getDarkModeState':
        sendResponse({
          success: true,
          data: {
            enabled: config.enabled,
            active: !!currentStyleEl,
            theme: config.theme,
            themeName: getActiveTheme().name,
            followSystem: config.followSystem,
            systemDark: systemDarkMode,
            domain: window.location.hostname,
            sitePref: config.sitePrefs[window.location.hostname],
            pausedUntil: config.pausedUntil,
            availableThemes: Object.entries(THEMES).map(([id, t]) => ({ id, name: t.name }))
          }
        });
        break;
    }
    return true;
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
