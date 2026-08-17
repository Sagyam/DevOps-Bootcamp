// Every byte of user input is parsed by one of these before it reaches SQL.
import { z } from 'zod';

// Nepali mobile numbers: 98xxxxxxxx / 97xxxxxxxx, optional +977.
const phone = z
  .string()
  .trim()
  .regex(/^(\+977)?9[78]\d{8}$/, 'must be a valid Nepali mobile number');

export const createOrderSchema = z.object({
  item_id: z.string().uuid('item_id must be a UUID'),
  quantity: z.number().int().min(1).max(20),
  customer_phone: phone,
  note: z.string().max(200).optional(),
});

export const orderIdSchema = z.object({
  id: z.string().uuid('order id must be a UUID'),
});

export const updateOrderStatusSchema = z.object({
  status: z.enum(['PENDING', 'PREPARING', 'DELIVERED', 'CANCELLED']),
});

export const createMenuItemSchema = z.object({
  name: z.string().trim().min(1).max(100),
  price_npr: z.number().int().min(1).max(100000),
  available: z.boolean().optional(),
});

export const updateMenuItemSchema = z.object({
  name: z.string().trim().min(1).max(100).optional(),
  price_npr: z.number().int().min(1).max(100000).optional(),
  available: z.boolean().optional(),
});

export const menuItemIdSchema = z.object({
  id: z.string().uuid('menu item id must be a UUID'),
});

// Reusable Express middleware factory.
export function validate(schema, source = 'body') {
  return (req, res, next) => {
    const data =
      source === 'params' ? req.params : source === 'query' ? req.query : req.body;
    const result = schema.safeParse(data);
    if (!result.success) {
      return res.status(400).json({
        error: 'validation_failed',
        details: result.error.flatten().fieldErrors,
      });
    }
    req.validated = result.data;
    next();
  };
}
