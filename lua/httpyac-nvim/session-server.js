'use strict';

/**
 * httpyac session sidecar — Node.js process that uses httpyac as a library
 * to keep all in-memory state (cookies, $global, OAuth tokens) alive across
 * requests from Neovim.
 *
 * Protocol: newline-delimited JSON on stdin/stdout.
 *
 * Commands (Lua → sidecar):
 *   { "type": "send", "file": "/abs/path.http", "line": 42, "env": "dev" }
 *   { "type": "send", "file": "/abs/path.http", "all": true, "env": "dev" }
 *   { "type": "reset" }
 *   { "type": "vars", "env": "dev" }
 *
 * Responses (sidecar → Lua):
 *   { "ok": true,  "output": "...", "globals": { ... } }
 *   { "ok": false, "error": "...", "output": "..." }
 */

const path = require('path');
const fs = require('fs');
const readline = require('readline');

// ---------------------------------------------------------------------------
// Resolve httpyac module from the httpyac CLI executable
// ---------------------------------------------------------------------------
function resolveHttpyac() {
  // 1. Direct require (works when installed in current NODE_PATH).
  try { return require('httpyac'); } catch (_) {}

  // 2. Locate via 'which httpyac' and walk up from the real binary path.
  try {
    const { execFileSync } = require('child_process');
    const bin = execFileSync('which', ['httpyac'], { encoding: 'utf8' }).trim();
    const realBin = fs.realpathSync(bin);

    // Walk up directory tree looking for node_modules/httpyac.
    // Homebrew pattern: .../libexec/bin/httpyac → .../libexec/lib/node_modules/httpyac
    let dir = path.dirname(realBin);
    for (let i = 0; i < 10; i++) {
      const parent = path.dirname(dir);
      const candidates = [
        path.join(dir,    'lib', 'node_modules', 'httpyac'),
        path.join(dir,    'node_modules',         'httpyac'),
        path.join(parent, 'lib', 'node_modules', 'httpyac'),
        path.join(parent, 'node_modules',         'httpyac'),
      ];
      for (const c of candidates) {
        try { return require(c); } catch (_) {}
      }
      if (dir === parent) break;
      dir = parent;
    }
  } catch (_) {}

  throw new Error(
    'httpyac module not found. Make sure httpyac is installed: npm install -g httpyac'
  );
}

// ---------------------------------------------------------------------------
// Bootstrap
// ---------------------------------------------------------------------------
let httpyac;
try {
  httpyac = resolveHttpyac();
} catch (err) {
  process.stderr.write('ERROR: ' + err.message + '\n');
  process.exit(1);
}

const { send, store, cli, io } = httpyac;
const { HttpFileStore } = store;

// Set up the file-system provider so httpyac can read .http and env files.
cli.initFileProvider();

// Suppress interactive prompts — they would block and conflict with our stdin
// JSON protocol.  userInteractionProvider starts with isTrusted = () => true.
io.userInteractionProvider.showNote          = async () => true;
io.userInteractionProvider.showInputPrompt   = async (_p, defaultVal) => defaultVal || '';
io.userInteractionProvider.showListPrompt    = async (_p, choices)    =>
  Array.isArray(choices) ? choices[0] : '';

// Silence all httpyac internal logging so it doesn't pollute stdout.
io.log.options.level = 1000; // LogLevel.none

const httpFileStore = new HttpFileStore();

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

/** Write one newline-delimited JSON response to stdout. */
function respond(obj) {
  process.stdout.write(JSON.stringify(obj) + '\n');
}

/**
 * Format a response object into a human-readable text block.
 * Mirrors the CLI "response" output format:
 *   HTTP/1.1 200 - OK
 *   header: value
 *
 *   body
 */
function formatResponse(response) {
  if (!response) return '';
  const lines = [];
  const statusMsg = response.statusMessage ? ` - ${response.statusMessage}` : '';
  lines.push(`${response.protocol || 'HTTP/1.1'} ${response.statusCode}${statusMsg}`);
  if (response.headers) {
    for (const [k, v] of Object.entries(response.headers)) {
      // Skip HTTP/2 pseudo-headers that start with ':'
      if (String(k).startsWith(':')) continue;
      const val = Array.isArray(v) ? v.join(', ') : String(v);
      lines.push(`${k}: ${val}`);
    }
  }
  const body = response.prettyPrintBody || response.body;
  if (body) {
    lines.push('');
    lines.push(body);
  }
  return lines.join('\n');
}

/**
 * Build the userSessionStore key used by httpyac for $global storage.
 * Mirrors: 'global_cache_' + J(activeEnvironment)
 * where J(arr) = arr.sort().join(',') || '__NONE__'
 */
function globalCacheKey(env) {
  if (env && env.length > 0) {
    return 'global_cache_' + [...env].sort().join(',');
  }
  return 'global_cache___NONE__';
}

/** Read the current $global object from the persistent session store. */
function readGlobals(env) {
  const key = globalCacheKey(env);
  const session = store.userSessionStore.getUserSession(key);
  return (session && session.details && session.details.$global) || {};
}

// ---------------------------------------------------------------------------
// Command handlers
// ---------------------------------------------------------------------------

async function handleSend(cmd) {
  const filePath = cmd.file;
  if (!filePath) {
    respond({ ok: false, error: 'Missing required field: file', output: '' });
    return;
  }

  // luaLine is 1-indexed (from Neovim cursor); undefined means "all"
  const luaLine  = typeof cmd.line === 'number' ? cmd.line : undefined;
  const sendAll  = cmd.all === true;
  const envArg   = (cmd.env && cmd.env !== '') ? [cmd.env] : undefined;
  const workingDir = path.dirname(filePath);

  const outputParts = [];

  try {
    // Force re-parse on every call so edits to the file are picked up.
    const version = Date.now();
    const httpFile = await httpFileStore.getOrCreate(
      filePath,
      () => fs.promises.readFile(filePath, 'utf-8'),
      version,
      { workingDir }
    );

    // Collect formatted response text via the logResponse hook.
    const logResponse = async (response /*, httpRegion */) => {
      const text = formatResponse(response);
      if (text) outputParts.push(text);
    };

    const baseOpts = { httpFile, activeEnvironment: envArg, logResponse };

    let success;

    if (sendAll) {
      // Execute all non-global regions.
      success = await send(baseOpts);

    } else if (luaLine !== undefined) {
      // Find the region that contains the Lua cursor line (1-indexed).
      // httpRegion.symbol.startLine and endLine are 0-indexed.
      const region = httpFile.httpRegions.find(
        (r) =>
          !r.isGlobal() &&
          r.symbol.startLine + 1 <= luaLine &&
          luaLine <= r.symbol.endLine + 1
      );
      if (!region) {
        respond({
          ok: false,
          error: `No HTTP request found at line ${luaLine}`,
          output: '',
          globals: readGlobals(envArg),
        });
        return;
      }
      success = await send({ ...baseOpts, httpRegion: region });

    } else {
      // No line and not --all: send everything in the file.
      success = await send(baseOpts);
    }

    respond({
      ok: success !== false,
      output: outputParts.join('\n\n---\n\n'),
      globals: readGlobals(envArg),
    });

  } catch (err) {
    respond({
      ok: false,
      error: err.message || String(err),
      output: outputParts.join('\n\n---\n\n'),
      globals: readGlobals(envArg),
    });
  }
}

function handleReset() {
  // Clear all persistent state: cookies, OAuth tokens, $global vars.
  store.userSessionStore.reset();
  // Also discard parsed file cache so fresh environment is loaded next time.
  httpFileStore.clear();
  respond({ ok: true, output: 'Session reset: $global cleared, cookies cleared.', globals: {} });
}

function handleVars(cmd) {
  const envArg = (cmd.env && cmd.env !== '') ? [cmd.env] : undefined;
  const globals = readGlobals(envArg);
  respond({
    ok: true,
    output: JSON.stringify(globals, null, 2),
    globals,
  });
}

// ---------------------------------------------------------------------------
// Stdin reader — serial command queue (one command at a time)
// ---------------------------------------------------------------------------
const rl = readline.createInterface({ input: process.stdin, terminal: false });

let commandQueue = Promise.resolve();

rl.on('line', (rawLine) => {
  const line = rawLine.trim();
  if (!line) return;

  commandQueue = commandQueue
    .then(async () => {
      let cmd;
      try {
        cmd = JSON.parse(line);
      } catch (e) {
        respond({ ok: false, error: 'Invalid JSON: ' + e.message });
        return;
      }

      switch (cmd.type) {
        case 'send':
          await handleSend(cmd);
          break;
        case 'reset':
          handleReset();
          break;
        case 'vars':
          handleVars(cmd);
          break;
        default:
          respond({ ok: false, error: `Unknown command type: ${cmd.type}` });
      }
    })
    .catch((err) => {
      respond({ ok: false, error: 'Internal error: ' + (err.message || String(err)) });
    });
});

rl.on('close', () => {
  process.exit(0);
});
