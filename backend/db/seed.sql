-- Seed data for recycling locations
INSERT INTO recycling_locations (id, name, latitude, longitude, accepted_materials)
VALUES
  ('demo-besiktas', 'Beşiktaş Geri Dönüşüm Merkezi', 41.0438, 29.0027, ARRAY['plastic', 'glass', 'paper', 'metal']),
  ('demo-kadikoy', 'Kadıköy Ayrıştırma Tesisi', 40.9889, 29.0250, ARRAY['plastic', 'glass', 'paper']),
  ('demo-uskudar', 'Üsküdar Geri Kazanım Noktası', 41.0245, 29.0151, ARRAY['plastic', 'paper', 'metal']),
  ('demo-sisli', 'Şişli Geri Dönüşüm Merkezi', 41.0607, 28.9873, ARRAY['plastic', 'glass', 'paper', 'metal', 'electronics'])
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  accepted_materials = EXCLUDED.accepted_materials;

