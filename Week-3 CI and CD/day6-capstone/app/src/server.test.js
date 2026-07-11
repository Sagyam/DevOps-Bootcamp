const { test } = require("node:test");
const assert = require("node:assert");
const { render } = require("./server");

test("/health returns ok", () => {
  const { status, body } = render("/health");
  assert.strictEqual(status, 200);
  assert.strictEqual(body.status, "ok");
});

test("root returns a greeting with a version", () => {
  const { body } = render("/");
  assert.match(body.message, /Express Mode/);
  assert.ok("version" in body);
});
