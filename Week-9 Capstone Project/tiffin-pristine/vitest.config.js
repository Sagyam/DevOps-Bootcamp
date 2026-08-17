import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    globals: true,
    env: {
      NODE_ENV: 'test',
      PGHOST: process.env.PGHOST || 'localhost',
      PGPORT: process.env.PGPORT || '5432',
      PGDATABASE: process.env.PGDATABASE || 'tiffin',
      PGUSER: process.env.PGUSER || 'tiffin',
      PGPASSWORD: process.env.PGPASSWORD || 'tiffin',
    },
    // Integration tests talk to a real Postgres from docker-compose, so they
    // get a longer timeout and run in a single fork to avoid schema races.
    testTimeout: 15000,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      include: ['src/**/*.js'],
      exclude: ['src/tracing.js', 'src/server.js'],
      // CI fails below these numbers. Start low, ratchet up over time.
      thresholds: {
        lines: 70,
        functions: 70,
        branches: 60,
        statements: 70,
      },
    },
  },
});
