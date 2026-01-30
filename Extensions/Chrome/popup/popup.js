// Thea Chrome Extension Popup Script

document.addEventListener('DOMContentLoaded', async () => {
  // Initialize UI
  await initializeStatus();
  await loadSettings();
  setupEventListeners();
  await updateBlockedCount();
});

// Status Management
async function initializeStatus() {
  const statusDot = document.querySelector('.status-dot');
  const statusText = document.querySelector('.status-text');

  try {
    // Check if native messaging is available
    const response = await chrome.runtime.sendMessage({ action: 'getStatus' });
    if (response?.connected) {
      statusDot.classList.add('connected');
      statusText.textContent = 'Connected to Thea';
    } else {
      statusDot.classList.remove('connected');
      statusText.textContent = 'Thea app not running';
    }
  } catch (error) {
    statusDot.classList.add('error');
    statusText.textContent = 'Connection error';
    console.error('Status check failed:', error);
  }
}

// Settings Management
async function loadSettings() {
  const settings = await chrome.storage.local.get(['adBlocking', 'trackerBlocking']);

  document.getElementById('ad-blocking').checked = settings.adBlocking !== false;
  document.getElementById('tracker-blocking').checked = settings.trackerBlocking !== false;
}

async function saveSettings() {
  const adBlocking = document.getElementById('ad-blocking').checked;
  const trackerBlocking = document.getElementById('tracker-blocking').checked;

  await chrome.storage.local.set({ adBlocking, trackerBlocking });

  // Notify background script
  chrome.runtime.sendMessage({
    action: 'updateSettings',
    settings: { adBlocking, trackerBlocking }
  });
}

// Event Listeners
function setupEventListeners() {
  // Settings button
  document.getElementById('settings-btn').addEventListener('click', () => {
    chrome.runtime.openOptionsPage();
  });

  // Quick action buttons
  document.getElementById('summarize-btn').addEventListener('click', summarizePage);
  document.getElementById('dark-mode-btn').addEventListener('click', toggleDarkMode);
  document.getElementById('clean-page-btn').addEventListener('click', cleanPage);
  document.getElementById('save-memory-btn').addEventListener('click', saveToMemory);

  // Chat input
  document.getElementById('chat-input').addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
      sendChatMessage();
    }
  });
  document.getElementById('send-btn').addEventListener('click', sendChatMessage);

  // Toggle switches
  document.getElementById('ad-blocking').addEventListener('change', saveSettings);
  document.getElementById('tracker-blocking').addEventListener('change', saveSettings);

  // Open app button
  document.getElementById('open-app-btn').addEventListener('click', (e) => {
    e.preventDefault();
    chrome.runtime.sendMessage({ action: 'openTheaApp' });
  });
}

// Quick Actions
async function summarizePage() {
  const btn = document.getElementById('summarize-btn');
  btn.disabled = true;

  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

    // Get page content
    const [result] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: () => document.body.innerText.substring(0, 10000)
    });

    const response = await chrome.runtime.sendMessage({
      action: 'analyzeContent',
      content: result.result,
      task: 'summarize'
    });

    showChatResponse(response?.summary || 'Unable to summarize this page.');
  } catch (error) {
    showChatResponse('Error: ' + error.message);
  } finally {
    btn.disabled = false;
  }
}

async function toggleDarkMode() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

  await chrome.scripting.executeScript({
    target: { tabId: tab.id },
    func: () => {
      const isDark = document.body.classList.toggle('thea-dark-mode');

      if (isDark) {
        const style = document.createElement('style');
        style.id = 'thea-dark-mode-styles';
        style.textContent = `
          html { filter: invert(1) hue-rotate(180deg); }
          img, video, canvas, [style*="background-image"] { filter: invert(1) hue-rotate(180deg); }
        `;
        document.head.appendChild(style);
      } else {
        document.getElementById('thea-dark-mode-styles')?.remove();
      }
    }
  });
}

async function cleanPage() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

  await chrome.scripting.executeScript({
    target: { tabId: tab.id },
    func: () => {
      // Remove common clutter elements
      const selectors = [
        'header', 'footer', 'nav', 'aside',
        '[class*="sidebar"]', '[class*="banner"]', '[class*="popup"]',
        '[class*="modal"]', '[class*="cookie"]', '[class*="newsletter"]',
        '[class*="ad-"]', '[class*="advertisement"]', '[id*="ad-"]',
        '.social-share', '.related-posts', '.comments'
      ];

      selectors.forEach(selector => {
        document.querySelectorAll(selector).forEach(el => {
          el.style.display = 'none';
        });
      });

      // Enhance readability
      document.body.style.maxWidth = '800px';
      document.body.style.margin = '0 auto';
      document.body.style.padding = '20px';
      document.body.style.fontSize = '18px';
      document.body.style.lineHeight = '1.6';
    }
  });

  showChatResponse('Page cleaned for reading.');
}

async function saveToMemory() {
  const btn = document.getElementById('save-memory-btn');
  btn.disabled = true;

  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

    // Get page metadata
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

    if (response?.success) {
      showChatResponse('Saved to Thea memory!');
    } else {
      showChatResponse('Could not save. Is Thea app running?');
    }
  } catch (error) {
    showChatResponse('Error: ' + error.message);
  } finally {
    btn.disabled = false;
  }
}

// Chat Functions
async function sendChatMessage() {
  const input = document.getElementById('chat-input');
  const message = input.value.trim();

  if (!message) return;

  input.value = '';
  input.disabled = true;

  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });

    // Get page context
    const [result] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: () => ({
        title: document.title,
        url: location.href,
        content: document.body.innerText.substring(0, 5000)
      })
    });

    const response = await chrome.runtime.sendMessage({
      action: 'askThea',
      message: message,
      context: result.result
    });

    showChatResponse(response?.answer || 'No response from Thea.');
  } catch (error) {
    showChatResponse('Error: ' + error.message);
  } finally {
    input.disabled = false;
    input.focus();
  }
}

function showChatResponse(text) {
  const responseEl = document.getElementById('chat-response');
  responseEl.textContent = text;
  responseEl.classList.remove('hidden');
}

// Blocked Count
async function updateBlockedCount() {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    const response = await chrome.runtime.sendMessage({
      action: 'getBlockedCount',
      tabId: tab.id
    });

    document.getElementById('blocked-count').textContent = response?.count || 0;
  } catch (error) {
    console.error('Failed to get blocked count:', error);
  }
}
