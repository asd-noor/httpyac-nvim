'use strict';

const assert = require('assert');
const copy = require('./copy_helper');

const check = async (text, name, output) => {
  const r = await copy(text, 1);
  assert.deepStrictEqual(r, { ok: true, name, output });
};

(async () => {
  await check(
    '@topic = my/topic\nMQTT mqtt://example.invalid:1883\nTopic: {{topic}}\nQoS: 1\nretain: true\nUsername: u\nPassword: it\'s\n\n{"on":true}\n',
    'mosquitto',
    "mosquitto_pub -h 'example.invalid' -p 1883 -u 'u' -P 'it'\\''s' -q 1 -t 'my/topic' -m '{\"on\":true}' -r"
  );
  await check(
    'MQTT mqtts://example.invalid\nsubscribe: a/#\nsubscribe: b/+\nclientId: me\nclean: false\n',
    'mosquitto',
    "mosquitto_sub -h 'example.invalid' --tls-use-os-certs -i 'me' -t 'a/#' -t 'b/+' -v -c"
  );
  const ws = await copy('MQTT ws://example.invalid/mqtt\ntopic: t\n', 1);
  assert.strictEqual(ws.ok, false);
  console.log('copy_mqtt: ok');
})().catch((e) => { console.error(e); process.exit(1); });
