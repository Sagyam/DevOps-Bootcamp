// Unit tests: pure functions, no database, run in milliseconds.
// These are the tests that would have caught the injection payloads.
import { describe, it, expect } from 'vitest';
import { createOrderSchema, orderIdSchema } from '../../src/schemas.js';

const validItem = '3f0d1c9e-9d3a-4f4e-8c2a-2b1f5a7e9c11';

describe('createOrderSchema', () => {
  it('accepts a well formed order', () => {
    const result = createOrderSchema.safeParse({
      item_id: validItem,
      quantity: 2,
      customer_phone: '9841234567',
    });
    expect(result.success).toBe(true);
  });

  it('accepts the +977 country code form', () => {
    const result = createOrderSchema.safeParse({
      item_id: validItem,
      quantity: 1,
      customer_phone: '+9779841234567',
    });
    expect(result.success).toBe(true);
  });

  it.each([
    ["'; DROP TABLE orders; --", 'sql injection payload'],
    ['not-a-uuid', 'plain string'],
    ['', 'empty string'],
  ])('rejects %s as item_id (%s)', (payload) => {
    const result = createOrderSchema.safeParse({
      item_id: payload,
      quantity: 1,
      customer_phone: '9841234567',
    });
    expect(result.success).toBe(false);
  });

  it.each([0, -1, 21, 1.5, '3'])('rejects quantity %s', (quantity) => {
    const result = createOrderSchema.safeParse({
      item_id: validItem,
      quantity,
      customer_phone: '9841234567',
    });
    expect(result.success).toBe(false);
  });

  it('rejects a non-Nepali phone number', () => {
    const result = createOrderSchema.safeParse({
      item_id: validItem,
      quantity: 1,
      customer_phone: '1234567890',
    });
    expect(result.success).toBe(false);
    expect(result.error.flatten().fieldErrors.customer_phone).toBeDefined();
  });

  it('strips unknown fields rather than trusting them', () => {
    const result = createOrderSchema.safeParse({
      item_id: validItem,
      quantity: 1,
      customer_phone: '9841234567',
      status: 'COMPLETED', // caller must not be able to set this
    });
    expect(result.success).toBe(true);
    expect(result.data.status).toBeUndefined();
  });
});

describe('orderIdSchema', () => {
  it('rejects a path traversal attempt', () => {
    expect(orderIdSchema.safeParse({ id: '../../etc/passwd' }).success).toBe(false);
  });
});
