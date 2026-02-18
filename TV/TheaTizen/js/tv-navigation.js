/**
 * Samsung TV D-pad navigation and remote control input handling.
 * Manages focus traversal, voice remote input, and TV-specific key mapping.
 */
'use strict';

var TVNavigation = (function () {
    // Samsung Tizen remote control key codes
    var KEY = {
        ENTER: 13,
        LEFT: 37,
        UP: 38,
        RIGHT: 39,
        DOWN: 40,
        BACK: 10009,       // Samsung Back button
        EXIT: 10182,       // Samsung Exit/Home
        PLAY: 415,
        PAUSE: 19,
        STOP: 413,
        CH_UP: 427,
        CH_DOWN: 428,
        VOL_UP: 447,
        VOL_DOWN: 448,
        MUTE: 449,
        INFO: 457,
        GUIDE: 458,
        MENU: 18,
        RED: 403,
        GREEN: 404,
        YELLOW: 405,
        BLUE: 406,
        NUM_0: 48, NUM_1: 49, NUM_2: 50, NUM_3: 51, NUM_4: 52,
        NUM_5: 53, NUM_6: 54, NUM_7: 55, NUM_8: 56, NUM_9: 57
    };

    // Focus zones define spatial navigation regions
    var ZONES = {
        sidebar: { selector: '#sidebar .focusable', direction: 'vertical' },
        chatInput: { selector: '#chat-view .input-area .focusable', direction: 'horizontal' },
        suggestions: { selector: '#suggestions .focusable', direction: 'horizontal' },
        messages: { selector: '#messages', direction: 'vertical', scrollable: true },
        settings: { selector: '#settings-view .focusable', direction: 'vertical' },
        pairing: { selector: '#pairing-screen .focusable', direction: 'vertical' },
        apikey: { selector: '#apikey-screen .focusable', direction: 'vertical' },
        dashboard: { selector: '#dashboard-view .focusable', direction: 'horizontal' }
    };

    var currentZone = 'pairing';
    var sidebarVisible = true;

    // --- Focus Management ---
    function getFocusableInZone(zoneName) {
        var zone = ZONES[zoneName];
        if (!zone) return [];
        var screen = getActiveScreen();
        if (!screen) return [];
        var elements = screen.querySelectorAll(zone.selector);
        return Array.prototype.slice.call(elements).filter(function (el) {
            return el.offsetParent !== null; // visible only
        });
    }

    function getActiveScreen() {
        return document.querySelector('.screen.active');
    }

    function getCurrentFocusIndex(elements) {
        var active = document.activeElement;
        for (var i = 0; i < elements.length; i++) {
            if (elements[i] === active) return i;
        }
        return -1;
    }

    function focusElement(el) {
        if (el && typeof el.focus === 'function') {
            el.focus({ preventScroll: false });
            // Ensure visible in scrollable container
            if (el.scrollIntoView) {
                el.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
            }
        }
    }

    function focusFirstInZone(zoneName) {
        var elements = getFocusableInZone(zoneName);
        if (elements.length > 0) {
            currentZone = zoneName;
            focusElement(elements[0]);
        }
    }

    // --- Directional Navigation ---
    function navigateInZone(direction) {
        var zone = ZONES[currentZone];
        if (!zone) return false;

        // Scrollable zone (messages) — scroll instead of focus change
        if (zone.scrollable) {
            var container = document.querySelector(zone.selector);
            if (container) {
                var scrollAmount = 200;
                if (direction === 'up') container.scrollTop -= scrollAmount;
                if (direction === 'down') container.scrollTop += scrollAmount;
                return true;
            }
            return false;
        }

        var elements = getFocusableInZone(currentZone);
        if (elements.length === 0) return false;

        var idx = getCurrentFocusIndex(elements);
        var isVertical = zone.direction === 'vertical';
        var newIdx = idx;

        if ((direction === 'down' && isVertical) || (direction === 'right' && !isVertical)) {
            newIdx = Math.min(idx + 1, elements.length - 1);
        } else if ((direction === 'up' && isVertical) || (direction === 'left' && !isVertical)) {
            newIdx = Math.max(idx - 1, 0);
        } else {
            // Cross-zone navigation
            return navigateCrossZone(direction);
        }

        if (newIdx !== idx && newIdx >= 0) {
            focusElement(elements[newIdx]);
            return true;
        }
        return navigateCrossZone(direction);
    }

    function navigateCrossZone(direction) {
        var activeView = getActiveView();

        if (activeView === 'chat-view') {
            if (direction === 'left' && currentZone !== 'sidebar' && sidebarVisible) {
                focusFirstInZone('sidebar');
                return true;
            }
            if (direction === 'right' && currentZone === 'sidebar') {
                // Move to chat content
                var sugElements = getFocusableInZone('suggestions');
                if (sugElements.length > 0) {
                    focusFirstInZone('suggestions');
                } else {
                    focusFirstInZone('chatInput');
                }
                return true;
            }
            if (direction === 'up' && currentZone === 'chatInput') {
                var sugElements2 = getFocusableInZone('suggestions');
                if (sugElements2.length > 0) {
                    focusFirstInZone('suggestions');
                } else {
                    currentZone = 'messages';
                    return true; // Let message scrolling handle it
                }
                return true;
            }
            if (direction === 'down' && currentZone === 'suggestions') {
                focusFirstInZone('chatInput');
                return true;
            }
            if (direction === 'down' && currentZone === 'messages') {
                var sugElements3 = getFocusableInZone('suggestions');
                if (sugElements3.length > 0) {
                    focusFirstInZone('suggestions');
                } else {
                    focusFirstInZone('chatInput');
                }
                return true;
            }
        }

        if (activeView === 'settings-view') {
            if (direction === 'left' && currentZone !== 'sidebar' && sidebarVisible) {
                focusFirstInZone('sidebar');
                return true;
            }
            if (direction === 'right' && currentZone === 'sidebar') {
                focusFirstInZone('settings');
                return true;
            }
        }

        if (activeView === 'dashboard-view') {
            if (direction === 'left' && currentZone !== 'sidebar' && sidebarVisible) {
                focusFirstInZone('sidebar');
                return true;
            }
            if (direction === 'right' && currentZone === 'sidebar') {
                focusFirstInZone('dashboard');
                return true;
            }
        }

        return false;
    }

    function getActiveView() {
        var view = document.querySelector('.content-view.active');
        return view ? view.id : null;
    }

    // --- Key Handling ---
    function handleKeyDown(e) {
        var keyCode = e.keyCode;

        switch (keyCode) {
            case KEY.UP:
                e.preventDefault();
                navigateInZone('up');
                break;

            case KEY.DOWN:
                e.preventDefault();
                navigateInZone('down');
                break;

            case KEY.LEFT:
                e.preventDefault();
                navigateInZone('left');
                break;

            case KEY.RIGHT:
                e.preventDefault();
                navigateInZone('right');
                break;

            case KEY.ENTER:
                handleEnter(e);
                break;

            case KEY.BACK:
                e.preventDefault();
                handleBack();
                break;

            case KEY.EXIT:
                // Let Tizen handle exit
                break;

            case KEY.RED:
                // Quick action: new conversation
                if (TheaClient && TheaClient.state.token) {
                    TheaClient.createConversation();
                }
                break;

            case KEY.GREEN:
                // Quick action: toggle sidebar
                toggleSidebar();
                break;

            case KEY.YELLOW:
                // Quick action: dashboard
                if (TheaClient) TheaClient.switchView('dashboard-view');
                break;

            case KEY.BLUE:
                // Quick action: settings
                if (TheaClient) TheaClient.switchView('settings-view');
                break;

            default:
                // Number keys for suggestion selection
                if (keyCode >= KEY.NUM_1 && keyCode <= KEY.NUM_9) {
                    var num = keyCode - KEY.NUM_0;
                    selectSuggestionByNumber(num);
                }
                break;
        }
    }

    function handleEnter(e) {
        var active = document.activeElement;
        if (!active) return;

        // Input fields — send on Enter
        if (active.id === 'chat-input') {
            e.preventDefault();
            TheaClient.sendMessage(active.value);
            return;
        }

        if (active.id === 'apikey-input') {
            e.preventDefault();
            var submitBtn = document.getElementById('apikey-submit');
            if (submitBtn) submitBtn.click();
            return;
        }

        // Clickable elements — simulate click
        if (active.classList.contains('focusable')) {
            active.click();
        }
    }

    function handleBack() {
        var screen = getActiveScreen();
        if (!screen) return;

        if (screen.id === 'apikey-screen') {
            // Back to pairing
            var cancelBtn = document.getElementById('apikey-cancel');
            if (cancelBtn) cancelBtn.click();
            return;
        }

        if (screen.id === 'chat-screen') {
            var view = getActiveView();
            if (view === 'settings-view' || view === 'dashboard-view') {
                // Back to chat
                TheaClient.switchView('chat-view');
                focusFirstInZone('chatInput');
                return;
            }
            if (currentZone !== 'sidebar') {
                // Move to sidebar
                focusFirstInZone('sidebar');
                return;
            }
        }
    }

    function selectSuggestionByNumber(num) {
        var suggestions = document.querySelectorAll('#suggestions .suggestion-chip');
        if (suggestions.length >= num) {
            suggestions[num - 1].click();
        }
    }

    function toggleSidebar() {
        var sidebar = document.getElementById('sidebar');
        if (!sidebar) return;
        sidebarVisible = !sidebarVisible;
        sidebar.style.display = sidebarVisible ? 'flex' : 'none';
        if (!sidebarVisible && currentZone === 'sidebar') {
            focusFirstInZone('chatInput');
        }
    }

    // --- Voice Input (Samsung TV microphone on remote) ---
    function initVoiceInput() {
        if (typeof webapis !== 'undefined' && webapis.speech) {
            try {
                webapis.speech.setCallback({
                    onresult: function (result) {
                        if (result && result.text) {
                            var input = document.getElementById('chat-input');
                            if (input) {
                                input.value = result.text;
                                input.focus();
                            }
                        }
                    },
                    onerror: function () { /* voice error, ignore */ }
                });
            } catch (e) {
                console.log('Voice input not available:', e);
            }
        }
    }

    // --- Register TV keys with Tizen InputDevice API ---
    function registerTVKeys() {
        if (typeof tizen !== 'undefined' && tizen.tvinputdevice) {
            var keysToRegister = [
                'MediaPlay', 'MediaPause', 'MediaStop',
                'ColorF0Red', 'ColorF1Green', 'ColorF2Yellow', 'ColorF3Blue',
                'ChannelUp', 'ChannelDown', 'Info', 'Guide', 'Menu',
                '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'
            ];
            keysToRegister.forEach(function (key) {
                try { tizen.tvinputdevice.registerKey(key); } catch (e) { /* key may not exist */ }
            });
        }
    }

    // --- Initialization ---
    function init() {
        document.addEventListener('keydown', handleKeyDown);
        registerTVKeys();
        initVoiceInput();

        // Set initial focus based on active screen
        setTimeout(function () {
            var screen = getActiveScreen();
            if (screen) {
                if (screen.id === 'pairing-screen') focusFirstInZone('pairing');
                else if (screen.id === 'apikey-screen') focusFirstInZone('apikey');
                else if (screen.id === 'chat-screen') focusFirstInZone('chatInput');
            }
        }, 100);
    }

    return {
        init: init,
        navigateInZone: navigateInZone,
        toggleSidebar: toggleSidebar,
        currentZone: function () { return currentZone; }
    };
})();

document.addEventListener('DOMContentLoaded', TVNavigation.init);
