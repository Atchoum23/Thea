# Thea Development - Quick Start Guide

Fast reference for common development tasks.

---

## 🚀 First Time Setup

```bash
# 1. Clone the repository
git clone <repository-url>
cd Thea/Development

# 2. Resolve dependencies
./resolve_packages.sh

# 3. Generate Xcode project (if needed)
xcodegen generate

# 4. Open in Xcode
open Thea.xcodeproj

# 5. Build and run (⌘R)
```

---

## 📦 Dependency Management

### Resolve/Update Dependencies

```bash
cd Development
./resolve_packages.sh
```

### Add New Package

1. Edit `Package.swift` and `project.yml`
2. Run `xcodegen generate`
3. Run `./resolve_packages.sh`
4. Commit changes

---

## 🏗️ Building

### Xcode

- **Build**: ⌘B
- **Run**: ⌘R
- **Test**: ⌘U
- **Clean**: ⇧⌘K

### Command Line

```bash
# Debug build
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS build

# Release build
xcodebuild -project Thea.xcodeproj -scheme Thea-macOS -configuration Release build

# Create DMG
./create-dmg.sh "v1.2.3"
```

---

## 🔧 Project Structure

```
Development/
├── Shared/              # Shared code (macOS + iOS)
├── macOS/               # macOS-specific code
├── iOS/                 # iOS-specific code
├── Tests/               # Unit tests
├── Package.swift        # SPM dependencies
├── project.yml          # XcodeGen configuration
├── Thea.xcodeproj/      # Xcode project (generated)
└── resolve_packages.sh  # Dependency management script
```

---

## 🐛 Troubleshooting

### Build Issues

```bash
# Clean everything
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf build
./resolve_packages.sh
```

### Xcode Issues

1. Quit Xcode
2. Run `./resolve_packages.sh`
3. Reopen Xcode
4. Product → Clean Build Folder (⇧⌘K)
5. Build (⌘B)

### Package Issues

```bash
# Force fresh package resolution
rm -rf ~/Library/Caches/org.swift.swiftpm
./resolve_packages.sh
```

---

## 📝 Common Commands

```bash
# Generate Xcode project
xcodegen generate

# Resolve packages
./resolve_packages.sh

# Create DMG
./create-dmg.sh "version-name"

# Run tests
xcodebuild test -project Thea.xcodeproj -scheme Thea-macOS

# Clean build
xcodebuild clean -project Thea.xcodeproj -scheme Thea-macOS
```

---

## 📚 Documentation

- **Full Dependency Guide**: See `DEPENDENCY_MANAGEMENT.md`
- **Changelog**: See `CHANGELOG-v1.2.3.md`
- **Spec**: See `../Planning/THEA_SPECIFICATION.md`

---

## 🆘 Help

- Check build logs: `/tmp/thea_resolve.log`
- GitHub Issues: (repository issues page)
- Internal docs: `DEPENDENCY_MANAGEMENT.md`
