import { Router } from 'express';
import { query } from '../db.js';
import { createOrderSchema, orderIdSchema, validate } from '../schemas.js';
import { ordersCreated } from '../metrics.js';

export const ordersRouter = Router();

ordersRouter.get(
  '/orders/:id',
  validate(orderIdSchema, 'params'),
  async (req, res, next) => {
    try {
      const result = await query(
        'SELECT id, item_id, quantity, status, created_at FROM orders WHERE id = $1',
        [req.validated.id],
      );
      if (result.rowCount === 0) {
        return res.status(404).json({ error: 'not_found' });
      }
      res.json(result.rows[0]);
    } catch (err) {
      next(err);
    }
  },
);

ordersRouter.post('/orders', validate(createOrderSchema), async (req, res, next) => {
  const { item_id, quantity, customer_phone, note } = req.validated;
  try {
    const result = await query(
      `INSERT INTO orders (item_id, quantity, customer_phone, note, status)
       VALUES ($1, $2, $3, $4, 'PENDING')
       RETURNING id, item_id, quantity, status, created_at`,
      [item_id, quantity, customer_phone, note ?? null],
    );
    ordersCreated.inc({ item_id });
    // Note what is NOT logged here: the phone number.
    req.log.info({ order_id: result.rows[0].id, item_id, quantity }, 'order created');
    res.status(201).json(result.rows[0]);
  } catch (err) {
    // Foreign key violation means the item_id does not exist.
    if (err.code === '23503') {
      return res.status(422).json({ error: 'unknown_item' });
    }
    next(err);
  }
});
