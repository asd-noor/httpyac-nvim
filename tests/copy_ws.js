'use strict';

const assert = require('assert');
const copy = require('./copy_helper');

(async () => {
  const r = await copy([
    '@host = example.invalid',
    'WSS wss://{{host}}/ws',
    "X-Key: abc'def",
    '',
    '{"hello":1}',
    '',
  ].join('\n'), 2);
  assert.strictEqual(r.ok, true, r.error);
  assert.strictEqual(r.name, 'websocat');
  assert.strictEqual(r.output,
    `printf '%s\\n' '{"hello":1}' | websocat -H='X-Key: abc'\\''def' 'wss://example.invalid/ws'`);

  const nb = await copy('WS ws://example.invalid/ws\n', 1);
  assert.strictEqual(nb.ok, true, nb.error);
  assert.strictEqual(nb.output, "websocat 'ws://example.invalid/ws'");
  console.log('copy_ws: ok');
})().catch((e) => { console.error(e); process.exit(1); });
