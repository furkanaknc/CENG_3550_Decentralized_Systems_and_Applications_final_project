INSERT INTO couriers (id, name, active, latitude, longitude, user_id)
SELECT 
  'courier-' || SUBSTRING(u.id FROM 6), 
  u.name || ' (Courier)',
  TRUE,
  41.0082,  
  28.9784,
  u.id
FROM users u
WHERE u.role = 'courier'
  AND NOT EXISTS (
    SELECT 1 FROM couriers c WHERE c.user_id = u.id
  );

SELECT 
  u.id as user_id,
  u.name as user_name,
  u.wallet_address,
  u.role,
  c.id as courier_id,
  CASE 
    WHEN c.id IS NULL THEN '❌ Courier kaydı yok!'
    ELSE '✅ Courier kaydı var'
  END as status
FROM users u
LEFT JOIN couriers c ON c.user_id = u.id
WHERE u.role = 'courier';

