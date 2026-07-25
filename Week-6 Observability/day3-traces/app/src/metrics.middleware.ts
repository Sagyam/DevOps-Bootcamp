/**
 * ---------------------------------------------------------------------------
 * metrics.middleware.ts  --  turn every request into two numbers.
 * ---------------------------------------------------------------------------
 *
 * Compare this with request-logger.middleware.ts. They fire at the same moment
 * on the same event and record the same facts. The difference is what happens
 * to those facts:
 *
 *   the logger    writes one line per request, kept individually
 *   this file     adds 1 to a counter and drops the request in a bucket
 *
 * After a million requests the log is a million lines. The metrics are still
 * about forty numbers.
 */

import { Injectable, NestMiddleware } from '@nestjs/common';
import type { Request, Response, NextFunction } from 'express';
import { httpRequestsTotal, httpRequestDuration } from './metrics';

@Injectable()
export class MetricsMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    // Do not measure the scrape endpoint. It would add a data point every
    // 5 seconds forever and tell you nothing about your users.
    if (req.path === '/metrics') return next();

    const startedAt = process.hrtime.bigint();

    res.on('finish', () => {
      const seconds = Number(process.hrtime.bigint() - startedAt) / 1e9;

      // ---------------------------------------------------------------
      // THE LINE THAT PROTECTS PROMETHEUS.
      //
      // req.route.path is the PATTERN: "/teas/:id". req.originalUrl is the
      // actual URL: "/teas/4127". Using originalUrl here would create a new
      // time series for every tea id ever requested.
      //
      // The fallback matters too. A request to a URL with no matching route
      // has no req.route, and using the raw path there would let anyone create
      // unlimited series just by hitting random URLs -- a real denial of
      // service against your own monitoring. So unmatched requests all
      // collapse into one bucket.
      // ---------------------------------------------------------------
      const route = (req as any).route?.path ?? 'unmatched';

      const labels = {
        method: req.method,
        route,
        status: String(res.statusCode),
      };

      httpRequestsTotal.inc(labels);
      httpRequestDuration.observe(labels, seconds);
    });

    next();
  }
}
