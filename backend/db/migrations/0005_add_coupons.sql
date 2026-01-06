-- Migration: Add coupons system
-- Kupon sistemi için tablolar

CREATE TABLE IF NOT EXISTS coupons (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  partner TEXT NOT NULL,
  discount_type TEXT NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
  discount_value NUMERIC NOT NULL,
  point_cost INTEGER NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_coupons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL REFERENCES users(id),
  coupon_id TEXT NOT NULL REFERENCES coupons(id),
  coupon_code TEXT NOT NULL,
  purchased_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  used_at TIMESTAMP WITH TIME ZONE,
  expires_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_user_coupons_user_id ON user_coupons(user_id);
CREATE INDEX IF NOT EXISTS idx_user_coupons_coupon_id ON user_coupons(coupon_id);

-- Seed: Örnek kuponlar
INSERT INTO coupons (id, name, description, partner, discount_type, discount_value, point_cost, is_active)
VALUES
  ('coupon-migros-10', 'Migros %10 İndirim', 'Tüm alışverişlerde geçerli %10 indirim', 'Migros', 'percentage', 10, 500, TRUE),
  ('coupon-a101-50', 'A101 50₺ Hediye Çeki', '50₺ değerinde alışveriş çeki', 'A101', 'fixed', 50, 750, TRUE),
  ('coupon-trendyol-100', 'Trendyol 100₺ İndirim', '250₺ ve üzeri alışverişlerde 100₺ indirim', 'Trendyol', 'fixed', 100, 1000, TRUE),
  ('coupon-bim-25', 'BİM 25₺ Hediye Çeki', '25₺ değerinde alışveriş çeki', 'BİM', 'fixed', 25, 400, TRUE),
  ('coupon-gratis-15', 'Gratis %15 İndirim', 'Kişisel bakım ürünlerinde %15 indirim', 'Gratis', 'percentage', 15, 600, TRUE),
  ('coupon-starbucks-free', 'Starbucks Ücretsiz İçecek', 'Tall boy içecek hediye', 'Starbucks', 'fixed', 35, 450, TRUE)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  partner = EXCLUDED.partner,
  discount_type = EXCLUDED.discount_type,
  discount_value = EXCLUDED.discount_value,
  point_cost = EXCLUDED.point_cost,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();
