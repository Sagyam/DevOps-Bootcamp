// Minimal forward-only migration runner. Records what it has applied so
// re-running is safe. Real projects use node-pg-migrate or Flyway; this is
// small enough to read in one sitting.
import { readdir, readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { query, closePool } from '../src/db.js';
import { logger } from '../src/logger.js';

const dir = join(dirname(fileURLToPath(import.meta.url)), 'migrations');

await query(`CREATE TABLE IF NOT EXISTS schema_migrations (
  filename TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
)`);

const applied = new Set(
  (await query('SELECT filename FROM schema_migrations')).rows.map((r) => r.filename),
);

for (const file of (await readdir(dir)).filter((f) => f.endsWith('.sql')).sort()) {
  if (applied.has(file)) continue;
  logger.info({ file }, 'applying migration');
  const sql = await readFile(join(dir, file), 'utf8');
  await query('BEGIN');
  try {
    await query(sql);
    await query('INSERT INTO schema_migrations (filename) VALUES ($1)', [file]);
    await query('COMMIT');
  } catch (err) {
    await query('ROLLBACK');
    logger.fatal({ err, file }, 'migration failed, rolled back');
    throw err;
  }
}

await closePool();
logger.info('migrations up to date');
