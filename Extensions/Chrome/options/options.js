// Thea Chrome Extension Options Script

document.addEventListener('DOMContentLoaded', async () => {
  await loadSettings();
  await checkConnection();
  setupEventListeners();
});

// Default settings
const defaultSettings = {
  adBlocking: true,
  trackerBlocking: true,
  cookieDecline: false,
  summarization: true,
  smartForms: true,
  browsingMemory: false,
  theme: 'dark',
  popupPosition: 'top-right'
};

// Load Settings
async function loadSettings() {
  const settings = await chrome.storage.local.get(Object.keys(defaultSettings));

  // Apply defaults for missing settings
  const mergedSettings = { ...defaultSettings, ...settings };

  // Set toggle states
  document.getElementById('ad-blocking').checked = mergedSettings.adBlocking;
  document.getElementById('tracker-blocking').checked = mergedSettings.trackerBlocking;
  document.getElementById('cookie-decline').checked = mergedSettings.cookieDecline;
  document.getElementById('summarization').checked = mergedSettings.summarization;
  document.getElementById('smart-forms').checked = mergedSettings.smartForms;
  document.getElementById('browsing-memory').checked = mergedSettings.browsingMemory;

  // Set select values
  document.getElementById('theme').value = mergedSettings.theme;
  document.getElementById('popup-position').value = mergedSettings.popupPosition;
}

// Save Settings
async function saveSettings() {
  const settings = {
    adBlocking: document.getElementById('ad-blocking').checked,
    trackerBlocking: document.getElementById('tracker-blocking').checked,
    cookieDecline: document.getElementById('cookie-decline').checked,
    summarization: document.getElementById('summarization').checked,
    smartForms: document.getElementById('smart-forms').checked,
    browsingMemory: document.getElementById('browsing-memory').checked,
    theme: document.getElementById('theme').value,
    popupPosition: document.getElementById('popup-position').value
  };

  await chrome.storage.local.set(settings);

  // Notify background script
  chrome.runtime.sendMessage({
    action: 'settingsUpdated',
    settings
  });

  // Show saved message
  const savedMsg = document.getElementById('saved-message');
  savedMsg.classList.add('show');
  setTimeout(() => savedMsg.classList.remove('show'), 2000);
}

// Reset Settings
async function resetSettings() {
  if (confirm('Are you sure you want to reset all settings to defaults?')) {
    await chrome.storage.local.set(defaultSettings);
    await loadSettings();

    chrome.runtime.sendMessage({
      action: 'settingsUpdated',
      settings: defaultSettings
    });

    const savedMsg = document.getElementById('saved-message');
    savedMsg.textContent = 'Settings reset!';
    savedMsg.classList.add('show');
    setTimeout(() => {
      savedMsg.classList.remove('show');
      savedMsg.textContent = 'Settings saved!';
    }, 2000);
  }
}

// Check Connection
async function checkConnection() {
  const statusEl = document.getElementById('connection-status');

  try {
    const response = await chrome.runtime.sendMessage({ action: 'getStatus' });

    if (response?.connected) {
      statusEl.textContent = 'Connected to Thea';
      statusEl.style.color = '#38a169';
    } else {
      statusEl.textContent = 'Not connected - Thea app may not be running';
      statusEl.style.color = '#d69e2e';
    }
  } catch (error) {
    statusEl.textContent = 'Connection error';
    statusEl.style.color = '#e94560';
  }
}

// Test Connection
async function testConnection() {
  const statusEl = document.getElementById('connection-status');
  const btn = document.getElementById('test-connection');

  btn.disabled = true;
  btn.textContent = 'Testing...';
  statusEl.textContent = 'Testing connection...';
  statusEl.style.color = '#a0aec0';

  try {
    const response = await chrome.runtime.sendMessage({ action: 'testConnection' });

    if (response?.success) {
      statusEl.textContent = `Connected! Thea v${response.version || 'unknown'}`;
      statusEl.style.color = '#38a169';
    } else {
      statusEl.textContent = response?.error || 'Connection failed';
      statusEl.style.color = '#e94560';
    }
  } catch (error) {
    statusEl.textContent = 'Connection error: ' + error.message;
    statusEl.style.color = '#e94560';
  } finally {
    btn.disabled = false;
    btn.textContent = 'Test Connection';
  }
}

// Setup Event Listeners
function setupEventListeners() {
  document.getElementById('save-btn').addEventListener('click', saveSettings);
  document.getElementById('reset-btn').addEventListener('click', resetSettings);
  document.getElementById('test-connection').addEventListener('click', testConnection);

  // Auto-save on toggle change
  const toggles = document.querySelectorAll('.toggle input');
  toggles.forEach(toggle => {
    toggle.addEventListener('change', saveSettings);
  });

  // Auto-save on select change
  const selects = document.querySelectorAll('select');
  selects.forEach(select => {
    select.addEventListener('change', saveSettings);
  });
}
