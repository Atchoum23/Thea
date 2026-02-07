// Thea Chrome Extension Options Script
// Sidebar-navigated settings page with auto-save

document.addEventListener('DOMContentLoaded', async () => {
  setupNavigation();
  setupEventListeners();
  await loadAllSettings();
  await loadStats();
  await checkConnections();
});

// ============================================================================
// Sidebar Navigation
// ============================================================================

function setupNavigation() {
  document.querySelectorAll('.nav-item').forEach(item => {
    item.addEventListener('click', () => {
      document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
      document.querySelectorAll('.settings-section').forEach(s => s.classList.remove('active'));
      item.classList.add('active');
      document.getElementById(`section-${item.dataset.section}`).classList.add('active');
    });
  });
}

// ============================================================================
// Load All Settings
// ============================================================================

async function loadAllSettings() {
  try {
    const state = await chrome.runtime.sendMessage({ action: 'getState' });
    if (!state) return;

    // General
    setSelect('opt-theme', 'dark');

    // Privacy & Blocking
    setToggle('opt-adblock', state.adBlockerEnabled);
    setToggle('opt-cosmetic', true);
    setToggle('opt-email', state.emailProtectionEnabled);

    // Privacy config
    const pc = state.privacyConfig || {};
    setToggle('opt-cookie-decline', pc.cookieAutoDecline);
    setToggle('opt-fingerprint', pc.fingerprintProtection);
    setToggle('opt-referrer', pc.referrerStripping);
    setToggle('opt-unshim', pc.linkUnshimming);
    setToggle('opt-tracking-params', pc.trackingParamRemoval);
    setToggle('opt-social', pc.socialWidgetBlocking);
    setToggle('opt-webrtc', pc.webrtcProtection);

    // Whitelist
    const whitelist = state.whitelist || [];
    document.getElementById('whitelist-textarea').value = whitelist.join('\n');

    // Dark Mode
    const dc = state.darkModeConfig || {};
    setToggle('opt-darkmode', dc.enabled);
    setToggle('opt-darkmode-system', dc.followSystem);
    setActiveTheme(dc.theme || 'midnight');

    // Video
    const vc = state.videoConfig || {};
    setToggle('opt-video', vc.enabled);
    setToggle('opt-video-overlay', vc.showOverlay);
    setToggle('opt-video-remember', vc.rememberSpeed);
    setSelect('opt-video-speed', String(vc.defaultSpeed || '1.0'));
    setSelect('opt-video-step', String(vc.speedStep || '0.1'));

    // AI
    setToggle('opt-ai', state.aiAssistantEnabled);
    setToggle('opt-reader', state.printFriendlyEnabled);

    // Passwords
    setToggle('opt-passwords', state.passwordManagerEnabled);
    setToggle('opt-password-suggest', true);
    setToggle('opt-password-update', true);

    // Memory
    setToggle('opt-memory', state.memoryEnabled);
    setToggle('opt-memory-auto', false);
  } catch (err) {
    console.error('Failed to load settings:', err);
  }
}

function setToggle(id, value) {
  const el = document.getElementById(id);
  if (el) el.checked = value !== false;
}

function setSelect(id, value) {
  const el = document.getElementById(id);
  if (el) el.value = value;
}

function setActiveTheme(theme) {
  document.querySelectorAll('.theme-chip').forEach(chip => {
    chip.classList.toggle('active', chip.dataset.theme === theme);
  });
}

// ============================================================================
// Stats
// ============================================================================

async function loadStats() {
  try {
    const stats = await chrome.runtime.sendMessage({ action: 'getStats' }) || {};

    setText('stats-ads', stats.adsBlocked || 0);
    setText('stats-trackers', stats.trackersBlocked || 0);
    setText('stats-cookies', stats.cookiesDeclined || 0);
    setText('stats-passwords', stats.passwordsAutofilled || 0);

    // Memory stats
    const memStats = await chrome.runtime.sendMessage({ action: 'getMemoryStats' }) || {};
    setText('mem-total', memStats.total || 0);
    setText('mem-active', memStats.active || 0);
    setText('mem-archived', memStats.archived || 0);
  } catch (err) {
    console.error('Failed to load stats:', err);
  }
}

function setText(id, value) {
  const el = document.getElementById(id);
  if (el) el.textContent = String(value);
}

// ============================================================================
// Connection Checks
// ============================================================================

async function checkConnections() {
  // App connection
  try {
    const response = await chrome.runtime.sendMessage({ action: 'getStatus' });
    const el = document.getElementById('connection-status');
    if (response?.connected) {
      el.textContent = 'Connected to Thea';
      el.style.color = '#38a169';
    } else {
      el.textContent = 'Not connected';
      el.style.color = '#d69e2e';
    }
  } catch {
    document.getElementById('connection-status').textContent = 'Error';
  }

  // iCloud
  try {
    const response = await chrome.runtime.sendMessage({ action: 'getiCloudStatus' });
    const el = document.getElementById('icloud-status');
    if (response?.connected) {
      el.textContent = 'Connected';
      el.style.color = '#38a169';
    } else {
      el.textContent = 'Not connected';
      el.style.color = '#d69e2e';
    }
  } catch {
    document.getElementById('icloud-status').textContent = 'Unavailable';
  }
}

// ============================================================================
// Event Listeners
// ============================================================================

function setupEventListeners() {
  // Feature toggles -> auto-save
  const featureToggles = {
    'opt-adblock': 'adBlockerEnabled',
    'opt-email': 'emailProtectionEnabled',
    'opt-ai': 'aiAssistantEnabled',
    'opt-reader': 'printFriendlyEnabled',
    'opt-passwords': 'passwordManagerEnabled',
    'opt-memory': 'memoryEnabled',
  };

  Object.entries(featureToggles).forEach(([id, feature]) => {
    const el = document.getElementById(id);
    if (el) el.addEventListener('change', () => {
      chrome.runtime.sendMessage({ action: 'toggleFeature', feature, enabled: el.checked });
      showToast();
    });
  });

  // Privacy config toggles
  const privacyToggles = [
    'opt-cookie-decline', 'opt-fingerprint', 'opt-referrer',
    'opt-unshim', 'opt-tracking-params', 'opt-social', 'opt-webrtc'
  ];
  privacyToggles.forEach(id => {
    const el = document.getElementById(id);
    if (el) el.addEventListener('change', savePrivacyConfig);
  });

  // Dark mode settings
  document.getElementById('opt-darkmode')?.addEventListener('change', saveDarkModeConfig);
  document.getElementById('opt-darkmode-system')?.addEventListener('change', saveDarkModeConfig);

  // Theme chips
  document.querySelectorAll('.theme-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      setActiveTheme(chip.dataset.theme);
      saveDarkModeConfig();
    });
  });

  // Video config
  ['opt-video', 'opt-video-overlay', 'opt-video-remember',
   'opt-video-speed', 'opt-video-step'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.addEventListener('change', saveVideoConfig);
  });

  // Whitelist
  document.getElementById('manage-whitelist')?.addEventListener('click', () => {
    document.getElementById('whitelist-editor').classList.toggle('hidden');
  });
  document.getElementById('save-whitelist')?.addEventListener('click', saveWhitelist);

  // Connection buttons
  document.getElementById('test-connection')?.addEventListener('click', testConnection);
  document.getElementById('connect-icloud')?.addEventListener('click', connectiCloud);

  // Data actions
  document.getElementById('export-data')?.addEventListener('click', exportData);
  document.getElementById('import-data')?.addEventListener('click', () => {
    document.getElementById('import-file').click();
  });
  document.getElementById('import-file')?.addEventListener('change', importData);
  document.getElementById('reset-btn')?.addEventListener('click', resetSettings);
  document.getElementById('clear-all-btn')?.addEventListener('click', clearAllData);
}

// ============================================================================
// Save Handlers
// ============================================================================

async function savePrivacyConfig() {
  const config = {
    cookieAutoDecline: document.getElementById('opt-cookie-decline').checked,
    fingerprintProtection: document.getElementById('opt-fingerprint').checked,
    referrerStripping: document.getElementById('opt-referrer').checked,
    linkUnshimming: document.getElementById('opt-unshim').checked,
    trackingParamRemoval: document.getElementById('opt-tracking-params').checked,
    socialWidgetBlocking: document.getElementById('opt-social').checked,
    webrtcProtection: document.getElementById('opt-webrtc').checked,
  };
  await chrome.runtime.sendMessage({ action: 'savePrivacyConfig', config });
  showToast();
}

async function saveDarkModeConfig() {
  const activeChip = document.querySelector('.theme-chip.active');
  const config = {
    enabled: document.getElementById('opt-darkmode').checked,
    followSystem: document.getElementById('opt-darkmode-system').checked,
    theme: activeChip?.dataset.theme || 'midnight',
  };
  await chrome.runtime.sendMessage({ action: 'saveDarkModeConfig', config });
  showToast();
}

async function saveVideoConfig() {
  const config = {
    enabled: document.getElementById('opt-video').checked,
    showOverlay: document.getElementById('opt-video-overlay').checked,
    rememberSpeed: document.getElementById('opt-video-remember').checked,
    defaultSpeed: parseFloat(document.getElementById('opt-video-speed').value),
    speedStep: parseFloat(document.getElementById('opt-video-step').value),
  };
  await chrome.runtime.sendMessage({ action: 'saveVideoConfig', config });
  showToast();
}

async function saveWhitelist() {
  const text = document.getElementById('whitelist-textarea').value;
  const whitelist = text.split('\n').map(s => s.trim()).filter(Boolean);
  await chrome.runtime.sendMessage({
    action: 'setState',
    state: { whitelist }
  });
  showToast();
}

// ============================================================================
// Action Handlers
// ============================================================================

async function testConnection() {
  const btn = document.getElementById('test-connection');
  const statusEl = document.getElementById('connection-status');
  btn.disabled = true;
  btn.textContent = 'Testing...';

  try {
    const response = await chrome.runtime.sendMessage({ action: 'getStatus' });
    if (response?.connected) {
      statusEl.textContent = 'Connected!';
      statusEl.style.color = '#38a169';
    } else {
      statusEl.textContent = 'Not connected';
      statusEl.style.color = '#e94560';
    }
  } catch {
    statusEl.textContent = 'Connection error';
    statusEl.style.color = '#e94560';
  } finally {
    btn.disabled = false;
    btn.textContent = 'Test';
  }
}

async function connectiCloud() {
  const btn = document.getElementById('connect-icloud');
  btn.disabled = true;
  btn.textContent = 'Connecting...';

  try {
    await chrome.runtime.sendMessage({ action: 'connectiCloud' });
    await checkConnections();
  } catch {
    document.getElementById('icloud-status').textContent = 'Failed';
  } finally {
    btn.disabled = false;
    btn.textContent = 'Connect';
  }
}

async function exportData() {
  try {
    const state = await chrome.runtime.sendMessage({ action: 'getState' });
    const memories = await chrome.runtime.sendMessage({ action: 'exportMemories' });

    const data = { state, memories, exportedAt: new Date().toISOString() };
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);

    const a = document.createElement('a');
    a.href = url;
    a.download = `thea-export-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(url);

    showToast('Data exported!');
  } catch (err) {
    showToast('Export failed: ' + err.message);
  }
}

async function importData(e) {
  const file = e.target.files[0];
  if (!file) return;

  try {
    const text = await file.text();
    const data = JSON.parse(text);

    if (data.state) {
      await chrome.runtime.sendMessage({ action: 'setState', state: data.state });
    }
    if (data.memories) {
      await chrome.runtime.sendMessage({ action: 'importMemories', data: data.memories });
    }

    await loadAllSettings();
    await loadStats();
    showToast('Data imported!');
  } catch (err) {
    showToast('Import failed: ' + err.message);
  }

  e.target.value = '';
}

async function resetSettings() {
  if (!confirm('Reset all settings to defaults? This cannot be undone.')) return;

  try {
    await chrome.storage.local.clear();
    location.reload();
  } catch (err) {
    showToast('Reset failed: ' + err.message);
  }
}

async function clearAllData() {
  if (!confirm('Delete ALL data including memories, stats, and settings? This cannot be undone.')) return;
  if (!confirm('Are you absolutely sure? This will permanently erase everything.')) return;

  try {
    await chrome.runtime.sendMessage({ action: 'deleteAllMemories' });
    await chrome.storage.local.clear();
    location.reload();
  } catch (err) {
    showToast('Clear failed: ' + err.message);
  }
}

// ============================================================================
// Toast
// ============================================================================

function showToast(message = 'Settings saved') {
  const toast = document.getElementById('toast');
  toast.textContent = message;
  toast.classList.add('show');
  setTimeout(() => toast.classList.remove('show'), 2000);
}
