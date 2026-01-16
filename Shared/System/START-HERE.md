# ⚡ ULTRA QUICK START - Thea Error Detection

## 🎯 Copy & Paste These 3 Commands

### Command 1: Navigate to Project
```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'
```

### Command 2: Run Installer
```bash
chmod +x install-automatic-checks.sh && ./install-automatic-checks.sh
```

### Command 3: Copy Snippet to Clipboard
```bash
cat xcode-build-phase-snippet.txt | pbcopy
```

---

## ✅ Now in Xcode:

1. **Open project:** `/Users/alexis/Documents/IT & Tech/MyApps/Thea`
2. **Click:** Project "Thea" → Target "Thea" → "Build Phases" tab
3. **Click:** `+` button → "New Run Script Phase"
4. **Drag** it ABOVE "Compile Sources"
5. **Paste:** ⌘+V (already in clipboard!)
6. **Build:** ⌘+B

---

## 🎉 Done!

Everything now runs automatically:
- ✅ Errors appear as you type
- ✅ Checks run on every build
- ✅ Git validates on every commit

---

## 📋 Daily Commands

```bash
cd '/Users/alexis/Documents/IT & Tech/MyApps/Thea'

make check      # See all errors
make summary    # Quick overview
make watch      # Background watcher
```

---

**That's it!** Everything is automatic now.

Full docs: `AUTO-ERROR-DETECTION-COMPLETE-GUIDE.md`
