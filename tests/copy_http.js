'use strict';

const assert = require('assert');
const copy = require('./copy_helper');

(async () => {
  const post = await copy([
    '@token = abc\'def',
    '',
    'POST https://example.invalid/items?q=1',
    'Authorization: Bearer {{token}}',
    'Content-Type: application/json',
    '',
    '{"name": "it\'s"}',
    '',
  ].join('\n'), 3);
  assert.deepStrictEqual(post, {
    ok: true,
    name: 'curl',
    output: "curl -L -X 'POST' 'https://example.invalid/items?q=1'"
      + " -H 'Authorization: Bearer abc'\\''def' -H 'Content-Type: application/json'"
      + " --data-raw '{\"name\": \"it'\\''s\"}'",
  });

  const get = await copy('# @noRedirect\n# @noRejectUnauthorized\nGET https://example.invalid/ping\n', 3);
  assert.deepStrictEqual(get, { ok: true, name: 'curl', output: "curl -k 'https://example.invalid/ping'" });

  const plain = await copy('GET https://example.invalid/ping\n', 1);
  assert.strictEqual(plain.output, "curl -L 'https://example.invalid/ping'");
  console.log('copy_http: ok');
})().catch((e) => { console.error(e); process.exit(1); });
