'use strict';

// Usage: const copy = require('./copy_helper'); const r = await copy(httpText, line);
// Writes httpText to a temp .http file and sends one "copy" command to the sidecar.
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

module.exports = (httpText, line) => new Promise((resolve, reject) => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'httpyac-copy-'));
  const file = path.join(dir, 'request.http');
  fs.writeFileSync(file, httpText);
  const server = spawn('node', [path.join(__dirname, '..', 'lua', 'httpyac-nvim', 'session-server.js')]);
  let out = '';
  server.stdout.on('data', (d) => {
    out += d;
    if (out.includes('\n')) {
      server.kill();
      fs.rmSync(dir, { recursive: true, force: true });
      resolve(JSON.parse(out.split('\n')[0]));
    }
  });
  server.on('error', reject);
  server.stdin.write(JSON.stringify({ type: 'copy', file, line }) + '\n');
});
