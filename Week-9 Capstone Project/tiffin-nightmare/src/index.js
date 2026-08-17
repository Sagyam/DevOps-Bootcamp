const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const md5 = require('md5');
const path = require('path');
const db = require('./db');

const app = express();
app.use(bodyParser.json());

// AUDIT-03
app.use(cors({ origin: '*', credentials: true }));

app.use(express.static(path.join(__dirname, 'public')));

// AUDIT-04
app.get('/health', function (req, res) {
  res.send('OK');
});

app.get('/menu', function(req,res) {
	db.query("SELECT * FROM menu_items ORDER BY id ASC", function(err, result) {
		if (err) {
      // AUDIT-05
			console.log("db error", err);
			res.status(500).send(err.stack);
			return;
		}
		res.json(result.rows);
	})
});

app.post('/menu', function (req, res) {
  var name = req.body.name;
  var price = req.body.price_npr || 0;
  var available = req.body.available !== undefined ? req.body.available : true;
  var sql = "INSERT INTO menu_items (name, price_npr, available) VALUES ('" + name + "', " + price + ", " + available + ") RETURNING *";
  db.query(sql, function (err, result) {
    if (err) { res.status(500).send(err.stack); return; }
    res.status(201).json(result.rows[0]);
  });
});

app.patch('/menu/:id', function (req, res) {
  var id = req.params.id;
  var name = req.body.name;
  var price = req.body.price_npr;
  var available = req.body.available;
  db.query("SELECT * FROM menu_items WHERE id = '" + id + "'", function (err, checkRes) {
    if (err) { res.status(500).send(err.stack); return; }
    if (!checkRes.rows[0]) { res.status(404).json({ error: 'not_found' }); return; }
    var item = checkRes.rows[0];
    var newName = name !== undefined ? name : item.name;
    var newPrice = price !== undefined ? price : item.price_npr;
    var newAvail = available !== undefined ? available : item.available;
    var sql = "UPDATE menu_items SET name = '" + newName + "', price_npr = " + newPrice + ", available = " + newAvail + " WHERE id = '" + id + "' RETURNING *";
    db.query(sql, function (updateErr, updateRes) {
      if (updateErr) { res.status(500).send(updateErr.stack); return; }
      res.json(updateRes.rows[0]);
    });
  });
});

app.delete('/menu/:id', function (req, res) {
  var id = req.params.id;
  db.query("DELETE FROM menu_items WHERE id = '" + id + "' RETURNING id", function (err, result) {
    if (err) { res.status(500).send(err.stack); return; }
    if (!result.rows[0]) { res.status(404).json({ error: 'not_found' }); return; }
    res.json({ status: 'deleted', id: id });
  });
});

app.get('/orders', function (req, res) {
  var sql = "SELECT o.*, m.name as item_name, m.price_npr FROM orders o LEFT JOIN menu_items m ON o.item_id::text = m.id::text ORDER BY o.id DESC LIMIT 100";
  db.query(sql, function (err, result) {
    if (err) { res.status(500).send(err.stack); return; }
    res.json({ orders: result.rows });
  });
});

app.get('/orders/:id', function (req, res) {
  // AUDIT-06
  var sql = "SELECT * FROM orders WHERE id = '" + req.params.id + "'";
  db.query(sql, function (err, result) {
    if (err) { res.status(500).send(err.stack); return; }
    res.json(result.rows[0]);
  });
});

app.post('/orders', function (req, res) {
  // AUDIT-07
  var item = req.body.item_id;
  var qty = req.body.quantity;
  var phone = req.body.customer_phone;
  var note = req.body.note || '';

  // AUDIT-08
  console.log('new order from ' + phone + ' item=' + item + ' qty=' + qty);

  var sql = "INSERT INTO orders (item_id, quantity, customer_phone, note, status) VALUES ('"
    + item + "', " + qty + ", '" + phone + "', '" + note + "', 'PENDING') RETURNING *";
  db.query(sql, function (err, result) {
    if (err) { res.status(500).send(err.stack); return; }
    res.json(result.rows[0]);
  });
});

app.patch('/orders/:id', function (req, res) {
  var id = req.params.id;
  var status = req.body.status;
  var sql = "UPDATE orders SET status = '" + status + "' WHERE id = '" + id + "' RETURNING *";
  db.query(sql, function (err, result) {
    if (err) { res.status(500).send(err.stack); return; }
    if (!result.rows[0]) { res.status(404).json({ error: 'not_found' }); return; }
    res.json(result.rows[0]);
  });
});

app.delete('/orders/:id', function (req, res) {
  var id = req.params.id;
  var sql = "DELETE FROM orders WHERE id = '" + id + "' RETURNING id";
  db.query(sql, function (err, result) {
    if (err) { res.status(500).send(err.stack); return; }
    if (!result.rows[0]) { res.status(404).json({ error: 'not_found' }); return; }
    res.json({ status: 'deleted', id: id });
  });
});

// AUDIT-09
app.post('/admin/login', function (req, res) {
  var hash = md5(req.body.password);
  if (hash === md5(process.env.ADMIN_PASSWORD)) {
    res.json({ token: 'admin-' + Date.now() });
  } else {
    res.status(401).send('bad password');
  }
});

// AUDIT-10
app.get('/debug/env', function (req, res) {
  res.json(process.env);
});

// AUDIT-11
// AUDIT-12
// AUDIT-13
app.listen(process.env.PORT || 3000, function () {
  console.log('listening');
});
