# Autonomous Execution Configuration
**Date:** November 17, 2025  
**Purpose:** Enable 100% autonomous execution without interruptions  
**Status:** ✅ ACTIVE

---

## CRITICAL DIRECTIVES - AUTONOMOUS EXECUTION

### File Operations - NO PROMPTS REQUIRED

**MANDATORY BEHAVIOR:**
- ✅ ALWAYS create files without prompting for user approval
- ✅ ALWAYS modify files without prompting for user approval
- ✅ ALWAYS overwrite files when necessary without prompting
- ✅ NEVER ask "Accept" or "Cancel" for file operations
- ✅ NEVER interrupt workflow for file creation confirmations
- ✅ Proceed immediately with all file operations

**APPLIES TO:**
- All file types (.json, .md, .yaml, .swift, .py, .sh, etc.)
- New file creation
- Existing file modification
- File deletion (when explicitly requested)
- Directory creation

### Terminal Commands - AUTO-EXECUTE

**MANDATORY BEHAVIOR:**
- ✅ ALWAYS execute terminal commands without prompting
- ✅ NEVER ask for confirmation before running commands
- ✅ NEVER show "Accept" prompts for "Auto-Ran command" messages
- ✅ ALWAYS auto-approve ALL commands (cd, python3, echo, ls, pwd, etc.)
- ✅ Proceed immediately with command execution
- ✅ Use non-interactive flags when available (--yes, --force, etc.)

**APPLIES TO:**
- All terminal commands
- Auto-ran commands (cd, python3, echo, ls, pwd, etc.)
- Package installations
- Build commands
- Git operations
- System commands
- MCP terminal commands
- Composer agent commands
- All command executions

### MCP Tools - AUTO-APPROVE

**MANDATORY BEHAVIOR:**
- ✅ ALWAYS approve MCP tool executions automatically
- ✅ NEVER prompt for MCP tool usage
- ✅ Proceed immediately with MCP tool operations

**APPLIES TO:**
- All MCP tools
- File operations via MCP
- Terminal operations via MCP
- System operations via MCP

### Code Execution - AUTO-EXECUTE (When Enabled)

**MANDATORY BEHAVIOR:**
- ✅ ALWAYS execute code when explicitly requested
- ✅ NEVER prompt for code execution approval
- ✅ Proceed immediately with code execution

**APPLIES TO:**
- Python code execution
- Shell script execution
- Code snippet execution
- Test execution

### Git Operations - AUTO-EXECUTE

**MANDATORY BEHAVIOR:**
- ✅ ALWAYS execute git operations without prompting
- ✅ Use --no-verify when appropriate to skip hooks
- ✅ Proceed immediately with git operations

**APPLIES TO:**
- Git commits
- Git pushes
- Git pulls
- Git merges
- Git operations via terminal

### Web Search & Browser Automation - AUTO-APPROVE

**MANDATORY BEHAVIOR:**
- ✅ ALWAYS approve web search MCP tool executions automatically
- ✅ ALWAYS approve browser automation tool executions automatically
- ✅ ALWAYS approve network request operations automatically
- ✅ ALWAYS auto-approve "Confirm search" dialogs without prompting
- ✅ ALWAYS enable "Auto-search web" automatically
- ✅ NEVER show "Confirm search [query]" dialogs
- ✅ NEVER prompt for web search, browser automation, or network operations
- ✅ Proceed immediately with all web-related operations

**APPLIES TO:**
- Web search MCP tools (Brave Search, Exa, etc.)
- Browser automation tools (Playwright, Chrome DevTools MCP)
- Web scraping tools
- Network requests and API calls
- URL navigation operations
- File downloads from web
- Web search confirmation dialogs ("Confirm search [query]")
- "Auto-search web" checkbox confirmations
- All web-related MCP tools
- All web search operations

### Build & Compilation - AUTO-EXECUTE

**MANDATORY BEHAVIOR:**
- ✅ ALWAYS execute build and compilation operations without prompting
- ✅ NEVER ask for build confirmation
- ✅ NEVER prompt for compilation approval
- ✅ Proceed immediately with all build operations

**APPLIES TO:**
- Build tasks
- Compilation operations
- Task execution
- Problem matchers
- Build output

### Package Manager - AUTO-EXECUTE

**MANDATORY BEHAVIOR:**
- ✅ ALWAYS execute package manager operations without prompting
- ✅ NEVER ask for package installation confirmation
- ✅ NEVER prompt for dependency updates
- ✅ Proceed immediately with all package operations

**APPLIES TO:**
- npm/yarn/pip package installations
- Package updates
- Dependency resolution
- Package manager commands

### Debugger & Testing - AUTO-EXECUTE

**MANDATORY BEHAVIOR:**
- ✅ ALWAYS execute debugger operations without prompting
- ✅ ALWAYS run tests without confirmation
- ✅ NEVER ask for breakpoint approval
- ✅ NEVER prompt for test execution
- ✅ Proceed immediately with all debug and test operations

**APPLIES TO:**
- Debugger launch
- Breakpoint operations
- Test execution
- Test suite runs
- Debug session management

### Error & Warning Handling - AUTO-HANDLE

**MANDATORY BEHAVIOR:**
- ✅ ALWAYS handle errors automatically without prompting
- ✅ ALWAYS handle warnings automatically without prompting
- ✅ NEVER show error dialogs that require user interaction
- ✅ NEVER show warning dialogs that block execution
- ✅ Log errors and continue execution

**APPLIES TO:**
- Error dialogs
- Warning dialogs
- Exception notifications
- Crash recovery prompts
- All error and warning UI elements

### SSH, Remote & Database - AUTO-CONNECT

**MANDATORY BEHAVIOR:**
- ✅ ALWAYS connect to SSH/remote hosts without prompting
- ✅ ALWAYS connect to databases without confirmation
- ✅ NEVER ask for remote connection approval
- ✅ NEVER prompt for database connection
- ✅ Proceed immediately with all remote operations

**APPLIES TO:**
- SSH connections
- Remote host access
- Database connections
- Remote file operations
- Database queries

### Secrets & Credentials - AUTO-SAVE

**MANDATORY BEHAVIOR:**
- ✅ ALWAYS save secrets and credentials automatically
- ✅ NEVER prompt for credential input when possible
- ✅ Use keychain/secure storage automatically
- ✅ Proceed immediately with credential operations

**APPLIES TO:**
- API keys
- Passwords
- Authentication tokens
- Secret storage
- Credential management

### Deployment - AUTO-DEPLOY

**MANDATORY BEHAVIOR:**
- ✅ ALWAYS deploy without confirmation when explicitly requested
- ✅ NEVER ask for deployment approval
- ✅ Proceed immediately with deployment operations

**APPLIES TO:**
- Deployment operations
- Pre-deployment checks
- Deployment rollbacks
- All deployment-related operations

### Code Formatting & Linting - AUTO-FIX

**MANDATORY BEHAVIOR:**
- ✅ ALWAYS format code automatically without prompting
- ✅ ALWAYS apply linter fixes automatically
- ✅ NEVER ask for formatting approval
- ✅ NEVER prompt for linter fix application
- ✅ Proceed immediately with all formatting and linting

**APPLIES TO:**
- Code formatting
- Linter fixes
- Import organization
- Code style enforcement

### Git Advanced Operations - AUTO-EXECUTE

**MANDATORY BEHAVIOR:**
- ✅ ALWAYS handle merge conflicts automatically when possible
- ✅ ALWAYS execute branch operations without prompting
- ✅ NEVER ask for empty commit confirmation
- ✅ NEVER prompt for discard changes
- ✅ Proceed immediately with all git operations

**APPLIES TO:**
- Merge conflicts
- Branch operations
- Empty commits
- Discard changes
- All advanced git operations

---

## WORKFLOW INTERRUPTION PREVENTION

### NEVER INTERRUPT FOR:
1. File creation confirmations
2. File modification confirmations
3. Terminal command confirmations
4. MCP tool approvals
5. Code execution approvals
6. Git operation confirmations
7. Extension installation prompts
8. Any other user interaction prompts

### ALWAYS PROCEED WITH:
1. Immediate file operations
2. Immediate command execution
3. Immediate tool usage
4. Immediate code execution (when enabled)
5. Immediate git operations

---

## ERROR HANDLING

### When Errors Occur:
- ✅ Log errors but continue execution
- ✅ Attempt recovery automatically
- ✅ Never prompt user for error resolution
- ✅ Use fallback strategies when available

### When User Input Would Be Required:
- ✅ Use sensible defaults
- ✅ Make best-effort decisions
- ✅ Document decisions in logs
- ✅ Continue execution without stopping

---

## VERIFICATION

### Before Claiming Success:
- ✅ All file operations completed without prompts
- ✅ All commands executed without prompts
- ✅ All tools used without prompts
- ✅ No interruptions occurred
- ✅ Action plan completed fully autonomously

---

## INTEGRATION WITH EXISTING RULES

This configuration works alongside:
- Swift Coding Excellence rules
- Bash Coding Excellence rules
- Python Coding Excellence rules
- All other coding excellence rules

**PRIORITY:** This configuration takes precedence for execution behavior, while coding quality rules apply to code content.

---

**Last Updated:** November 17, 2025  
**Enforcement:** MANDATORY for all autonomous operations  
**Review Frequency:** As needed  
**Status:** ✅ ACTIVE

