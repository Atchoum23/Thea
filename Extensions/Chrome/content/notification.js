// Thea Chrome Extension - Shared Notification Module
// Toast notifications, loading indicators, AI response popups

(function() {
  'use strict';

  // Initialize shared namespace
  window.TheaModules = window.TheaModules || {};

  // ============================================================================
  // HTML Escaping (shared utility)
  // ============================================================================

  /**
   * Escapes HTML special characters to prevent XSS attacks.
   * SECURITY: Always use this when inserting user-generated or external content into HTML.
   * @param {string} text - The text to escape
   * @returns {string} - HTML-escaped text safe for innerHTML
   */
  function escapeHtml(text) {
    if (text == null) return '';
    const div = document.createElement('div');
    div.textContent = String(text);
    return div.innerHTML;
  }

  // ============================================================================
  // Toast Notification
  // ============================================================================

  function showNotification(message) {
    const notification = document.createElement('div');
    notification.style.cssText = `
      position: fixed;
      bottom: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: #323232;
      color: white;
      padding: 12px 24px;
      border-radius: 8px;
      z-index: 1000000;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      font-size: 14px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.3);
    `;
    notification.textContent = message;
    document.body.appendChild(notification);

    setTimeout(() => {
      notification.style.opacity = '0';
      notification.style.transition = 'opacity 0.3s';
      setTimeout(() => notification.remove(), 300);
    }, 3000);
  }

  // ============================================================================
  // AI Response Popup
  // ============================================================================

  function showAIResponsePopup(response) {
    const popup = document.createElement('div');
    popup.style.cssText = `
      position: fixed;
      bottom: 20px;
      right: 20px;
      background: white;
      border-radius: 12px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.2);
      padding: 16px;
      max-width: 400px;
      z-index: 1000000;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    `;

    // SECURITY: Escape AI response to prevent XSS from malicious API responses
    popup.innerHTML = `
      <div style="display: flex; justify-content: space-between; margin-bottom: 12px;">
        <strong style="color: #2196F3;">Thea AI</strong>
        <button style="border: none; background: none; cursor: pointer; font-size: 16px;">✕</button>
      </div>
      <div style="line-height: 1.5; color: #333;">${escapeHtml(response)}</div>
    `;

    popup.querySelector('button').addEventListener('click', () => popup.remove());
    document.body.appendChild(popup);

    // Auto remove after 30 seconds
    setTimeout(() => popup.remove(), 30000);
  }

  // ============================================================================
  // Quick Prompt Dialog
  // ============================================================================

  let quickPromptElement = null;

  function showQuickPrompt() {
    // Remove existing
    if (quickPromptElement) {
      quickPromptElement.remove();
    }

    quickPromptElement = document.createElement('div');
    quickPromptElement.id = 'thea-quick-prompt';
    quickPromptElement.innerHTML = `
      <style>
        #thea-quick-prompt {
          position: fixed;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          background: white;
          border-radius: 16px;
          box-shadow: 0 8px 32px rgba(0,0,0,0.3);
          width: 600px;
          max-width: 90vw;
          z-index: 1000000;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        #thea-quick-prompt .header {
          padding: 16px 20px;
          border-bottom: 1px solid #eee;
          display: flex;
          align-items: center;
          gap: 12px;
        }
        #thea-quick-prompt .header svg {
          color: #2196F3;
        }
        #thea-quick-prompt .header h3 {
          margin: 0;
          font-size: 16px;
          font-weight: 600;
        }
        #thea-quick-prompt .body {
          padding: 20px;
        }
        #thea-quick-prompt textarea {
          width: 100%;
          border: 1px solid #ddd;
          border-radius: 8px;
          padding: 12px;
          font-size: 15px;
          resize: none;
          font-family: inherit;
        }
        #thea-quick-prompt textarea:focus {
          outline: none;
          border-color: #2196F3;
        }
        #thea-quick-prompt .response {
          margin-top: 16px;
          padding: 16px;
          background: #f5f5f5;
          border-radius: 8px;
          display: none;
          max-height: 300px;
          overflow-y: auto;
        }
        #thea-quick-prompt .footer {
          padding: 12px 20px;
          border-top: 1px solid #eee;
          display: flex;
          justify-content: flex-end;
          gap: 8px;
        }
        #thea-quick-prompt button {
          padding: 8px 16px;
          border: none;
          border-radius: 6px;
          cursor: pointer;
          font-size: 14px;
        }
        #thea-quick-prompt button.primary {
          background: #2196F3;
          color: white;
        }
        #thea-quick-prompt button.secondary {
          background: #e0e0e0;
        }
        #thea-quick-prompt .overlay {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          background: rgba(0,0,0,0.5);
          z-index: -1;
        }
      </style>
      <div class="overlay"></div>
      <div class="header">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z"/>
        </svg>
        <h3>Ask Thea</h3>
      </div>
      <div class="body">
        <textarea rows="3" placeholder="Ask anything about this page..."></textarea>
        <div class="response"></div>
      </div>
      <div class="footer">
        <button class="secondary" id="thea-prompt-close">Cancel</button>
        <button class="primary" id="thea-prompt-submit">Ask</button>
      </div>
    `;

    document.body.appendChild(quickPromptElement);

    const textarea = quickPromptElement.querySelector('textarea');
    const responseDiv = quickPromptElement.querySelector('.response');
    const submitBtn = quickPromptElement.querySelector('#thea-prompt-submit');
    const closeBtn = quickPromptElement.querySelector('#thea-prompt-close');
    const overlay = quickPromptElement.querySelector('.overlay');

    textarea.focus();

    submitBtn.addEventListener('click', async () => {
      const question = textarea.value.trim();
      if (!question) return;

      submitBtn.disabled = true;
      submitBtn.textContent = 'Thinking...';

      try {
        const response = await chrome.runtime.sendMessage({
          type: 'askAI',
          data: {
            question,
            context: {
              url: window.location.href,
              title: document.title,
              selection: window.getSelection()?.toString()
            }
          }
        });

        responseDiv.style.display = 'block';
        responseDiv.textContent = response.data.response;
      } catch (e) {
        responseDiv.style.display = 'block';
        responseDiv.textContent = 'Failed to get response';
      }

      submitBtn.disabled = false;
      submitBtn.textContent = 'Ask';
    });

    const close = () => quickPromptElement.remove();
    closeBtn.addEventListener('click', close);
    overlay.addEventListener('click', close);

    // Close on Escape
    document.addEventListener('keydown', function escHandler(e) {
      if (e.key === 'Escape') {
        close();
        document.removeEventListener('keydown', escHandler);
      }
    });
  }

  // ============================================================================
  // Save Password Dialog
  // ============================================================================

  function promptSavePassword() {
    const passwordFields = document.querySelectorAll('input[type="password"]');
    if (passwordFields.length === 0) {
      showNotification('No password field found');
      return;
    }

    const form = passwordFields[0].closest('form');
    if (!form) return;

    const usernameField = form.querySelector('input[type="text"], input[type="email"]');
    if (!usernameField) return;

    const username = usernameField.value;
    const password = passwordFields[0].value;

    if (!username || !password) {
      showNotification('Please fill in credentials first');
      return;
    }

    // Show save dialog
    // SECURITY: Escape username and hostname to prevent XSS
    const dialog = document.createElement('div');
    dialog.innerHTML = `
      <div style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.5); z-index: 999999; display: flex; align-items: center; justify-content: center;">
        <div style="background: white; border-radius: 12px; padding: 24px; width: 350px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;">
          <h3 style="margin: 0 0 16px;">Save Password?</h3>
          <p style="margin: 0 0 8px; color: #666;">Username: ${escapeHtml(username)}</p>
          <p style="margin: 0 0 16px; color: #666;">Site: ${escapeHtml(window.location.hostname)}</p>
          <div style="display: flex; gap: 8px; justify-content: flex-end;">
            <button id="thea-save-no" style="padding: 8px 16px; border: 1px solid #ddd; border-radius: 6px; background: white; cursor: pointer;">Not Now</button>
            <button id="thea-save-yes" style="padding: 8px 16px; border: none; border-radius: 6px; background: #2196F3; color: white; cursor: pointer;">Save</button>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(dialog);

    dialog.querySelector('#thea-save-no').addEventListener('click', () => dialog.remove());
    dialog.querySelector('#thea-save-yes').addEventListener('click', async () => {
      try {
        await chrome.runtime.sendMessage({
          type: 'saveCredential',
          data: {
            domain: window.location.hostname,
            username,
            password
          }
        });
        showNotification('Password saved!');
      } catch (e) {
        showNotification('Failed to save password');
      }
      dialog.remove();
    });
  }

  // ============================================================================
  // Export to shared namespace
  // ============================================================================

  window.TheaModules.escapeHtml = escapeHtml;
  window.TheaModules.showNotification = showNotification;
  window.TheaModules.showAIResponsePopup = showAIResponsePopup;
  window.TheaModules.showQuickPrompt = showQuickPrompt;
  window.TheaModules.promptSavePassword = promptSavePassword;

})();
