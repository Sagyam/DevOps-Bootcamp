import { Router } from 'express';
import { query } from '../db.js';

export const menuRouter = Router();

menuRouter.get('/menu', async (_req, res, next) => {
  try {
    const result = await query(
      'SELECT id, name, price_npr, available FROM menu_items WHERE available = true ORDER BY name',
    );
    res.json({ items: result.rows });
  } catch (err) {
    next(err);
  }
});
