-- ============================================================
--  Smart Ranch — Initial Database Schema
--  PostgreSQL 16 + PostGIS 3.4
-- ============================================================

-- Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================
--  1. Users (ranch operators)
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    full_name VARCHAR(200),
    role VARCHAR(50) DEFAULT 'operator',  -- 'admin', 'operator', 'viewer'
    phone VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
--  2. Animals (core identity)
-- ============================================================
CREATE TABLE IF NOT EXISTS animals (
    id SERIAL PRIMARY KEY,
    device_id VARCHAR(50) UNIQUE,                -- ESP32 device_id
    name VARCHAR(100) NOT NULL,
    ear_tag VARCHAR(50) UNIQUE,                  -- arete SINIIGA
    breed VARCHAR(100),
    sex VARCHAR(10) NOT NULL CHECK (sex IN ('male', 'female')),
    birth_date DATE,
    weight_kg FLOAT,
    category VARCHAR(50) DEFAULT 'cow',          -- 'calf', 'heifer', 'cow', 'bull', 'steer'
    mother_id INT REFERENCES animals(id) ON DELETE SET NULL,
    father_id INT REFERENCES animals(id) ON DELETE SET NULL,
    status VARCHAR(20) DEFAULT 'active'
        CHECK (status IN ('active', 'sold', 'dead', 'transferred', 'quarantine')),
    photo_url TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_animals_device ON animals(device_id);
CREATE INDEX idx_animals_status ON animals(status);
CREATE INDEX idx_animals_category ON animals(category);

-- ============================================================
--  3. Medical Records
-- ============================================================
CREATE TABLE IF NOT EXISTS medical_records (
    id SERIAL PRIMARY KEY,
    animal_id INT NOT NULL REFERENCES animals(id) ON DELETE CASCADE,
    record_type VARCHAR(50) NOT NULL
        CHECK (record_type IN ('vaccine', 'treatment', 'deworming', 'surgery', 'exam', 'other')),
    product_name VARCHAR(200),
    dose VARCHAR(100),
    administered_by VARCHAR(100),
    cost DECIMAL(10,2),
    notes TEXT,
    next_due_date DATE,
    withdrawal_days INT DEFAULT 0,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_medical_animal ON medical_records(animal_id);
CREATE INDEX idx_medical_next_due ON medical_records(next_due_date)
    WHERE next_due_date IS NOT NULL;

-- ============================================================
--  4. Reproductive Events
-- ============================================================
CREATE TABLE IF NOT EXISTS reproductive_events (
    id SERIAL PRIMARY KEY,
    animal_id INT NOT NULL REFERENCES animals(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL
        CHECK (event_type IN (
            'heat_detected', 'mating', 'artificial_insemination',
            'pregnancy_check', 'birth', 'weaning', 'abortion', 'other'
        )),
    bull_or_semen VARCHAR(100),
    pregnancy_confirmed BOOLEAN,
    expected_birth_date DATE,
    calf_id INT REFERENCES animals(id) ON DELETE SET NULL,
    notes TEXT,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_repro_animal ON reproductive_events(animal_id);
CREATE INDEX idx_repro_type ON reproductive_events(event_type);

-- ============================================================
--  5. Weight Records
-- ============================================================
CREATE TABLE IF NOT EXISTS weight_records (
    id SERIAL PRIMARY KEY,
    animal_id INT NOT NULL REFERENCES animals(id) ON DELETE CASCADE,
    weight_kg FLOAT NOT NULL,
    body_condition_score INT CHECK (body_condition_score BETWEEN 1 AND 9),
    notes TEXT,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_weight_animal ON weight_records(animal_id);

-- ============================================================
--  6. GPS Zones (geofencing with PostGIS)
-- ============================================================
CREATE TABLE IF NOT EXISTS gps_zones (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    zone_type VARCHAR(50) DEFAULT 'pasture'
        CHECK (zone_type IN ('pasture', 'water', 'corral', 'shade', 'danger', 'other')),
    boundary GEOMETRY(POLYGON, 4326) NOT NULL,
    color VARCHAR(7) DEFAULT '#4CAF50',          -- hex color for map display
    alert_on_exit BOOLEAN DEFAULT TRUE,
    alert_on_enter BOOLEAN DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_zones_geom ON gps_zones USING GIST(boundary);

-- ============================================================
--  7. GPS Positions (location history)
-- ============================================================
CREATE TABLE IF NOT EXISTS gps_positions (
    id BIGSERIAL PRIMARY KEY,
    device_id VARCHAR(50) NOT NULL,
    position GEOMETRY(POINT, 4326) NOT NULL,
    altitude FLOAT,
    speed FLOAT,
    heading FLOAT,
    hdop FLOAT,                                  -- GPS accuracy
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_gps_device ON gps_positions(device_id);
CREATE INDEX idx_gps_time ON gps_positions(recorded_at DESC);
CREATE INDEX idx_gps_geom ON gps_positions USING GIST(position);

-- Partition by month for performance at scale (300+ animals)
-- For now, we'll use a simple table and add partitioning later if needed.

-- ============================================================
--  8. Alerts Log
-- ============================================================
CREATE TABLE IF NOT EXISTS alerts_log (
    id SERIAL PRIMARY KEY,
    animal_id INT REFERENCES animals(id) ON DELETE SET NULL,
    device_id VARCHAR(50),
    alert_type VARCHAR(50) NOT NULL
        CHECK (alert_type IN (
            'thi_danger', 'thi_emergency', 'health_fever', 'health_lethargy',
            'health_sick', 'estrus_detected', 'geofence_exit', 'geofence_enter',
            'vaccine_due', 'birth_expected', 'weight_loss', 'low_battery', 'other'
        )),
    severity VARCHAR(20) DEFAULT 'warning'
        CHECK (severity IN ('info', 'warning', 'danger', 'emergency')),
    message TEXT,
    metadata JSONB,                              -- flexible extra data
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by VARCHAR(100),
    acknowledged_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_alerts_animal ON alerts_log(animal_id);
CREATE INDEX idx_alerts_type ON alerts_log(alert_type);
CREATE INDEX idx_alerts_unack ON alerts_log(acknowledged) WHERE acknowledged = FALSE;

-- ============================================================
--  9. Feed / Supplements (basic)
-- ============================================================
CREATE TABLE IF NOT EXISTS feed_records (
    id SERIAL PRIMARY KEY,
    animal_id INT REFERENCES animals(id) ON DELETE SET NULL,  -- NULL = group feeding
    group_name VARCHAR(100),                     -- "Potrero Norte", "Lote 3"
    feed_type VARCHAR(100) NOT NULL,             -- "alfalfa", "concentrado", "mineral"
    quantity_kg FLOAT,
    cost DECIMAL(10,2),
    notes TEXT,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_feed_animal ON feed_records(animal_id);

-- ============================================================
--  10. Financial Events (basic)
-- ============================================================
CREATE TABLE IF NOT EXISTS financial_events (
    id SERIAL PRIMARY KEY,
    animal_id INT REFERENCES animals(id) ON DELETE SET NULL,
    event_type VARCHAR(50) NOT NULL
        CHECK (event_type IN ('purchase', 'sale', 'vet_expense', 'feed_expense', 'other_expense', 'other_income')),
    amount DECIMAL(12,2) NOT NULL,
    buyer_seller VARCHAR(200),
    weight_at_event FLOAT,
    notes TEXT,
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_financial_animal ON financial_events(animal_id);
CREATE INDEX idx_financial_type ON financial_events(event_type);

-- ============================================================
--  Insert default admin user
-- ============================================================
INSERT INTO users (username, full_name, role)
VALUES ('admin', 'Administrador', 'admin')
ON CONFLICT (username) DO NOTHING;

-- ============================================================
--  Sample GPS zones for Cananea ranch area (approximate)
-- ============================================================
INSERT INTO gps_zones (name, zone_type, boundary, color) VALUES
    ('Corral Principal', 'corral',
     ST_GeomFromText('POLYGON((-110.303 30.976, -110.301 30.976, -110.301 30.978, -110.303 30.978, -110.303 30.976))', 4326),
     '#FF5722'),
    ('Potrero Norte', 'pasture',
     ST_GeomFromText('POLYGON((-110.310 30.980, -110.300 30.980, -110.300 30.990, -110.310 30.990, -110.310 30.980))', 4326),
     '#4CAF50'),
    ('Bebedero Arroyo', 'water',
     ST_GeomFromText('POLYGON((-110.305 30.982, -110.303 30.982, -110.303 30.984, -110.305 30.984, -110.305 30.982))', 4326),
     '#2196F3')
ON CONFLICT DO NOTHING;
