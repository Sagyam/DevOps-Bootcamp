// Prometheus metrics. Four golden signals: traffic, errors, latency, saturation.
import client from 'prom-client';

export const registry = new client.Registry();
client.collectDefaultMetrics({ register: registry, prefix: 'tiffin_' });

export const httpRequestDuration = new client.Histogram({
  name: 'tiffin_http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status_code'],
  // Buckets chosen around the 200ms SLO target, not the library default.
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.2, 0.5, 1, 2, 5],
  registers: [registry],
});

export const ordersCreated = new client.Counter({
  name: 'tiffin_orders_created_total',
  help: 'Total orders successfully created',
  labelNames: ['item_id'],
  registers: [registry],
});

export const dbPoolSize = new client.Gauge({
  name: 'tiffin_db_pool_connections',
  help: 'Postgres pool connections by state',
  labelNames: ['state'],
  registers: [registry],
});

// Express middleware. Uses req.route.path, not req.url, so /orders/123 and
// /orders/456 do not create two million distinct label values.
export function metricsMiddleware(req, res, next) {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    const route = req.route?.path ?? 'unmatched';
    end({ method: req.method, route, status_code: res.statusCode });
  });
  next();
}
