// The part that needs real infrastructure: persist a short link in Postgres,
// cache lookups in Redis. Integration tests point these at service containers
// spun up by the Day 4 workflow.

const { Pool } = require("pg");
const { createClient } = require("redis");
const { shortCode } = require("./shorten");

function makeStore({ databaseUrl, redisUrl }) {
  const pool = new Pool({ connectionString: databaseUrl });
  const redis = createClient({ url: redisUrl });

  async function init() {
    await redis.connect();
    await pool.query(`
      CREATE TABLE IF NOT EXISTS links (
        code TEXT PRIMARY KEY,
        url  TEXT NOT NULL
      )
    `);
  }

  async function save(url) {
    const code = shortCode(url);
    await pool.query(
      "INSERT INTO links (code, url) VALUES ($1, $2) ON CONFLICT (code) DO NOTHING",
      [code, url]
    );
    await redis.set(`link:${code}`, url);
    return code;
  }

  async function resolve(code) {
    const cached = await redis.get(`link:${code}`);
    if (cached) return { url: cached, source: "cache" };

    const { rows } = await pool.query("SELECT url FROM links WHERE code = $1", [code]);
    if (rows.length === 0) return null;

    await redis.set(`link:${code}`, rows[0].url);
    return { url: rows[0].url, source: "db" };
  }

  async function close() {
    await redis.quit();
    await pool.end();
  }

  return { init, save, resolve, close };
}

module.exports = { makeStore };
