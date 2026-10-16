'use strict';

const assert = require('assert');
const copy = require('./copy_helper');

(async () => {
  const r = await copy('FOO example.invalid\n', 1);
  assert.strictEqual(r.ok, false);
  const none = await copy('# only a comment\n', 1);
  assert.strictEqual(none.ok, false);
  console.log('copy: ok');
})().catch((e) => { console.error(e); process.exit(1); });
