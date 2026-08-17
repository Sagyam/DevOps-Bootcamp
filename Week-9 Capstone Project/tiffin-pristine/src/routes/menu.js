import { Router } from 'express';
import { query } from '../db.js';
import {
  createMenuItemSchema,
  updateMenuItemSchema,
  menuItemIdSchema,
  validate,
} from '../schemas.js';

export const menuRouter = Router();

menuRouter.get('/menu', async (_req, res, next) => {
  try {
    const result = await query(
      'SELECT id, name, price_npr, available FROM menu_items ORDER BY name',
    );
    res.json({ items: result.rows });
  } catch (err) {
    next(err);
  }
});

menuRouter.post('/menu', validate(createMenuItemSchema), async (req, res, next) => {
  const { name, price_npr, available = true } = req.validated;
  try {
    const result = await query(
      `INSERT INTO menu_items (name, price_npr, available)
       VALUES ($1, $2, $3)
       RETURNING id, name, price_npr, available`,
      [name, price_npr, available],
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    next(err);
  }
});

menuRouter.patch(
  '/menu/:id',
  validate(menuItemIdSchema, 'params'),
  validate(updateMenuItemSchema),
  async (req, res, next) => {
    const { id } = req.params;
    const { name, price_npr, available } = req.validated;
    try {
      const existing = await query('SELECT * FROM menu_items WHERE id = $1', [id]);
      if (existing.rowCount === 0) {
        return res.status(404).json({ error: 'not_found' });
      }
      const item = existing.rows[0];
      const newName = name !== undefined ? name : item.name;
      const newPrice = price_npr !== undefined ? price_npr : item.price_npr;
      const newAvail = available !== undefined ? available : item.available;

      const result = await query(
        `UPDATE menu_items
         SET name = $1, price_npr = $2, available = $3
         WHERE id = $4
         RETURNING id, name, price_npr, available`,
        [newName, newPrice, newAvail, id],
      );
      res.json(result.rows[0]);
    } catch (err) {
      next(err);
    }
  },
);

menuRouter.delete(
  '/menu/:id',
  validate(menuItemIdSchema, 'params'),
  async (req, res, next) => {
    try {
      const result = await query('DELETE FROM menu_items WHERE id = $1 RETURNING id', [
        req.validated.id,
      ]);
      if (result.rowCount === 0) {
        return res.status(404).json({ error: 'not_found' });
      }
      res.json({ status: 'deleted', id: req.validated.id });
    } catch (err) {
      next(err);
    }
  },
);
