-- Add wallet authentication and role management

-- Add role type
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM ('user', 'courier', 'admin');
  END IF;
END $$;

-- Modify users table to support wallet-based authentication
ALTER TABLE users
ADD COLUMN IF NOT EXISTS wallet_address TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS role user_role NOT NULL DEFAULT 'user',
ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW();

-- Update email to be nullable (since we use wallet for auth)
ALTER TABLE users
ALTER COLUMN email DROP NOT NULL;

-- Create index for faster wallet lookups
CREATE INDEX IF NOT EXISTS idx_users_wallet_address ON users(wallet_address);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- Update couriers table to link with users
ALTER TABLE couriers
ADD COLUMN IF NOT EXISTS user_id TEXT REFERENCES users(id);

-- Create a trigger to automatically update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Insert demo accounts
INSERT INTO users (id, name, email, wallet_address, role, green_points)
VALUES 
  ('admin-001', 'Admin User', 'admin@greencycle.com', '0xAdminWalletAddressHere', 'admin', 1000),
  ('courier-001', 'Kurye Ahmet', 'ahmet@greencycle.com', '0xCourierWallet1Here', 'courier', 500),
  ('courier-002', 'Kurye Ayşe', 'ayse@greencycle.com', '0xCourierWallet2Here', 'courier', 600),
  ('user-001', 'Demo User', 'user@greencycle.com', '0xUserWallet1Here', 'user', 250)
ON CONFLICT (id) DO NOTHING;

-- Update existing courier records to link with user accounts
UPDATE couriers SET user_id = 'courier-001' WHERE id = '11111111-1111-1111-1111-111111111111';

