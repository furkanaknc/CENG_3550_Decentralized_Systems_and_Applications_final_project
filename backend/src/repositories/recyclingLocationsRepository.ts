import { query } from '../db/client';
import { RecyclingLocation } from '../models';

type RecyclingLocationRow = {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  accepted_materials: string[];
};

function mapLocation(row: RecyclingLocationRow): RecyclingLocation {
  return {
    id: row.id,
    name: row.name,
    coordinates: { latitude: Number(row.latitude), longitude: Number(row.longitude) },
    acceptedMaterials: row.accepted_materials as RecyclingLocation['acceptedMaterials']
  };
}

export async function upsertRecyclingLocation(location: RecyclingLocation): Promise<RecyclingLocation> {
  const { id, name, coordinates, acceptedMaterials } = location;

  await query(
    `INSERT INTO recycling_locations (id, name, latitude, longitude, accepted_materials)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (id) DO UPDATE SET
       name = EXCLUDED.name,
       latitude = EXCLUDED.latitude,
       longitude = EXCLUDED.longitude,
       accepted_materials = EXCLUDED.accepted_materials`,
    [id, name, coordinates.latitude, coordinates.longitude, acceptedMaterials]
  );

  return location;
}

export async function findLocationById(id: string): Promise<RecyclingLocation | null> {
  const { rows } = await query<RecyclingLocationRow>(
    'SELECT * FROM recycling_locations WHERE id = $1 LIMIT 1',
    [id]
  );

  if (rows.length === 0) {
    return null;
  }

  return mapLocation(rows[0]);
}
