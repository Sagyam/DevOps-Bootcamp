import pg from 'pg';
import { config } from './config.js';
import { logger } from './logger.js';
import { dbPoolSize } from './metrics.js';

export const pool = new pg.Pool({
  host: config.PGHOST,
  port: config.PGPORT,
  database: config.PGDATABASE,
  user: config.PGUSER,
  password: config.PGPASSWORD,
  ssl: config.PGSSLMODE === 'require' ? { rejectUnauthorized: true } : false,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on('error', (err) => {
  logger.error({ err }, 'idle postgres client errored');
});

setInterval(() => {
  dbPoolSize.set({ state: 'total' }, pool.totalCount);
  dbPoolSize.set({ state: 'idle' }, pool.idleCount);
  dbPoolSize.set({ state: 'waiting' }, pool.waitingCount);
}, 5000).unref();

// The only way to run SQL in this codebase. Parameters are always bound,
// never interpolated — this is what closes the injection hole.
export async function query(text, params = []) {
  const start = process.hrtime.bigint();
  try {
    return await pool.query(text, params);
  } finally {
    const ms = Number(process.hrtime.bigint() - start) / 1e6;
    if (ms > 500) logger.warn({ ms, sql: text.slice(0, 120) }, 'slow query');
  }
}

export async function checkHealth() {
  const res = await query('SELECT 1 AS ok');
  return res.rows[0]?.ok === 1;
}

export async function closePool() {
  await pool.end();
}
