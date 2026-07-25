/**
 * ---------------------------------------------------------------------------
 * metrics.ts  --  every number this service publishes.
 * ---------------------------------------------------------------------------
 *
 * WHY THIS FILE EXISTS AT ALL
 *
 * Yesterday you drew a p95 latency chart out of nginx logs. It worked. It also
 * required Loki to read and parse every log line in the window. Try that over
 * 30 days across 200 services and you are running a small data warehouse to
 * answer "is the site slow".
 *
 * A metric throws away the individual events and keeps only the aggregate. One
 * counter is a single number in memory, regardless of whether it counted ten
 * requests or ten billion. That is the trade you are making today:
 *
 *   logs    -> every detail, one event at a time, expensive at scale
 *   metrics -> no detail, all events at once, nearly free at any scale
 *
 * You need both. Metrics tell you SOMETHING is wrong and how bad. Logs tell
 * you WHICH request. Tomorrow, traces tell you WHERE in the code.
 *
 * ---------------------------------------------------------------------------
 * PUSH VS PULL
 *
 * Nothing here sends anything anywhere. We keep numbers in memory and expose
 * them on GET /metrics as text. Prometheus comes and asks, every 5 seconds.
 *
 * That is "pull", and it has a property worth noticing: because the scraper
 * initiated the connection, IT knows who you are. So we do NOT stamp
 * service/instance labels on our own metrics -- Prometheus adds `job` and
 * `instance` itself. If we set them too, Prometheus would rename ours to
 * `exported_instance` and you would spend twenty minutes confused.
 *
 * (Tomorrow's traces work the opposite way: the app pushes to a collector, so
 * the app must declare its own identity. Watch for that contrast.)
 */

import client from 'prom-client';

/**
 * A registry is a bag of metrics. One is plenty; the reason to have your own
 * rather than using the global default is that it keeps library metrics and
 * your metrics separable if you ever need that.
 */
export const registry = new client.Registry();

/**
 * Free Node.js runtime metrics: heap, garbage collection, event loop lag,
 * open handles, process CPU. About 30 series, and they answer a startling
 * number of "why is it slow" questions before you write any custom metric.
 */
client.collectDefaultMetrics({ register: registry });

/**
 * ---------------------------------------------------------------------------
 * THE FOUR METRIC TYPES, one example of each.
 * ---------------------------------------------------------------------------
 */

/**
 * COUNTER -- only goes up, resets to zero when the process restarts.
 *
 * You almost never look at a counter's value. You look at rate(): "how fast is
 * this going up". rate() understands restarts and handles the reset for you,
 * which is exactly why counters are not allowed to go down.
 *
 * NAMING: <namespace>_<thing>_<unit>, and counters end in _total. This is a
 * Prometheus convention and following it makes your metrics legible to anyone
 * who has seen Prometheus before.
 */
export const httpRequestsTotal = new client.Counter({
  name: 'chiya_http_requests_total',
  help: 'Total HTTP requests handled, by method, route and status code',
  // ---------------------------------------------------------------------
  // CARDINALITY. The most important idea on this page.
  //
  // Prometheus stores one time series per unique combination of label values.
  // Here: ~4 methods x ~6 routes x ~6 statuses = a bounded, small number.
  //
  // Now imagine we used the raw URL instead of the route pattern. /teas/1,
  // /teas/2, /teas/3... one series per tea id, forever, and they never expire
  // because Prometheus keeps them for the retention period. That is how people
  // take down their own monitoring.
  //
  // Rule: a label value must come from a small, FIXED set that you can list.
  // If you cannot list it, it is a log field, not a label.
  // ---------------------------------------------------------------------
  labelNames: ['method', 'route', 'status'],
  registers: [registry],
});

/**
 * HISTOGRAM -- counts observations into buckets.
 *
 * This is how you get percentiles. It does NOT store your durations; it stores
 * "how many were under 5ms, how many under 10ms, ..." and percentiles are
 * interpolated from those counts at query time.
 *
 * Consequence worth internalising: your percentiles are only as precise as
 * your bucket edges. If everything lands between 50ms and 100ms and you have
 * no bucket boundary in there, p95 will be a straight-faced lie. Pick buckets
 * that bracket the latency you actually expect.
 *
 * Cost note: a histogram creates one series PER BUCKET, per label combination,
 * plus _sum and _count. The 11 buckets below are already the most expensive
 * thing in this file. Do not put a histogram on a high-cardinality label.
 */
export const httpRequestDuration = new client.Histogram({
  name: 'chiya_http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers: [registry],
});

/**
 * A second counter, this time measuring the business rather than the plumbing.
 *
 * `outcome` has four possible values. `tea` has five. Both listable, both safe.
 * This is the metric a shop owner would actually care about, and it costs
 * essentially nothing to publish.
 */
export const ordersTotal = new client.Counter({
  name: 'chiya_orders_total',
  help: 'Orders by outcome',
  labelNames: ['outcome', 'tea'],
  registers: [registry],
});

/** Money. Also a counter -- revenue only accumulates. */
export const revenueNprTotal = new client.Counter({
  name: 'chiya_revenue_npr_total',
  help: 'Total value of successful orders, in NPR',
  registers: [registry],
});

/**
 * GAUGE -- a value that goes up and down. Current stock, queue depth,
 * temperature, number of connected users.
 *
 * A gauge is a snapshot at scrape time. If stock dips to zero and recovers
 * between two scrapes, Prometheus never sees it. Gauges lose spikes; counters
 * do not. When it matters, count the event as well as gauging the level.
 */
export const teaStock = new client.Gauge({
  name: 'chiya_tea_stock',
  help: 'Cups currently in stock',
  labelNames: ['tea'],
  registers: [registry],
});

/**
 * SUMMARY is the fourth type. It computes percentiles inside the process,
 * which sounds better than a histogram until you try to combine two replicas:
 * you cannot average percentiles. Histograms aggregate correctly across
 * instances; summaries do not. Prefer histograms. We do not use one here, and
 * that omission is the lesson.
 */
