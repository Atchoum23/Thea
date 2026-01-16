#!/bin/bash
# Terminal MCP Server Installation Script
# This script installs and configures the Terminal MCP Server for Claude Code

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR"
CONFIG_DIR="$HOME/.config/claude-code"
CONFIG_FILE="$CONFIG_DIR/mcp.json"

echo "=========================================="
echo "  Terminal MCP Server Installation"
echo "=========================================="
echo ""

# Check Node.js
echo "Checking Node.js..."
if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please install Node.js 18+ first:"
    echo "   brew install node"
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Node.js 18+ required. Current version: $(node -v)"
    echo "   brew upgrade node"
    exit 1
fi
echo "✅ Node.js $(node -v) found"

# Check npm
echo "Checking npm..."
if ! command -v npm &> /dev/null; then
    echo "❌ npm not found. Please install npm."
    exit 1
fi
echo "✅ npm $(npm -v) found"
echo ""

# Install dependencies
echo "Installing dependencies..."
cd "$SERVER_DIR"
npm install
echo "✅ Dependencies installed"
echo ""

# Build TypeScript
echo "Building TypeScript..."
npm run build
echo "✅ Build completed"
echo ""

# Test build
echo "Testing build..."
if [ ! -f "$SERVER_DIR/dist/index.js" ]; then
    echo "❌ Build failed - dist/index.js not found"
    exit 1
fi

node "$SERVER_DIR/dist/index.js" --help > /dev/null 2>&1
echo "✅ Build verified"
echo ""

# Configure Claude Code
echo "Configuring Claude Code..."
mkdir -p "$CONFIG_DIR"

# Create or update MCP config
if [ -f "$CONFIG_FILE" ]; then
    echo "Existing config found at $CONFIG_FILE"

    # Backup existing config
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup"
    echo "✅ Backup created: $CONFIG_FILE.backup"

    # Check if terminal server already configured
    if grep -q '"terminal"' "$CONFIG_FILE"; then
        echo "⚠️  Terminal MCP server already configured. Updating..."
    fi

    # Use node to merge config
    node -e "
const fs = require('fs');
const config = JSON.parse(fs.readFileSync('$CONFIG_FILE', 'utf8'));
config.mcpServers = config.mcpServers || {};
config.mcpServers.terminal = {
    command: 'node',
    args: ['$SERVER_DIR/dist/index.js']
};
fs.writeFileSync('$CONFIG_FILE', JSON.stringify(config, null, 2));
console.log('Config updated');
"
else
    # Create new config
    cat > "$CONFIG_FILE" << EOF
{
  "mcpServers": {
    "terminal": {
      "command": "node",
      "args": ["$SERVER_DIR/dist/index.js"]
    }
  }
}
EOF
fi

echo "✅ MCP config created/updated: $CONFIG_FILE"
echo ""

# Also configure for Claude Desktop if it exists
CLAUDE_DESKTOP_DIR="$HOME/Library/Application Support/Claude"
CLAUDE_DESKTOP_CONFIG="$CLAUDE_DESKTOP_DIR/claude_desktop_config.json"

if [ -d "$CLAUDE_DESKTOP_DIR" ]; then
    echo "Claude Desktop detected..."

    if [ -f "$CLAUDE_DESKTOP_CONFIG" ]; then
        cp "$CLAUDE_DESKTOP_CONFIG" "$CLAUDE_DESKTOP_CONFIG.backup"

        node -e "
const fs = require('fs');
const config = JSON.parse(fs.readFileSync('$CLAUDE_DESKTOP_CONFIG', 'utf8'));
config.mcpServers = config.mcpServers || {};
config.mcpServers.terminal = {
    command: 'node',
    args: ['$SERVER_DIR/dist/index.js']
};
fs.writeFileSync('$CLAUDE_DESKTOP_CONFIG', JSON.stringify(config, null, 2));
console.log('Claude Desktop config updated');
"
    else
        cat > "$CLAUDE_DESKTOP_CONFIG" << EOF
{
  "mcpServers": {
    "terminal": {
      "command": "node",
      "args": ["$SERVER_DIR/dist/index.js"]
    }
  }
}
EOF
    fi
    echo "✅ Claude Desktop config updated: $CLAUDE_DESKTOP_CONFIG"
fi

echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
echo "The Terminal MCP Server has been installed and configured."
echo ""
echo "Server location: $SERVER_DIR/dist/index.js"
echo "Config location: $CONFIG_FILE"
echo ""
echo "Available tools:"
echo "  - terminal_execute      Execute shell commands"
echo "  - terminal_applescript  Execute AppleScript"
echo "  - terminal_read_file    Read file contents"
echo "  - terminal_write_file   Write to files"
echo "  - terminal_list_directory  List directories"
echo "  - terminal_system_info  Get system info"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code to load the new MCP server"
echo "  2. Try: terminal_execute with command 'echo Hello World'"
echo ""
echo "To test manually:"
echo "  npx @modelcontextprotocol/inspector node $SERVER_DIR/dist/index.js"
echo ""
