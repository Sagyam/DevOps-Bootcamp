/**
 * ---------------------------------------------------------------------------
 * request-logger.middleware.ts  --  one line in, one line out.
 * ---------------------------------------------------------------------------
 *
 * This is the single most valuable log in most services. It runs for every
 * request and records: what was asked for, what came back, and how long it
 * took. Almost every "is the site slow?" conversation starts here.
 *
 * Two details worth pausing on:
 *
 * REQUEST ID -- nginx generates `$request_id` and forwards it as the
 * X-Request-Id header. We reuse it rather than making our own, so the nginx
 * access log line and the twelve application log lines all carry the same id.
 * That is what makes "show me everything about this one slow request"
 * possible. If the header is missing (someone hit the API directly) we mint
 * one so the field is never empty.
 *
 * LEVEL FROM STATUS -- the level is derived, not hardcoded. A 200 is info,
 * a 404 is a warn (the caller did something wrong), a 500 is an error (we did
 * something wrong). This is what lets a dashboard count errors without
 * parsing English.
 */

import { Injectable, NestMiddleware } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { Request, Response, NextFunction } from 'express';
import { rootLogger, requestContext, log } from './logger';

@Injectable()
export class RequestLoggerMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    const requestId = (req.headers['x-request-id'] as string) || randomUUID();

    // hrtime.bigint() is a monotonic clock in nanoseconds. Date.now() can jump
    // backwards when NTP corrects the system clock, which produces negative
    // durations and a very confusing afternoon.
    const startedAt = process.hrtime.bigint();

    const store = { requestId, logger: rootLogger.child({ requestId }) };

    // Everything inside this callback -- including the 'finish' handler we
    // register below, because it is created here -- can see `store`.
    requestContext.run(store, () => {
      log().debug({ method: req.method, path: req.originalUrl }, 'request received');

      res.on('finish', () => {
        const durationMs = Number(process.hrtime.bigint() - startedAt) / 1_000_000;
        const level = res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info';

        log()[level](
          {
            method: req.method,
            path: req.originalUrl,
            // req.route.path is the *pattern* ("/teas/:id"), not the actual
            // URL. On Day 2 you will see why that distinction matters: using
            // the raw URL as a metric label would create one time series per
            // tea id and melt Prometheus.
            route: (req as any).route?.path ?? 'unmatched',
            status: res.statusCode,
            durationMs: Number(durationMs.toFixed(2)),
            userAgent: req.headers['user-agent'],
          },
          'request completed',
        );
      });

      next();
    });
  }
}
