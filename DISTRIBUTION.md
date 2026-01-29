# Thea macOS Distribution Guide

## Quick Start

To build, sign, and notarize Thea for distribution:

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea"
./Scripts/build-and-notarize.sh
```

## First-Time Setup

Before running the script for the first time, set up notarization credentials:

```bash
xcrun notarytool store-credentials "notarytool-profile" \
    --apple-id "alexis@calevras.com" \
    --team-id "6B66PM4JLK"
```

You'll be prompted for an **app-specific password** (create one at https://appleid.apple.com/account/manage).

## Script Options

| Option | Description |
|--------|-------------|
| `--skip-build` | Skip Xcode build, use existing Release build |

## Output Files

After running, distribution files are in `/Distribution/`:
- `Thea.app` - Signed application
- `Thea.dmg` - Disk image (for direct download)
- `Thea.pkg` - Installer package

## Manual Commands

### Sign the app
```bash
codesign --deep --force --verify --verbose \
    --sign "Developer ID Application: Alexis Calevras (6B66PM4JLK)" \
    --options runtime \
    Thea.app
```

### Create PKG
```bash
productbuild --component Thea.app /Applications \
    --sign "Developer ID Installer: Alexis Calevras (6B66PM4JLK)" \
    Thea.pkg
```

### Notarize
```bash
xcrun notarytool submit Thea.pkg \
    --keychain-profile "notarytool-profile" \
    --wait
```

### Staple ticket
```bash
xcrun stapler staple Thea.pkg
```

## Certificates & Profiles

| Type | Name | Expiration |
|------|------|------------|
| Developer ID Application | Alexis Calevras (6B66PM4JLK) | 2027/02/01 |
| Developer ID Installer | Alexis Calevras (6B66PM4JLK) | 2027/02/01 |

### Provisioning Profiles (Developer ID)
- Thea macOS Developer ID
- Thea Finder Extension Developer ID
- Thea QuickLook Extension Developer ID
- Thea Safari Extension Developer ID
- Thea Spotlight Extension Developer ID
- Thea Mail Extension Developer ID
- Thea Network Extension Developer ID
- Thea VPN Extension Developer ID

Profiles stored in: `/Users/alexis/Documents/IT & Tech/Apple/2026.01.28/`

## Team Information

- **Team ID:** 6B66PM4JLK
- **Apple ID:** alexis@calevras.com
- **Bundle ID:** app.thea.macos
