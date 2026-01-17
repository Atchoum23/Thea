# Swift Package Manager Dependency Management

This document explains how to manage Swift Package Manager (SPM) dependencies for the Thea project.

---

## 📦 Current Dependencies

The Thea project uses the following Swift Package Manager dependencies:

| Package | Version | Purpose | Repository |
|---------|---------|---------|------------|
| **OpenAI** | 0.4.7+ | OpenAI API integration (ChatGPT) | [MacPaw/OpenAI](https://github.com/MacPaw/OpenAI) |
| **KeychainAccess** | 4.2.2+ | Secure credential storage | [kishikawakatsumi/KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) |
| **MarkdownUI** | 2.4.0+ | Markdown rendering in SwiftUI | [gonzalezreal/swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) |
| **Highlightr** | 2.3.0+ | Syntax highlighting | [raspu/Highlightr](https://github.com/raspu/Highlightr) |

### Transitive Dependencies

These packages are automatically included as dependencies of the above packages:

- **NetworkImage** (6.0.1+) - Image loading for MarkdownUI
- **swift-openapi-runtime** (1.9.0+) - OpenAPI runtime for OpenAI SDK
- **swift-http-types** (1.5.1+) - HTTP type definitions
- **swift-cmark** (0.7.1+) - CommonMark parser for MarkdownUI

---

## 📂 File Locations

### Package.swift
**Location**: `Development/Package.swift`

Defines the package structure and dependencies. This is the **source of truth** for SPM dependencies.

```swift
dependencies: [
    .package(url: "https://github.com/MacPaw/OpenAI", from: "0.2.0"),
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.0"),
    .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0"),
    .package(url: "https://github.com/raspu/Highlightr", from: "2.1.0"),
]
```

### Package.resolved
**Location**: `Development/Thea.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
**Symlink**: `Development/Package.resolved` → (points to actual file)

Contains the exact versions and commit hashes of all resolved dependencies. This file should be **committed to version control** to ensure reproducible builds.

**Important**: Xcode stores `Package.resolved` inside the `.xcodeproj` bundle, not at the project root. A convenience symlink is created at `Development/Package.resolved` for easy access.

### project.yml (XcodeGen)
**Location**: `Development/project.yml`

XcodeGen configuration that includes package dependencies for the Xcode project:

```yaml
packages:
  OpenAI:
    url: https://github.com/MacPaw/OpenAI
    from: "0.2.0"
  # ... other packages
```

---

## 🔧 Dependency Resolution Script

### resolve_packages.sh

**Location**: `Development/resolve_packages.sh`

A comprehensive bash script that performs a complete clean and fresh resolution of all Swift Package Manager dependencies.

#### Usage

```bash
cd Development
./resolve_packages.sh
```

#### What It Does

1. **Cleans SPM Cache** - Removes `~/Library/Caches/org.swift.swiftpm`
2. **Cleans Build Directory** - Removes `Development/build`
3. **Cleans DerivedData** - Removes Xcode DerivedData for Thea project
4. **Backs Up Package.resolved** - Creates `Package.resolved.backup`
5. **Forces Fresh Resolution** - Runs `xcodebuild -resolvePackageDependencies`
6. **Verifies Resolution** - Checks that Package.resolved was created
7. **Creates Symlink** - Links `Package.resolved` to the actual file in `.xcodeproj`
8. **Displays Package List** - Shows all resolved packages and versions

#### When to Use

- After cloning the repository for the first time
- When dependencies fail to resolve in Xcode
- When switching between branches with different dependencies
- Before creating a release build
- When troubleshooting package-related build errors

#### Features

- ✅ **Idempotent** - Safe to run multiple times
- ✅ **Colored Output** - Easy to read status messages
- ✅ **Error Handling** - Exits on errors with clear messages
- ✅ **Automatic Backup** - Backs up existing Package.resolved
- ✅ **JSON Parsing** - Uses `jq` for pretty package display (optional)

---

## 🤖 GitHub Actions CI/CD

### dependencies.yml Workflow

**Location**: `.github/workflows/dependencies.yml`

Automated workflow that runs on every push to `main` or `develop` branches to verify dependencies resolve correctly.

#### Triggers

- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Manual workflow dispatch

#### What It Does

1. **Validates Package.swift** - Ensures syntax is correct
2. **Generates Xcode Project** - Runs `xcodegen generate`
3. **Resolves Dependencies** - Fetches and resolves all packages
4. **Caches Packages** - Speeds up subsequent runs
5. **Verifies Required Packages** - Checks all required packages are present
6. **Uploads Artifacts** - Saves Package.resolved for debugging
7. **Checks for Changes** - Warns if Package.resolved is outdated in PRs

#### Cache Strategy

The workflow caches resolved packages based on the `Package.resolved` hash:

```yaml
key: ${{ runner.os }}-spm-${{ hashFiles('Development/Package.resolved') }}
```

This provides significant speed improvements (typically 80-90% faster) when dependencies haven't changed.

---

## 🛠️ Common Tasks

### Adding a New Dependency

1. **Update Package.swift**

```swift
dependencies: [
    // ... existing packages
    .package(url: "https://github.com/example/NewPackage", from: "1.0.0"),
]
```

2. **Update project.yml (XcodeGen)**

```yaml
packages:
  NewPackage:
    url: https://github.com/example/NewPackage
    from: "1.0.0"

targets:
  Thea-macOS:
    dependencies:
      - package: NewPackage
```

3. **Regenerate Xcode Project**

```bash
cd Development
xcodegen generate
```

4. **Resolve Dependencies**

```bash
./resolve_packages.sh
```

5. **Commit Changes**

```bash
git add Package.swift project.yml Thea.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
git commit -m "Add NewPackage dependency"
```

### Updating Dependencies

#### Update to Latest Compatible Versions

```bash
cd Development
./resolve_packages.sh
```

This will fetch the latest versions that satisfy the version constraints in `Package.swift`.

#### Update to Specific Version

1. **Modify Package.swift**

```swift
.package(url: "https://github.com/MacPaw/OpenAI", from: "0.5.0"),  // Changed from 0.2.0
```

2. **Resolve Dependencies**

```bash
./resolve_packages.sh
```

#### Force Update All Packages

```bash
# Remove Package.resolved to force re-resolution
rm -rf Thea.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
./resolve_packages.sh
```

### Removing a Dependency

1. **Remove from Package.swift**
2. **Remove from project.yml**
3. **Regenerate Xcode Project**: `xcodegen generate`
4. **Resolve Dependencies**: `./resolve_packages.sh`
5. **Commit Changes**

---

## 🐛 Troubleshooting

### "Package.resolved file is corrupted"

**Solution**:
```bash
cd Development
rm -f Thea.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
./resolve_packages.sh
```

### "Package graph is unresolvable"

This usually means version conflicts between dependencies.

**Solution**:
1. Check `Package.swift` for conflicting version requirements
2. Review the error output for specific conflicts
3. Update version constraints to be compatible
4. Run `./resolve_packages.sh` again

### "Xcode can't find package products"

**Solution**:
1. Clean build folder in Xcode: **Product → Clean Build Folder** (⇧⌘K)
2. Close Xcode
3. Run `./resolve_packages.sh`
4. Reopen Xcode
5. Build the project (⌘B)

### Packages not downloading

**Solution**:
```bash
# Clear all SPM caches
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/Developer/Xcode/DerivedData

# Resolve fresh
cd Development
./resolve_packages.sh
```

### "Authentication required" errors

Some packages may require GitHub authentication.

**Solution**:
1. Generate a GitHub Personal Access Token:
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - Create token with `repo` scope
2. Configure Git credentials:
   ```bash
   git config --global credential.helper osxkeychain
   ```
3. On next package fetch, enter your GitHub username and PAT

---

## 📋 Best Practices

### 1. Always Commit Package.resolved

✅ **DO**: Commit `Package.resolved` to ensure reproducible builds across team members and CI.

❌ **DON'T**: Add `Package.resolved` to `.gitignore` (this is only for package *libraries*, not applications).

### 2. Version Constraints

Use appropriate version constraints:

- **Exact version**: `.exact("1.2.3")` - Pins to specific version
- **Up to next major**: `.upToNextMajor(from: "1.2.0")` - Allows 1.2.x → 1.9.9, not 2.0.0
- **Up to next minor**: `.upToNextMinor(from: "1.2.0")` - Allows 1.2.x only
- **Range**: `"1.2.0" ..< "2.0.0"` - Custom range

**Recommended**: Use `.upToNextMajor()` for most dependencies to get bug fixes and features while avoiding breaking changes.

### 3. Regular Dependency Updates

Schedule regular dependency updates:

- **Monthly**: Check for new versions
- **Quarterly**: Update to latest compatible versions
- **As needed**: Update for security patches

### 4. Test After Updates

Always test thoroughly after updating dependencies:

1. Run unit tests: `⌘U`
2. Run UI tests
3. Manual testing of affected features
4. Check for deprecation warnings

### 5. Document Breaking Changes

When updating to a new major version (potential breaking changes):

1. Review the package's CHANGELOG
2. Test all code that uses the package
3. Update your code for any API changes
4. Document the changes in your commit message

---

## 🔍 Inspecting Dependencies

### List All Resolved Packages

```bash
cd Development
jq -r '.pins[] | "\(.identity) @ \(.state.version // .state.revision[0:8])"' \
  Thea.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
```

### View Package Dependency Tree

```bash
cd Development
swift package show-dependencies
```

### Check for Outdated Packages

```bash
cd Development
swift package show-dependencies --format json > deps.json
```

Then manually compare versions in `deps.json` with latest releases on GitHub.

---

## 🏗️ Build Integration

### Xcode Build Process

When you build in Xcode:

1. Xcode reads `Package.resolved` for exact versions
2. Downloads packages to `~/Library/Caches/org.swift.swiftpm`
3. Checks out packages to `DerivedData/SourcePackages/checkouts`
4. Compiles package products
5. Links them into your app

### Command-Line Build

```bash
cd Development

# Build for macOS
xcodebuild \
  -project Thea.xcodeproj \
  -scheme Thea-macOS \
  -configuration Release \
  -derivedDataPath build \
  build
```

Packages are automatically resolved before the build starts.

---

## 📚 Additional Resources

- [Swift Package Manager Documentation](https://swift.org/package-manager/)
- [Apple SPM Documentation](https://developer.apple.com/documentation/swift_packages)
- [XcodeGen Documentation](https://github.com/yonaskolb/XcodeGen)
- [Semantic Versioning](https://semver.org)

---

## 🆘 Getting Help

### Internal Resources

- Check this document for common tasks and troubleshooting
- Review `resolve_packages.sh` output for detailed error messages
- Check GitHub Actions workflow runs for CI failures

### External Resources

- [Swift Forums - Package Manager](https://forums.swift.org/c/development/SwiftPM)
- [Stack Overflow - swift-package-manager tag](https://stackoverflow.com/questions/tagged/swift-package-manager)
- Individual package GitHub Issues

---

**Last Updated**: January 15, 2026
**Maintainer**: Thea Development Team
