// Pure logic: deterministically turn a URL into a short code.
// No database, no network — so it can be unit-tested anywhere, instantly.
// The Postgres/Redis parts live in store.js and are exercised by the
// integration tests, which need service containers.

const crypto = require("crypto");

function shortCode(url, length = 7) {
  if (typeof url !== "string" || url.length === 0) {
    throw new TypeError("shortCode expects a non-empty string");
  }
  const hash = crypto.createHash("sha256").update(url).digest("base64url");
  return hash.slice(0, length);
}

module.exports = { shortCode };
