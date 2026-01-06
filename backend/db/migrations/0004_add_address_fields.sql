-- Add address fields to pickups table for courier visibility
ALTER TABLE pickups ADD COLUMN IF NOT EXISTS neighborhood TEXT;
ALTER TABLE pickups ADD COLUMN IF NOT EXISTS district TEXT;
ALTER TABLE pickups ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE pickups ADD COLUMN IF NOT EXISTS street TEXT;
ALTER TABLE pickups ADD COLUMN IF NOT EXISTS building TEXT;
