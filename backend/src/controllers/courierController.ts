import { Request, Response } from 'express';
import { getCouriers, updateCourier } from '../repositories/couriersRepository';

export async function listCouriers(_req: Request, res: Response) {
  try {
    const couriers = await getCouriers();
    res.json({ couriers });
  } catch (error) {
    console.error('Failed to list couriers', error);
    res.status(500).json({ message: 'Unable to list couriers' });
  }
}

export async function updateCourierLocation(req: Request, res: Response) {
  const { id } = req.params;
  const { latitude, longitude, active } = req.body;

  try {
    const courier = await updateCourier(id, {
      latitude: typeof latitude === 'number' ? latitude : undefined,
      longitude: typeof longitude === 'number' ? longitude : undefined,
      active: typeof active === 'boolean' ? active : undefined
    });

    if (!courier) {
      return res.status(404).json({ message: 'Courier not found' });
    }

    res.json({ courier });
  } catch (error) {
    console.error('Failed to update courier', error);
    res.status(500).json({ message: 'Unable to update courier' });
  }
}
