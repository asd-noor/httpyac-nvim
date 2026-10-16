'use strict';

const assert = require('assert');
const copy = require('./copy_helper');

(async () => {
  const http = [
    '@host = example.invalid:50051',
    '',
    'GRPC grpc://{{host}}/pkg.Svc/Method',
    'Authorization: Bearer it\'s',
    '',
    '{"a":1}',
    '',
  ].join('\n');
  const start = Date.now();
  const r = await copy(http, 3);
  assert.deepStrictEqual(r, {
    ok: true,
    name: 'grpcurl',
    output: "grpcurl -plaintext -H 'Authorization: Bearer it'\\''s' -d '{\"a\":1}' 'example.invalid:50051' 'pkg.Svc/Method'",
  });
  assert.ok(Date.now() - start < 5000, 'copy must not connect');

  const tls = await copy('GRPC example.invalid:443/pkg.Svc/Method\nChannelCredentials: ssl\n', 1);
  assert.strictEqual(tls.output, "grpcurl 'example.invalid:443' 'pkg.Svc/Method'");
  console.log('copy_grpc: ok');
})().catch((e) => { console.error(e); process.exit(1); });
