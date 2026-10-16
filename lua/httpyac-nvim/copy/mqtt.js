'use strict';

const { quote } = require('./shell');

// Header lookup mirrors httpyac: names are case-insensitive, repeated headers arrive as arrays.
const get = (headers, name) => {
  const entry = Object.entries(headers || {}).find(([k]) => k.toLowerCase() === name);
  return entry ? entry[1] : undefined;
};
const list = (headers, name) => [].concat(get(headers, name) ?? []);

// httpyac subscribes to topic+subscribe and, when a body exists, publishes it to topic+publish.
// Everything else is passed to mqtt.js as client options; only those mosquitto can express are mapped.
module.exports = {
  name: 'mosquitto',
  build(request) {
    const h = request.headers || {};
    const url = new URL(request.url);
    const scheme = url.protocol.replace(':', '');
    if (scheme === 'ws' || scheme === 'wss') throw new Error('mosquitto clients do not support MQTT over WebSockets');
    const tls = ['mqtts', 'ssl', 'tls'].includes(scheme);

    const conn = ['-h', quote(url.hostname)];
    if (url.port) conn.push('-p', url.port);
    // ponytail: TLS uses the OS CA store; custom CA/client certs (--cafile/--cert) are not inferable from the request.
    if (tls) conn.push('--tls-use-os-certs');
    const user = get(h, 'username') ?? (url.username && decodeURIComponent(url.username));
    const pass = get(h, 'password') ?? (url.password && decodeURIComponent(url.password));
    if (user) conn.push('-u', quote(user));
    if (pass) conn.push('-P', quote(pass));
    const clientId = get(h, 'clientid');
    if (clientId) conn.push('-i', quote(clientId));
    const keepalive = get(h, 'keepalive');
    if (keepalive !== undefined) conn.push('-k', quote(keepalive));
    const qos = String(get(h, 'qos'));
    if (qos === '1' || qos === '2') conn.push('-q', qos);

    const pubTopics = [...list(h, 'topic'), ...list(h, 'publish')];
    if (request.body && pubTopics.length) {
      const extra = get(h, 'retain') ? ['-r'] : []; // httpyac: any non-empty retain value is truthy
      // mosquitto_pub accepts a single -t, so publish to each topic with its own command.
      return pubTopics
        .map((t) => ['mosquitto_pub', ...conn, '-t', quote(t), '-m', quote(request.body), ...extra].join(' '))
        .join(' && ');
    }

    const subTopics = [...list(h, 'topic'), ...list(h, 'subscribe')];
    if (!subTopics.length) throw new Error('MQTT request has no topic, subscribe or publish header');
    const extra = String(get(h, 'clean')) === 'false' ? ['-c'] : [];
    return ['mosquitto_sub', ...conn, ...subTopics.flatMap((t) => ['-t', quote(t)]), '-v', ...extra].join(' ');
  },
};
