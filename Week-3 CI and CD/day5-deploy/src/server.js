// The app is intentionally boring: today is about *shipping* it safely, not
// about what it does. It exposes its version so you can prove a deploy landed.

const http = require("http");

const VERSION = process.env.APP_VERSION || "dev";

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    return res.end(JSON.stringify({ status: "ok", version: VERSION }));
  }
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end(`Deployed version: ${VERSION}\n`);
});

const port = process.env.PORT || 3000;
server.listen(port, () => console.log(`v${VERSION} listening on ${port}`));
