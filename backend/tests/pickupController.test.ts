import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { newDb } from 'pg-mem';
import request from 'supertest';

const db = newDb({ autoCreateForeignKeyIndices: true });
const pgMem = db.adapters.createPg();

jest.mock('pg', () => pgMem);

jest.mock('../src/services/maps', () => ({
  __esModule: true,
  default: {
    findNearbyLocations: jest.fn(),
    calculateRoute: jest.fn(),
  },
}));

import app from '../src/index';
import { query, shutdownPool } from '../src/db/client';
import type { Coordinates, RecyclingLocation } from '../src/models';

const migrationPath = resolve(__dirname, '../db/migrations/0001_init.sql');
let migrationSql = readFileSync(migrationPath, 'utf-8');
migrationSql = migrationSql.replace(/DO \$\$[\s\S]*?\$\$;/g, '');

type MockedMapService = {
  findNearbyLocations: jest.Mock<Promise<RecyclingLocation[]>, [Coordinates, number?]>;
  calculateRoute: jest.Mock;
};

const mockedMapService = require('../src/services/maps').default as MockedMapService;

beforeAll(async () => {
  db.public.registerEnum('pickup_status', ['pending', 'assigned', 'completed']);
  db.public.none(migrationSql);
  db.public.none(
    `ALTER TABLE users ADD COLUMN wallet_address TEXT;
     ALTER TABLE couriers ADD COLUMN user_id TEXT;`
  );
});

beforeEach(async () => {
  mockedMapService.findNearbyLocations.mockResolvedValue([
    {
      id: 'demo-1',
      name: 'Test Recycling',
      coordinates: { latitude: 41.02, longitude: 29.0 },
      acceptedMaterials: ['plastic', 'metal'],
    },
  ]);

  await query('DELETE FROM carbon_reports');
  await query('DELETE FROM pickups');
  await query('DELETE FROM recycling_locations');
  await query('DELETE FROM couriers');
  await query('DELETE FROM users');

  await query(
    'INSERT INTO couriers (id, name, active, latitude, longitude) VALUES ($1, $2, TRUE, $3, $4)',
    ['test-courier', 'Test Courier', 41.01, 29.02],
  );
});

afterEach(() => {
  jest.clearAllMocks();
});

afterAll(async () => {
  await shutdownPool();
});

describe('pickup controller', () => {
  it('creates pickup requests and returns nearby locations', async () => {
    const payload = {
      userId: 'mobile-user',
      material: 'plastic',
      weightKg: 4.5,
      pickupLocation: {
        coordinates: {
          latitude: 41.05,
          longitude: 29.03,
        },
      },
    };

    const response = await request(app).post('/api/pickups').send(payload);

    expect(response.status).toBe(201);
    expect(response.body.pickup).toBeDefined();
    expect(response.body.pickup.status).toBe('pending');
    expect(response.body.pickup.pickupLocation).toMatchObject({
      latitude: payload.pickupLocation.coordinates.latitude,
      longitude: payload.pickupLocation.coordinates.longitude,
    });
    expect(response.body.nearbyLocations).toHaveLength(1);
    expect(mockedMapService.findNearbyLocations).toHaveBeenCalledWith(
      payload.pickupLocation.coordinates,
    );

    const { rows } = await query<{ status: string }>('SELECT status FROM pickups');
    expect(rows).toHaveLength(1);
    expect(rows[0].status).toBe('pending');
  });

  it('rejects pickup requests without coordinates', async () => {
    const response = await request(app).post('/api/pickups').send({
      userId: 'mobile-user',
      material: 'glass',
      weightKg: 3,
    });

    expect(response.status).toBe(400);
    expect(response.body).toMatchObject({ message: 'Missing pickup fields' });
  });
});
