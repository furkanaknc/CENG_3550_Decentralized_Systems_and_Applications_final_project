import { query } from '../db/client';
import { Courier } from '../models';

type CourierRow = {
  id: string;
  name: string;
  active: boolean;
  latitude: number | null;
  longitude: number | null;
  updated_at: Date;
};

function mapCourier(row: CourierRow): Courier {
  return {
    id: row.id,
    name: row.name,
    active: row.active,
    currentLocation:
      row.latitude !== null && row.longitude !== null
        ? { latitude: Number(row.latitude), longitude: Number(row.longitude) }
        : { latitude: 0, longitude: 0 }
  };
}

export async function getCouriers(): Promise<Courier[]> {
  const { rows } = await query<CourierRow>('SELECT * FROM couriers ORDER BY name ASC');
  return rows.map(mapCourier);
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
