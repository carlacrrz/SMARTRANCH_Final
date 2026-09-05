-- Migration 003: Users, Feed Records, Financial Events tables + auth default user
-- Depends on: 001_initial_schema.sql

-- Users table for authentication
CREATE TABLE IF NOT EXISTS users (
    id              SERIAL PRIMARY KEY,
    username        VARCHAR(100) UNIQUE NOT NULL,
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   TEXT NOT NULL,
    full_name       VARCHAR(200),
    role            VARCHAR(50) DEFAULT 'operator' CHECK (role IN ('admin', 'operator', 'viewer')),
    last_login      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Feed records for nutrition tracking
CREATE TABLE IF NOT EXISTS feed_records (
    id              SERIAL PRIMARY KEY,
    animal_id       INT REFERENCES animals(id),
    group_name      VARCHAR(100),
    feed_type       VARCHAR(100) NOT NULL,
    quantity_kg     DECIMAL(10,2),
    cost            DECIMAL(10,2),
    notes           TEXT,
    recorded_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Financial events for income/expense tracking
CREATE TABLE IF NOT EXISTS financial_events (
    id              SERIAL PRIMARY KEY,
    animal_id       INT REFERENCES animals(id),
    event_type      VARCHAR(50) NOT NULL CHECK (event_type IN ('sale', 'purchase', 'expense', 'income')),
    amount          DECIMAL(12,2) NOT NULL,
    buyer_seller    VARCHAR(200),
    weight_at_event DECIMAL(10,2),
    notes           TEXT,
    recorded_at     TIMESTAMPTZ DEFAULT NOW()
);

-- Add battery_level column to gps_positions if not exists
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_name='gps_positions' AND column_name='battery_level')
  THEN
    ALTER TABLE gps_positions ADD COLUMN battery_level DECIMAL(5,2);
  END IF;
END $$;

-- Default admin user (password: admin123)
-- Hash generated with PBKDF2-SHA256, salt=16 random bytes
-- This is a placeholder — the actual hash is created by auth.py at runtime
-- Use POST /api/auth/register to create the first admin user

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_feed_records_animal ON feed_records(animal_id);
CREATE INDEX IF NOT EXISTS idx_feed_records_date ON feed_records(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_financial_events_animal ON financial_events(animal_id);
CREATE INDEX IF NOT EXISTS idx_financial_events_type ON financial_events(event_type);
CREATE INDEX IF NOT EXISTS idx_financial_events_date ON financial_events(recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
