// Full-stack integration test: real HTTP server, real Postgres.
// Skips locally unless DATABASE_URL is set; CI provides it via a service container.

const { test, before, after } = require("node:test");
const assert = require("node:assert");
const { makeDb } = require("../src/db");
const { createServer } = require("../src/server");

const hasDb = !!process.env.DATABASE_URL;
const maybe = hasDb ? test : test.skip;

let db;
let server;
let base;

before(async () => {
  if (!hasDb) return;
  db = makeDb(process.env.DATABASE_URL);
  await db.init();
  server = createServer(db);
  await new Promise((resolve) => server.listen(0, resolve));
  base = `http://localhost:${server.address().port}`;
});

after(async () => {
  if (server) await new Promise((resolve) => server.close(resolve));
  if (db) await db.close();
});

maybe("health check responds ok", async () => {
  const res = await fetch(`${base}/health`);
  assert.strictEqual(res.status, 200);
});

maybe("create then list a task", async () => {
  const create = await fetch(`${base}/tasks`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title: "Ship the capstone" }),
  });
  assert.strictEqual(create.status, 201);

  const list = await fetch(`${base}/tasks`);
  const tasks = await list.json();
  assert.ok(tasks.some((t) => t.title === "Ship the capstone"));
});

maybe("rejects an empty title with 400", async () => {
  const res = await fetch(`${base}/tasks`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title: "" }),
  });
  assert.strictEqual(res.status, 400);
});
