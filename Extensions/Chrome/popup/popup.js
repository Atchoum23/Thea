// Thea Chrome Extension Popup Script
// Matches tabbed UI: Actions | Shield | Tools

document.addEventListener('DOMContentLoaded', async () => {
  setupTabs();
  setupEventListeners();
  await loadStats();
  await loadToggles();
  await checkiCloudStatus();
});

// ============================================================================
// Tab Navigation
// ============================================================================

function setupTabs() {
  const tabs = document.querySelectorAll('.tab');
  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      tabs.forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
      tab.classList.add('active');
      document.getElementById(`tab-${tab.dataset.tab}`).classList.add('active');
    });
  });
}

// ============================================================================
// Stats Dashboard
// ============================================================================

async function loadStats() {
  try {
    const response = await chrome.runtime.sendMessage({ action: 'getStats' });
    const stats = response || {};

    document.getElementById('stat-blocked').textContent = formatNumber(
      (stats.adsBlocked || 0) + (stats.trackersBlocked || 0)
    );
    document.getElementById('stat-trackers').textContent = formatNumber(
      stats.trackersBlocked || 0
    );
    document.getElementById('stat-cookies').textContent = formatNumber(
      stats.cookiesDeclined || 0
    );
    document.getElementById('stat-memories').textContent = formatNumber(
      stats.memoriesSaved || 0
    );
  } catch (err) {
    console.error('Failed to load stats:', err);
  }
}

function formatNumber(n) {
  if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
  if (n >= 1000) return (n / 1000).toFixed(1) + 'K';
  return String(n);
}

// ============================================================================
// Toggle States (Shield + Tools tabs)
// ============================================================================

async function loadToggles() {
  try {
    const response = await chrome.runtime.sendMessage({ action: 'getState' });
    if (!response) return;

    // Shield tab
    setToggle('toggle-adblock', response.adBlockerEnabled);
    setToggle('toggle-privacy', response.privacyProtectionEnabled);
    setToggle('toggle-cookies', response.privacyConfig?.cookieAutoDecline);
    setToggle('toggle-email', response.emailProtectionEnabled);
    setToggle('toggle-passwords', response.passwordManagerEnabled);

    // Tools tab
    setToggle('toggle-darkmode', response.darkModeEnabled);
    setToggle('toggle-video', response.videoControllerEnabled);
    setToggle('toggle-ai', response.aiAssistantEnabled);
    setToggle('toggle-memory', response.memoryEnabled);
  } catch (err) {
    console.error('Failed to load toggles:', err);
  }
}

function setToggle(id, value) {
  const el = document.getElementById(id);
  if (el) el.checked = value !== false;
}

// ============================================================================
// Event Listeners
// ============================================================================

function setupEventListeners() {
  // Header buttons
  document.getElementById('sidebar-btn').addEventListener('click', openAISidebar);
  document.getElementById('settings-btn').addEventListener('click', () => {
    chrome.runtime.openOptionsPage();
  });

  // Actions tab buttons
  document.getElementById('summarize-btn').addEventListener('click', summarizePage);
  document.getElementById('reader-btn').addEventListener('click', activateReaderMode);
  document.getElementById('ai-sidebar-btn').addEventListener('click', openAISidebar);
  document.getElementById('save-memory-btn').addEventListener('click', saveToMemory);
  document.getElementById('pick-element-btn').addEventListener('click', activateElementPicker);
  document.getElementById('passwords-btn').addEventListener('click', openPasswordManager);

  // Shield tab toggles
  bindToggle('toggle-adblock', 'adBlockerEnabled');
  bindToggle('toggle-privacy', 'privacyProtectionEnabled');
  bindToggle('toggle-cookies', 'cookieAutoDecline', true);
  bindToggle('toggle-email', 'emailProtectionEnabled');
  bindToggle('toggle-passwords', 'passwordManagerEnabled');

  // Tools tab toggles
  bindToggle('toggle-darkmode', 'darkModeEnabled');
  bindToggle('toggle-video', 'videoControllerEnabled');
  bindToggle('toggle-ai', 'aiAssistantEnabled');
  bindToggle('toggle-memory', 'memoryEnabled');

  // Footer
  document.getElementById('open-app-btn').addEventListener('click', (e) => {
    e.preventDefault();
    chrome.runtime.sendMessage({ action: 'syncWithApp' });
  });
}

function bindToggle(toggleId, featureKey, isPrivacySubKey = false) {
  const el = document.getElementById(toggleId);
  if (!el) return;

  el.addEventListener('change', async () => {
    if (isPrivacySubKey) {
      const config = await chrome.runtime.sendMessage({ action: 'getPrivacyConfig' });
      const updated = { ...(config || {}), [featureKey]: el.checked };
      await chrome.runtime.sendMessage({ action: 'savePrivacyConfig', config: updated });
    } else {
      await chrome.runtime.sendMessage({
        action: 'toggleFeature',
        feature: featureKey,
        enabled: el.checked
      });
    }
  });
}

// ============================================================================
// Action Handlers
// ============================================================================

async function summarizePage() {
  const btn = document.getElementById('summarize-btn');
  btn.classList.add('loading');
  btn.disabled = true;

  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    const [result] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: () => document.body.innerText.substring(0, 10000)
    });

    const response = await chrome.runtime.sendMessage({
      action: 'analyzeContent',
      content: result.result,
      task: 'summarize'
    });

    showNotification(response?.summary || 'Unable to summarize this page.');
  } catch (error) {
    showNotification('Error: ' + error.message);
  } finally {
    btn.classList.remove('loading');
    btn.disabled = false;
  }
}

async function activateReaderMode() {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    await chrome.tabs.sendMessage(tab.id, { action: 'activatePrintFriendly' });
    window.close();
  } catch (error) {
    showNotification('Error activating reader mode.');
  }
}

async function openAISidebar() {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    await chrome.tabs.sendMessage(tab.id, { action: 'toggleAISidebar' });
    window.close();
  } catch (error) {
    showNotification('Error opening AI sidebar.');
  }
}

async function saveToMemory() {
  const btn = document.getElementById('save-memory-btn');
  btn.classList.add('loading');
  btn.disabled = true;

  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    const [result] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: () => ({
        title: document.title,
        url: location.href,
        description: document.querySelector('meta[name="description"]')?.content || '',
        content: document.body.innerText.substring(0, 5000)
      })
    });

    const response = await chrome.runtime.sendMessage({
      action: 'saveToMemory',
      data: result.result
    });

    showNotification(response?.success ? 'Saved to memory!' : 'Failed to save.');
    await loadStats();
  } catch (error) {
    showNotification('Error: ' + error.message);
  } finally {
    btn.classList.remove('loading');
    btn.disabled = false;
  }
}

async function activateElementPicker() {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    await chrome.tabs.sendMessage(tab.id, { action: 'activateElementPicker' });
    window.close();
  } catch (error) {
    showNotification('Error activating element picker.');
  }
}

async function openPasswordManager() {
  try {
    await chrome.runtime.sendMessage({ action: 'openPasswordManager' });
  } catch (error) {
    showNotification('Error opening password manager.');
  }
}

// ============================================================================
// iCloud Status
// ============================================================================

async function checkiCloudStatus() {
  const statusEl = document.getElementById('icloud-status');
  const textEl = document.getElementById('icloud-text');
  if (!statusEl || !textEl) return;

  try {
    const response = await chrome.runtime.sendMessage({ action: 'getiCloudStatus' });
    if (response?.connected) {
      statusEl.classList.add('connected');
      textEl.textContent = 'iCloud: Connected';
    } else {
      statusEl.classList.remove('connected');
      textEl.textContent = 'iCloud: Not connected';
    }
  } catch {
    textEl.textContent = 'iCloud: Unavailable';
  }
}

// ============================================================================
// Notification Toast
// ============================================================================

function showNotification(message) {
  let toast = document.getElementById('thea-toast');
  if (!toast) {
    toast = document.createElement('div');
    toast.id = 'thea-toast';
    toast.className = 'toast';
    document.body.appendChild(toast);
  }

  toast.textContent = message;
  toast.classList.add('show');

  setTimeout(() => {
    toast.classList.remove('show');
  }, 3000);
}
