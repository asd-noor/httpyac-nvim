'use strict';

const { quote } = require('./shell');

module.exports = {
  name: 'curl',
  build(request) {
    const parts = ['curl'];
    if (!request.noRedirect) parts.push('-L');
    if (request.noRejectUnauthorized) parts.push('-k');
    if (request.method !== 'GET' || request.body !== undefined) parts.push('-X', quote(request.method));
    parts.push(quote(request.url));
    for (const [key, value] of Object.entries(request.headers || {})) {
      for (const v of [].concat(value)) parts.push('-H', quote(`${key}: ${v}`));
    }
    if (request.body !== undefined) parts.push('--data-raw', quote(request.body));
    return parts.join(' ');
  },
};
