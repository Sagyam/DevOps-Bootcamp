-- Migrations are numbered, forward-only, and applied by CI before deploy.
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS menu_items (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL,
  price_npr  INTEGER NOT NULL CHECK (price_npr > 0),
  available  BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS orders (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id        UUID NOT NULL REFERENCES menu_items(id),
  quantity       INTEGER NOT NULL CHECK (quantity BETWEEN 1 AND 20),
  customer_phone TEXT NOT NULL,
  note           TEXT,
  status         TEXT NOT NULL CHECK (status IN ('PENDING','PREPARING','DELIVERED','CANCELLED')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- The legacy repo had no indexes at all. This one supports the dashboard query.
CREATE INDEX IF NOT EXISTS orders_created_at_idx ON orders (created_at DESC);
CREATE INDEX IF NOT EXISTS orders_status_idx ON orders (status) WHERE status = 'PENDING';

INSERT INTO menu_items (name, price_npr) VALUES
  ('Dal Bhat Set', 250),
  ('Chicken Momo', 180),
  ('Veg Thukpa', 160),
  ('Sel Roti (2 pcs)', 60)
ON CONFLICT DO NOTHING;
