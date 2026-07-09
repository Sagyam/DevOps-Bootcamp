// Integration test: needs a real Postgres and a real Redis.
// Locally this is skipped unless you export DATABASE_URL and REDIS_URL.
// In CI, the Day 4 workflow provides both via *service containers*.

const { test, before, after } = require("node:test");
const assert = require("node:assert");
const { makeStore } = require("../src/store");

const hasServices = process.env.DATABASE_URL && process.env.REDIS_URL;

// node:test has no top-level skip switch, so we guard each test.
const maybe = hasServices ? test : test.skip;

let store;

before(async () => {
  if (!hasServices) return;
  store = makeStore({
    databaseUrl: process.env.DATABASE_URL,
    redisUrl: process.env.REDIS_URL,
  });
  await store.init();
});

after(async () => {
  if (store) await store.close();
});

maybe("save then resolve round-trips through Postgres", async () => {
  const code = await store.save("https://sagyamthapa.com.np");
  const result = await store.resolve(code);
  assert.strictEqual(result.url, "https://sagyamthapa.com.np");
});

maybe("second resolve is served from the Redis cache", async () => {
  const code = await store.save("https://blog.sagyamthapa.com.np");
  await store.resolve(code); // warms cache
  const second = await store.resolve(code);
  assert.strictEqual(second.source, "cache");
});
