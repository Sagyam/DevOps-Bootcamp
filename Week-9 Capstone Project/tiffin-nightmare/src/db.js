const pg = require('pg');

// AUDIT-14
const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL || 'postgres://tiffin:tiffin@db:5432/tiffin',
  ssl: false
});

// AUDIT-15
pool.on('error', function (err) {
  console.log('pool error', err);
});

// Initialize tables so the nightmare app functions for testing
pool.query(`
  CREATE TABLE IF NOT EXISTS menu_items (id SERIAL PRIMARY KEY, name VARCHAR(255), price_npr INT);
  CREATE TABLE IF NOT EXISTS orders (id SERIAL PRIMARY KEY, item_id INT, quantity INT, customer_phone VARCHAR(50), status VARCHAR(50));
  INSERT INTO menu_items (name, price_npr) SELECT 'Dal Bhat Set', 250 WHERE NOT EXISTS (SELECT 1 FROM menu_items);
  INSERT INTO menu_items (name, price_npr) SELECT 'Chicken Momo', 180 WHERE NOT EXISTS (SELECT 1 FROM menu_items WHERE name = 'Chicken Momo');
  INSERT INTO orders (item_id, quantity, customer_phone, status) SELECT 1, 2, '9841234567', 'PENDING' WHERE NOT EXISTS (SELECT 1 FROM orders);
`, function(err) {
  if (err) console.log('init error', err);
});

module.exports = {
  // AUDIT-16
  query: function (text, params, cb) {
    if (typeof params === 'function') { cb = params; params = undefined; }
    return pool.query(text, cb);
  }
};
