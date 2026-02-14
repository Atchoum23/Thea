# Thea QA Tools Setup Guide

**Version**: 1.0.0
**Last Updated**: January 16, 2026

This guide explains how to set up the QA tools for Thea and configure the required API keys/tokens.

---

## Quick Overview

| Tool | Purpose | Config File | Needs API Key |
|------|---------|-------------|---------------|
| **SwiftLint** | Static code analysis | `.swiftlint.yml` | ❌ No |
| **GitHub Actions** | CI/CD pipeline | `.github/workflows/ci.yml` | ✅ Yes (secrets) |
| **CodeCov** | Code coverage reporting | `codecov.yml` | ✅ Yes |
| **SonarCloud** | Continuous code quality | `sonar-project.properties` | ✅ Yes |
| **DeepSource** | Automated code review | `.deepsource.toml` | ✅ Yes |

---

## 1. SwiftLint (Local - No API Key Needed)

SwiftLint runs locally and doesn't require any API keys.

### Install SwiftLint

```bash
brew install swiftlint
```

### Run SwiftLint

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"
swiftlint lint
```

### Run with Auto-fix

```bash
swiftlint lint --fix
```

### Xcode Integration

Add a Run Script Build Phase in Xcode:

```bash
if which swiftlint > /dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
```

---

## 2. GitHub Actions CI/CD

The CI pipeline runs automatically on push/PR to main or develop branches.

### Required GitHub Secrets

Go to your GitHub repo → Settings → Secrets and variables → Actions → New repository secret

Add these secrets:

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `CODECOV_TOKEN` | CodeCov upload token | codecov.io → Settings → Upload Token |
| `SONAR_TOKEN` | SonarCloud token | sonarcloud.io → My Account → Security → Generate Tokens |
| `DEEPSOURCE_DSN` | DeepSource DSN | deepsource.io → Project Settings → DSN |

### Workflow Triggers

- **Push to main/develop**: Full CI (build, test, coverage upload)
- **Pull Request**: Build and test only
- **Manual**: Go to Actions → CI → Run workflow

---

## 3. CodeCov Setup

### Step 1: Sign Up

1. Go to [codecov.io](https://codecov.io)
2. Sign in with GitHub
3. Add your Thea repository

### Step 2: Get Upload Token

1. Go to Repository Settings
2. Copy the **Upload Token**
3. Add it as `CODECOV_TOKEN` GitHub secret

### Step 3: Badge (Optional)

Add to README.md:

```markdown
[![codecov](https://codecov.io/gh/YOUR-ORG/thea/branch/main/graph/badge.svg?token=YOUR_TOKEN)](https://codecov.io/gh/YOUR-ORG/thea)
```

---

## 4. SonarCloud Setup

### Step 1: Sign Up

1. Go to [sonarcloud.io](https://sonarcloud.io)
2. Sign in with GitHub
3. Import your Thea repository

### Step 2: Get Token

1. Go to My Account → Security
2. Generate a new token (name it "Thea CI")
3. Copy the token
4. Add it as `SONAR_TOKEN` GitHub secret

### Step 3: Update Configuration

Edit `sonar-project.properties`:

```properties
sonar.organization=your-github-username-or-org
sonar.projectKey=your-org_thea
```

### Step 4: Badge (Optional)

Add to README.md:

```markdown
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=YOUR_PROJECT_KEY&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=YOUR_PROJECT_KEY)
```

---

## 5. DeepSource Setup

### Step 1: Sign Up

1. Go to [deepsource.io](https://deepsource.io)
2. Sign in with GitHub
3. Add your Thea repository

### Step 2: Get DSN

1. Go to Project Settings
2. Find the **DSN** (Data Source Name)
3. Copy it (format: `https://xxx@deepsource.io`)
4. Add it as `DEEPSOURCE_DSN` GitHub secret

### Step 3: Badge (Optional)

Add to README.md:

```markdown
[![DeepSource](https://deepsource.io/gh/YOUR-ORG/thea.svg/?label=active+issues)](https://deepsource.io/gh/YOUR-ORG/thea/?ref=repository-badge)
```

---

## Quick Setup Checklist

```
☐ SwiftLint installed locally (brew install swiftlint)
☐ CodeCov account created + token added to GitHub secrets
☐ SonarCloud account created + token added to GitHub secrets
☐ SonarCloud sonar-project.properties updated with organization
☐ DeepSource account created + DSN added to GitHub secrets
☐ Push to GitHub to trigger first CI run
☐ Verify all checks pass in GitHub Actions
```

---

## Running Locally

### Full QA Check

```bash
cd "/Users/alexis/Documents/IT & Tech/MyApps/Thea/Development"

# Run SwiftLint
swiftlint lint --reporter emoji

# Build and test with coverage
xcodebuild test \
  -scheme Thea-macOS \
  -destination 'platform=macOS' \
  -enableCodeCoverage YES \
  -resultBundlePath build/test-results.xcresult

# Export coverage
xcrun xccov view --report build/test-results.xcresult
```

---

## Troubleshooting

### SwiftLint Not Finding Files

Make sure you're in the correct directory (where `.swiftlint.yml` is located).

### CodeCov Upload Failing

1. Check the `CODECOV_TOKEN` is correct
2. Ensure coverage.xml is being generated
3. Check CodeCov dashboard for upload status

### SonarCloud Analysis Failing

1. Verify `SONAR_TOKEN` is set
2. Check `sonar.organization` is correct
3. Ensure the project key matches SonarCloud

### DeepSource Not Detecting Swift

1. Verify `.deepsource.toml` exists in repo root
2. Check Swift analyzer is enabled
3. Ensure DSN is correctly formatted

---

## Support

- **SwiftLint**: [github.com/realm/SwiftLint](https://github.com/realm/SwiftLint)
- **CodeCov**: [docs.codecov.com](https://docs.codecov.com)
- **SonarCloud**: [sonarcloud.io/documentation](https://sonarcloud.io/documentation)
- **DeepSource**: [deepsource.io/docs](https://deepsource.io/docs)
