// A deliberately tiny, STATELESS service. No database, no session, no disk.
// That's what makes it safe to run many identical copies behind a load balancer
// and to redeploy at will — the whole point of Express Mode + Fargate.

const http = require("http");
const os = require("os");

const VERSION = process.env.APP_VERSION || "dev";
const PORT = process.env.PORT || 8080;

// Pure function so it's trivially unit-testable (no server needed in tests).
function render(url) {
  if (url === "/health") {
    return { status: 200, body: { status: "ok", version: VERSION } };
  }
  return {
    status: 200,
    body: {
      message: "Hello from ECS Express Mode",
      version: VERSION,
      servedBy: os.hostname(), // changes per task — proof the LB is spreading load
    },
  };
}

const server = http.createServer((req, res) => {
  const { status, body } = render(req.url);
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
});

if (require.main === module) {
  server.listen(PORT, () => console.log(`v${VERSION} listening on :${PORT}`));
}

module.exports = { render };
