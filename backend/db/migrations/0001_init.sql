CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  green_points INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS couriers (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  active BOOLEAN DEFAULT TRUE,
  location GEOGRAPHY(Point, 4326)
);

CREATE TABLE IF NOT EXISTS recycling_locations (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  accepted_materials TEXT[] NOT NULL
);

CREATE TYPE pickup_status AS ENUM ('pending', 'assigned', 'completed');

CREATE TABLE IF NOT EXISTS pickups (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  courier_id UUID REFERENCES couriers(id),
  material TEXT NOT NULL,
  weight_kg NUMERIC NOT NULL,
  status pickup_status NOT NULL DEFAULT 'pending',
  pickup_latitude DOUBLE PRECISION NOT NULL,
  pickup_longitude DOUBLE PRECISION NOT NULL,
  dropoff_location UUID REFERENCES recycling_locations(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS carbon_reports (
  pickup_id UUID REFERENCES pickups(id) PRIMARY KEY,
  estimated_saving_kg NUMERIC NOT NULL,
  generated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
