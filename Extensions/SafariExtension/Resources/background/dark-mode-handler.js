// Thea Safari Extension - Dark Mode Handler
// Generates dark mode CSS for web pages with multiple theme options

// Theme definitions: { bg, surface, text, textSec, link, accent, border, imgBrightness }
var darkThemes = {
    pure: {
        bg: '#000000', surface: '#111111', text: '#e0e0e0', textSec: '#999999',
        link: '#6ea8fe', accent: '#6ea8fe', border: '#222222', imgBrightness: '0.85'
    },
    midnight: {
        bg: '#0f1119', surface: '#181b28', text: '#d4d4dc', textSec: '#8888a0',
        link: '#7aa2f7', accent: '#7aa2f7', border: '#252836', imgBrightness: '0.90'
    },
    warm: {
        bg: '#1a1410', surface: '#231e18', text: '#d5cec4', textSec: '#9a9080',
        link: '#e0a870', accent: '#e0a870', border: '#332a20', imgBrightness: '0.92'
    },
    nord: {
        bg: '#2e3440', surface: '#3b4252', text: '#eceff4', textSec: '#d8dee9',
        link: '#88c0d0', accent: '#81a1c1', border: '#434c5e', imgBrightness: '0.90'
    },
    oled: {
        bg: '#000000', surface: '#0a0a0a', text: '#ffffff', textSec: '#888888',
        link: '#58a6ff', accent: '#58a6ff', border: '#161616', imgBrightness: '0.80'
    },
    dracula: {
        bg: '#282a36', surface: '#343746', text: '#f8f8f2', textSec: '#6272a4',
        link: '#8be9fd', accent: '#bd93f9', border: '#44475a', imgBrightness: '0.90'
    },
    monokai: {
        bg: '#272822', surface: '#2e2f2a', text: '#f8f8f2', textSec: '#75715e',
        link: '#66d9ef', accent: '#a6e22e', border: '#3e3d32', imgBrightness: '0.90'
    },
    solarized: {
        bg: '#002b36', surface: '#073642', text: '#839496', textSec: '#586e75',
        link: '#268bd2', accent: '#2aa198', border: '#094959', imgBrightness: '0.90'
    },
    gruvbox: {
        bg: '#282828', surface: '#32302f', text: '#ebdbb2', textSec: '#a89984',
        link: '#83a598', accent: '#fabd2f', border: '#3c3836', imgBrightness: '0.90'
    },
    catppuccin: {
        bg: '#1e1e2e', surface: '#262637', text: '#cdd6f4', textSec: '#a6adc8',
        link: '#89b4fa', accent: '#cba6f7', border: '#313244', imgBrightness: '0.90'
    },
    tokyoNight: {
        bg: '#1a1b26', surface: '#24283b', text: '#c0caf5', textSec: '#565f89',
        link: '#7aa2f7', accent: '#bb9af7', border: '#292e42', imgBrightness: '0.90'
    },
    oneDark: {
        bg: '#282c34', surface: '#2c313a', text: '#abb2bf', textSec: '#5c6370',
        link: '#61afef', accent: '#c678dd', border: '#3b4048', imgBrightness: '0.90'
    },
    githubDark: {
        bg: '#0d1117', surface: '#161b22', text: '#c9d1d9', textSec: '#8b949e',
        link: '#58a6ff', accent: '#1f6feb', border: '#21262d', imgBrightness: '0.90'
    },
    rosePine: {
        bg: '#191724', surface: '#1f1d2e', text: '#e0def4', textSec: '#908caa',
        link: '#c4a7e7', accent: '#ebbcba', border: '#26233a', imgBrightness: '0.90'
    },
    ayu: {
        bg: '#0b0e14', surface: '#11151c', text: '#bfbdb6', textSec: '#565b66',
        link: '#39bae6', accent: '#e6b450', border: '#1c2028', imgBrightness: '0.90'
    },
    palenight: {
        bg: '#292d3e', surface: '#2f3347', text: '#a6accd', textSec: '#676e95',
        link: '#82aaff', accent: '#c792ea', border: '#373b53', imgBrightness: '0.90'
    },
    horizon: {
        bg: '#1c1e26', surface: '#232530', text: '#d5d8da', textSec: '#6c6f93',
        link: '#25b0bc', accent: '#e95678', border: '#2e303e', imgBrightness: '0.90'
    },
    everforest: {
        bg: '#2d353b', surface: '#343f44', text: '#d3c6aa', textSec: '#859289',
        link: '#83c092', accent: '#a7c080', border: '#3d484d', imgBrightness: '0.92'
    },
    kanagawa: {
        bg: '#1f1f28', surface: '#2a2a37', text: '#dcd7ba', textSec: '#727169',
        link: '#7e9cd8', accent: '#957fb8', border: '#363646', imgBrightness: '0.90'
    },
    material: {
        bg: '#212121', surface: '#292929', text: '#eeffff', textSec: '#b0bec5',
        link: '#82aaff', accent: '#c792ea', border: '#333333', imgBrightness: '0.90'
    },
    cobalt: {
        bg: '#132738', surface: '#193549', text: '#e1efff', textSec: '#7e97b3',
        link: '#ffc600', accent: '#ff9d00', border: '#1f4662', imgBrightness: '0.90'
    }
};

/**
 * Adjust the brightness of a hex color.
 * @param {string} hex - Hex color string (e.g., '#282828')
 * @param {number} amount - Positive to lighten, negative to darken (-255 to 255)
 * @returns {string} Adjusted hex color
 */
function adjustBrightness(hex, amount) {
    var cleanHex = hex.replace('#', '');
    var r = Math.max(0, Math.min(255, parseInt(cleanHex.substring(0, 2), 16) + amount));
    var g = Math.max(0, Math.min(255, parseInt(cleanHex.substring(2, 4), 16) + amount));
    var b = Math.max(0, Math.min(255, parseInt(cleanHex.substring(4, 6), 16) + amount));
    return '#' + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1);
}

/**
 * Get the theme configuration for a domain, considering per-site preferences.
 * @param {string} domain - The website domain
 * @returns {Object} Theme configuration object
 */
function getDarkModeTheme(domain) {
    var config = state.darkModeConfig || {};
    var themeName = 'midnight'; // default

    // Check per-site preference first
    if (config.sitePrefs && config.sitePrefs[domain] && config.sitePrefs[domain].theme) {
        themeName = config.sitePrefs[domain].theme;
    } else if (config.theme) {
        themeName = config.theme;
    }

    // Check custom themes
    if (config.customThemes && config.customThemes[themeName]) {
        return config.customThemes[themeName];
    }

    return darkThemes[themeName] || darkThemes.midnight;
}

/**
 * Check if dark mode is paused (pausedUntil timestamp in the future).
 */
function isDarkModePaused() {
    var config = state.darkModeConfig || {};
    if (!config.pausedUntil) return false;
    return Date.now() < config.pausedUntil;
}

/**
 * Check if dark mode is disabled for a specific domain.
 */
function isDarkModeDisabledForSite(domain) {
    var config = state.darkModeConfig || {};
    if (config.sitePrefs && config.sitePrefs[domain]) {
        return config.sitePrefs[domain].disabled === true;
    }
    return false;
}

/**
 * Generate full dark mode CSS for a given domain.
 * @param {string} domain - The website domain
 * @returns {string} CSS string to inject
 */
async function generateDarkModeCSS(domain) {
    if (isDarkModePaused() || isDarkModeDisabledForSite(domain)) {
        return '';
    }

    var theme = getDarkModeTheme(domain);
    var surfaceLight = adjustBrightness(theme.surface, 15);
    var surfaceLighter = adjustBrightness(theme.surface, 30);
    var borderLight = adjustBrightness(theme.border, 10);

    var css = '';
    css += '/* Thea Dark Mode - Theme applied */\n';
    css += ':root {\n';
    css += '  --thea-bg: ' + theme.bg + ';\n';
    css += '  --thea-surface: ' + theme.surface + ';\n';
    css += '  --thea-surface-light: ' + surfaceLight + ';\n';
    css += '  --thea-surface-lighter: ' + surfaceLighter + ';\n';
    css += '  --thea-text: ' + theme.text + ';\n';
    css += '  --thea-text-sec: ' + theme.textSec + ';\n';
    css += '  --thea-link: ' + theme.link + ';\n';
    css += '  --thea-accent: ' + theme.accent + ';\n';
    css += '  --thea-border: ' + theme.border + ';\n';
    css += '  --thea-border-light: ' + borderLight + ';\n';
    css += '}\n\n';

    // Base body and html styles
    css += 'html, body {\n';
    css += '  background-color: var(--thea-bg) !important;\n';
    css += '  color: var(--thea-text) !important;\n';
    css += '}\n\n';

    // Common elements
    css += 'div, section, article, aside, header, footer, nav, main, ';
    css += 'form, fieldset, details, summary, figure, figcaption {\n';
    css += '  background-color: inherit !important;\n';
    css += '  color: inherit !important;\n';
    css += '  border-color: var(--thea-border) !important;\n';
    css += '}\n\n';

    // Text elements
    css += 'p, span, h1, h2, h3, h4, h5, h6, li, td, th, dt, dd, label, legend {\n';
    css += '  color: var(--thea-text) !important;\n';
    css += '}\n\n';

    // Links
    css += 'a, a:visited { color: var(--thea-link) !important; }\n';
    css += 'a:hover { color: ' + adjustBrightness(theme.link, 30) + ' !important; }\n\n';

    // Inputs and controls
    css += 'input, textarea, select, button {\n';
    css += '  background-color: var(--thea-surface) !important;\n';
    css += '  color: var(--thea-text) !important;\n';
    css += '  border-color: var(--thea-border) !important;\n';
    css += '}\n\n';

    css += 'input::placeholder, textarea::placeholder {\n';
    css += '  color: var(--thea-text-sec) !important;\n';
    css += '}\n\n';

    // Tables
    css += 'table, tr, td, th {\n';
    css += '  background-color: var(--thea-surface) !important;\n';
    css += '  border-color: var(--thea-border) !important;\n';
    css += '}\n\n';

    css += 'th { background-color: var(--thea-surface-light) !important; }\n\n';

    // Code blocks
    css += 'pre, code, kbd, samp {\n';
    css += '  background-color: var(--thea-surface-light) !important;\n';
    css += '  color: var(--thea-text) !important;\n';
    css += '}\n\n';

    // Image brightness adjustment
    css += 'img, video, canvas, svg {\n';
    css += '  filter: brightness(' + theme.imgBrightness + ') !important;\n';
    css += '}\n\n';

    // Scrollbar styling
    css += '::-webkit-scrollbar { background-color: var(--thea-bg) !important; width: 10px; }\n';
    css += '::-webkit-scrollbar-thumb { background-color: var(--thea-border) !important; border-radius: 5px; }\n';
    css += '::-webkit-scrollbar-thumb:hover { background-color: var(--thea-text-sec) !important; }\n\n';

    // Selection
    css += '::selection {\n';
    css += '  background-color: ' + theme.accent + ' !important;\n';
    css += '  color: ' + theme.bg + ' !important;\n';
    css += '}\n';

    return css;
}
