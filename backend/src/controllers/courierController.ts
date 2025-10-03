import { Request, Response } from 'express';
import { Courier } from '../models';
import { v4 as uuid } from 'uuid';

const couriers: Courier[] = [
  {
    id: uuid(),
    name: 'Eco Kurye 1',
    active: true,
    currentLocation: { latitude: 41.0082, longitude: 28.9784 }
  }
];

export function listCouriers(_req: Request, res: Response) {
  res.json({ couriers });
}

export function updateCourierLocation(req: Request, res: Response) {
  const { id } = req.params;
  const { latitude, longitude, active } = req.body;

  const courier = couriers.find((c) => c.id === id);
  if (!courier) {
    return res.status(404).json({ message: 'Courier not found' });
  }

  if (typeof latitude === 'number' && typeof longitude === 'number') {
    courier.currentLocation = { latitude, longitude };
  }
  if (typeof active === 'boolean') {
    courier.active = active;
  }

  res.json({ courier });
}
