# thea-audit Security Report

Generated: 2026-02-18T19:11:26Z

## Summary

| Severity | Count |
|----------|-------|
| 🔴 Critical | 0 |
| 🟠 High | 41 |
| 🟡 Medium | 0 |
| 🟢 Low | 0 |
| **Total** | **41** |

## High Severity Findings
### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/setup-mac-sync.sh:15`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(cd "$(dirname "$0")" && pwd)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/setup-mac-sync.sh:16`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(cd "$SCRIPT_DIR/.." && pwd)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/setup-mac-sync.sh:41`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(cat "$LOCK_FILE" 2>/dev/null || echo "")
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Dangerous File Operation

- **Rule:** `SCRIPT-FILE-001`
- **File:** `Scripts/setup-mac-sync.sh:102`
- **Category:** Access Control
- **CWE:** CWE-732

Detects potentially dangerous file operations:
- rm -rf without safeguards
- chmod 777
- Writing to system directories

**Evidence:**
```
rm -rf /
```

**Recommendation:** Add safeguards to file operations:
- Use variables for paths, verify before rm -rf
- Avoid chmod 777, use minimal permissions
- Don't write to /etc, /usr, /bin without good reason
- Add dry-run options for destructive scripts

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/setup-gpg-key.sh:22`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(gpg --list-secret-keys --keyid-format LONG | grep -E "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/setup-gpg-key.sh:45`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(gpg --list-secret-keys --keyid-format LONG | grep -E "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/verify_build.sh:7`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/build-with-all-errors.sh:23`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/create-dmg.sh:104`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(grep "MARKETING_VERSION:" "$PROJECT_DIR/project.yml" | awk '{print $2}' | tr -d '"')
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/create-dmg.sh:105`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(grep "CURRENT_PROJECT_VERSION:" "$PROJECT_DIR/project.yml" | awk '{print $2}' | tr -d '"')
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/create-dmg.sh:231`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "UNKNOWN")
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/create-dmg.sh:309`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(defaults read "$MOUNTED_APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "UNKNOWN")
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/create-dmg.sh:329`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(du -h "$DMG_PATH" | cut -f1)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/finish-setup.sh:16`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
eval "$
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/finish-setup.sh:10`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(cd "$(dirname "$0")/.." && pwd)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/build-and-notarize.sh:21`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(cd "$(dirname "$0")" && pwd)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/build-and-notarize.sh:22`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(dirname "$SCRIPT_DIR")
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/build-and-notarize.sh:79`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(find "$DERIVED_DATA" -name "Thea.app" -path "*/Release/*" -type d 2>/dev/null | head -1)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/create-dmg-v1.3.0.sh:79`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(du -h "$DMG_PATH" | cut -f1)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/install-automatic-checks.sh:24`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/push-changes.sh:2`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(dirname "$0")
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/validate-settings.sh:23`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/validate-settings.sh:24`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(dirname "$SCRIPT_DIR")
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/validate-settings.sh:264`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(grep "INFOPLIST_KEY_LSApplicationCategoryType" "$PBXPROJ" | head -1 | sed 's/.*= "\(.*\)";/\1/')
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/resolve_packages.sh:24`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/resolve_packages.sh:115`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(basename $PACKAGE_RESOLVED_DIR)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/resolve_packages.sh:193`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(find "$BUILD_DIR" -name "Package.resolved" -not -path "*/checkouts/*" 2>/dev/null | head -1)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/resolve_packages.sh:224`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(find "$PACKAGES_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/auto-build-check.sh:24`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/complete-mission.sh:60`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(dirname "$0")
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/pre-commit:50`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(git show ":$file" 2>/dev/null || true)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/pre-commit:173`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(git diff --cached --name-only --diff-filter=d | grep "\.swift$" || true)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/pre-commit:177`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(echo "$SWIFT_FILES" | wc -l | tr -d ' ')
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/pre-commit:178`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(echo "$SWIFT_FILES" | xargs swiftlint lint --force-exclude 2>&1 || true)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/error-summary.sh:16`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/error-summary.sh:35`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(echo "$LINT_OUTPUT" | grep -c "error:" || echo "0")
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/error-summary.sh:36`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(echo "$LINT_OUTPUT" | grep -c "warning:" || echo "0")
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/watch-and-check.sh:17`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/watch-and-check.sh:37`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(basename "$event")
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/build-and-install.sh:9`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(cd "$(dirname "$0")/.." && pwd)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

### Unsafe Eval Usage

- **Rule:** `SCRIPT-EVAL-001`
- **File:** `Scripts/build-release.sh:23`
- **Category:** Injection
- **CWE:** CWE-78

Detects dangerous eval and exec patterns:
- eval with user input
- exec with dynamic content
- $() command substitution with variables
These patterns can lead to command injection.

**Evidence:**
```
$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
```

**Recommendation:** Avoid eval and exec where possible.
If required:
- Validate and sanitize all inputs
- Use allow-list validation
- Quote all variables properly
- Consider safer alternatives

---

---

*Generated by thea-audit v1.0.0 - Part of AgentSec Strict Mode*