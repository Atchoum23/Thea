#!/usr/bin/env python3
"""AZ3 Accessibility Agent — runs on MSM3U from Terminal.app
Requires: Terminal.app has Accessibility permission (System Settings → Privacy → Accessibility)

Start this from an MSM3U Terminal window BEFORE running az3-functional-test.sh.
Then az3-functional-test.sh calls this agent to:
  - Type messages into Thea's input field
  - Click buttons in Thea's UI
  - Navigate to specific Settings views

HTTP server on port 18792:
  POST /type         body: {"text": "your message"}
  POST /click        body: {"label": "Send"}
  POST /keystroke    body: {"key": "return"}  (or "escape", "tab", etc.)
  GET  /ping         → OK
"""

import http.server
import subprocess
import json
import os
import time


def run_osascript(script: str) -> tuple[bool, str]:
    result = subprocess.run(
        ['osascript', '-e', script],
        capture_output=True,
        text=True,
        timeout=10
    )
    ok = result.returncode == 0
    out = result.stdout.strip() or result.stderr.strip()
    return ok, out


def activate_thea() -> bool:
    ok, _ = run_osascript('tell application "Thea" to activate')
    time.sleep(0.5)
    return ok


def type_text(text: str) -> tuple[bool, str]:
    """Type text into the currently focused field in Thea."""
    activate_thea()
    time.sleep(0.3)
    # Escape any special characters for AppleScript string
    escaped = text.replace('"', '\\"').replace('\\', '\\\\')
    script = f'''
tell application "System Events"
    tell process "Thea"
        keystroke "{escaped}"
    end tell
end tell
'''
    return run_osascript(script)


def click_button(label: str) -> tuple[bool, str]:
    """Click a button by label in Thea."""
    activate_thea()
    time.sleep(0.3)
    escaped = label.replace('"', '\\"')
    script = f'''
tell application "System Events"
    tell process "Thea"
        try
            click button "{escaped}" of window 1
            return "clicked"
        on error e
            -- Try deeper
            try
                click button "{escaped}" of group 1 of window 1
                return "clicked (group)"
            on error e2
                return "not found: " & e2
            end try
        end try
    end tell
end tell
'''
    return run_osascript(script)


def send_keystroke(key: str) -> tuple[bool, str]:
    """Send a system keystroke to Thea (return, escape, tab, etc.)."""
    activate_thea()
    time.sleep(0.2)
    script = f'''
tell application "System Events"
    tell process "Thea"
        key code {key_to_code(key)}
    end tell
end tell
'''
    return run_osascript(script)


def key_to_code(key: str) -> int:
    """Map key name to macOS key code."""
    codes = {
        'return': 36, 'enter': 36,
        'escape': 53, 'esc': 53,
        'tab': 48,
        'space': 49,
        'delete': 51, 'backspace': 51,
        'up': 126, 'down': 125, 'left': 123, 'right': 124,
        'a': 0, 'c': 8, 'v': 9, 'x': 7, 'z': 6,
    }
    return codes.get(key.lower(), 36)  # default: return


def click_message_input() -> tuple[bool, str]:
    """Click Thea's 'Message Thea...' input field."""
    activate_thea()
    time.sleep(0.3)
    script = '''
tell application "System Events"
    tell process "Thea"
        try
            -- Try clicking the text field directly
            set tf to first text field of window 1
            click tf
            return "clicked text field"
        on error
            try
                -- Try by placeholder value
                set ui to entire contents of window 1
                repeat with elem in ui
                    if class of elem is text field then
                        click elem
                        return "clicked text field (search)"
                    end if
                end repeat
                return "text field not found"
            on error e
                return "error: " & e
            end try
        end try
    end tell
end tell
'''
    return run_osascript(script)


def send_chat_message(text: str) -> tuple[bool, str]:
    """Click input field, type message, press Return."""
    ok, r = click_message_input()
    if not ok:
        return False, f"Click failed: {r}"
    time.sleep(0.3)
    ok2, r2 = type_text(text)
    if not ok2:
        return False, f"Type failed: {r2}"
    time.sleep(0.2)
    ok3, r3 = send_keystroke('return')
    return ok3, f"Sent: {r3}"


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/ping':
            self.respond(200, 'OK')
        else:
            self.respond(404, 'Not found')

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length)
        try:
            data = json.loads(body) if body else {}
        except Exception:
            self.respond(400, 'Invalid JSON')
            return

        if self.path == '/type':
            text = data.get('text', '')
            ok, msg = type_text(text)
            self.respond(200 if ok else 500, json.dumps({'ok': ok, 'result': msg}))

        elif self.path == '/click':
            label = data.get('label', '')
            ok, msg = click_button(label)
            self.respond(200 if ok else 500, json.dumps({'ok': ok, 'result': msg}))

        elif self.path == '/keystroke':
            key = data.get('key', 'return')
            ok, msg = send_keystroke(key)
            self.respond(200 if ok else 500, json.dumps({'ok': ok, 'result': msg}))

        elif self.path == '/send-chat':
            text = data.get('text', '')
            ok, msg = send_chat_message(text)
            self.respond(200 if ok else 500, json.dumps({'ok': ok, 'result': msg}))

        elif self.path == '/activate':
            ok = activate_thea()
            self.respond(200 if ok else 500, json.dumps({'ok': ok}))

        elif self.path == '/navigate':
            # Navigate via URL scheme
            url = data.get('url', '')
            if url.startswith('thea://'):
                ok, msg = run_osascript(f'open location "{url}"')
                self.respond(200 if ok else 500, json.dumps({'ok': ok, 'result': msg}))
            else:
                self.respond(400, 'URL must start with thea://')

        else:
            self.respond(404, 'Unknown endpoint')

    def respond(self, code: int, body: str):
        data = body.encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        pass  # silent


print('AZ3 Accessibility Agent listening on :18792')
print('Endpoints: POST /type, POST /click, POST /keystroke, POST /send-chat, POST /navigate, GET /ping')
print('Run from Terminal.app on MSM3U (must have Accessibility permission)')
http.server.HTTPServer(('127.0.0.1', 18792), Handler).serve_forever()
