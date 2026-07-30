const cfg = window.CHIYA_CONFIG || {};
const ORDERS = cfg.ordersApi || "/api/orders";
const KITCHEN = cfg.kitchenApi || "/api/kitchen";

document.getElementById("shop-tagline").textContent = cfg.tagline || "";

const $ = (id) => document.getElementById(id);

async function refreshOrders() {
  try {
    const res = await fetch(ORDERS + "/orders");
    const data = await res.json();
    const body = document.querySelector("#orders tbody");
    body.innerHTML = "";
    for (const o of data.orders || []) {
      const tr = document.createElement("tr");
      tr.innerHTML = `<td>${o.id}</td><td>${o.flavour}</td><td>${o.qty}</td>` +
                     `<td>${o.status}</td><td>${o.served_by || "-"}</td>`;
      body.appendChild(tr);
    }
    $("served-by").textContent = "orders-api pod: " + (data.pod || "?") +
                                 "  |  node: " + (data.node || "?");
  } catch (e) {
    $("served-by").textContent = "orders-api unreachable: " + e.message;
  }
}

async function refreshFleet() {
  try {
    const res = await fetch(KITCHEN + "/fleet");
    if (res.status === 403) {
      $("fleet").textContent =
        "403 Forbidden -- the ServiceAccount has no RBAC permission to list pods.\n" +
        "That is the lesson. Re-apply the RoleBinding and try again.";
      return;
    }
    const data = await res.json();
    $("fleet").textContent = (data.pods || [])
      .map(p => `${p.name.padEnd(34)} ${p.node.padEnd(14)} ${p.phase}`)
      .join("\n") || "(none)";
  } catch (e) {
    $("fleet").textContent = "kitchen-api unreachable: " + e.message;
  }
}

$("order-btn").onclick = async () => {
  const btn = $("order-btn");
  btn.disabled = true;
  try {
    const res = await fetch(ORDERS + "/orders", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ flavour: $("flavour").value, qty: Number($("qty").value) })
    });
    if (res.status === 429) {
      $("order-status").textContent = "429 Too Many Requests -- the gateway rate limit kicked in.";
    } else {
      const d = await res.json();
      $("order-status").textContent = "queued order #" + d.id;
    }
  } catch (e) {
    $("order-status").textContent = "error: " + e.message;
  }
  btn.disabled = false;
  refreshOrders();
};

$("load-btn").onclick = async () => {
  const btn = $("load-btn");
  btn.disabled = true;
  $("load-status").textContent = "running...";
  const jobs = [];
  for (let i = 0; i < 40; i++) jobs.push(fetch(KITCHEN + "/cook?ms=1500").catch(() => {}));
  await Promise.all(jobs);
  $("load-status").textContent = "done -- check 'kubectl get hpa -w'";
  btn.disabled = false;
};

refreshOrders();
refreshFleet();
setInterval(refreshOrders, 2500);
setInterval(refreshFleet, 5000);
