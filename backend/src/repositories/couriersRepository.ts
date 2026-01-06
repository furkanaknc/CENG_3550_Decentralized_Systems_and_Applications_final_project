import { query } from '../db/client';
import { Courier } from '../models';

type CourierRow = {
  id: string;
  name: string;
  active: boolean;
  latitude: number | null;
  longitude: number | null;
  updated_at: Date;
  user_id: string | null;
  wallet_address?: string | null;
};

function mapCourier(row: CourierRow): Courier {
  const courier: Courier = {
    id: row.id,
    name: row.name,
    active: row.active,
    currentLocation:
      row.latitude !== null && row.longitude !== null
        ? { latitude: Number(row.latitude), longitude: Number(row.longitude) }
        : { latitude: 0, longitude: 0 }
  };

  if (row.user_id) {
    courier.userId = row.user_id;
  }

  if (row.wallet_address) {
    courier.walletAddress = row.wallet_address;
  }

  return courier;
}

export async function getCouriers(): Promise<Courier[]> {
  const { rows } = await query<CourierRow>(
    `SELECT c.*, u.wallet_address
     FROM couriers c
     LEFT JOIN users u ON u.id = c.user_id
     ORDER BY c.name ASC`
  );
  return rows.map(mapCourier);
}

export async function getCourierByUserId(userId: string): Promise<Courier | null> {
  const { rows } = await query<CourierRow>(
    `SELECT c.*, u.wallet_address
     FROM couriers c
     LEFT JOIN users u ON u.id = c.user_id
     WHERE c.user_id = $1
     LIMIT 1`,
    [userId]
  );

  if (rows.length === 0) {
    return null;
  }

  return mapCourier(rows[0]);
}

export async function getCourierByIdWithWallet(
  courierId: string
): Promise<Courier | null> {
  const { rows } = await query<CourierRow>(
    `SELECT c.*, u.wallet_address
     FROM couriers c
     LEFT JOIN users u ON u.id = c.user_id
     WHERE c.id = $1
     LIMIT 1`,
    [courierId]
  );

  if (rows.length === 0) {
    return null;
  }

  return mapCourier(rows[0]);
}

export async function updateCourier(
  id: string,
  updates: { latitude?: number; longitude?: number; active?: boolean }
): Promise<Courier | null> {
  const { latitude, longitude, active } = updates;

  const { rows } = await query<CourierRow>(
    `UPDATE couriers
     SET
       latitude = COALESCE($2, latitude),
       longitude = COALESCE($3, longitude),
       active = COALESCE($4, active),
       updated_at = NOW()
     WHERE id = $1
     RETURNING *`,
    [id, latitude ?? null, longitude ?? null, active ?? null]
  );

  if (rows.length === 0) {
    return null;
  }

  return mapCourier(rows[0]);
}
