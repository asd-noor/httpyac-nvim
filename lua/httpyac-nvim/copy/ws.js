'use strict';

const { quote } = require('./shell');

module.exports = {
  name: 'websocat',
  build(request) {
    // -H= form: websocat's bare `-H` can swallow following args (incl. the URL).
    const headers = Object.entries(request.headers || {})
      .map(([k, v]) => ' -H=' + quote(`${k}: ${v}`)).join('');
    const cmd = 'websocat' + headers + ' ' + quote(request.url);
    // ponytail: whole body sent as one message; httpyac multi-message bodies not split.
    return request.body ? `printf '%s\\n' ${quote(request.body)} | ${cmd}` : cmd;
  },
};
