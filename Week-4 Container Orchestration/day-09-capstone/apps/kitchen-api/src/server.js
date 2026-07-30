// kitchen-api -- the worker + introspection half of the Chiya Shop.
//
// Kubernetes concepts this file exists to demonstrate:
//   * HPA           : GET /cook burns CPU on purpose so the autoscaler has
//                     something real to react to.
//   * RBAC          : GET /fleet calls the Kubernetes API with this pod's
//                     ServiceAccount token. Delete the RoleBinding and it 403s.
//   * StatefulSet   : the worker loop BRPOPs from Valkey, which is a hand-written
//                     StatefulSet with a headless Service.
//   * Downward API  : POD_NAME / NODE_NAME come from the kubelet.
import http from "node:http";
import fs from "node:fs";
import Redis from "ioredis";
import pg from "pg";

const PORT = process.env.PORT || 8080;
const POD = process.env.POD_NAME || "local";
const NODE = process.env.NODE_NAME || "local";
const NAMESPACE = process.env.POD_NAMESPACE || "default";
const QUEUE_ADDR = process.env.QUEUE_ADDR || "";
const COOK_MS = Number(process.env.COOK_MS || 1200);

const SA = "/var/run/secrets/kubernetes.io/serviceaccount";

const pool = new pg.Pool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: process.env.DB_HOST ? { rejectUnauthorized: false } : false,
  max: 4
});

// ---------------------------------------------------------------- worker loop
async function worker() {
  if (!QUEUE_ADDR) {
    console.log("QUEUE_ADDR unset, worker loop disabled");
    return;
  }
  const [host, port] = QUEUE_ADDR.split(":");
  const redis = new Redis({ host, port: Number(port || 6379), lazyConnect: true,
                            retryStrategy: (n) => Math.min(n * 500, 5000) });
  await redis.connect().catch((e) => console.error("valkey connect:", e.message));
  console.log(`worker attached to ${QUEUE_ADDR}`);

  for (;;) {
    try {
      const res = await redis.brpop("chiya:queue", 5);
      if (!res) continue;
      const id = res[1];
      await pool.query("UPDATE orders SET status='cooking' WHERE id=$1", [id]);
      await new Promise((r) => setTimeout(r, COOK_MS));
      await pool.query("UPDATE orders SET status='ready', served_by=$2 WHERE id=$1", [id, POD]);
      console.log(`order ${id} served by ${POD}`);
    } catch (e) {
      console.error("worker:", e.message);
      await new Promise((r) => setTimeout(r, 1000));
    }
  }
}

// ---------------------------------------------------------------- k8s API call
async function listSiblings() {
  const token = fs.readFileSync(`${SA}/token`, "utf8");
  const url = `https://kubernetes.default.svc/api/v1/namespaces/${NAMESPACE}/pods`;
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (res.status === 401 || res.status === 403) {
    const err = new Error("forbidden");
    err.status = res.status;
    throw err;
  }
  const body = await res.json();
  return (body.items || []).map((p) => ({
    name: p.metadata.name,
    node: p.spec.nodeName || "-",
    phase: p.status.phase
  }));
}

// ---------------------------------------------------------------- cpu burn
function burn(ms) {
  const end = Date.now() + ms;
  let x = 0;
  while (Date.now() < end) {
    // Deliberately hot. This is what the HPA is measuring.
    x += Math.sqrt(Math.random() * 1e9) | 0;
  }
  return x;
}

// ---------------------------------------------------------------- http
const json = (res, code, body) => {
  res.writeHead(code, { "Content-Type": "application/json" });
  res.end(JSON.stringify(body));
};

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, "http://x");

  if (url.pathname === "/healthz") return json(res, 200, { ok: true });

  if (url.pathname === "/readyz") {
    try {
      await pool.query("SELECT 1");
      return json(res, 200, { ready: true });
    } catch (e) {
      return json(res, 503, { ready: false, error: e.message });
    }
  }

  if (url.pathname === "/whoami") return json(res, 200, { pod: POD, node: NODE, ns: NAMESPACE });

  if (url.pathname === "/cook") {
    const ms = Math.min(Number(url.searchParams.get("ms") || 800), 5000);
    burn(ms);
    return json(res, 200, { cooked: true, ms, pod: POD, node: NODE });
  }

  if (url.pathname === "/fleet") {
    try {
      const pods = await listSiblings();
      return json(res, 200, { pods, asked_by: POD });
    } catch (e) {
      if (e.status === 403 || e.status === 401) {
        return json(res, 403, {
          error: "forbidden",
          hint: "This pod's ServiceAccount cannot list pods. Check the Role and RoleBinding."
        });
      }
      return json(res, 500, { error: e.message });
    }
  }

  json(res, 404, { error: "not found" });
});

server.listen(PORT, () => console.log(`kitchen-api up on ${PORT} pod=${POD} node=${NODE}`));
worker();
