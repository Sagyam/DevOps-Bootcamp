// Integration tests: real Express app, real Postgres (from docker-compose or
// the CI service container). Slower, fewer, higher confidence.
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import request from 'supertest';
import { createApp } from '../../src/app.js';
import { query, closePool } from '../../src/db.js';

const app = createApp();
let itemId;

beforeAll(async () => {
  await query(`
    CREATE TABLE IF NOT EXISTS menu_items (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL,
      price_npr INTEGER NOT NULL,
      available BOOLEAN NOT NULL DEFAULT true
    )`);
  await query(`
    CREATE TABLE IF NOT EXISTS orders (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      item_id UUID NOT NULL REFERENCES menu_items(id),
      quantity INTEGER NOT NULL,
      customer_phone TEXT NOT NULL,
      note TEXT,
      status TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )`);
  const res = await query(
    'INSERT INTO menu_items (name, price_npr) VALUES ($1, $2) RETURNING id',
    ['Dal Bhat Set', 250],
  );
  itemId = res.rows[0].id;
});

afterAll(async () => {
  await query('DELETE FROM orders');
  await closePool();
});

describe('GET /healthz and /readyz', () => {
  it('liveness returns 200 without touching the database', async () => {
    const res = await request(app).get('/healthz');
    expect(res.status).toBe(200);
  });

  it('readiness returns 200 when the database answers', async () => {
    const res = await request(app).get('/readyz');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ready');
  });
});

describe('POST /orders', () => {
  it('creates an order and returns 201', async () => {
    const res = await request(app)
      .post('/orders')
      .send({ item_id: itemId, quantity: 2, customer_phone: '9841234567' });
    expect(res.status).toBe(201);
    expect(res.body.status).toBe('PENDING');
    expect(res.body).toHaveProperty('id');
  });

  it('never echoes the customer phone number back', async () => {
    const res = await request(app)
      .post('/orders')
      .send({ item_id: itemId, quantity: 1, customer_phone: '9841234567' });
    expect(JSON.stringify(res.body)).not.toContain('9841234567');
  });

  it('rejects invalid input with 400 and does not create a row', async () => {
    const before = await query('SELECT count(*)::int AS c FROM orders');
    const res = await request(app)
      .post('/orders')
      .send({ item_id: 'bogus', quantity: 999, customer_phone: 'x' });
    const after = await query('SELECT count(*)::int AS c FROM orders');
    expect(res.status).toBe(400);
    expect(after.rows[0].c).toBe(before.rows[0].c);
  });

  it('survives an injection payload without dropping the table', async () => {
    await request(app).post('/orders').send({
      item_id: "' OR '1'='1'; DROP TABLE orders; --",
      quantity: 1,
      customer_phone: '9841234567',
    });
    const still = await query('SELECT count(*)::int AS c FROM orders');
    expect(still.rows[0].c).toBeGreaterThanOrEqual(0); // table still exists
  });

  it('returns 422 for an item that does not exist', async () => {
    const res = await request(app).post('/orders').send({
      item_id: '00000000-0000-4000-8000-000000000000',
      quantity: 1,
      customer_phone: '9841234567',
    });
    expect(res.status).toBe(422);
  });
});

describe('GET /metrics', () => {
  it('exposes Prometheus metrics', async () => {
    const res = await request(app).get('/metrics');
    expect(res.status).toBe(200);
    expect(res.text).toContain('tiffin_http_request_duration_seconds');
  });
});

describe('error handling', () => {
  it('does not leak stack traces to clients', async () => {
    const res = await request(app).get('/orders/not-a-uuid');
    expect(res.status).toBe(400);
    expect(res.text).not.toContain('at Object');
  });
});
