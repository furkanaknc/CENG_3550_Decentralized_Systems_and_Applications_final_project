import { Request, Response } from 'express';
import mapService from '../services/maps';
import {
  calculateGreenPoints,
  estimateCarbonSavings
} from '../services/analytics';
import { v4 as uuid } from 'uuid';
import {
  assignCourierToPickup,
  completePickup as completePickupRecord,
  createPickup as createPickupRecord,
  getPickupById,
  listPickups as listPickupRecords,
  saveCarbonReport
} from '../repositories/pickupsRepository';
import {
  ensureUserExists,
  addGreenPoints
} from '../repositories/usersRepository';
import { getCouriers } from '../repositories/couriersRepository';

export async function createPickup(req: Request, res: Response) {
  const { userId, material, weightKg, pickupLocation } = req.body;

  if (!userId || !material || !weightKg || !pickupLocation) {
    return res.status(400).json({ message: 'Missing pickup fields' });
  }

  // pickupLocation.coordinates yapısından coordinates'i çıkar
  const coordinates = pickupLocation.coordinates || pickupLocation;

  if (!coordinates.latitude || !coordinates.longitude) {
    return res.status(400).json({ message: 'Missing pickup coordinates' });
  }

  try {
    const pickupId = uuid();
    await ensureUserExists(userId);
    const pickup = await createPickupRecord({
      id: pickupId,
      userId,
      material,
      weightKg,
      pickupLocation: coordinates
    });
    const locations = await mapService.findNearbyLocations(coordinates);

    return res.status(201).json({ pickup, nearbyLocations: locations });
  } catch (error) {
    console.error('Failed to create pickup', error);
    return res.status(500).json({ message: 'Pickup could not be created' });
  }
}

export async function assignCourier(req: Request, res: Response) {
  const { id } = req.params;
  const { courierId, dropoffLocation } = req.body;

  if (!courierId) {
    return res.status(400).json({ message: 'courierId is required' });
  }

  if (
    dropoffLocation &&
    (!dropoffLocation.id ||
      !dropoffLocation.coordinates ||
      dropoffLocation.coordinates.latitude === undefined ||
      dropoffLocation.coordinates.longitude === undefined)
  ) {
    return res
      .status(400)
      .json({ message: 'dropoffLocation requires id and coordinates' });
  }

  try {
    const pickup = await getPickupById(id);
    if (!pickup) {
      return res.status(404).json({ message: 'Pickup not found' });
    }

    const couriers = await getCouriers();
    const courierExists = couriers.some((courier) => courier.id === courierId);
    if (!courierExists) {
      return res.status(404).json({ message: 'Courier not found' });
    }

    const updatedPickup = await assignCourierToPickup(
      id,
      courierId,
      dropoffLocation
    );

    const route = dropoffLocation
      ? await mapService.calculateRoute(
          updatedPickup.pickupLocation,
          dropoffLocation.coordinates
        )
      : undefined;

    res.json({ pickup: updatedPickup, route });
  } catch (error) {
    console.error('Failed to assign courier', error);
    res.status(500).json({ message: 'Unable to assign courier' });
  }
}

export async function completePickup(req: Request, res: Response) {
  const { id } = req.params;

  try {
    const pickup = await completePickupRecord(id);
    if (!pickup) {
      return res.status(404).json({ message: 'Pickup not found' });
    }

    const carbon = estimateCarbonSavings(pickup);
    const points = calculateGreenPoints(pickup);

    await saveCarbonReport(pickup.id, carbon.estimatedSavingKg);
    await addGreenPoints(pickup.userId, points);

    res.json({ pickup, carbon, points });
  } catch (error) {
    console.error('Failed to complete pickup', error);
    res.status(500).json({ message: 'Unable to complete pickup' });
  }
}

export function listPickups(_req: Request, res: Response) {
  listPickupRecords()
    .then((pickups) => res.json({ pickups }))
    .catch((error) => {
      console.error('Failed to list pickups', error);
      res.status(500).json({ message: 'Unable to list pickups' });
    });
}
