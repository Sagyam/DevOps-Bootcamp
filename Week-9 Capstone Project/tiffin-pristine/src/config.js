// Single place where environment variables are read and validated.
// The process refuses to start with bad config rather than failing at 3am.
import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),
  PGHOST: z.string().min(1),
  PGPORT: z.coerce.number().int().default(5432),
  PGDATABASE: z.string().min(1),
  PGUSER: z.string().min(1),
  PGPASSWORD: z.string().min(1),
  PGSSLMODE: z.enum(['disable', 'require']).default('disable'),
  SHUTDOWN_TIMEOUT_MS: z.coerce.number().int().default(10000),
});

const parsed = schema.safeParse(process.env);

if (!parsed.success) {
  // Cannot use the logger here — it depends on config.
  process.stderr.write(
    'Invalid configuration:\n' +
      JSON.stringify(parsed.error.flatten().fieldErrors, null, 2) +
      '\n',
  );
  throw new Error('Invalid configuration');
}

export const config = Object.freeze(parsed.data);
