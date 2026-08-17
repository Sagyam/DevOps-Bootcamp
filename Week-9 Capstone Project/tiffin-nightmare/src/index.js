const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const md5 = require('md5');
const db = require('./db');

const app = express();
app.use(bodyParser.json());

// AUDIT-03
app.use(cors({ origin: '*', credentials: true }));

// AUDIT-04
app.get('/health', function (req, res) {
  res.send('OK');
});

app.get('/menu', function(req,res) {
	db.query("SELECT * FROM menu_items", function(err, result) {
		if (err) {
      // AUDIT-05
			console.log("db error", err);
			res.status(500).send(err.stack);
			return;
		}
		res.json(result.rows);
	})
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

  // AUDIT-08
  console.log('new order from ' + phone + ' item=' + item + ' qty=' + qty);

  var sql = "INSERT INTO orders (item_id, quantity, customer_phone, status) VALUES ('"
    + item + "', " + qty + ", '" + phone + "', 'PENDING') RETURNING *";
  db.query(sql, function (err, result) {
    if (err) { res.status(500).send(err.stack); return; }
    res.json(result.rows[0]);
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
