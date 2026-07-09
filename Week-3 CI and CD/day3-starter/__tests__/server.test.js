// Uses Node's built-in test runner (node:test) — no dependencies at all.
// Run with:  node --test
const { test } = require("node:test");
const assert = require("node:assert");
const { slugify } = require("../src/server");

test("health-style slug basics", () => {
  assert.strictEqual(slugify("Hello Docker"), "hello-docker");
});

test("strips punctuation", () => {
  assert.strictEqual(slugify("Ship it, now!"), "ship-it-now");
});

test("handles empty input", () => {
  assert.strictEqual(slugify(""), "");
});
