// Structured JSON logs. One object per line, machine-parseable by Loki.
// Redaction is not optional: customer phone numbers are PII.
import pino from 'pino';
import pinoHttp from 'pino-http';
import { randomUUID } from 'node:crypto';
import { config } from './config.js';

export const logger = pino({
  level: config.LOG_LEVEL,
  base: { service: 'tiffin-api', env: config.NODE_ENV },
  redact: {
    paths: [
      'req.headers.authorization',
      'req.headers.cookie',
      'req.body.customer_phone',
      'customer_phone',
      '*.password',
      '*.token',
    ],
    censor: '[REDACTED]',
  },
  timestamp: pino.stdTimeFunctions.isoTime,
});

export const httpLogger = pinoHttp({
  logger,
  // Correlation ID: honour an inbound one, otherwise mint one. Every log line
  // for a request carries it, which is what makes Loki useful.
  genReqId: (req, res) => {
    const existing = req.headers['x-request-id'];
    const id = existing || randomUUID();
    res.setHeader('x-request-id', id);
    return id;
  },
  customLogLevel: (_req, res, err) => {
    if (err || res.statusCode >= 500) return 'error';
    if (res.statusCode >= 400) return 'warn';
    return 'info';
  },
  // Health probes would otherwise drown the logs.
  autoLogging: {
    ignore: (req) => req.url === '/healthz' || req.url === '/readyz',
  },
});
