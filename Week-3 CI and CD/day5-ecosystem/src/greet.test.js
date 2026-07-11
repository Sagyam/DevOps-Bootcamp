const { test } = require("node:test");
const assert = require("node:assert");
const { greet } = require("./greet");

test("greets by name", () => {
  assert.strictEqual(greet("Sagyam"), "Hello, Sagyam!");
});

test("rejects an empty name", () => {
  assert.throws(() => greet(""), /name is required/);
});
