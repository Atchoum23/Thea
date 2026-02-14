# Thea Security User Guide

**Version:** 1.4.2
**Last Updated:** January 23, 2026

This guide explains Thea's security features and how to use them to protect your data and privacy.

---

## Table of Contents

1. [Approval System](#approval-system)
2. [Remote Server Security](#remote-server-security)
3. [Data Privacy Controls](#data-privacy-controls)
4. [GDPR Data Export](#gdpr-data-export)
5. [Terminal Command Security](#terminal-command-security)
6. [Best Practices](#best-practices)

---

## Approval System

### Overview

Thea uses an approval system to ensure you maintain control over sensitive operations. The AI assistant will request your approval before performing actions that could modify files, execute commands, or access sensitive data.

### Execution Modes

Thea offers three execution modes:

| Mode | Description | Recommended For |
|------|-------------|-----------------|
| **Supervised** | Approval required before each major step | Learning Thea, sensitive work, production environments |
| **Automatic** | Approval only for destructive operations | Day-to-day development work |
| **Dry Run** | Simulates execution without making changes | Testing workflows, understanding what Thea will do |

#### Changing Execution Mode

1. Open **Settings** → **Self Execution**
2. Select your preferred mode from the segmented control
3. The mode takes effect immediately

### What Requires Approval

The following operations always require your explicit approval:

- **File Operations**: Creating, modifying, or deleting files
- **Terminal Commands**: Executing shell commands that modify the system
- **System Automation**: AppleScript or system-level automation
- **Network Operations**: Making external API calls (when enabled)

### Responding to Approval Requests

When Thea needs approval, you'll see a dialog with:

- **Description**: What the operation will do
- **Details**: Specific files, commands, or data involved
- **Approve**: Allow this specific operation
- **Reject**: Deny the operation

---

## Remote Server Security

### Network Discovery

Network discovery allows other devices on your local network to find and connect to Thea.

**Important**: Network discovery is **disabled by default** for your privacy. Enable it only when you need to connect from another device.

#### Enabling Network Discovery

1. Open **Settings** → **Remote Server**
2. Toggle **Enable Network Discovery** ON
3. Your device will be visible on the local network

#### Security Recommendations

- Only enable discovery when actively connecting from another device
- Disable discovery when not in use
- Use network discovery only on trusted networks (home, office)
- Never enable on public WiFi

### Pairing Security

When connecting a new device, Thea uses a secure pairing process:

1. A **12-character alphanumeric code** is generated
2. Enter this code on the connecting device
3. The connection is encrypted end-to-end

**Why 12 characters?** The longer code provides significantly better protection against brute-force attacks compared to shorter codes.

### TLS Encryption

All remote connections use TLS encryption. Thea validates certificate chains to prevent man-in-the-middle attacks.

---

## Data Privacy Controls

### What Thea Tracks

Thea can track various types of data to provide personalized assistance. All tracking is **opt-in** and can be configured individually:

| Data Type | Purpose | Default |
|-----------|---------|---------|
| Input Activity | Productivity insights | Off |
| Browser History | Context awareness | Off |
| Location | Location-based reminders | Off |
| Health Data | Wellness insights | Off |
| Screen Time | Usage analytics | Off |

### Configuring Privacy Settings

1. Open **Settings** → **Life Tracking**
2. Toggle individual tracking features on/off
3. Set data retention period (default: 90 days)

### Password Protection

Thea automatically **excludes password fields** from any input tracking. When you're typing in a password field, your keystrokes are not counted or logged.

### URL Privacy

When browser tracking is enabled, Thea automatically sanitizes URLs to remove sensitive information:

**Removed from URLs:**
- API keys and tokens
- Session identifiers
- Passwords
- Credit card numbers
- Personal identifiers

**Example:**
- Original: `https://api.service.com/data?token=abc123&user=john`
- Stored: `https://api.service.com/data?user=john`

---

## GDPR Data Export

### Your Rights

Under GDPR (General Data Protection Regulation), you have the right to:

1. **Access your data** (Article 15)
2. **Export your data** in a portable format (Article 20)
3. **Delete your data** (Article 17 - "Right to be forgotten")

### Exporting Your Data

To export all your data:

1. Open **Settings** → **Privacy**
2. Click **Export My Data**
3. Choose a save location
4. Data is exported as a JSON file

**Exported data includes:**
- Input activity statistics
- Browser history (sanitized)
- Conversations and messages
- User preferences and settings
- Memory system contents

### Deleting Your Data

To delete all your data:

1. Open **Settings** → **Privacy**
2. Click **Delete All My Data**
3. Confirm the deletion

**Warning**: This action is irreversible. All your data will be permanently deleted.

---

## Terminal Command Security

### Command Restrictions

For your protection, Thea restricts which terminal commands can be executed. This prevents accidental or malicious damage to your system.

### Allowed Commands

Safe commands that Thea can execute include:

- **File viewing**: `ls`, `pwd`, `cat`, `head`, `tail`, `find`, `file`, `stat`
- **Development**: `swift`, `swiftc`, `xcodebuild`, `git`, `npm`, `node`, `python`
- **Safe modifications**: `mkdir`, `touch`, `cp`, `mv`
- **System info**: `date`, `whoami`, `which`, `echo`

### Blocked Commands

Dangerous commands are blocked automatically:

- `rm -rf /` and similar destructive patterns
- `sudo` and privilege escalation
- `chmod 777` (overly permissive)
- Piped downloads (`curl | sh`, `wget | sh`)
- Fork bombs and system attacks

### Requesting Blocked Commands

If you need to run a blocked command, you must execute it manually in Terminal. Thea will not execute potentially dangerous commands even if explicitly requested.

---

## Best Practices

### General Security

1. **Use Supervised mode** when working with sensitive projects
2. **Review approvals carefully** before clicking Approve
3. **Keep Thea updated** to receive security patches
4. **Use strong pairing codes** - don't share them

### Privacy

1. **Disable tracking** for features you don't need
2. **Export your data regularly** if you want backups
3. **Review what's being tracked** in Settings → Life Tracking
4. **Use the shortest data retention period** that meets your needs

### Remote Connections

1. **Disable network discovery** when not in use
2. **Only connect on trusted networks**
3. **Review connected devices** periodically
4. **Disconnect unused sessions**

### Development Work

1. **Use Dry Run mode** to preview changes before executing
2. **Keep project paths organized** to avoid accidental modifications
3. **Review generated code** before running
4. **Back up important files** before major operations

---

## Reporting Security Issues

If you discover a security vulnerability in Thea, please report it responsibly:

1. **Email**: security@theathe.app
2. **Do not** disclose publicly until fixed
3. **Include**: Steps to reproduce, potential impact, any relevant logs

We take security seriously and will respond within 48 hours.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.4.2 | 2026-01-23 | Added GDPR export, enhanced approval system, improved command restrictions |
| 1.4.1 | 2026-01-15 | Initial security documentation |

---

*For technical details, see [SECURITY_REMEDIATION_SUMMARY.md](../../SECURITY_REMEDIATION_SUMMARY.md)*
