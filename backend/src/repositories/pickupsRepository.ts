import { query } from "../db/client";
import { Coordinates, PickupRequest, RecyclingLocation } from "../models";
import {
  findLocationById,
  upsertRecyclingLocation,
} from "./recyclingLocationsRepository";

type PickupRow = {
  id: string;
  user_id: string;
  courier_id: string | null;
  material: PickupRequest["material"];
  weight_kg: number;
  status: PickupRequest["status"];
  pickup_latitude: number;
  pickup_longitude: number;
  dropoff_location: string | null;
  created_at: Date;
  updated_at: Date;
  dropoff_name: string | null;
  dropoff_latitude: number | null;
  dropoff_longitude: number | null;
  dropoff_accepted_materials: string[] | null;
  neighborhood: string | null;
  district: string | null;
  city: string | null;
  street: string | null;
  building: string | null;
};

function mapPickup(row: PickupRow): PickupRequest {
  const pickup: PickupRequest = {
    id: row.id,
    userId: row.user_id,
    courierId: row.courier_id ?? undefined,
    material: row.material,
    weightKg: Number(row.weight_kg),
    status: row.status,
    pickupLocation: toCoordinates(row.pickup_latitude, row.pickup_longitude),
    createdAt: row.created_at.toISOString(),
    updatedAt: row.updated_at.toISOString(),
    address: {
      neighborhood: row.neighborhood ?? undefined,
      district: row.district ?? undefined,
      city: row.city ?? undefined,
      street: row.street ?? undefined,
      building: row.building ?? undefined,
    },
  };

  if (
    row.dropoff_location &&
    row.dropoff_name &&
    row.dropoff_latitude !== null &&
    row.dropoff_longitude !== null
  ) {
    pickup.dropoffLocation = {
      id: row.dropoff_location,
      name: row.dropoff_name,
      coordinates: toCoordinates(row.dropoff_latitude, row.dropoff_longitude),
      acceptedMaterials: (row.dropoff_accepted_materials ||
        []) as RecyclingLocation["acceptedMaterials"],
    };
  }

  return pickup;
}

function toCoordinates(latitude: number, longitude: number): Coordinates {
  return { latitude: Number(latitude), longitude: Number(longitude) };
}

async function hydratePickup(row: PickupRow): Promise<PickupRequest> {
  if (!row.dropoff_location || row.dropoff_name) {
    return mapPickup(row);
  }

  const location = await findLocationById(row.dropoff_location);
  const pickup = mapPickup(row);
  if (location) {
    pickup.dropoffLocation = location;
  }
  return pickup;
}

export async function getPickupById(id: string): Promise<PickupRequest | null> {
  const { rows } = await query<PickupRow>(
    `SELECT p.*, rl.name as dropoff_name, rl.latitude as dropoff_latitude, rl.longitude as dropoff_longitude,
            rl.accepted_materials as dropoff_accepted_materials
     FROM pickups p
     LEFT JOIN recycling_locations rl ON rl.id = p.dropoff_location
     WHERE p.id = $1
     LIMIT 1`,
    [id]
  );

  if (rows.length === 0) {
    return null;
  }

  return mapPickup(rows[0]);
}

export async function createPickup(pickup: {
  id: string;
  userId: string;
  material: PickupRequest["material"];
  weightKg: number;
  pickupLocation: Coordinates;
  address?: {
    neighborhood?: string;
    district?: string;
    city?: string;
    street?: string;
    building?: string;
  };
}): Promise<PickupRequest> {
  const { id, userId, material, weightKg, pickupLocation, address } = pickup;

  await query(
    `INSERT INTO pickups (id, user_id, material, weight_kg, pickup_latitude, pickup_longitude, neighborhood, district, city, street, building)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
    [
      id,
      userId,
      material,
      weightKg,
      pickupLocation.latitude,
      pickupLocation.longitude,
      address?.neighborhood ?? null,
      address?.district ?? null,
      address?.city ?? null,
      address?.street ?? null,
      address?.building ?? null,
    ]
  );

  const created = await getPickupById(id);
  if (!created) {
    throw new Error("Failed to create pickup");
  }

  return created;
}

export async function assignCourierToPickup(
  pickupId: string,
  courierId: string,
  dropoff?: RecyclingLocation
) {
  let locationId: string | null = null;

  if (dropoff) {
    await upsertRecyclingLocation(dropoff);
    locationId = dropoff.id;
  }

  await query(
    `UPDATE pickups
     SET courier_id = $2,
         dropoff_location = COALESCE($3, dropoff_location),
         status = 'assigned',
         updated_at = NOW()
     WHERE id = $1`,
    [pickupId, courierId, locationId]
  );

  const updated = await getPickupById(pickupId);
  if (!updated) {
    throw new Error("Failed to load pickup after assignment");
  }

  return updated;
}

export async function completePickup(
  pickupId: string
): Promise<PickupRequest | null> {
  const { rows } = await query<PickupRow>(
    `UPDATE pickups
     SET status = 'completed',
         updated_at = NOW()
     WHERE id = $1
     RETURNING *`,
    [pickupId]
  );

  if (rows.length === 0) {
    return null;
  }

  return hydratePickup(rows[0]);
}

export async function listPickups(): Promise<PickupRequest[]> {
  const { rows } = await query<PickupRow>(
    `SELECT p.*, rl.name as dropoff_name, rl.latitude as dropoff_latitude, rl.longitude as dropoff_longitude,
            rl.accepted_materials as dropoff_accepted_materials
     FROM pickups p
     LEFT JOIN recycling_locations rl ON rl.id = p.dropoff_location
     ORDER BY p.created_at DESC`
  );

  return rows.map(mapPickup);
}

export async function listPickupsByStatus(
  status: PickupRequest["status"]
): Promise<PickupRequest[]> {
  const { rows } = await query<PickupRow>(
    `SELECT p.*, rl.name as dropoff_name, rl.latitude as dropoff_latitude, rl.longitude as dropoff_longitude,
            rl.accepted_materials as dropoff_accepted_materials
     FROM pickups p
     LEFT JOIN recycling_locations rl ON rl.id = p.dropoff_location
     WHERE p.status = $1
     ORDER BY p.created_at DESC`,
    [status]
  );

  return rows.map(mapPickup);
}

export async function listCompletedPickups(): Promise<PickupRequest[]> {
  const { rows } = await query<PickupRow>(
    `SELECT p.*, rl.name as dropoff_name, rl.latitude as dropoff_latitude, rl.longitude as dropoff_longitude,
            rl.accepted_materials as dropoff_accepted_materials
     FROM pickups p
     LEFT JOIN recycling_locations rl ON rl.id = p.dropoff_location
     WHERE p.status = 'completed'
     ORDER BY p.updated_at DESC`
  );

  return rows.map(mapPickup);
}

export async function saveCarbonReport(
  pickupId: string,
  estimatedSavingKg: number
): Promise<void> {
  await query(
    `INSERT INTO carbon_reports (pickup_id, estimated_saving_kg)
     VALUES ($1, $2)
     ON CONFLICT (pickup_id) DO UPDATE SET
       estimated_saving_kg = EXCLUDED.estimated_saving_kg,
       generated_at = NOW()`,
    [pickupId, estimatedSavingKg]
  );
}
