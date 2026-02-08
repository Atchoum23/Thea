// Thea Safari Extension - Options Page Script
// Full settings management with sidebar navigation

// Theme definitions (must match dark-mode-handler.js)
var themeList = [
    { id: 'midnight',   name: 'Midnight',    bg: '#0f1119', text: '#d4d4dc', link: '#7aa2f7', accent: '#7aa2f7' },
    { id: 'pure',       name: 'Pure Black',   bg: '#000000', text: '#e0e0e0', link: '#6ea8fe', accent: '#6ea8fe' },
    { id: 'oled',       name: 'OLED',         bg: '#000000', text: '#ffffff', link: '#58a6ff', accent: '#58a6ff' },
    { id: 'warm',       name: 'Warm',         bg: '#1a1410', text: '#d5cec4', link: '#e0a870', accent: '#e0a870' },
    { id: 'nord',       name: 'Nord',         bg: '#2e3440', text: '#eceff4', link: '#88c0d0', accent: '#81a1c1' },
    { id: 'dracula',    name: 'Dracula',      bg: '#282a36', text: '#f8f8f2', link: '#8be9fd', accent: '#bd93f9' },
    { id: 'monokai',    name: 'Monokai',      bg: '#272822', text: '#f8f8f2', link: '#66d9ef', accent: '#a6e22e' },
    { id: 'solarized',  name: 'Solarized',    bg: '#002b36', text: '#839496', link: '#268bd2', accent: '#2aa198' },
    { id: 'gruvbox',    name: 'Gruvbox',      bg: '#282828', text: '#ebdbb2', link: '#83a598', accent: '#fabd2f' },
    { id: 'catppuccin', name: 'Catppuccin',   bg: '#1e1e2e', text: '#cdd6f4', link: '#89b4fa', accent: '#cba6f7' },
    { id: 'tokyoNight', name: 'Tokyo Night',  bg: '#1a1b26', text: '#c0caf5', link: '#7aa2f7', accent: '#bb9af7' },
    { id: 'oneDark',    name: 'One Dark',     bg: '#282c34', text: '#abb2bf', link: '#61afef', accent: '#c678dd' },
    { id: 'githubDark', name: 'GitHub Dark',  bg: '#0d1117', text: '#c9d1d9', link: '#58a6ff', accent: '#1f6feb' },
    { id: 'rosePine',   name: 'Rose Pine',    bg: '#191724', text: '#e0def4', link: '#c4a7e7', accent: '#ebbcba' },
    { id: 'ayu',        name: 'Ayu',          bg: '#0b0e14', text: '#bfbdb6', link: '#39bae6', accent: '#e6b450' },
    { id: 'palenight',  name: 'Palenight',    bg: '#292d3e', text: '#a6accd', link: '#82aaff', accent: '#c792ea' },
    { id: 'horizon',    name: 'Horizon',      bg: '#1c1e26', text: '#d5d8da', link: '#25b0bc', accent: '#e95678' },
    { id: 'everforest', name: 'Everforest',   bg: '#2d353b', text: '#d3c6aa', link: '#83c092', accent: '#a7c080' },
    { id: 'kanagawa',   name: 'Kanagawa',     bg: '#1f1f28', text: '#dcd7ba', link: '#7e9cd8', accent: '#957fb8' },
    { id: 'material',   name: 'Material',     bg: '#212121', text: '#eeffff', link: '#82aaff', accent: '#c792ea' },
    { id: 'cobalt',     name: 'Cobalt',       bg: '#132738', text: '#e1efff', link: '#ffc600', accent: '#ff9d00' }
];

var currentState = {};

document.addEventListener('DOMContentLoaded', () => {
    initializeOptions();
});

async function initializeOptions() {
    setupNavigation();
    renderThemeGrid();
    populateThemeDropdowns();
    await loadAllConfig();
    setupGeneralButtons();
    setupDarkModeControls();
    setupVideoControls();
    setupPrivacyToggles();
    setupPasswordControls();
    setupMemoryControls();
    setupWritingControls();
    setupAdBlockerControls();
    setupAbout();
    setupSliderDisplays();
}

// --- Navigation ---

function setupNavigation() {
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', () => {
            var section = item.dataset.section;
            document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
            item.classList.add('active');
            document.querySelectorAll('.settings-section').forEach(s => s.classList.remove('active'));
            document.getElementById('section-' + section).classList.add('active');
        });
    });
}

// --- Config Loading ---

async function loadAllConfig() {
    try {
        var response = await browser.runtime.sendMessage({ action: 'getState' });
        if (!response) return;
        currentState = response;
        populateFromState(response);
    } catch (e) {
        console.error('[Thea Options] Load config error:', e);
    }
}

function populateFromState(s) {
    // Dark mode
    var dm = s.darkModeConfig || {};
    setChecked('dm-follow-system', dm.followSystem);
    setChecked('dm-pause', !!dm.pausedUntil && dm.pausedUntil > Date.now());
    setSlider('dm-img-brightness', 'dm-brightness-val',
        Math.round(parseFloat(dm.customThemes && dm.customThemes._imgBrightness || '90')), '%');
    selectThemeSwatch(dm.theme || 'midnight');
    renderSiteOverrides(dm.sitePrefs || {});

    // Video
    var vc = s.videoConfig || {};
    setSlider('video-speed', 'video-speed-val', Math.round((vc.defaultSpeed || 1) * 100), 'x', v => (v / 100).toFixed(1) + 'x');
    setSlider('video-step', 'video-step-val', Math.round((vc.speedStep || 0.1) * 100), 'x', v => (v / 100).toFixed(1) + 'x');
    setChecked('video-overlay', vc.showOverlay !== false);
    setChecked('video-remember', vc.rememberSpeed !== false);
    renderSpeedRules(vc.autoSpeedRules || []);

    // AI
    setChecked('ai-enabled', s.aiAssistantEnabled !== false);
    setChecked('ai-deep-research', !!s.deepResearch);

    // Privacy
    var pc = s.privacyConfig || {};
    setChecked('priv-cookies', pc.cookieAutoDecline !== false);
    setChecked('priv-fingerprint', pc.fingerprintProtection !== false);
    setChecked('priv-cname', pc.cnameDefense !== false);
    setChecked('priv-referrer', pc.referrerStripping !== false);
    setChecked('priv-unshim', pc.linkUnshimming !== false);
    setChecked('priv-params', pc.trackingParamRemoval !== false);
    setChecked('priv-social', !!pc.socialWidgetBlocking);
    setChecked('priv-webrtc', !!pc.webrtcProtection);

    // Passwords
    setChecked('pass-enabled', !!s.passwordManagerEnabled);
    setChecked('pass-passkey', !!s.passkeySupport);
    setChecked('pass-totp', !!s.totpEnabled);

    // Memory
    setChecked('mem-enabled', s.memoryEnabled !== false);
    setChecked('mem-auto', !!s.autoCapture);
    var mc = s.memoryConfig || {};
    setSlider('mem-max', 'mem-max-val', mc.maxMemories || 500, '');
    setSlider('mem-expiry', 'mem-expiry-val', mc.expiryDays || 90, '');

    // Writing
    var wc = s.writingConfig || {};
    setChecked('write-enabled', !!s.writingAssistantEnabled);
    setSlider('write-delay', 'write-delay-val', wc.suggestionDelay || 500, 'ms');

    // Ad blocker
    setChecked('ab-enabled', s.adBlockerEnabled !== false);
    var abCount = document.getElementById('ab-count');
    if (abCount && s.stats) abCount.textContent = formatNumber(s.stats.adsBlocked || 0);
    renderWhitelist(s.whitelist || []);
}

// --- Theme Grid ---

function renderThemeGrid() {
    var grid = document.getElementById('theme-grid');
    if (!grid) return;
    grid.innerHTML = '';

    themeList.forEach(function(t) {
        var swatch = document.createElement('div');
        swatch.className = 'theme-swatch';
        swatch.dataset.theme = t.id;
        swatch.innerHTML =
            '<div class="swatch-colors">' +
            '<span style="background:' + t.bg + '"></span>' +
            '<span style="background:' + t.text + '"></span>' +
            '<span style="background:' + t.link + '"></span>' +
            '<span style="background:' + t.accent + '"></span>' +
            '</div>' +
            '<span class="theme-swatch-name">' + t.name + '</span>';

        swatch.addEventListener('click', function() {
            selectThemeSwatch(t.id);
            saveConfig({ darkModeConfig: { theme: t.id } });
        });
        grid.appendChild(swatch);
    });
}

function selectThemeSwatch(themeId) {
    document.querySelectorAll('.theme-swatch').forEach(function(s) {
        s.classList.toggle('active', s.dataset.theme === themeId);
    });
}

function populateThemeDropdowns() {
    var sel = document.getElementById('site-override-theme');
    if (!sel) return;
    themeList.forEach(function(t) {
        var opt = document.createElement('option');
        opt.value = t.id;
        opt.textContent = t.name;
        sel.appendChild(opt);
    });
}

// --- General Buttons ---

function setupGeneralButtons() {
    document.getElementById('btn-sync').addEventListener('click', async function() {
        await loadAllConfig();
        showToast('Settings synced');
    });

    document.getElementById('btn-reset').addEventListener('click', async function() {
        if (!confirm('Reset all settings to defaults?')) return;
        try {
            await browser.runtime.sendMessage({ action: 'resetState' });
            await loadAllConfig();
            showToast('Settings reset');
        } catch (e) { console.error(e); }
    });

    document.getElementById('btn-export-all').addEventListener('click', function() {
        downloadJSON(currentState, 'thea-settings.json');
    });

    document.getElementById('btn-import-all').addEventListener('click', function() {
        document.getElementById('import-file').click();
    });

    document.getElementById('import-file').addEventListener('change', async function(e) {
        var file = e.target.files[0];
        if (!file) return;
        try {
            var text = await file.text();
            var data = JSON.parse(text);
            await saveConfig(data);
            await loadAllConfig();
            showToast('Settings imported');
        } catch (err) { showToast('Import failed: invalid JSON'); }
        e.target.value = '';
    });
}

// --- Dark Mode Controls ---

function setupDarkModeControls() {
    onChange('dm-follow-system', function(v) { saveConfig({ darkModeConfig: { followSystem: v } }); });

    onChange('dm-pause', function(v) {
        var until = v ? Date.now() + 86400000 : null;
        saveConfig({ darkModeConfig: { pausedUntil: until } });
    });

    onSlider('dm-img-brightness', 'dm-brightness-val', '%', function(v) {
        saveConfig({ darkModeConfig: { customThemes: { _imgBrightness: String(v) } } });
    });

    document.getElementById('btn-add-override').addEventListener('click', function() {
        var domain = document.getElementById('site-override-domain').value.trim();
        var theme = document.getElementById('site-override-theme').value;
        if (!domain) return;
        var prefs = (currentState.darkModeConfig || {}).sitePrefs || {};
        prefs[domain] = { theme: theme || 'midnight' };
        saveConfig({ darkModeConfig: { sitePrefs: prefs } });
        renderSiteOverrides(prefs);
        document.getElementById('site-override-domain').value = '';
    });

    // Custom theme preview
    ['custom-bg', 'custom-text', 'custom-link', 'custom-accent'].forEach(function(id) {
        var el = document.getElementById(id);
        if (el) el.addEventListener('input', updateCustomPreview);
    });

    document.getElementById('btn-save-custom-theme').addEventListener('click', function() {
        var name = document.getElementById('custom-theme-name').value.trim();
        if (!name) { showToast('Enter a theme name'); return; }
        var custom = (currentState.darkModeConfig || {}).customThemes || {};
        custom[name] = {
            bg: document.getElementById('custom-bg').value,
            surface: document.getElementById('custom-bg').value,
            text: document.getElementById('custom-text').value,
            textSec: document.getElementById('custom-text').value,
            link: document.getElementById('custom-link').value,
            accent: document.getElementById('custom-accent').value,
            border: document.getElementById('custom-bg').value,
            imgBrightness: '0.90'
        };
        saveConfig({ darkModeConfig: { customThemes: custom } });
        showToast('Theme "' + name + '" saved');
    });
}

function updateCustomPreview() {
    var preview = document.getElementById('custom-preview');
    if (!preview) return;
    preview.style.background = document.getElementById('custom-bg').value;
    preview.querySelector('.preview-heading').style.color = document.getElementById('custom-text').value;
    preview.querySelector('.preview-text').style.color = document.getElementById('custom-text').value;
    preview.querySelector('.preview-link').style.color = document.getElementById('custom-link').value;
}

function renderSiteOverrides(prefs) {
    var list = document.getElementById('site-overrides-list');
    if (!list) return;
    list.innerHTML = '';
    Object.keys(prefs).forEach(function(domain) {
        var item = createListItem(domain + ' (' + (prefs[domain].theme || 'default') + ')', function() {
            delete prefs[domain];
            saveConfig({ darkModeConfig: { sitePrefs: prefs } });
            renderSiteOverrides(prefs);
        });
        list.appendChild(item);
    });
}

// --- Video Controls ---

function setupVideoControls() {
    onSlider('video-speed', 'video-speed-val', 'x', function(v) {
        saveConfig({ videoConfig: { defaultSpeed: v / 100 } });
    }, function(v) { return (v / 100).toFixed(1) + 'x'; });

    onSlider('video-step', 'video-step-val', 'x', function(v) {
        saveConfig({ videoConfig: { speedStep: v / 100 } });
    }, function(v) { return (v / 100).toFixed(1) + 'x'; });

    onChange('video-overlay', function(v) { saveConfig({ videoConfig: { showOverlay: v } }); });
    onChange('video-remember', function(v) { saveConfig({ videoConfig: { rememberSpeed: v } }); });

    document.getElementById('btn-add-speed-rule').addEventListener('click', function() {
        var dur = parseInt(document.getElementById('rule-duration').value);
        var spd = parseFloat(document.getElementById('rule-speed').value);
        if (isNaN(dur) || isNaN(spd)) return;
        var rules = (currentState.videoConfig || {}).autoSpeedRules || [];
        rules.push({ minDuration: dur, speed: spd });
        rules.sort(function(a, b) { return a.minDuration - b.minDuration; });
        saveConfig({ videoConfig: { autoSpeedRules: rules } });
        renderSpeedRules(rules);
        document.getElementById('rule-duration').value = '';
        document.getElementById('rule-speed').value = '';
    });
}

function renderSpeedRules(rules) {
    var list = document.getElementById('speed-rules-list');
    if (!list) return;
    list.innerHTML = '';
    rules.forEach(function(rule, i) {
        var item = createListItem('>' + rule.minDuration + 's -> ' + rule.speed + 'x', function() {
            rules.splice(i, 1);
            saveConfig({ videoConfig: { autoSpeedRules: rules } });
            renderSpeedRules(rules);
        });
        list.appendChild(item);
    });
}

// --- Privacy Controls ---

function setupPrivacyToggles() {
    var map = {
        'priv-cookies': 'cookieAutoDecline',
        'priv-fingerprint': 'fingerprintProtection',
        'priv-cname': 'cnameDefense',
        'priv-referrer': 'referrerStripping',
        'priv-unshim': 'linkUnshimming',
        'priv-params': 'trackingParamRemoval',
        'priv-social': 'socialWidgetBlocking',
        'priv-webrtc': 'webrtcProtection'
    };
    Object.keys(map).forEach(function(id) {
        onChange(id, function(v) {
            var upd = {};
            upd[map[id]] = v;
            saveConfig({ privacyConfig: upd });
        });
    });
}

// --- Password Controls ---

function setupPasswordControls() {
    onChange('pass-enabled', function(v) { saveConfig({ passwordManagerEnabled: v }); });
    onChange('pass-passkey', function(v) { saveConfig({ passkeySupport: v }); });
    onChange('pass-totp', function(v) { saveConfig({ totpEnabled: v }); });
}

// --- Memory Controls ---

function setupMemoryControls() {
    onChange('mem-enabled', function(v) { saveConfig({ memoryEnabled: v }); });
    onChange('mem-auto', function(v) { saveConfig({ autoCapture: v }); });

    onSlider('mem-max', 'mem-max-val', '', function(v) {
        saveConfig({ memoryConfig: { maxMemories: v } });
    });

    onSlider('mem-expiry', 'mem-expiry-val', '', function(v) {
        saveConfig({ memoryConfig: { expiryDays: v } });
    });

    document.getElementById('memory-search').addEventListener('input', function() {
        filterMemories(this.value);
    });

    document.getElementById('btn-export-memory').addEventListener('click', async function() {
        try {
            var resp = await browser.runtime.sendMessage({ target: 'native', data: { action: 'exportMemories' } });
            if (resp && resp.memories) downloadJSON(resp.memories, 'thea-memories.json');
        } catch (e) { showToast('Export failed'); }
    });

    document.getElementById('btn-import-memory').addEventListener('click', function() {
        document.getElementById('memory-import-file').click();
    });

    document.getElementById('memory-import-file').addEventListener('change', async function(e) {
        var file = e.target.files[0];
        if (!file) return;
        try {
            var text = await file.text();
            var data = JSON.parse(text);
            await browser.runtime.sendMessage({ target: 'native', data: { action: 'importMemories', memories: data } });
            showToast('Memories imported');
        } catch (err) { showToast('Import failed'); }
        e.target.value = '';
    });

    document.getElementById('btn-clear-memory').addEventListener('click', async function() {
        if (!confirm('Clear all memories? This cannot be undone.')) return;
        try {
            await browser.runtime.sendMessage({ target: 'native', data: { action: 'clearMemories' } });
            showToast('Memories cleared');
            document.getElementById('memory-list').innerHTML = '<div class="empty-state">No memories saved yet</div>';
        } catch (e) { showToast('Clear failed'); }
    });

    loadMemories();
}

async function loadMemories() {
    try {
        var resp = await browser.runtime.sendMessage({ target: 'native', data: { action: 'getRecentSaves' } });
        if (resp && resp.saves && resp.saves.length > 0) {
            renderMemories(resp.saves);
        }
    } catch (e) { /* keep empty state */ }
}

function renderMemories(memories) {
    var list = document.getElementById('memory-list');
    if (!list) return;
    list.innerHTML = '';
    memories.forEach(function(mem) {
        var item = createListItem(
            (mem.title || 'Untitled') + ' - ' + formatDate(mem.timestamp),
            function() {
                browser.runtime.sendMessage({ target: 'native', data: { action: 'deleteMemory', id: mem.id } });
                item.remove();
            }
        );
        item.dataset.searchText = ((mem.title || '') + ' ' + (mem.url || '')).toLowerCase();
        list.appendChild(item);
    });
}

function filterMemories(query) {
    var q = query.toLowerCase();
    document.querySelectorAll('#memory-list .data-list-item').forEach(function(item) {
        item.style.display = (!q || (item.dataset.searchText || '').includes(q)) ? '' : 'none';
    });
}

// --- Writing Controls ---

function setupWritingControls() {
    onChange('write-enabled', function(v) { saveConfig({ writingAssistantEnabled: v }); });

    onSlider('write-delay', 'write-delay-val', 'ms', function(v) {
        saveConfig({ writingConfig: { suggestionDelay: v } });
    });

    var toneEl = document.getElementById('write-tone');
    if (toneEl) {
        toneEl.addEventListener('change', function() {
            saveConfig({ writingConfig: { tone: toneEl.value } });
        });
    }
}

// --- Ad Blocker Controls ---

function setupAdBlockerControls() {
    onChange('ab-enabled', function(v) { saveConfig({ adBlockerEnabled: v }); });

    document.getElementById('btn-add-whitelist').addEventListener('click', function() {
        var domain = document.getElementById('whitelist-domain').value.trim();
        if (!domain) return;
        var wl = currentState.whitelist || [];
        if (!wl.includes(domain)) wl.push(domain);
        saveConfig({ whitelist: wl });
        renderWhitelist(wl);
        document.getElementById('whitelist-domain').value = '';
    });

    document.getElementById('btn-add-rule').addEventListener('click', function() {
        var domain = document.getElementById('rule-domain').value.trim();
        var selector = document.getElementById('rule-selector').value.trim();
        if (!domain || !selector) return;
        var rules = currentState.customRules || [];
        rules.push({ domain: domain, selector: selector });
        saveConfig({ customRules: rules });
        renderCustomRules(rules);
        document.getElementById('rule-domain').value = '';
        document.getElementById('rule-selector').value = '';
    });

    renderCustomRules(currentState.customRules || []);
}

function renderWhitelist(wl) {
    var list = document.getElementById('whitelist-list');
    if (!list) return;
    list.innerHTML = '';
    wl.forEach(function(domain, i) {
        var item = createListItem(domain, function() {
            wl.splice(i, 1);
            saveConfig({ whitelist: wl });
            renderWhitelist(wl);
        });
        list.appendChild(item);
    });
}

function renderCustomRules(rules) {
    var list = document.getElementById('custom-rules-list');
    if (!list) return;
    list.innerHTML = '';
    rules.forEach(function(rule, i) {
        var item = createListItem(rule.domain + ': ' + rule.selector, function() {
            rules.splice(i, 1);
            saveConfig({ customRules: rules });
            renderCustomRules(rules);
        });
        list.appendChild(item);
    });
}

// --- About ---

function setupAbout() {
    var ver = browser.runtime.getManifest().version;
    ['ext-version', 'about-version'].forEach(function(id) {
        var el = document.getElementById(id);
        if (el) el.textContent = ver;
    });

    document.getElementById('about-open-app').addEventListener('click', function(e) {
        e.preventDefault();
        browser.tabs.create({ url: 'thea://' });
    });

    document.getElementById('btn-clear-history').addEventListener('click', async function() {
        if (!confirm('Clear all AI conversation history?')) return;
        try {
            await browser.runtime.sendMessage({ target: 'native', data: { action: 'clearHistory' } });
            showToast('History cleared');
        } catch (e) { showToast('Clear failed'); }
    });
}

// --- Slider Displays ---

function setupSliderDisplays() {
    // Ensure all slider values are displayed on load
    ['dm-img-brightness', 'video-speed', 'video-step', 'mem-max', 'mem-expiry', 'write-delay'].forEach(function(id) {
        var el = document.getElementById(id);
        if (el) el.dispatchEvent(new Event('input'));
    });
}

// --- Helpers ---

async function saveConfig(updates) {
    try {
        // Merge into currentState locally for immediate UI consistency
        Object.assign(currentState, updates);
        await browser.runtime.sendMessage({ action: 'updateState', updates: updates });
    } catch (e) {
        console.error('[Thea Options] Save config error:', e);
    }
}

function setChecked(id, val) {
    var el = document.getElementById(id);
    if (el) el.checked = !!val;
}

function setSlider(sliderId, valId, value, suffix) {
    var slider = document.getElementById(sliderId);
    var valEl = document.getElementById(valId);
    if (slider) slider.value = value;
    if (valEl) valEl.textContent = value + (suffix || '');
}

function onChange(id, cb) {
    var el = document.getElementById(id);
    if (el) el.addEventListener('change', function() { cb(el.checked); });
}

function onSlider(sliderId, valId, suffix, saveCb, formatFn) {
    var slider = document.getElementById(sliderId);
    var valEl = document.getElementById(valId);
    if (!slider) return;
    slider.addEventListener('input', function() {
        var v = parseInt(slider.value);
        if (valEl) valEl.textContent = formatFn ? formatFn(v) : (v + (suffix || ''));
    });
    slider.addEventListener('change', function() {
        if (saveCb) saveCb(parseInt(slider.value));
    });
}

function createListItem(text, onRemove) {
    var item = document.createElement('div');
    item.className = 'data-list-item';
    var span = document.createElement('span');
    span.textContent = text;
    var btn = document.createElement('button');
    btn.className = 'remove-btn';
    btn.textContent = 'Remove';
    btn.addEventListener('click', onRemove);
    item.appendChild(span);
    item.appendChild(btn);
    return item;
}

function downloadJSON(data, filename) {
    var blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
}

function formatNumber(num) {
    if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
    if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
    return String(num);
}

function formatDate(timestamp) {
    if (!timestamp) return '';
    var d = new Date(timestamp);
    return d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

function showToast(message) {
    var existing = document.querySelector('.toast');
    if (existing) existing.remove();
    var toast = document.createElement('div');
    toast.className = 'toast';
    toast.textContent = message;
    toast.style.cssText = 'position:fixed;bottom:20px;right:20px;background:var(--text-primary);color:var(--bg-primary);padding:10px 18px;border-radius:8px;font-size:13px;font-weight:500;z-index:9999;animation:slideIn 0.2s ease-out;';
    document.body.appendChild(toast);
    setTimeout(function() { toast.remove(); }, 2500);
}
