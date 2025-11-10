import { query } from '../db/client';
import { v4 as uuid } from 'uuid';

type UserRole = 'user' | 'courier' | 'admin';

export interface User {
  id: string;
  name: string;
  email: string | null;
  walletAddress: string;
  role: UserRole;
  greenPoints: number;
  createdAt: Date;
  updatedAt: Date;
}

type UserRow = {
  id: string;
  name: string;
  email: string | null;
  wallet_address: string;
  role: UserRole;
  green_points: number;
  created_at: Date;
  updated_at: Date;
};

function mapUser(row: UserRow): User {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    walletAddress: row.wallet_address,
    role: row.role,
    greenPoints: row.green_points,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function buildPlaceholderEmail(userId: string): string {
  const sanitized = userId.replace(/[^a-zA-Z0-9]/g, '').slice(0, 24);
  const suffix =
    sanitized ||
    uuid()
      .replace(/[^a-zA-Z0-9]/g, '')
      .slice(0, 12);
  return `user+${suffix}@example.com`;
}

export async function getUserByWallet(
  walletAddress: string
): Promise<User | null> {
  const { rows } = await query<UserRow>(
    'SELECT * FROM users WHERE wallet_address = $1 LIMIT 1',
    [walletAddress.toLowerCase()]
  );

  if (rows.length === 0) {
    return null;
  }

  return mapUser(rows[0]);
}

export async function getUserById(userId: string): Promise<User | null> {
  const { rows } = await query<UserRow>(
    'SELECT * FROM users WHERE id = $1 LIMIT 1',
    [userId]
  );

  if (rows.length === 0) {
    return null;
  }

  return mapUser(rows[0]);
}

export async function createOrUpdateUser(data: {
  walletAddress: string;
  name?: string;
  role?: UserRole;
}): Promise<User> {
  const walletLower = data.walletAddress.toLowerCase();
  const name = data.name || `User ${walletLower.substring(0, 8)}`;
  const role = data.role || 'user';
  const id = `user-${uuid()}`;
  const email = buildPlaceholderEmail(id);

  const { rows } = await query<UserRow>(
    `INSERT INTO users (id, name, email, wallet_address, role)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (wallet_address) 
     DO UPDATE SET 
       name = COALESCE(EXCLUDED.name, users.name),
       updated_at = NOW()
     RETURNING *`,
    [id, name, email, walletLower, role]
  );

  const user = mapUser(rows[0]);

  // Eğer rol courier ise ve courier kaydı yoksa otomatik oluştur
  if (user.role === 'courier') {
    await ensureCourierExists(user.id, user.name);
  }

  return user;
}

async function ensureCourierExists(
  userId: string,
  userName: string
): Promise<void> {
  const courierId = 'courier-' + userId.substring(5); // 'user-' kısmını çıkar

  await query(
    `INSERT INTO couriers (id, name, active, latitude, longitude, user_id)
     VALUES ($1, $2, TRUE, 41.0082, 28.9784, $3)
     ON CONFLICT (id) DO UPDATE SET
       user_id = EXCLUDED.user_id,
       name = EXCLUDED.name`,
    [courierId, userName + ' (Courier)', userId]
  );
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

export async function addGreenPoints(
  userId: string,
  points: number
): Promise<void> {
  await ensureUserExists(userId);
  await query(
    'UPDATE users SET green_points = green_points + $1 WHERE id = $2',
    [points, userId]
  );
}

export async function listUsersByRole(role: UserRole): Promise<User[]> {
  const { rows } = await query<UserRow>(
    'SELECT * FROM users WHERE role = $1 ORDER BY created_at DESC',
    [role]
  );

  return rows.map(mapUser);
}
