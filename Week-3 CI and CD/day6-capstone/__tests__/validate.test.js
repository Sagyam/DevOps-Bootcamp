const { test } = require("node:test");
const assert = require("node:assert");
const { validateTitle } = require("../src/validate");

test("accepts a normal title", () => {
  assert.strictEqual(validateTitle("Write the pipeline"), null);
});

test("rejects empty / whitespace", () => {
  assert.strictEqual(validateTitle("   "), "title must not be empty");
});

test("rejects non-strings", () => {
  assert.strictEqual(validateTitle(null), "title must be a string");
});

test("rejects overly long titles", () => {
  assert.strictEqual(
    validateTitle("x".repeat(201)),
    "title must be 200 characters or fewer"
  );
});
