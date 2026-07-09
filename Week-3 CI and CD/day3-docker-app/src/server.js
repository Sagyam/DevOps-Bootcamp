// A small HTTP API — real enough to containerize and ship.
// No framework: Node's built-in http module keeps the image tiny and the
// dependency list honest, so today's lesson is about *Docker in CI*, not npm.

const http = require("http");

function slugify(input) {
  return String(input)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, "")
    .replace(/[\s-]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function handler(req, res) {
  const url = new URL(req.url, "http://localhost");

  if (url.pathname === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    return res.end(JSON.stringify({ status: "ok" }));
  }

  if (url.pathname === "/slug") {
    const text = url.searchParams.get("text") || "";
    res.writeHead(200, { "Content-Type": "application/json" });
    return res.end(JSON.stringify({ input: text, slug: slugify(text) }));
  }

  res.writeHead(404, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ error: "not found" }));
}

const server = http.createServer(handler);

// Only listen when run directly, so tests can import `handler` without a port.
if (require.main === module) {
  const port = process.env.PORT || 3000;
  server.listen(port, () => console.log(`listening on ${port}`));
}

module.exports = { handler, slugify, server };
