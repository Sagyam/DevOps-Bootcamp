const { test } = require("node:test");
const assert = require("node:assert");
const { shortCode } = require("../src/shorten");

test("same url gives the same code (deterministic)", () => {
  assert.strictEqual(
    shortCode("https://example.com"),
    shortCode("https://example.com")
  );
});

test("different urls give different codes", () => {
  assert.notStrictEqual(
    shortCode("https://a.com"),
    shortCode("https://b.com")
  );
});

test("respects requested length", () => {
  assert.strictEqual(shortCode("https://example.com", 4).length, 4);
});

test("rejects empty input", () => {
  assert.throws(() => shortCode(""), TypeError);
});
