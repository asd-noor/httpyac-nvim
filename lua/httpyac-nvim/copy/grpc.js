'use strict';

const { quote } = require('./shell');

// httpyac picks TLS only from the ChannelCredentials header ("ssl"); the default
// is insecure, and the url scheme does not matter. Proto files live in
// context.options.protoDefinitions, which build() does not receive, so the
// command relies on server reflection (add -import-path/-proto by hand if needed).
module.exports = {
  name: 'grpcurl',
  build(request) {
    const url = String(request.url).trim().replace(/^(grpc|https?):\/\//i, '');
    const m = /^([^/]+?)(?:\/.+)?\/([^/]+?\/[^/]+?)$/.exec(url);
    if (!m) throw new Error(`Cannot parse gRPC url: ${request.url}`);
    let tls = false;
    const parts = ['grpcurl'];
    const headers = [];
    for (const [key, value] of Object.entries(request.headers || {})) {
      if (key.toLowerCase() === 'channelcredentials') {
        tls = String(value).toLowerCase() === 'ssl';
        continue;
      }
      for (const v of [].concat(value)) headers.push('-H', quote(`${key}: ${v}`));
    }
    if (!tls) parts.push('-plaintext');
    parts.push(...headers);
    if (request.body) parts.push('-d', quote(request.body));
    parts.push(quote(m[1]), quote(m[2]));
    return parts.join(' ');
  },
};
