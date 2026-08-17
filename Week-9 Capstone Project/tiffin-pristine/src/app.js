import path from 'node:path';
import { fileURLToPath } from 'node:url';
import express from 'express';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { httpLogger } from './logger.js';
import { registry, metricsMiddleware } from './metrics.js';
import { healthRouter } from './routes/health.js';
import { menuRouter } from './routes/menu.js';
import { ordersRouter } from './routes/orders.js';
import { config } from './config.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Exported separately from server.js so tests can mount the app without
// binding a port or starting the OTel SDK.
export function createApp() {
  const app = express();

  app.disable('x-powered-by');
  app.set('trust proxy', 1); // behind the ingress; needed for correct client IPs

  app.use(
    helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'", 'https://fonts.googleapis.com'],
          fontSrc: ["'self'", 'https://fonts.gstatic.com', 'data:'],
          imgSrc: ["'self'", 'data:', 'https:'],
          connectSrc: ["'self'"],
        },
      },
    }),
  );
  app.use(express.static(path.join(__dirname, 'public')));
  app.use(express.json({ limit: '32kb' })); // body size cap
  app.use(httpLogger);
  app.use(metricsMiddleware);

  // No wildcard CORS. An explicit allowlist, and no credentials.
  const allowedOrigins = new Set(['https://tiffin.example.np']);
  app.use((req, res, next) => {
    const origin = req.headers.origin;
    if (origin && allowedOrigins.has(origin)) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Vary', 'Origin');
    }
    next();
  });

  app.use(
    rateLimit({
      windowMs: 60_000,
      limit: 100,
      standardHeaders: 'draft-7',
      legacyHeaders: false,
      // Probes and scrapes should never be rate limited.
      skip: (req) => ['/healthz', '/readyz', '/metrics'].includes(req.path),
    }),
  );

  app.use(healthRouter);
  app.use(menuRouter);
  app.use(ordersRouter);

  app.get('/metrics', async (_req, res) => {
    res.set('Content-Type', registry.contentType);
    res.end(await registry.metrics());
  });

  app.use((_req, res) => res.status(404).json({ error: 'not_found' }));

  // Central error handler. Stack traces go to logs, never to the client.
  app.use((err, req, res, _next) => {
    req.log.error({ err }, 'unhandled error');
    res.status(500).json({
      error: 'internal_error',
      request_id: req.id,
      ...(config.NODE_ENV === 'development' ? { detail: err.message } : {}),
    });
  });

  return app;
}
