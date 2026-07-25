/**
 * ---------------------------------------------------------------------------
 * tracing.ts  --  OpenTelemetry setup. Runs BEFORE anything else.
 * ---------------------------------------------------------------------------
 *
 * WHY A TRACE
 *
 * Day 2's dashboard can tell you that GET /teas/:id/pairings has a p95 of
 * 900ms. It cannot tell you whether that is the database, a slow loop, or a
 * call to another service. A metric is one number per request; you cannot
 * decompose it after the fact.
 *
 * A trace is the inside of one request: a tree of timed operations, each with
 * a parent, each with attributes. It answers "where did the 900ms go".
 *
 * VOCABULARY, and it is small:
 *   span    one timed operation with a name, a start, an end, attributes
 *   trace   all the spans sharing one trace id, forming a tree
 *   context the current trace id + span id, passed down implicitly
 *
 * ---------------------------------------------------------------------------
 * WHY THIS FILE LOADS FIRST
 *
 * Automatic instrumentation works by monkey-patching libraries -- it replaces
 * http.request, Express's router, Prisma's query path. It can only patch a
 * module it gets hold of BEFORE your code requires it.
 *
 * So this file must run before main.ts. Look at the Dockerfile:
 *
 *     CMD ["node", "-r", "./dist/tracing.js", "dist/main.js"]
 *
 * `-r` preloads a module before the main script. If you instead put
 * `import './tracing'` at the top of main.ts it usually works, but "usually"
 * depends on import hoisting rules you do not want to be relying on at 2am.
 * Be explicit.
 */

import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { ParentBasedSampler, TraceIdRatioBasedSampler } from '@opentelemetry/sdk-trace-node';
import { resourceFromAttributes } from '@opentelemetry/resources';
import {
  ATTR_SERVICE_NAME,
  ATTR_SERVICE_VERSION,
} from '@opentelemetry/semantic-conventions';
import { PrismaInstrumentation } from '@prisma/instrumentation';
import { ExpressLayerType } from '@opentelemetry/instrumentation-express';

/**
 * ---------------------------------------------------------------------------
 * SAMPLING -- today's big idea.
 * ---------------------------------------------------------------------------
 *
 * A trace is not one record. A single request through this service produces
 * roughly 10-20 spans, each with a name, timestamps and attributes. Call it
 * 5 KB. At 1,000 requests per second that is 5 MB/s, ~430 GB/day, from one
 * service. Traces are the most expensive telemetry you will ever collect, per
 * unit of insight.
 *
 * So you keep a fraction. TRACE_SAMPLE_RATIO=0.1 means "keep 10%".
 *
 * The decision is made ONCE, at the start of the trace, and is derived from
 * the trace id itself -- not from a coin flip. That matters: every service in
 * a distributed system computes the same answer for the same trace id, so you
 * never end up with half a trace.
 *
 * ParentBasedSampler wraps that rule with: "if someone upstream already
 * decided, honour their decision." Otherwise service A samples 10%, service B
 * samples 10% independently, and only 1% of traces are complete end to end.
 *
 * WHAT YOU LOSE: sampling is random, so the slow request a customer is
 * complaining about is probably not in your 10%. The production answer to that
 * is TAIL sampling -- buffer whole traces in a collector, decide AFTER seeing
 * how they ended, and keep 100% of errors and slow ones plus a few percent of
 * the boring ones. That needs a collector doing the buffering, which is beyond
 * today, but it is what you should reach for in a real system.
 *
 * We default to 1.0 (keep everything) because an empty Jaeger teaches nothing.
 * Exercise 4.3 has you turn it down and feel the trade.
 */
const SAMPLE_RATIO = Number(process.env.TRACE_SAMPLE_RATIO ?? 1.0);

const sdk = new NodeSDK({
  /**
   * The RESOURCE is "who am I". Every span this process emits carries these
   * attributes, and service.name is what groups spans in Jaeger's UI.
   *
   * Contrast with Day 2: Prometheus PULLED, so the scraper knew who we were
   * and added the labels. Traces PUSH, so we must declare our own identity.
   * Get service.name wrong and every service in Jaeger is called
   * "unknown_service".
   */
  resource: resourceFromAttributes({
    [ATTR_SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'chiya-api',
    [ATTR_SERVICE_VERSION]: '1.0.0',
    // Not a semantic convention, just useful: tells the two replicas apart.
    'service.instance.id': process.env.HOSTNAME || 'unknown',
  }),

  /**
   * Where spans go. OTLP over HTTP, straight to Jaeger, which speaks OTLP
   * natively on port 4318.
   *
   * The SDK wraps this in a BatchSpanProcessor: spans are buffered and flushed
   * in batches rather than one HTTP request per span. Without batching, adding
   * tracing would roughly double your outbound request count.
   */
  traceExporter: new OTLPTraceExporter({
    url:
      process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT ||
      'http://jaeger:4318/v1/traces',
  }),

  sampler: new ParentBasedSampler({
    root: new TraceIdRatioBasedSampler(SAMPLE_RATIO),
  }),

  instrumentations: [
    /**
     * ONE LINE, and you get a full request tree without touching a controller:
     * http, express and nestjs-core are all patched automatically.
     *
     * But read the block below carefully, because CURATING auto-instrumentation
     * is a real job. Left at its defaults this produces about 21 spans per
     * request to /teas/:id/pairings, of which roughly 12 are Express internals
     * named "middleware - <anonymous>". They are not wrong, they are just
     * noise, and noise in a trace is expensive twice over: you pay to store it,
     * and you pay again in the seconds it takes a human to find the real span.
     *
     * Turn things off until a trace reads like a story.
     */
    getNodeAutoInstrumentations({
      // Instruments every file read. Enormous span volume, near-zero value.
      // This is the first thing everyone turns off.
      '@opentelemetry/instrumentation-fs': { enabled: false },

      // Off DELIBERATELY, even though it does something we want.
      //
      // This instrumentation would silently inject trace_id into every pino
      // log line. That is convenient and it is also a black box. We do it by
      // hand in logger.ts instead, so you can see the mechanism. In your own
      // projects, turn this on and delete that code.
      '@opentelemetry/instrumentation-pino': { enabled: false },

      // Duplicates what instrumentation-express already reports, with worse
      // names ("middleware - patched"). Pure noise here.
      '@opentelemetry/instrumentation-router': { enabled: false },

      // TCP connect and DNS lookup spans. Occasionally the answer to a
      // mystery, usually just clutter. Turn them on when you suspect the
      // network, not before.
      '@opentelemetry/instrumentation-net': { enabled: false },
      '@opentelemetry/instrumentation-dns': { enabled: false },

      // Keep Express, but drop the per-middleware spans. We still get the
      // request-handler span, which is the one that carries the route.
      //
      // Comment this out and restart to see what the raw firehose looks like.
      // It is worth doing once.
      '@opentelemetry/instrumentation-express': {
        ignoreLayersType: [ExpressLayerType.MIDDLEWARE],
      },
    }),

    // Prisma ships its own instrumentation. Without it you would see one
    // opaque span covering "the database call" and nothing about which query.
    // With it you get a span per operation and per engine query -- which is
    // how the N+1 problem in shop.service.ts becomes visible rather than
    // theoretical.
    new PrismaInstrumentation(),
  ],
});

sdk.start();

/**
 * Spans sit in a buffer until the batch processor flushes. Killing the process
 * without flushing loses them -- which is exactly when you most want the trace,
 * because the process was shutting down. Flush on the way out.
 */
for (const signal of ['SIGTERM', 'SIGINT'] as const) {
  process.on(signal, () => {
    sdk
      .shutdown()
      .catch(() => undefined)
      .finally(() => process.exit(0));
  });
}
