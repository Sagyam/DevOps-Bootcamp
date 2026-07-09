const http = require("http");
const { makeDb } = require("./db");
const { validateTitle } = require("./validate");

function createServer(db) {
  return http.createServer(async (req, res) => {
    res.setHeader("Content-Type", "application/json");

    try {
      if (req.method === "GET" && req.url === "/health") {
        res.writeHead(200);
        return res.end(JSON.stringify({ status: "ok" }));
      }

      if (req.method === "GET" && req.url === "/tasks") {
        const tasks = await db.listTasks();
        res.writeHead(200);
        return res.end(JSON.stringify(tasks));
      }

      if (req.method === "POST" && req.url === "/tasks") {
        let body = "";
        for await (const chunk of req) body += chunk;
        const { title } = JSON.parse(body || "{}");
        const error = validateTitle(title);
        if (error) {
          res.writeHead(400);
          return res.end(JSON.stringify({ error }));
        }
        const task = await db.addTask(title.trim());
        res.writeHead(201);
        return res.end(JSON.stringify(task));
      }

      res.writeHead(404);
      res.end(JSON.stringify({ error: "not found" }));
    } catch (err) {
      res.writeHead(500);
      res.end(JSON.stringify({ error: err.message }));
    }
  });
}

if (require.main === module) {
  const db = makeDb(process.env.DATABASE_URL);
  db.init().then(() => {
    const port = process.env.PORT || 3000;
    createServer(db).listen(port, () => console.log(`listening on ${port}`));
  });
}

module.exports = { createServer };
