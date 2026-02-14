// Thea Chrome Extension - Dark Mode Handler
// Theme definitions, CSS generation, and brightness utilities

import { state } from './state-manager.js';

// ============================================================================
// Theme Definitions
// ============================================================================

export const darkThemes = {
  pure: {
    bg: '#000000',
    text: '#ffffff',
    link: '#4da6ff',
    border: '#333333'
  },
  midnight: {
    bg: '#1a1a2e',
    text: '#eaeaea',
    link: '#6b9fff',
    border: '#2d2d44'
  },
  warm: {
    bg: '#1f1b18',
    text: '#e8e4df',
    link: '#d4a574',
    border: '#3d3530'
  },
  nord: {
    bg: '#2e3440',
    text: '#eceff4',
    link: '#88c0d0',
    border: '#3b4252'
  },
  oled: {
    bg: '#000000',
    text: '#ffffff',
    link: '#4fc3f7',
    border: '#1a1a1a'
  }
};

// ============================================================================
// CSS Generation
// ============================================================================

export async function generateDarkModeCSS(domain) {
  if (!state.darkModeEnabled) {
    return '';
  }

  // Check site preferences
  const sitePref = state.darkModeSitePreferences[domain];
  if (sitePref === 'never') {
    return '';
  }

  const themeName = sitePref?.theme || state.darkModeTheme;
  const theme = darkThemes[themeName] || darkThemes.midnight;

  return `
    :root {
      --thea-bg: ${theme.bg};
      --thea-text: ${theme.text};
      --thea-link: ${theme.link};
      --thea-border: ${theme.border};
    }

    html, body {
      background-color: var(--thea-bg) !important;
      color: var(--thea-text) !important;
    }

    * {
      border-color: var(--thea-border) !important;
    }

    a, a:link, a:visited {
      color: var(--thea-link) !important;
    }

    input, textarea, select, button {
      background-color: ${adjustBrightness(theme.bg, 0.1)} !important;
      color: var(--thea-text) !important;
      border-color: var(--thea-border) !important;
    }

    img {
      opacity: 0.9;
    }

    ::selection {
      background-color: var(--thea-link) !important;
      color: var(--thea-bg) !important;
    }
  `;
}

// ============================================================================
// Brightness Utilities
// ============================================================================

export function adjustBrightness(hex, amount) {
  const num = parseInt(hex.replace('#', ''), 16);
  const r = Math.min(255, Math.max(0, (num >> 16) + amount * 255));
  const g = Math.min(255, Math.max(0, ((num >> 8) & 0x00FF) + amount * 255));
  const b = Math.min(255, Math.max(0, (num & 0x0000FF) + amount * 255));
  return `#${((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)}`;
}
