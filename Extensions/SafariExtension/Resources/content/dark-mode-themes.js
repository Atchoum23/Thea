(function() {
  'use strict';

  var THEMES = {
    pure: {
      name: 'Pure Black', bg: '#000000', surface: '#0a0a0a', text: '#ffffff',
      textSec: '#a0a0a0', link: '#4da6ff', accent: '#0066ff', border: '#1a1a1a', imgBrightness: 0.85
    },
    midnight: {
      name: 'Midnight', bg: '#1a1a2e', surface: '#1f1f35', text: '#eaeaea',
      textSec: '#9e9eb8', link: '#6b9fff', accent: '#4d7fff', border: '#2d2d44', imgBrightness: 0.9
    },
    warm: {
      name: 'Warm Night', bg: '#1f1b18', surface: '#252220', text: '#e8e4df',
      textSec: '#a8a4a0', link: '#d4a574', accent: '#c4935c', border: '#3d3530', imgBrightness: 0.9
    },
    nord: {
      name: 'Nord', bg: '#2e3440', surface: '#3b4252', text: '#eceff4',
      textSec: '#d8dee9', link: '#88c0d0', accent: '#5e81ac', border: '#434c5e', imgBrightness: 0.9
    },
    oled: {
      name: 'OLED', bg: '#000000', surface: '#0a0a0a', text: '#ffffff',
      textSec: '#888888', link: '#4fc3f7', accent: '#29b6f6', border: '#111111', imgBrightness: 0.85
    },
    dracula: {
      name: 'Dracula', bg: '#282a36', surface: '#2d2f3d', text: '#f8f8f2',
      textSec: '#6272a4', link: '#8be9fd', accent: '#bd93f9', border: '#44475a', imgBrightness: 0.9
    },
    monokai: {
      name: 'Monokai', bg: '#272822', surface: '#2d2e27', text: '#f8f8f2',
      textSec: '#75715e', link: '#66d9ef', accent: '#a6e22e', border: '#3e3d32', imgBrightness: 0.9
    },
    solarized: {
      name: 'Solarized Dark', bg: '#002b36', surface: '#073642', text: '#839496',
      textSec: '#657b83', link: '#268bd2', accent: '#2aa198', border: '#073642', imgBrightness: 0.9
    },
    gruvbox: {
      name: 'Gruvbox', bg: '#282828', surface: '#3c3836', text: '#ebdbb2',
      textSec: '#a89984', link: '#83a598', accent: '#b8bb26', border: '#504945', imgBrightness: 0.9
    },
    catppuccin: {
      name: 'Catppuccin', bg: '#1e1e2e', surface: '#313244', text: '#cdd6f4',
      textSec: '#a6adc8', link: '#89b4fa', accent: '#cba6f7', border: '#45475a', imgBrightness: 0.9
    },
    tokyoNight: {
      name: 'Tokyo Night', bg: '#1a1b26', surface: '#24283b', text: '#c0caf5',
      textSec: '#565f89', link: '#7aa2f7', accent: '#bb9af7', border: '#292e42', imgBrightness: 0.9
    },
    oneDark: {
      name: 'One Dark', bg: '#282c34', surface: '#2c313a', text: '#abb2bf',
      textSec: '#5c6370', link: '#61afef', accent: '#c678dd', border: '#3e4452', imgBrightness: 0.9
    },
    githubDark: {
      name: 'GitHub Dark', bg: '#0d1117', surface: '#161b22', text: '#c9d1d9',
      textSec: '#8b949e', link: '#58a6ff', accent: '#1f6feb', border: '#30363d', imgBrightness: 0.9
    },
    rosePine: {
      name: 'Rose Pine', bg: '#191724', surface: '#1f1d2e', text: '#e0def4',
      textSec: '#908caa', link: '#9ccfd8', accent: '#c4a7e7', border: '#26233a', imgBrightness: 0.9
    },
    ayu: {
      name: 'Ayu Dark', bg: '#0a0e14', surface: '#0d1117', text: '#bfbdb6',
      textSec: '#565b66', link: '#39bae6', accent: '#e6b450', border: '#11151c', imgBrightness: 0.9
    },
    palenight: {
      name: 'Palenight', bg: '#292d3e', surface: '#2f3344', text: '#a6accd',
      textSec: '#676e95', link: '#82aaff', accent: '#c792ea', border: '#3a3f58', imgBrightness: 0.9
    },
    horizon: {
      name: 'Horizon', bg: '#1c1e26', surface: '#232530', text: '#d5d8da',
      textSec: '#6c6f93', link: '#e95678', accent: '#fab795', border: '#2e303e', imgBrightness: 0.9
    },
    everforest: {
      name: 'Everforest', bg: '#2d353b', surface: '#343f44', text: '#d3c6aa',
      textSec: '#859289', link: '#a7c080', accent: '#83c092', border: '#475258', imgBrightness: 0.9
    },
    kanagawa: {
      name: 'Kanagawa', bg: '#1f1f28', surface: '#2a2a37', text: '#dcd7ba',
      textSec: '#727169', link: '#7e9cd8', accent: '#957fb8', border: '#363646', imgBrightness: 0.9
    },
    material: {
      name: 'Material Dark', bg: '#212121', surface: '#2c2c2c', text: '#eeffff',
      textSec: '#b0bec5', link: '#82aaff', accent: '#c792ea', border: '#373737', imgBrightness: 0.9
    },
    cobalt: {
      name: 'Cobalt', bg: '#132738', surface: '#193549', text: '#ffffff',
      textSec: '#8ba7c0', link: '#ffc600', accent: '#ff9d00', border: '#1f4662', imgBrightness: 0.9
    }
  };

  var DARK_MODE_SKIP_SITES = [
    'github.com', 'twitter.com', 'x.com', 'reddit.com', 'discord.com',
    'slack.com', 'notion.so', 'figma.com', 'linear.app', 'vercel.com',
    'youtube.com', 'spotify.com', 'netflix.com', 'twitch.tv', 'vscode.dev',
    'codepen.io', 'stackoverflow.com', 'gitlab.com', 'bitbucket.org'
  ];

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.DarkModeThemes = {
    THEMES: THEMES,
    DARK_MODE_SKIP_SITES: DARK_MODE_SKIP_SITES
  };
})();
