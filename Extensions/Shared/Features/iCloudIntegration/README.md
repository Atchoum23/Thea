# Thea iCloud Integration

This directory contains the iCloud integration for Thea browser extensions, providing Safari-like experience for Chrome and Brave browsers.

## Architecture Overview

### Hide My Email (iCloud+ Feature)

The Hide My Email integration uses a **direct API approach** similar to existing Chrome extensions:

```
Chrome/Brave Extension
        ↓
  icloud-client.js (Background Worker)
        ↓
  iCloud.com Session Cookies
        ↓
  iCloud Premium Mail Settings API
        ↓
  Real @icloud.com Aliases (synced to iCloud)
```

**API Endpoints Used:**
- `POST /setup/ws/1/validate` - Validate session & get service URLs
- `GET /v2/hme/list` - List all aliases
- `POST /v1/hme/generate` - Generate new alias
- `POST /v1/hme/reserve` - Reserve/confirm alias with metadata
- `POST /v1/hme/deactivate` - Deactivate alias
- `POST /v1/hme/reactivate` - Reactivate alias
- `POST /v1/hme/delete` - Delete alias permanently

**Key Files:**
- `Extensions/Chrome/background/icloud-client.js` - Direct iCloud API client
- `Extensions/Chrome/content/icloud-autofill-ui.js` - Safari-like autofill UI
- `iCloudHideMyEmailBridge.swift` - Native fallback & cache (optional)

### iCloud Passwords (Keychain)

Password management requires native messaging for Keychain access:

```
Chrome/Brave Extension
        ↓
  icloud-bridge.js (Native Messaging)
        ↓
  TheaNativeMessagingHost
        ↓
  iCloudPasswordsBridge.swift
        ↓
  macOS Keychain (via Security framework)
        ↓
  iCloud Keychain Sync
```

**Key Files:**
- `Extensions/Chrome/background/icloud-bridge.js` - Native messaging bridge
- `Extensions/NativeHost/TheaNativeMessagingHost.swift` - Native host
- `iCloudPasswordsBridge.swift` - Keychain access

## User Experience

### Hide My Email
1. User visits a website with an email field
2. "Hide" button appears in the email field
3. Click to create a new `@icloud.com` alias
4. Alias is automatically saved to iCloud (visible in Settings)
5. All emails forward to user's real inbox

### iCloud Passwords
1. User visits a login page
2. Key icon appears in username field
3. Click to see saved credentials from iCloud Keychain
4. Select credential to autofill
5. "Suggest Password" creates Apple-format strong passwords

## Authentication

### Hide My Email
- Uses existing iCloud.com session cookies
- User must be signed into icloud.com in their browser
- Session persists (no repeated authentication needed)
- Extension requires host permission for `*.icloud.com`

### iCloud Passwords
- Uses Face ID / Touch ID via LocalAuthentication
- Session token persists for 30 days
- Stored securely in macOS Keychain
- Native host must be installed and configured

## Email Address Types

| Type | Domain | Source |
|------|--------|--------|
| Hide My Email | `@icloud.com` | Created via iCloud+ (Safari, Settings, this extension) |
| Sign in with Apple | `@privaterelay.appleid.com` | Only via Apple authentication flow |

**Important:** This extension creates `@icloud.com` aliases only. The `@privaterelay.appleid.com` format is exclusively for "Sign in with Apple" authentication.

## Installation Requirements

### Chrome/Brave Extension
1. Install extension from Chrome Web Store or load unpacked
2. Grant permissions when prompted
3. Sign in to iCloud.com in your browser

### Native Host (for Passwords)
1. Build `TheaNativeMessagingHost`
2. Run `install_native_host.sh`
3. Extension will auto-detect native host

## Privacy & Security

- **No passwords sent to servers** - All Keychain access is local
- **iCloud.com cookies stay in browser** - Extension uses existing session
- **Face ID/Touch ID required** - For Keychain access
- **Local cache encrypted** - Using macOS Keychain
- **Aliases sync to iCloud** - Visible in Settings > Apple ID > iCloud > Hide My Email

## Comparison to Safari

| Feature | Safari | Thea (Chrome/Brave) |
|---------|--------|---------------------|
| Hide My Email | Native WebKit | iCloud.com API |
| Password Autofill | Native Keychain | Native Messaging |
| Strong Passwords | System API | System API (via native) |
| Biometric Auth | Built-in | LocalAuthentication |
| iCloud Sync | Automatic | Automatic |

The goal is to provide an **identical user experience** to Safari's native iCloud integration.
