import { Router } from 'express';
import { checkHealth } from '../db.js';
import { logger } from '../logger.js';

export const healthRouter = Router();

// Liveness: is the process wedged? Must NOT check dependencies, or a database
// blip will make Kubernetes kill every healthy pod at once.
healthRouter.get('/healthz', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Readiness: can this pod serve traffic right now? This one does check the DB,
// so a pod with a dead connection pool is pulled from the Service endpoints.
healthRouter.get('/readyz', async (_req, res) => {
  try {
    await checkHealth();
    res.status(200).json({ status: 'ready' });
  } catch (err) {
    logger.warn({ err }, 'readiness check failed');
    res.status(503).json({ status: 'not_ready' });
  }
});
