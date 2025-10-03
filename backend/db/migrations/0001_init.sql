CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  green_points INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS couriers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS recycling_locations (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  accepted_materials TEXT[] NOT NULL
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'pickup_status') THEN
    CREATE TYPE pickup_status AS ENUM ('pending', 'assigned', 'completed');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS pickups (
  id UUID PRIMARY KEY,
  user_id TEXT NOT NULL,
  courier_id TEXT REFERENCES couriers(id),
  material TEXT NOT NULL,
  weight_kg NUMERIC NOT NULL,
  status pickup_status NOT NULL DEFAULT 'pending',
  pickup_latitude DOUBLE PRECISION NOT NULL,
  pickup_longitude DOUBLE PRECISION NOT NULL,
  dropoff_location TEXT REFERENCES recycling_locations(id),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS carbon_reports (
  pickup_id UUID PRIMARY KEY REFERENCES pickups(id),
  estimated_saving_kg NUMERIC NOT NULL,
  generated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

INSERT INTO couriers (id, name, active, latitude, longitude)
VALUES ('11111111-1111-1111-1111-111111111111', 'Eco Kurye 1', TRUE, 41.0082, 28.9784)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  active = EXCLUDED.active,
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  updated_at = NOW();
