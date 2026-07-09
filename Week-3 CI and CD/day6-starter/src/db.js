const { Pool } = require("pg");

function makeDb(connectionString) {
  const pool = new Pool({ connectionString });

  async function init() {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS tasks (
        id     SERIAL PRIMARY KEY,
        title  TEXT NOT NULL,
        done   BOOLEAN NOT NULL DEFAULT false
      )
    `);
  }

  async function addTask(title) {
    const { rows } = await pool.query(
      "INSERT INTO tasks (title) VALUES ($1) RETURNING *",
      [title]
    );
    return rows[0];
  }

  async function listTasks() {
    const { rows } = await pool.query("SELECT * FROM tasks ORDER BY id");
    return rows;
  }

  async function close() {
    await pool.end();
  }

  return { init, addTask, listTasks, close };
}

module.exports = { makeDb };
