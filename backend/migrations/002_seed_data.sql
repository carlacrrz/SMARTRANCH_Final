-- ============================================================
-- Smart Ranch — Seed Data for Development/Demo
-- Run after 001_initial_schema.sql
-- ============================================================

-- ============================================================
-- Default admin user
-- ============================================================
INSERT INTO users (username, password_hash, role, full_name, email)
VALUES ('admin', '$2b$12$dummy_hash_replace_me', 'admin', 'Administrador', 'admin@rancho-cananea.mx')
ON CONFLICT (username) DO NOTHING;

-- ============================================================
-- Sample Animals (5 hembras Rancho Cananea)
-- ============================================================
INSERT INTO animals (ear_tag, name, breed, sex, category, birth_date, weight_kg, status, device_id, notes)
VALUES
    ('MX-0026-0001', 'Lupita',    'Hereford',  'hembra', 'vaca', '2022-03-15', 420.0, 'active', 'vaca_001', 'Líder del hato, excelente productora'),
    ('MX-0026-0002', 'Estrella',  'Angus',     'hembra', 'vaca', '2021-06-22', 380.0, 'active', 'vaca_002', 'Temperamento dócil, buena madre'),
    ('MX-0026-0003', 'Canela',    'Charolais', 'hembra', 'vaca', '2023-01-10', 350.0, 'active', 'vaca_003', 'Jóven, buen potencial de peso'),
    ('MX-0026-0004', 'Luna',      'Brahman',   'hembra', 'vaca', '2020-09-05', 450.0, 'active', 'vaca_004', 'La más pesada, resistente al calor'),
    ('MX-0026-0005', 'Valentina', 'Simmental', 'hembra', 'vaca', '2022-11-18', 400.0, 'active', 'vaca_005', 'Doble propósito, buena leche')
ON CONFLICT (ear_tag) DO NOTHING;

-- ============================================================
-- GPS Zones (Potreros and key areas)
-- ============================================================
INSERT INTO gps_zones (name, zone_type, geom, capacity_heads, notes)
VALUES
    ('Potrero Norte', 'potrero',
     ST_SetSRID(ST_GeomFromText('POLYGON((-110.310 30.980, -110.300 30.980, -110.300 30.990, -110.310 30.990, -110.310 30.980))'), 4326),
     50, 'Potrero principal de pastoreo, pasto buffel'),

    ('Potrero Sur', 'potrero',
     ST_SetSRID(ST_GeomFromText('POLYGON((-110.312 30.972, -110.302 30.972, -110.302 30.980, -110.312 30.980, -110.312 30.972))'), 4326),
     40, 'Potrero secundario, pasto bermuda'),

    ('Corral Principal', 'corral',
     ST_SetSRID(ST_GeomFromText('POLYGON((-110.303 30.976, -110.301 30.976, -110.301 30.978, -110.303 30.978, -110.303 30.976))'), 4326),
     20, 'Corral de manejo veterinario'),

    ('Bebedero Arroyo', 'bebedero',
     ST_SetSRID(ST_GeomFromText('POLYGON((-110.305 30.982, -110.303 30.982, -110.303 30.984, -110.305 30.984, -110.305 30.982))'), 4326),
     NULL, 'Bebedero natural del arroyo'),

    ('Zona Sombra', 'sombra',
     ST_SetSRID(ST_GeomFromText('POLYGON((-110.306 30.985, -110.304 30.985, -110.304 30.987, -110.306 30.987, -110.306 30.985))'), 4326),
     NULL, 'Zona de árboles, sombra natural')
ON CONFLICT DO NOTHING;

-- ============================================================
-- Sample Medical Records
-- ============================================================
INSERT INTO medical_records (animal_id, record_type, product_name, dose, administered_by, cost, withdrawal_days, next_due_date, notes)
VALUES
    (1, 'vaccine',   'Pasturela bovina',            '5ml IM',  'Dr. Ramírez', 180.00, 0,  CURRENT_DATE + INTERVAL '180 days', 'Vacuna anual aplicada'),
    (2, 'vaccine',   'Brucelosis (RB51)',            '2ml SC',  'Dr. Ramírez', 350.00, 0,  NULL, 'Dosis única de por vida'),
    (1, 'deworming', 'Ivermectina 1%',               '10ml SC', 'Juan',        95.00,  28, CURRENT_DATE + INTERVAL '90 days',  'Desparasitación trimestral'),
    (3, 'treatment', 'Penicilina + Estreptomicina',  '15ml IM', 'Dr. Ramírez', 220.00, 30, NULL, 'Tratamiento por infección leve'),
    (4, 'vaccine',   'Carbunco (Ántrax)',            '1ml SC',  'Dr. Ramírez', 120.00, 0,  CURRENT_DATE + INTERVAL '365 days', 'Vacuna anual zona endémica'),
    (5, 'exam',      'Tuberculina (PPD)',             'Intradérmica', 'Dr. Ramírez', 200.00, 0, CURRENT_DATE + INTERVAL '365 days', 'Prueba TB negativa');

-- ============================================================
-- Sample Reproductive Events
-- ============================================================
INSERT INTO reproductive_events (animal_id, event_type, bull_or_semen, pregnancy_confirmed, expected_birth_date, notes)
VALUES
    (1, 'heat_detected',          NULL,                   NULL,  NULL, 'Actividad elevada detectada por sensor de movimiento'),
    (1, 'artificial_insemination','Angus Premium #4521',  NULL,  CURRENT_DATE + INTERVAL '283 days', 'Inseminación a tiempo fijo (IATF)'),
    (4, 'pregnancy_check',        'Toro Canelo',          true,  CURRENT_DATE + INTERVAL '120 days', 'Gestación confirmada por palpación'),
    (2, 'birth',                  'Brahman #231',         NULL,  NULL, 'Parto normal, becerro macho 32kg'),
    (5, 'mating',                 'Toro Negro',           NULL,  NULL, 'Monta natural observada en potrero');

-- ============================================================
-- Sample Weight Records (history for growth curves)
-- ============================================================
INSERT INTO weight_records (animal_id, weight_kg, body_condition_score, notes, recorded_at)
VALUES
    -- Lupita weight history
    (1, 395.0, 5, 'Entrada al rancho',       CURRENT_TIMESTAMP - INTERVAL '90 days'),
    (1, 408.0, 5, 'Pesaje mensual',          CURRENT_TIMESTAMP - INTERVAL '60 days'),
    (1, 415.0, 6, 'Buena ganancia',          CURRENT_TIMESTAMP - INTERVAL '30 days'),
    (1, 420.0, 6, 'Condición normal',        CURRENT_TIMESTAMP),
    -- Estrella
    (2, 372.0, 5, 'Post-parto',             CURRENT_TIMESTAMP - INTERVAL '30 days'),
    (2, 380.0, 5, 'Recuperándose',           CURRENT_TIMESTAMP),
    -- Canela
    (3, 340.0, 6, 'Primera pesada',          CURRENT_TIMESTAMP - INTERVAL '30 days'),
    (3, 350.0, 7, 'Excelente condición',     CURRENT_TIMESTAMP),
    -- Luna
    (4, 445.0, 6, 'Pesaje mensual',          CURRENT_TIMESTAMP - INTERVAL '30 days'),
    (4, 450.0, 6, 'Estable',                CURRENT_TIMESTAMP),
    -- Valentina
    (5, 390.0, 5, 'Bajo peso',              CURRENT_TIMESTAMP - INTERVAL '30 days'),
    (5, 400.0, 6, 'Mejorando',              CURRENT_TIMESTAMP);

-- ============================================================
-- Sample GPS Positions (current location simulation)
-- ============================================================
INSERT INTO gps_positions (device_id, geom, speed, battery_level)
VALUES
    ('vaca_001', ST_SetSRID(ST_MakePoint(-110.305, 30.984), 4326), 0.2, 85.0),
    ('vaca_002', ST_SetSRID(ST_MakePoint(-110.303, 30.986), 4326), 0.0, 92.0),
    ('vaca_003', ST_SetSRID(ST_MakePoint(-110.302, 30.977), 4326), 0.5, 78.0),
    ('vaca_004', ST_SetSRID(ST_MakePoint(-110.304, 30.983), 4326), 0.1, 88.0),
    ('vaca_005', ST_SetSRID(ST_MakePoint(-110.315, 30.992), 4326), 1.2, 65.0);

-- ============================================================
-- Sample Alerts
-- ============================================================
INSERT INTO alerts_log (device_id, alert_type, severity, message)
VALUES
    ('vaca_001', 'thi_danger',    'danger',  'THI=82.5 — Proveer sombra y agua inmediatamente'),
    ('vaca_005', 'geofence_exit', 'warning', 'Valentina salió de zona: Potrero Sur'),
    ('vaca_003', 'vaccine_due',   'info',    'Canela necesita desparasitación en 7 días');
