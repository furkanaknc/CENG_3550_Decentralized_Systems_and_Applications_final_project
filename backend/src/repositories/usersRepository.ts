import { query } from '../db/client';
import { v4 as uuid } from 'uuid';

function buildPlaceholderEmail(userId: string): string {
  const sanitized = userId.replace(/[^a-zA-Z0-9]/g, '').slice(0, 24);
  const suffix = sanitized || uuid().replace(/[^a-zA-Z0-9]/g, '').slice(0, 12);
  return `user+${suffix}@example.com`;
}

export async function ensureUserExists(userId: string): Promise<void> {
  const placeholderEmail = buildPlaceholderEmail(userId);
  const placeholderName = `Kullanıcı ${userId.substring(0, 8) || 'Anonim'}`;

  await query(
    `INSERT INTO users (id, name, email)
     VALUES ($1, $2, $3)
     ON CONFLICT (id) DO NOTHING`,
    [userId, placeholderName, placeholderEmail]
  );
}

export async function addGreenPoints(userId: string, points: number): Promise<void> {
  await ensureUserExists(userId);
  await query('UPDATE users SET green_points = green_points + $1 WHERE id = $2', [points, userId]);
}
