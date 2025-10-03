import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import { newDb } from 'pg-mem';

const db = newDb({ autoCreateForeignKeyIndices: true });
const pgMem = db.adapters.createPg();

jest.mock('pg', () => pgMem);

import { query, shutdownPool } from '../src/db/client';
import { ensureUserExists, addGreenPoints } from '../src/repositories/usersRepository';
import { getCouriers, updateCourier } from '../src/repositories/couriersRepository';
import {
  assignCourierToPickup,
  completePickup,
  createPickup,
  listCompletedPickups,
  saveCarbonReport
} from '../src/repositories/pickupsRepository';
import { findLocationById } from '../src/repositories/recyclingLocationsRepository';
import type { RecyclingLocation } from '../src/models';

const migrationPath = resolve(__dirname, '../db/migrations/0001_init.sql');
let migrationSql = readFileSync(migrationPath, 'utf-8');
// pg-mem does not support DO blocks, strip the migration guard for enum creation.
migrationSql = migrationSql.replace(/DO \$\$[\s\S]*?\$\$;/g, '');

const defaultCourier = {
  id: 'courier-1',
  name: 'Eco Courier',
  latitude: 41.01,
  longitude: 28.97
};

beforeAll(() => {
  db.public.registerEnum('pickup_status', ['pending', 'assigned', 'completed']);
  db.public.none(migrationSql);
});

beforeEach(async () => {
  await query('DELETE FROM carbon_reports');
  await query('DELETE FROM pickups');
  await query('DELETE FROM recycling_locations');
  await query('DELETE FROM couriers');
  await query('DELETE FROM users');

  await query(
    'INSERT INTO couriers (id, name, active, latitude, longitude) VALUES ($1, $2, TRUE, $3, $4)',
    [defaultCourier.id, defaultCourier.name, defaultCourier.latitude, defaultCourier.longitude]
  );
});

afterAll(async () => {
  await shutdownPool();
});

describe('repository integration with PostgreSQL', () => {
  it('creates placeholder users once when ensuring existence', async () => {
    await ensureUserExists('user-123');
    await ensureUserExists('user-123');

    const { rows } = await query<{ email: string }>('SELECT email FROM users WHERE id = $1', ['user-123']);
    expect(rows).toHaveLength(1);
    expect(rows[0].email).toMatch(/user\+.+@example\.com/);
  });

  it('increments green points for users', async () => {
    await addGreenPoints('user-456', 10);
    await addGreenPoints('user-456', 5);

    const { rows } = await query<{ green_points: number }>(
      'SELECT green_points FROM users WHERE id = $1',
      ['user-456']
    );

    expect(rows[0].green_points).toBe(15);
  });

  it('lists and updates couriers with their latest location', async () => {
    const couriers = await getCouriers();
    expect(couriers).toHaveLength(1);
    expect(couriers[0]).toMatchObject({ id: defaultCourier.id, name: defaultCourier.name, active: true });

    const updated = await updateCourier(defaultCourier.id, { latitude: 41.05, longitude: 29.02, active: false });
    expect(updated).not.toBeNull();
    expect(updated?.active).toBe(false);
    expect(updated?.currentLocation).toEqual({ latitude: 41.05, longitude: 29.02 });
  });

  it('creates pickups with pending status and timestamp metadata', async () => {
    const pickupId = randomUUID();

    const created = await createPickup({
      id: pickupId,
      userId: 'user-789',
      material: 'plastic',
      weightKg: 3.5,
      pickupLocation: { latitude: 41.08, longitude: 29.01 }
    });

    expect(created.id).toBe(pickupId);
    expect(created.status).toBe('pending');
    expect(created.createdAt).toBeTruthy();
    expect(created.updatedAt).toBeTruthy();
    expect(created.courierId).toBeUndefined();
  });

  it('assigns couriers and persists recycling drop-off locations', async () => {
    const pickupId = randomUUID();
    await createPickup({
      id: pickupId,
      userId: 'user-321',
      material: 'glass',
      weightKg: 4,
      pickupLocation: { latitude: 41.09, longitude: 29.05 }
    });

    const dropoff: RecyclingLocation = {
      id: 'recycle-1',
      name: 'Kadikoy Recycling',
      coordinates: { latitude: 40.98, longitude: 29.03 },
      acceptedMaterials: ['glass', 'plastic']
    };

    const assigned = await assignCourierToPickup(pickupId, defaultCourier.id, dropoff);

    expect(assigned.status).toBe('assigned');
    expect(assigned.courierId).toBe(defaultCourier.id);
    expect(assigned.dropoffLocation).toMatchObject({ id: dropoff.id, name: dropoff.name });

    const storedLocation = await findLocationById(dropoff.id);
    expect(storedLocation).not.toBeNull();
    expect(storedLocation).toMatchObject({
      id: dropoff.id,
      acceptedMaterials: ['glass', 'plastic']
    });
  });

  it('completes pickups and keeps drop-off association', async () => {
    const pickupId = randomUUID();
    await createPickup({
      id: pickupId,
      userId: 'user-654',
      material: 'paper',
      weightKg: 2,
      pickupLocation: { latitude: 41.0, longitude: 29.1 }
    });

    const dropoff: RecyclingLocation = {
      id: 'recycle-2',
      name: 'Besiktas Recycling',
      coordinates: { latitude: 41.05, longitude: 29.01 },
      acceptedMaterials: ['paper']
    };

    await assignCourierToPickup(pickupId, defaultCourier.id, dropoff);
    const completed = await completePickup(pickupId);

    expect(completed).not.toBeNull();
    expect(completed?.status).toBe('completed');
    expect(completed?.dropoffLocation?.id).toBe(dropoff.id);
  });

  it('lists only completed pickups', async () => {
    const completedId = randomUUID();
    await createPickup({
      id: completedId,
      userId: 'user-000',
      material: 'metal',
      weightKg: 6,
      pickupLocation: { latitude: 41.12, longitude: 29.02 }
    });
    await assignCourierToPickup(completedId, defaultCourier.id);
    await completePickup(completedId);

    const pendingId = randomUUID();
    await createPickup({
      id: pendingId,
      userId: 'user-999',
      material: 'electronics',
      weightKg: 1.2,
      pickupLocation: { latitude: 41.13, longitude: 29.04 }
    });

    const completed = await listCompletedPickups();
    expect(completed).toHaveLength(1);
    expect(completed[0].id).toBe(completedId);
  });

  it('upserts carbon reports for pickups', async () => {
    const pickupId = randomUUID();
    await createPickup({
      id: pickupId,
      userId: 'user-carbon',
      material: 'plastic',
      weightKg: 1.5,
      pickupLocation: { latitude: 41.2, longitude: 29.0 }
    });

    await saveCarbonReport(pickupId, 12.4);
    await saveCarbonReport(pickupId, 15.1);

    const { rows } = await query<{ estimated_saving_kg: number }>(
      'SELECT estimated_saving_kg FROM carbon_reports WHERE pickup_id = $1',
      [pickupId]
    );

    expect(rows[0].estimated_saving_kg).toBeCloseTo(15.1);
  });
});
