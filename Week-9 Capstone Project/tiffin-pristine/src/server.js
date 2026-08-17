// Tracing must be imported first so instrumentation can patch modules.
import './tracing.js';
import { createApp } from './app.js';
import { config } from './config.js';
import { logger } from './logger.js';
import { closePool } from './db.js';

const app = createApp();
const server = app.listen(config.PORT, () => {
  logger.info({ port: config.PORT }, 'tiffin-api listening');
});

// Graceful shutdown. Kubernetes sends SIGTERM, then waits, then SIGKILLs.
// Draining in-flight requests here is what makes rolling updates zero-downtime.
let shuttingDown = false;
function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  logger.info({ signal }, 'shutting down');

  const force = setTimeout(() => {
    logger.error('graceful shutdown timed out, forcing exit');
    process.exit(1);
  }, config.SHUTDOWN_TIMEOUT_MS);
  force.unref();

  server.close(async () => {
    try {
      await closePool();
      logger.info('shutdown complete');
      process.exit(0);
    } catch (err) {
      logger.error({ err }, 'error during shutdown');
      process.exit(1);
    }
  });
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('unhandledRejection', (reason) => {
  logger.fatal({ reason }, 'unhandled promise rejection');
  shutdown('unhandledRejection');
});
