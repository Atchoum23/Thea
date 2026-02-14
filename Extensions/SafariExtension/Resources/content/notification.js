(function() {
  'use strict';

  var THEA_GRADIENT = 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)';
  var NOTIFICATION_Z_INDEX = 2147483640;
  var activeNotifications = [];
  var activeLoading = null;
  var activeModal = null;

  function injectBaseStyles() {
    if (document.getElementById('thea-notification-styles')) return;
    var style = document.createElement('style');
    style.id = 'thea-notification-styles';
    style.textContent = [
      '.thea-toast {',
      '  position: fixed; bottom: 24px; right: 24px; z-index: ' + NOTIFICATION_Z_INDEX + ';',
      '  max-width: 380px; min-width: 260px; padding: 14px 20px;',
      '  background: #1e1e2e; color: #fff; border-radius: 12px;',
      '  box-shadow: 0 8px 32px rgba(0,0,0,0.35); font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;',
      '  font-size: 14px; line-height: 1.5; opacity: 0; transform: translateY(20px);',
      '  transition: opacity 0.3s ease, transform 0.3s ease;',
      '  border-left: 4px solid; border-image: ' + THEA_GRADIENT + ' 1;',
      '}',
      '.thea-toast.thea-visible { opacity: 1; transform: translateY(0); }',
      '.thea-toast-title {',
      '  font-weight: 600; font-size: 13px; margin-bottom: 4px;',
      '  background: ' + THEA_GRADIENT + '; -webkit-background-clip: text; -webkit-text-fill-color: transparent;',
      '}',
      '.thea-toast-message { color: #cdd6f4; font-size: 13px; }',
      '.thea-toast-close {',
      '  position: absolute; top: 8px; right: 10px; background: none; border: none;',
      '  color: #6c7086; cursor: pointer; font-size: 16px; padding: 2px 6px; line-height: 1;',
      '}',
      '.thea-toast-close:hover { color: #fff; }',
      '.thea-loading-overlay {',
      '  position: fixed; top: 0; left: 0; width: 100%; height: 100%;',
      '  z-index: ' + (NOTIFICATION_Z_INDEX + 1) + '; background: rgba(0,0,0,0.4);',
      '  display: flex; align-items: center; justify-content: center;',
      '}',
      '.thea-loading-box {',
      '  background: #1e1e2e; border-radius: 16px; padding: 32px 40px;',
      '  text-align: center; box-shadow: 0 16px 48px rgba(0,0,0,0.5);',
      '}',
      '.thea-loading-spinner {',
      '  width: 40px; height: 40px; border: 3px solid #313244;',
      '  border-top-color: #667eea; border-radius: 50%;',
      '  animation: thea-spin 0.8s linear infinite; margin: 0 auto 16px;',
      '}',
      '@keyframes thea-spin { to { transform: rotate(360deg); } }',
      '.thea-loading-text { color: #cdd6f4; font-size: 14px; font-family: -apple-system, sans-serif; }',
      '.thea-modal-overlay {',
      '  position: fixed; top: 0; left: 0; width: 100%; height: 100%;',
      '  z-index: ' + (NOTIFICATION_Z_INDEX + 2) + '; background: rgba(0,0,0,0.5);',
      '  display: flex; align-items: center; justify-content: center;',
      '  opacity: 0; transition: opacity 0.25s ease;',
      '}',
      '.thea-modal-overlay.thea-visible { opacity: 1; }',
      '.thea-modal {',
      '  background: #1e1e2e; border-radius: 16px; padding: 28px 32px;',
      '  max-width: 560px; width: 90%; max-height: 70vh; overflow-y: auto;',
      '  box-shadow: 0 20px 60px rgba(0,0,0,0.6); position: relative;',
      '}',
      '.thea-modal-title {',
      '  font-size: 18px; font-weight: 700; margin-bottom: 16px;',
      '  background: ' + THEA_GRADIENT + '; -webkit-background-clip: text; -webkit-text-fill-color: transparent;',
      '  font-family: -apple-system, sans-serif;',
      '}',
      '.thea-modal-content {',
      '  color: #cdd6f4; font-size: 14px; line-height: 1.7; font-family: -apple-system, sans-serif;',
      '  white-space: pre-wrap; word-break: break-word;',
      '}',
      '.thea-modal-close {',
      '  position: absolute; top: 12px; right: 16px; background: none; border: none;',
      '  color: #6c7086; cursor: pointer; font-size: 20px; padding: 4px 8px;',
      '}',
      '.thea-modal-close:hover { color: #fff; }'
    ].join('\n');
    document.head.appendChild(style);
  }

  function showNotification(title, message, duration) {
    if (typeof duration === 'undefined') duration = 4000;
    injectBaseStyles();
    var toast = document.createElement('div');
    toast.className = 'thea-toast';
    var offset = activeNotifications.length * 72;
    toast.style.bottom = (24 + offset) + 'px';
    toast.innerHTML =
      '<button class="thea-toast-close" aria-label="Close">&times;</button>' +
      '<div class="thea-toast-title">' + escapeHtml(title) + '</div>' +
      '<div class="thea-toast-message">' + escapeHtml(message) + '</div>';
    document.body.appendChild(toast);
    activeNotifications.push(toast);
    requestAnimationFrame(function() { toast.classList.add('thea-visible'); });
    var closeBtn = toast.querySelector('.thea-toast-close');
    closeBtn.addEventListener('click', function() { removeToast(toast); });
    if (duration > 0) {
      setTimeout(function() { removeToast(toast); }, duration);
    }
    return toast;
  }

  function removeToast(toast) {
    toast.classList.remove('thea-visible');
    setTimeout(function() {
      if (toast.parentNode) toast.parentNode.removeChild(toast);
      var idx = activeNotifications.indexOf(toast);
      if (idx > -1) activeNotifications.splice(idx, 1);
      repositionToasts();
    }, 300);
  }

  function repositionToasts() {
    activeNotifications.forEach(function(t, i) {
      t.style.bottom = (24 + i * 72) + 'px';
    });
  }

  function showLoading(message) {
    if (activeLoading) hideLoading();
    injectBaseStyles();
    var overlay = document.createElement('div');
    overlay.className = 'thea-loading-overlay';
    overlay.innerHTML =
      '<div class="thea-loading-box">' +
      '  <div class="thea-loading-spinner"></div>' +
      '  <div class="thea-loading-text">' + escapeHtml(message || 'Processing...') + '</div>' +
      '</div>';
    document.body.appendChild(overlay);
    activeLoading = overlay;
    return overlay;
  }

  function hideLoading() {
    if (activeLoading && activeLoading.parentNode) {
      activeLoading.parentNode.removeChild(activeLoading);
    }
    activeLoading = null;
  }

  function showResult(title, content) {
    if (activeModal) hideResult();
    injectBaseStyles();
    var overlay = document.createElement('div');
    overlay.className = 'thea-modal-overlay';
    overlay.innerHTML =
      '<div class="thea-modal">' +
      '  <button class="thea-modal-close" aria-label="Close">&times;</button>' +
      '  <div class="thea-modal-title">' + escapeHtml(title) + '</div>' +
      '  <div class="thea-modal-content">' + escapeHtml(content) + '</div>' +
      '</div>';
    document.body.appendChild(overlay);
    activeModal = overlay;
    requestAnimationFrame(function() { overlay.classList.add('thea-visible'); });
    overlay.querySelector('.thea-modal-close').addEventListener('click', hideResult);
    overlay.addEventListener('click', function(e) {
      if (e.target === overlay) hideResult();
    });
    return overlay;
  }

  function hideResult() {
    if (activeModal) {
      activeModal.classList.remove('thea-visible');
      var ref = activeModal;
      setTimeout(function() {
        if (ref.parentNode) ref.parentNode.removeChild(ref);
      }, 250);
      activeModal = null;
    }
  }

  function hideAllNotifications() {
    activeNotifications.slice().forEach(removeToast);
    hideLoading();
    hideResult();
  }

  function escapeHtml(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }

  window.TheaModules = window.TheaModules || {};
  window.TheaModules.Notification = {
    showNotification: showNotification,
    showLoading: showLoading,
    hideLoading: hideLoading,
    showResult: showResult,
    hideResult: hideResult,
    hideAllNotifications: hideAllNotifications
  };
})();
