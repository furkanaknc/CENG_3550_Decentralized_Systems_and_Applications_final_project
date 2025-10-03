import { Request, Response } from 'express';
import mapService from '../services/maps';
import { calculateGreenPoints, estimateCarbonSavings } from '../services/analytics';
import { PickupRequest } from '../models';
import { v4 as uuid } from 'uuid';
import { registerCompletedPickup } from './analyticsController';

const inMemoryPickups: PickupRequest[] = [];

export async function createPickup(req: Request, res: Response) {
  const { userId, material, weightKg, pickupLocation } = req.body;

  if (!userId || !material || !weightKg || !pickupLocation) {
    return res.status(400).json({ message: 'Missing pickup fields' });
  }

  const newPickup: PickupRequest = {
    id: uuid(),
    userId,
    material,
    weightKg,
    status: 'pending',
    pickupLocation,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };

  inMemoryPickups.push(newPickup);
  const locations = await mapService.findNearbyLocations(pickupLocation);

  return res.status(201).json({ pickup: newPickup, nearbyLocations: locations });
}

export async function assignCourier(req: Request, res: Response) {
  const { id } = req.params;
  const { courierId, dropoffLocation } = req.body;

  const pickup = inMemoryPickups.find((p) => p.id === id);
  if (!pickup) {
    return res.status(404).json({ message: 'Pickup not found' });
  }

  pickup.courierId = courierId;
  pickup.dropoffLocation = dropoffLocation;
  pickup.status = 'assigned';
  pickup.updatedAt = new Date().toISOString();

  const route = dropoffLocation
    ? await mapService.calculateRoute(pickup.pickupLocation, dropoffLocation.coordinates)
    : undefined;

  res.json({ pickup, route });
}

export function completePickup(req: Request, res: Response) {
  const { id } = req.params;
  const pickup = inMemoryPickups.find((p) => p.id === id);
  if (!pickup) {
    return res.status(404).json({ message: 'Pickup not found' });
  }

  pickup.status = 'completed';
  pickup.updatedAt = new Date().toISOString();

  const carbon = estimateCarbonSavings(pickup);
  const points = calculateGreenPoints(pickup);

  registerCompletedPickup(pickup);

  res.json({ pickup, carbon, points });
}

export function listPickups(_req: Request, res: Response) {
  res.json({ pickups: inMemoryPickups });
}
