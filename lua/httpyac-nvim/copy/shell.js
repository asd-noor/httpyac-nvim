'use strict';

/** Quote a value for POSIX shells: wrap in '' and escape embedded quotes. */
exports.quote = (value) => "'" + String(value).replace(/'/g, "'\\''") + "'";
