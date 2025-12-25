import { query } from "../db/client";
import { RecyclingLocation } from "../models";

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
    coordinates: {
      latitude: Number(row.latitude),
      longitude: Number(row.longitude),
    },
    acceptedMaterials:
      row.accepted_materials as RecyclingLocation["acceptedMaterials"],
  };
}

export async function upsertRecyclingLocation(
  location: RecyclingLocation
): Promise<RecyclingLocation> {
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

export async function findLocationById(
  id: string
): Promise<RecyclingLocation | null> {
  const { rows } = await query<RecyclingLocationRow>(
    "SELECT * FROM recycling_locations WHERE id = $1 LIMIT 1",
    [id]
  );

  if (rows.length === 0) {
    return null;
  }

  return mapLocation(rows[0]);
}

export async function findNearbyLocations(
  latitude: number,
  longitude: number,
  radiusKm: number
): Promise<RecyclingLocation[]> {
  const { rows } = await query<RecyclingLocationRow>(
    `SELECT *,
      (6371 * acos(
        cos(radians($1)) * cos(radians(latitude)) *
        cos(radians(longitude) - radians($2)) +
        sin(radians($1)) * sin(radians(latitude))
      )) AS distance
     FROM recycling_locations
     WHERE (6371 * acos(
        cos(radians($1)) * cos(radians(latitude)) *
        cos(radians(longitude) - radians($2)) +
        sin(radians($1)) * sin(radians(latitude))
      )) <= $3
     ORDER BY distance
     LIMIT 20`,
    [latitude, longitude, radiusKm]
  );

  return rows.map(mapLocation);
}

export async function listAllLocations(): Promise<RecyclingLocation[]> {
  const { rows } = await query<RecyclingLocationRow>(
    "SELECT * FROM recycling_locations ORDER BY name"
  );
  return rows.map(mapLocation);
}

export async function deleteLocation(id: string): Promise<boolean> {
  const { rowCount } = await query(
    "DELETE FROM recycling_locations WHERE id = $1",
    [id]
  );
  return (rowCount ?? 0) > 0;
}
