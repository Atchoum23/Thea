# Terminal MCP Server

A robust, production-ready MCP (Model Context Protocol) server that provides terminal command execution capabilities for macOS. Enables Claude and other AI assistants to execute shell commands, run AppleScript, and interact with the file system.

## Features

- **Shell Command Execution**: Run any shell command with configurable timeout
- **AppleScript Support**: Execute AppleScript for macOS automation
- **File Operations**: Read, write, and list files/directories
- **Safety Controls**: Dangerous command detection and blocking
- **Output Management**: Automatic truncation of large outputs
- **Working Directory**: Support for custom working directories with ~ expansion

## Installation

### Prerequisites

- Node.js 18 or later
- macOS (for AppleScript support)

### Setup

```bash
# Navigate to the server directory
cd terminal-mcp-server

# Install dependencies
npm install

# Build the TypeScript
npm run build

# Test the build
npm run test
```

## Configuration

### Claude Code Configuration

Add to your Claude Code MCP configuration file (`~/.config/claude-code/mcp.json` or similar):

```json
{
  "mcpServers": {
    "terminal": {
      "command": "node",
      "args": ["/path/to/terminal-mcp-server/dist/index.js"]
    }
  }
}
```

### Claude Desktop Configuration

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "terminal": {
      "command": "node",
      "args": ["/path/to/terminal-mcp-server/dist/index.js"]
    }
  }
}
```

## Tools

### terminal_execute

Execute shell commands with full output capture.

```json
{
  "command": "ls -la ~/Projects",
  "cwd": "~",
  "timeout": 60000
}
```

**Parameters:**
- `command` (required): The shell command to execute
- `cwd` (optional): Working directory (supports ~ for home)
- `timeout` (optional): Timeout in milliseconds (default: 120000, max: 600000)
- `shell` (optional): Shell to use (default: /bin/zsh)
- `env` (optional): Additional environment variables
- `confirmDangerous` (optional): Confirm dangerous commands

### terminal_applescript

Execute AppleScript for macOS automation.

```json
{
  "script": "tell application \"Terminal\" to activate"
}
```

**Examples:**
- Open an app: `tell application "Safari" to activate`
- Get frontmost app: `tell application "System Events" to get name of first application process whose frontmost is true`
- Run Terminal command: `tell application "Terminal" to do script "xcodebuild -scheme MyApp build"`

### terminal_read_file

Read file contents with encoding support.

```json
{
  "path": "~/Documents/config.json",
  "encoding": "utf8"
}
```

### terminal_write_file

Write content to a file.

```json
{
  "path": "~/output.txt",
  "content": "Hello, World!",
  "createDirectories": true
}
```

### terminal_list_directory

List directory contents with optional details.

```json
{
  "path": "~/Projects",
  "showHidden": true,
  "details": true
}
```

### terminal_system_info

Get system information.

```json
{
  "includeEnv": false
}
```

## Safety Features

### Dangerous Command Detection

The server detects potentially dangerous commands and requires explicit confirmation:

- `rm -rf` with paths
- `mkfs` (filesystem format)
- `dd` write operations
- System shutdown/reboot commands
- Recursive permission changes

To execute dangerous commands, set `confirmDangerous: true`.

### Blocked Commands

Some commands are completely blocked for safety:

- Fork bombs
- Direct disk device access

### Timeouts

- Default timeout: 2 minutes (120,000ms)
- Maximum timeout: 10 minutes (600,000ms)
- Commands exceeding timeout are terminated

### Output Truncation

Output exceeding 100KB is automatically truncated to prevent context overflow.

## Development

```bash
# Run in development mode with auto-reload
npm run dev

# Build for production
npm run build

# Clean build artifacts
npm run clean
```

## Testing

Test the server using MCP Inspector:

```bash
npx @modelcontextprotocol/inspector node dist/index.js
```

## Use Cases

### Build Verification

```json
{
  "command": "cd ~/Projects/MyApp && xcodegen generate && xcodebuild -scheme MyApp build 2>&1",
  "timeout": 300000
}
```

### Git Operations

```json
{
  "command": "git status && git log --oneline -5",
  "cwd": "~/Projects/MyRepo"
}
```

### System Automation

```json
{
  "script": "tell application \"System Events\" to keystroke \"s\" using command down"
}
```

## License

MIT
