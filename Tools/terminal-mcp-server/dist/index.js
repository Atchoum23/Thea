#!/usr/bin/env node
/**
 * Terminal MCP Server
 *
 * A robust MCP server that provides terminal/shell command execution capabilities
 * for macOS. Includes safety controls, timeout handling, and comprehensive output capture.
 *
 * Features:
 * - Execute shell commands with configurable timeouts
 * - Working directory support
 * - Environment variable passthrough
 * - Output truncation for large responses
 * - Safety controls for dangerous commands
 * - AppleScript execution for macOS automation
 */
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { exec } from "child_process";
import { promisify } from "util";
import * as path from "path";
import * as fs from "fs";
import * as os from "os";
const execAsync = promisify(exec);
// ============================================================================
// Constants
// ============================================================================
const SERVER_NAME = "terminal-mcp-server";
const SERVER_VERSION = "1.0.0";
const DEFAULT_TIMEOUT_MS = 120000; // 2 minutes
const MAX_TIMEOUT_MS = 600000; // 10 minutes
const MAX_OUTPUT_LENGTH = 100000; // 100KB max output
const DEFAULT_SHELL = process.env.SHELL || "/bin/zsh";
// SECURITY FIX (FINDING-012): Allowed directories for file operations
// Only these directories (and their subdirectories) can be accessed
const ALLOWED_DIRECTORIES = [
    os.homedir(), // User's home directory
    "/tmp", // Temporary files
    "/var/tmp", // Persistent temporary files
    process.cwd(), // Current working directory
];
// SECURITY FIX (FINDING-012): Blocked paths that should never be accessed
const BLOCKED_PATHS = [
    "/System",
    "/Library",
    "/private",
    "/var",
    "/etc",
    "/bin",
    "/sbin",
    "/usr",
    ".ssh",
    ".gnupg",
    ".aws",
    ".kube",
    "Keychain",
];
/**
 * SECURITY FIX (FINDING-012): Validate that a path is within allowed directories
 */
function isPathAllowed(targetPath) {
    const resolvedPath = path.resolve(targetPath.replace(/^~/, os.homedir()));
    // Check for blocked paths first
    for (const blocked of BLOCKED_PATHS) {
        if (resolvedPath.includes(blocked)) {
            return { allowed: false, reason: `Path contains blocked pattern: ${blocked}` };
        }
    }
    // Check if path is within any allowed directory
    for (const allowedDir of ALLOWED_DIRECTORIES) {
        const resolvedAllowed = path.resolve(allowedDir);
        if (resolvedPath.startsWith(resolvedAllowed + path.sep) || resolvedPath === resolvedAllowed) {
            return { allowed: true };
        }
    }
    return { allowed: false, reason: `Path is not within allowed directories` };
}
// Commands that require explicit confirmation (destructive operations)
const DANGEROUS_PATTERNS = [
    /rm\s+(-rf?|--recursive).*\//i, // rm -rf with path
    /rm\s+-rf?\s+~/i, // rm -rf home directory
    /mkfs/i, // Format filesystem
    /dd\s+.*of=/i, // dd write operations
    />\s*\/dev\//i, // Write to device files
    /chmod\s+-R\s+777/i, // Recursive 777 permissions
    /:(){ :|:& };:/, // Fork bomb
    /shutdown/i, // System shutdown
    /reboot/i, // System reboot
    /init\s+0/i, // System halt
];
// Commands that are completely blocked
const BLOCKED_PATTERNS = [
    /:(){ :|:& };:/, // Fork bomb
    /\/dev\/sd[a-z]/i, // Direct disk access
    /format\s+c:/i, // Windows format (just in case)
];
// ============================================================================
// Utility Functions
// ============================================================================
/**
 * Check if a command matches any dangerous patterns
 */
function isDangerousCommand(command) {
    for (const pattern of BLOCKED_PATTERNS) {
        if (pattern.test(command)) {
            return { dangerous: true, reason: "This command pattern is blocked for safety." };
        }
    }
    for (const pattern of DANGEROUS_PATTERNS) {
        if (pattern.test(command)) {
            return {
                dangerous: true,
                reason: "This command may be destructive. Please confirm you want to proceed."
            };
        }
    }
    return { dangerous: false };
}
/**
 * Truncate output if it exceeds the maximum length
 */
function truncateOutput(output, maxLength = MAX_OUTPUT_LENGTH) {
    if (output.length <= maxLength) {
        return { text: output, truncated: false };
    }
    const truncatedText = output.substring(0, maxLength) +
        `\n\n... [OUTPUT TRUNCATED: ${output.length - maxLength} characters omitted] ...`;
    return { text: truncatedText, truncated: true };
}
/**
 * Resolve and validate working directory
 */
function resolveWorkingDirectory(cwd) {
    if (!cwd) {
        return process.cwd();
    }
    // Expand ~ to home directory
    const expandedPath = cwd.replace(/^~/, os.homedir());
    const resolvedPath = path.resolve(expandedPath);
    // Verify directory exists
    if (!fs.existsSync(resolvedPath)) {
        throw new Error(`Working directory does not exist: ${resolvedPath}`);
    }
    if (!fs.statSync(resolvedPath).isDirectory()) {
        throw new Error(`Path is not a directory: ${resolvedPath}`);
    }
    return resolvedPath;
}
/**
 * Execute a shell command with timeout and output capture
 */
async function executeCommand(command, options = {}) {
    const startTime = Date.now();
    const workingDirectory = resolveWorkingDirectory(options.cwd);
    const timeout = Math.min(options.timeout || DEFAULT_TIMEOUT_MS, MAX_TIMEOUT_MS);
    const shell = options.shell || DEFAULT_SHELL;
    // Merge environment variables
    const env = {
        ...process.env,
        ...options.env,
    };
    try {
        const { stdout, stderr } = await execAsync(command, {
            cwd: workingDirectory,
            timeout,
            shell,
            env,
            maxBuffer: 50 * 1024 * 1024, // 50MB buffer
            encoding: "utf8",
        });
        const duration = Date.now() - startTime;
        const { text: truncatedStdout, truncated: stdoutTruncated } = truncateOutput(stdout);
        const { text: truncatedStderr, truncated: stderrTruncated } = truncateOutput(stderr);
        return {
            success: true,
            exitCode: 0,
            stdout: truncatedStdout,
            stderr: truncatedStderr,
            duration,
            truncated: stdoutTruncated || stderrTruncated,
            command,
            workingDirectory,
        };
    }
    catch (error) {
        const duration = Date.now() - startTime;
        if (error instanceof Error) {
            const execError = error;
            // Handle timeout
            if (execError.killed || execError.signal === "SIGTERM") {
                return {
                    success: false,
                    exitCode: null,
                    stdout: execError.stdout || "",
                    stderr: `Command timed out after ${timeout}ms`,
                    duration,
                    truncated: false,
                    command,
                    workingDirectory,
                };
            }
            const { text: truncatedStdout, truncated: stdoutTruncated } = truncateOutput(execError.stdout || "");
            const { text: truncatedStderr, truncated: stderrTruncated } = truncateOutput(execError.stderr || execError.message);
            return {
                success: false,
                exitCode: typeof execError.code === "number" ? execError.code : 1,
                stdout: truncatedStdout,
                stderr: truncatedStderr,
                duration,
                truncated: stdoutTruncated || stderrTruncated,
                command,
                workingDirectory,
            };
        }
        return {
            success: false,
            exitCode: 1,
            stdout: "",
            stderr: String(error),
            duration,
            truncated: false,
            command,
            workingDirectory,
        };
    }
}
/**
 * Execute AppleScript for macOS automation
 */
async function executeAppleScript(script) {
    try {
        const { stdout, stderr } = await execAsync(`osascript -e '${script.replace(/'/g, "'\\''")}'`, {
            timeout: 30000,
            encoding: "utf8",
        });
        return {
            success: true,
            output: stdout.trim(),
            error: stderr ? stderr.trim() : null,
        };
    }
    catch (error) {
        if (error instanceof Error) {
            const execError = error;
            return {
                success: false,
                output: "",
                error: execError.stderr || execError.message,
            };
        }
        return {
            success: false,
            output: "",
            error: String(error),
        };
    }
}
/**
 * Get system information
 */
function getSystemInfo() {
    return {
        platform: os.platform(),
        arch: os.arch(),
        hostname: os.hostname(),
        homedir: os.homedir(),
        tmpdir: os.tmpdir(),
        shell: DEFAULT_SHELL,
        nodeVersion: process.version,
    };
}
// ============================================================================
// Zod Schemas
// ============================================================================
const ExecuteCommandSchema = z.object({
    command: z.string()
        .min(1, "Command cannot be empty")
        .max(10000, "Command too long (max 10000 characters)")
        .describe("The shell command to execute"),
    cwd: z.string()
        .optional()
        .describe("Working directory for command execution. Supports ~ for home directory."),
    timeout: z.number()
        .int()
        .min(1000)
        .max(MAX_TIMEOUT_MS)
        .default(DEFAULT_TIMEOUT_MS)
        .describe(`Timeout in milliseconds (default: ${DEFAULT_TIMEOUT_MS}, max: ${MAX_TIMEOUT_MS})`),
    shell: z.string()
        .optional()
        .describe(`Shell to use for execution (default: ${DEFAULT_SHELL})`),
    env: z.record(z.string())
        .optional()
        .describe("Additional environment variables to set"),
    confirmDangerous: z.boolean()
        .default(false)
        .describe("Set to true to confirm execution of potentially dangerous commands"),
}).strict();
const ExecuteAppleScriptSchema = z.object({
    script: z.string()
        .min(1, "Script cannot be empty")
        .max(50000, "Script too long")
        .describe("AppleScript code to execute"),
}).strict();
const ReadFileSchema = z.object({
    path: z.string()
        .min(1, "Path cannot be empty")
        .describe("File path to read. Supports ~ for home directory."),
    encoding: z.enum(["utf8", "base64", "hex"])
        .default("utf8")
        .describe("File encoding"),
    maxSize: z.number()
        .int()
        .min(1)
        .max(10 * 1024 * 1024) // 10MB
        .default(1024 * 1024) // 1MB
        .describe("Maximum file size to read in bytes"),
}).strict();
const WriteFileSchema = z.object({
    path: z.string()
        .min(1, "Path cannot be empty")
        .describe("File path to write. Supports ~ for home directory."),
    content: z.string()
        .describe("Content to write to file"),
    encoding: z.enum(["utf8", "base64", "hex"])
        .default("utf8")
        .describe("File encoding"),
    createDirectories: z.boolean()
        .default(false)
        .describe("Create parent directories if they don't exist"),
}).strict();
const ListDirectorySchema = z.object({
    path: z.string()
        .default(".")
        .describe("Directory path to list. Supports ~ for home directory."),
    showHidden: z.boolean()
        .default(false)
        .describe("Include hidden files (starting with .)"),
    details: z.boolean()
        .default(false)
        .describe("Include file details (size, modified date, permissions)"),
}).strict();
// ============================================================================
// MCP Server Setup
// ============================================================================
const server = new McpServer({
    name: SERVER_NAME,
    version: SERVER_VERSION,
});
// ----------------------------------------------------------------------------
// Tool: terminal_execute
// ----------------------------------------------------------------------------
server.registerTool("terminal_execute", {
    title: "Execute Terminal Command",
    description: `Execute a shell command in the terminal and return the output.

This tool runs commands in a shell (default: ${DEFAULT_SHELL}) with configurable timeout and working directory.

Args:
  - command (string, required): The shell command to execute
  - cwd (string, optional): Working directory (supports ~ for home)
  - timeout (number, optional): Timeout in ms (default: ${DEFAULT_TIMEOUT_MS}, max: ${MAX_TIMEOUT_MS})
  - shell (string, optional): Shell to use (default: ${DEFAULT_SHELL})
  - env (object, optional): Additional environment variables
  - confirmDangerous (boolean, optional): Confirm dangerous commands

Returns:
  {
    "success": boolean,
    "exitCode": number | null,
    "stdout": string,
    "stderr": string,
    "duration": number,
    "truncated": boolean,
    "command": string,
    "workingDirectory": string
  }

Examples:
  - List files: { "command": "ls -la" }
  - Build project: { "command": "xcodebuild -scheme MyApp build", "cwd": "~/Projects/MyApp", "timeout": 300000 }
  - Run tests: { "command": "npm test", "cwd": "~/myproject" }

Safety:
  - Dangerous commands (rm -rf, etc.) require confirmDangerous: true
  - Some commands are blocked entirely for safety
  - Commands timeout after the specified duration`,
    inputSchema: ExecuteCommandSchema,
    annotations: {
        readOnlyHint: false,
        destructiveHint: true,
        idempotentHint: false,
        openWorldHint: true,
    },
}, async (params) => {
    // Safety check
    const dangerCheck = isDangerousCommand(params.command);
    if (dangerCheck.dangerous) {
        if (!params.confirmDangerous) {
            return {
                content: [{
                        type: "text",
                        text: JSON.stringify({
                            success: false,
                            error: "DANGEROUS_COMMAND",
                            reason: dangerCheck.reason,
                            hint: "Set confirmDangerous: true to proceed with this command.",
                            command: params.command,
                        }, null, 2),
                    }],
            };
        }
    }
    try {
        const result = await executeCommand(params.command, {
            cwd: params.cwd,
            timeout: params.timeout,
            shell: params.shell,
            env: params.env,
        });
        return {
            content: [{
                    type: "text",
                    text: JSON.stringify(result, null, 2),
                }],
            structuredContent: result,
        };
    }
    catch (error) {
        return {
            content: [{
                    type: "text",
                    text: JSON.stringify({
                        success: false,
                        error: error instanceof Error ? error.message : String(error),
                    }, null, 2),
                }],
        };
    }
});
// ----------------------------------------------------------------------------
// Tool: terminal_applescript
// ----------------------------------------------------------------------------
server.registerTool("terminal_applescript", {
    title: "Execute AppleScript",
    description: `Execute AppleScript code for macOS automation.

This tool runs AppleScript using osascript, enabling control of macOS applications and system features.

Args:
  - script (string, required): AppleScript code to execute

Returns:
  {
    "success": boolean,
    "output": string,
    "error": string | null
  }

Examples:
  - Get frontmost app: { "script": "tell application \\"System Events\\" to get name of first application process whose frontmost is true" }
  - Show notification: { "script": "display notification \\"Hello\\" with title \\"MCP\\"" }
  - Open Terminal: { "script": "tell application \\"Terminal\\" to activate" }
  - Run Terminal command: { "script": "tell application \\"Terminal\\" to do script \\"ls -la\\"" }`,
    inputSchema: ExecuteAppleScriptSchema,
    annotations: {
        readOnlyHint: false,
        destructiveHint: true,
        idempotentHint: false,
        openWorldHint: true,
    },
}, async (params) => {
    try {
        const result = await executeAppleScript(params.script);
        return {
            content: [{
                    type: "text",
                    text: JSON.stringify(result, null, 2),
                }],
            structuredContent: result,
        };
    }
    catch (error) {
        return {
            content: [{
                    type: "text",
                    text: JSON.stringify({
                        success: false,
                        output: "",
                        error: error instanceof Error ? error.message : String(error),
                    }, null, 2),
                }],
        };
    }
});
// ----------------------------------------------------------------------------
// Tool: terminal_read_file
// ----------------------------------------------------------------------------
server.registerTool("terminal_read_file", {
    title: "Read File",
    description: `Read the contents of a file.

Args:
  - path (string, required): File path (supports ~ for home directory)
  - encoding (string, optional): "utf8" | "base64" | "hex" (default: "utf8")
  - maxSize (number, optional): Maximum file size in bytes (default: 1MB, max: 10MB)

Returns:
  {
    "success": boolean,
    "path": string,
    "content": string,
    "size": number,
    "encoding": string,
    "error": string | null
  }`,
    inputSchema: ReadFileSchema,
    annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
    },
}, async (params) => {
    try {
        const expandedPath = params.path.replace(/^~/, os.homedir());
        const resolvedPath = path.resolve(expandedPath);
        // SECURITY FIX (FINDING-012): Validate path is allowed
        const pathCheck = isPathAllowed(resolvedPath);
        if (!pathCheck.allowed) {
            return {
                content: [{
                        type: "text",
                        text: JSON.stringify({
                            success: false,
                            path: resolvedPath,
                            error: `SECURITY: ${pathCheck.reason}`,
                        }, null, 2),
                    }],
            };
        }
        // Check file exists
        if (!fs.existsSync(resolvedPath)) {
            return {
                content: [{
                        type: "text",
                        text: JSON.stringify({
                            success: false,
                            path: resolvedPath,
                            error: "File not found",
                        }, null, 2),
                    }],
            };
        }
        // Check file size
        const stats = fs.statSync(resolvedPath);
        if (stats.size > params.maxSize) {
            return {
                content: [{
                        type: "text",
                        text: JSON.stringify({
                            success: false,
                            path: resolvedPath,
                            size: stats.size,
                            error: `File too large (${stats.size} bytes > ${params.maxSize} max)`,
                        }, null, 2),
                    }],
            };
        }
        const content = fs.readFileSync(resolvedPath, { encoding: params.encoding });
        const result = {
            success: true,
            path: resolvedPath,
            content,
            size: stats.size,
            encoding: params.encoding,
            error: null,
        };
        return {
            content: [{
                    type: "text",
                    text: JSON.stringify(result, null, 2),
                }],
            structuredContent: result,
        };
    }
    catch (error) {
        return {
            content: [{
                    type: "text",
                    text: JSON.stringify({
                        success: false,
                        path: params.path,
                        error: error instanceof Error ? error.message : String(error),
                    }, null, 2),
                }],
        };
    }
});
// ----------------------------------------------------------------------------
// Tool: terminal_write_file
// ----------------------------------------------------------------------------
server.registerTool("terminal_write_file", {
    title: "Write File",
    description: `Write content to a file.

Args:
  - path (string, required): File path (supports ~ for home directory)
  - content (string, required): Content to write
  - encoding (string, optional): "utf8" | "base64" | "hex" (default: "utf8")
  - createDirectories (boolean, optional): Create parent directories if needed (default: false)

Returns:
  {
    "success": boolean,
    "path": string,
    "bytesWritten": number,
    "error": string | null
  }`,
    inputSchema: WriteFileSchema,
    annotations: {
        readOnlyHint: false,
        destructiveHint: true,
        idempotentHint: true,
        openWorldHint: false,
    },
}, async (params) => {
    try {
        const expandedPath = params.path.replace(/^~/, os.homedir());
        const resolvedPath = path.resolve(expandedPath);
        // SECURITY FIX (FINDING-012): Validate path is allowed
        const pathCheck = isPathAllowed(resolvedPath);
        if (!pathCheck.allowed) {
            return {
                content: [{
                        type: "text",
                        text: JSON.stringify({
                            success: false,
                            path: resolvedPath,
                            error: `SECURITY: ${pathCheck.reason}`,
                        }, null, 2),
                    }],
            };
        }
        // Create directories if requested
        if (params.createDirectories) {
            const dir = path.dirname(resolvedPath);
            fs.mkdirSync(dir, { recursive: true });
        }
        fs.writeFileSync(resolvedPath, params.content, { encoding: params.encoding });
        const stats = fs.statSync(resolvedPath);
        const result = {
            success: true,
            path: resolvedPath,
            bytesWritten: stats.size,
            error: null,
        };
        return {
            content: [{
                    type: "text",
                    text: JSON.stringify(result, null, 2),
                }],
            structuredContent: result,
        };
    }
    catch (error) {
        return {
            content: [{
                    type: "text",
                    text: JSON.stringify({
                        success: false,
                        path: params.path,
                        error: error instanceof Error ? error.message : String(error),
                    }, null, 2),
                }],
        };
    }
});
// ----------------------------------------------------------------------------
// Tool: terminal_list_directory
// ----------------------------------------------------------------------------
server.registerTool("terminal_list_directory", {
    title: "List Directory",
    description: `List contents of a directory.

Args:
  - path (string, optional): Directory path (default: current directory, supports ~)
  - showHidden (boolean, optional): Include hidden files (default: false)
  - details (boolean, optional): Include file details (default: false)

Returns:
  {
    "success": boolean,
    "path": string,
    "entries": [
      {
        "name": string,
        "type": "file" | "directory" | "symlink",
        "size": number,        // if details: true
        "modified": string,    // if details: true
        "permissions": string  // if details: true
      }
    ],
    "error": string | null
  }`,
    inputSchema: ListDirectorySchema,
    annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
    },
}, async (params) => {
    try {
        const expandedPath = params.path.replace(/^~/, os.homedir());
        const resolvedPath = path.resolve(expandedPath);
        // SECURITY FIX (FINDING-012): Validate path is allowed
        const pathCheck = isPathAllowed(resolvedPath);
        if (!pathCheck.allowed) {
            return {
                content: [{
                        type: "text",
                        text: JSON.stringify({
                            success: false,
                            path: resolvedPath,
                            error: `SECURITY: ${pathCheck.reason}`,
                        }, null, 2),
                    }],
            };
        }
        if (!fs.existsSync(resolvedPath)) {
            return {
                content: [{
                        type: "text",
                        text: JSON.stringify({
                            success: false,
                            path: resolvedPath,
                            error: "Directory not found",
                        }, null, 2),
                    }],
            };
        }
        const entries = fs.readdirSync(resolvedPath, { withFileTypes: true });
        const result = {
            success: true,
            path: resolvedPath,
            entries: entries
                .filter(entry => params.showHidden || !entry.name.startsWith("."))
                .map(entry => {
                const entryPath = path.join(resolvedPath, entry.name);
                const type = entry.isDirectory() ? "directory" : entry.isSymbolicLink() ? "symlink" : "file";
                if (params.details) {
                    try {
                        const stats = fs.statSync(entryPath);
                        return {
                            name: entry.name,
                            type,
                            size: stats.size,
                            modified: stats.mtime.toISOString(),
                            permissions: (stats.mode & 0o777).toString(8),
                        };
                    }
                    catch {
                        return { name: entry.name, type };
                    }
                }
                return { name: entry.name, type };
            })
                .sort((a, b) => {
                // Directories first, then alphabetically
                if (a.type === "directory" && b.type !== "directory")
                    return -1;
                if (a.type !== "directory" && b.type === "directory")
                    return 1;
                return a.name.localeCompare(b.name);
            }),
            error: null,
        };
        return {
            content: [{
                    type: "text",
                    text: JSON.stringify(result, null, 2),
                }],
            structuredContent: result,
        };
    }
    catch (error) {
        return {
            content: [{
                    type: "text",
                    text: JSON.stringify({
                        success: false,
                        path: params.path,
                        error: error instanceof Error ? error.message : String(error),
                    }, null, 2),
                }],
        };
    }
});
// ----------------------------------------------------------------------------
// Tool: terminal_system_info
// ----------------------------------------------------------------------------
server.registerTool("terminal_system_info", {
    title: "Get System Information",
    description: `Get system information about the host machine.

Returns:
  {
    "platform": string,
    "arch": string,
    "hostname": string,
    "homedir": string,
    "tmpdir": string,
    "shell": string,
    "nodeVersion": string,
    "cwd": string,
    "env": object
  }`,
    inputSchema: z.object({
        includeEnv: z.boolean()
            .default(false)
            .describe("Include environment variables (filtered for safety)"),
    }).strict(),
    annotations: {
        readOnlyHint: true,
        destructiveHint: false,
        idempotentHint: true,
        openWorldHint: false,
    },
}, async (params) => {
    const info = {
        ...getSystemInfo(),
        cwd: process.cwd(),
        ...(params.includeEnv ? {
            env: Object.fromEntries(Object.entries(process.env)
                .filter(([key]) => !key.toLowerCase().includes("secret") &&
                !key.toLowerCase().includes("password") &&
                !key.toLowerCase().includes("token") &&
                !key.toLowerCase().includes("key"))),
        } : {}),
    };
    return {
        content: [{
                type: "text",
                text: JSON.stringify(info, null, 2),
            }],
        structuredContent: info,
    };
});
// ============================================================================
// Main Entry Point
// ============================================================================
async function main() {
    // Handle --help flag
    if (process.argv.includes("--help") || process.argv.includes("-h")) {
        console.log(`
${SERVER_NAME} v${SERVER_VERSION}

A robust MCP server for terminal command execution on macOS.

Usage:
  ${SERVER_NAME}              Start the MCP server via stdio
  ${SERVER_NAME} --help       Show this help message

Tools provided:
  - terminal_execute        Execute shell commands
  - terminal_applescript    Execute AppleScript for macOS automation
  - terminal_read_file      Read file contents
  - terminal_write_file     Write content to files
  - terminal_list_directory List directory contents
  - terminal_system_info    Get system information

Configuration:
  Add to your Claude Code MCP config:

  {
    "mcpServers": {
      "terminal": {
        "command": "node",
        "args": ["${process.cwd()}/dist/index.js"]
      }
    }
  }

Safety:
  - Dangerous commands require explicit confirmation
  - Some destructive patterns are blocked entirely
  - Commands have configurable timeouts (max ${MAX_TIMEOUT_MS}ms)
  - Output is truncated at ${MAX_OUTPUT_LENGTH} characters
`);
        process.exit(0);
    }
    // Start MCP server
    const transport = new StdioServerTransport();
    try {
        await server.connect(transport);
        console.error(`${SERVER_NAME} v${SERVER_VERSION} running via stdio`);
    }
    catch (error) {
        console.error("Failed to start MCP server:", error);
        process.exit(1);
    }
}
main().catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
});
//# sourceMappingURL=index.js.map