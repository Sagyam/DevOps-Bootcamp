/**
 * GET /metrics -- the scrape endpoint.
 *
 * Prometheus polls this every 5 seconds (see prometheus/prometheus.yml) and
 * parses the plain-text response. Open http://localhost:8080/metrics in a
 * browser and read it: it is deliberately human-readable, and reading it once
 * demystifies the entire protocol.
 *
 * Format, one metric at a time:
 *
 *   # HELP chiya_http_requests_total Total HTTP requests handled...
 *   # TYPE chiya_http_requests_total counter
 *   chiya_http_requests_total{method="GET",route="/teas",status="200"} 4821
 *
 * That is all Prometheus is: a program that fetches this text on a timer and
 * remembers it with a timestamp.
 *
 * @ApiExcludeEndpoint keeps it off the Swagger page -- it is not part of the
 * product's API surface.
 */
import { Controller, Get, Header } from '@nestjs/common';
import { ApiExcludeEndpoint } from '@nestjs/swagger';
import { registry } from './metrics';

@Controller()
export class MetricsController {
  @Get('metrics')
  @ApiExcludeEndpoint()
  @Header('Content-Type', registry.contentType)
  metrics() {
    return registry.metrics();
  }
}
