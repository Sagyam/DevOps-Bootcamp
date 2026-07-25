/**
 * ---------------------------------------------------------------------------
 * A synthetic load generator. No dependencies -- just Node's built-in fetch.
 * ---------------------------------------------------------------------------
 *
 * An observability lab with no traffic is a set of empty dashboards. This
 * script keeps a steady, slightly-messy stream of requests flowing so that
 * every panel has something to show.
 *
 * The traffic mix is deliberate. Real traffic is not 100% happy path, and a
 * dashboard that only ever shows green teaches you nothing:
 *
 *   - most requests succeed                     -> info logs, 200s
 *   - some ask for teas that do not exist       -> warn logs, 404s
 *   - some order the scarce tea in bulk         -> warn logs, 409s
 *   - some hit the flaky fake payment gateway   -> error logs, 503s
 *
 * Tune RPS in docker-compose.yml. Try 1 to read individual lines, or 50 to
 * see what a dashboard looks like under pressure.
 */

const TARGET = process.env.TARGET || 'http://nginx:8080';
const RPS = Number(process.env.RPS || 5);

/** Same JSON-line format the API uses, so these land in Loki looking familiar. */
function log(level, fields, msg) {
  process.stdout.write(
    JSON.stringify({ level, time: new Date().toISOString(), service: 'loadgen', ...fields, msg }) + '\n',
  );
}

/**
 * Weighted pick. Give each action a weight and it is chosen roughly that
 * often. Easier to tune than a chain of if/else on Math.random().
 */
const ACTIONS = [
  { weight: 45, name: 'list_teas',      run: () => hit('GET', '/teas') },
  { weight: 15, name: 'get_tea',        run: () => hit('GET', `/teas/${rand(1, 5)}`) },
  { weight: 5,  name: 'get_missing_tea', run: () => hit('GET', `/teas/${rand(900, 999)}`) },
  { weight: 20, name: 'order_common',   run: () => hit('POST', '/orders', { teaId: rand(1, 4), quantity: rand(1, 3) }) },
  { weight: 8,  name: 'order_scarce',   run: () => hit('POST', '/orders', { teaId: 5, quantity: rand(1, 5) }) },
  { weight: 5,  name: 'recent_orders',  run: () => hit('GET', '/orders?limit=10') },
  { weight: 2,  name: 'health',         run: () => hit('GET', '/healthz') },
];

const TOTAL_WEIGHT = ACTIONS.reduce((sum, a) => sum + a.weight, 0);

function rand(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function pickAction() {
  let n = Math.random() * TOTAL_WEIGHT;
  for (const action of ACTIONS) {
    n -= action.weight;
    if (n <= 0) return action;
  }
  return ACTIONS[0];
}

async function hit(method, path, body) {
  const startedAt = Date.now();
  try {
    const res = await fetch(TARGET + path, {
      method,
      headers: body ? { 'content-type': 'application/json' } : {},
      body: body ? JSON.stringify(body) : undefined,
    });
    // Drain the body. If you do not read it, Node keeps the socket open and
    // you slowly leak connections until the whole thing stalls.
    await res.text();

    return { status: res.status, durationMs: Date.now() - startedAt };
  } catch (err) {
    return { status: 0, durationMs: Date.now() - startedAt, error: err.message };
  }
}

async function tick() {
  const action = pickAction();
  const result = await action.run();

  // Only log the interesting outcomes. A load generator that logs every 200
  // drowns out the service you are trying to watch -- which is itself a lesson
  // about log volume.
  if (result.status === 0) {
    log('error', { action: action.name, ...result }, 'request failed to connect');
  } else if (result.status >= 500) {
    log('warn', { action: action.name, ...result }, 'server error from api');
  }
}

async function waitForApi() {
  for (let attempt = 1; attempt <= 60; attempt++) {
    const res = await hit('GET', '/healthz');
    if (res.status === 200) {
      log('info', { target: TARGET, attempt }, 'api is up, starting load');
      return;
    }
    await new Promise((r) => setTimeout(r, 2000));
  }
  log('error', { target: TARGET }, 'api never became healthy, giving up');
  process.exit(1);
}

(async () => {
  log('info', { target: TARGET, rps: RPS }, 'load generator starting');
  await waitForApi();
  // setInterval, not a while-loop with await: a loop would send requests
  // serially and your actual rate would be governed by latency, not by RPS.
  setInterval(tick, Math.max(1, Math.floor(1000 / RPS)));
})();
