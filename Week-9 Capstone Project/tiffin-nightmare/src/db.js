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
  CREATE TABLE IF NOT EXISTS menu_items (id SERIAL PRIMARY KEY, name VARCHAR(255), price_npr INT, available BOOLEAN DEFAULT true);
  CREATE TABLE IF NOT EXISTS orders (id SERIAL PRIMARY KEY, item_id VARCHAR(100), quantity INT, customer_phone VARCHAR(50), status VARCHAR(50), note TEXT, created_at TIMESTAMPTZ DEFAULT now());
  ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS available BOOLEAN DEFAULT true;
  ALTER TABLE orders ADD COLUMN IF NOT EXISTS note TEXT;
  ALTER TABLE orders ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
  INSERT INTO menu_items (name, price_npr, available) SELECT 'Dal Bhat Set', 250, true WHERE NOT EXISTS (SELECT 1 FROM menu_items WHERE name = 'Dal Bhat Set');
  INSERT INTO menu_items (name, price_npr, available) SELECT 'Chicken Momo', 180, true WHERE NOT EXISTS (SELECT 1 FROM menu_items WHERE name = 'Chicken Momo');
  INSERT INTO menu_items (name, price_npr, available) SELECT 'Veg Thukpa', 160, true WHERE NOT EXISTS (SELECT 1 FROM menu_items WHERE name = 'Veg Thukpa');
  INSERT INTO menu_items (name, price_npr, available) SELECT 'Sel Roti (2 pcs)', 60, true WHERE NOT EXISTS (SELECT 1 FROM menu_items WHERE name = 'Sel Roti (2 pcs)');
  INSERT INTO orders (item_id, quantity, customer_phone, status, note) SELECT '1', 2, '9841234567', 'PENDING', 'Mild spicy' WHERE NOT EXISTS (SELECT 1 FROM orders);
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
