import { Response } from 'express';
import {
  getCouriers,
  updateCourier,
  getCourierByUserId,
  getCourierByIdWithWallet
} from '../repositories/couriersRepository';
import {
  listPickupsByStatus,
  getPickupById
} from '../repositories/pickupsRepository';
import { AuthenticatedRequest } from '../middleware/auth';
import { getUserById } from '../repositories/usersRepository';
import {
  assignCourierAndSync,
  completePickupAndReward
} from '../services/pickupLifecycle';
import { isBlockchainConfigured } from '../services/blockchain';

export async function listCouriers(_req: AuthenticatedRequest, res: Response) {
  try {
    const couriers = await getCouriers();
    res.json({ couriers });
  } catch (error) {
    console.error('Failed to list couriers', error);
    res.status(500).json({ message: 'Unable to list couriers' });
  }
}

export async function updateCourierLocation(
  req: AuthenticatedRequest,
  res: Response
) {
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

export async function getPendingPickups(
  _req: AuthenticatedRequest,
  res: Response
) {
  try {
    const pickups = await listPickupsByStatus('pending');
    res.json({ pickups });
  } catch (error) {
    console.error('Failed to list pending pickups', error);
    res.status(500).json({ message: 'Unable to list pending pickups' });
  }
}

export async function getMyPickups(req: AuthenticatedRequest, res: Response) {
  if (!req.user) {
    return res.status(401).json({ message: 'Unauthorized' });
  }

  try {
    // Get courier ID from user
    const courier = await getCourierByUserId(req.user.id);

    if (!courier) {
      return res.status(404).json({ message: 'Courier profile not found' });
    }

    // Get all pickups assigned to this courier
    const { query } = await import('../db/client');
    const { rows } = await query(
      `SELECT 
        p.id,
        p.user_id,
        p.material,
        p.weight_kg as "weightKg",
        p.status,
        p.pickup_latitude as latitude,
        p.pickup_longitude as longitude,
        p.created_at as "createdAt",
        p.updated_at as "updatedAt"
      FROM pickups p
      WHERE p.courier_id = $1
        AND p.status IN ('assigned', 'completed')
      ORDER BY 
        CASE 
          WHEN p.status = 'assigned' THEN 1
          WHEN p.status = 'completed' THEN 2
        END,
        p.updated_at DESC`,
      [courier.id]
    );

    const pickups = rows.map((row: any) => ({
      id: row.id,
      userId: row.user_id,
      material: row.material,
      weightKg: Number(row.weightKg),
      status: row.status,
      pickupLocation: {
        latitude: Number(row.latitude),
        longitude: Number(row.longitude)
      },
      createdAt: row.createdAt,
      updatedAt: row.updatedAt
    }));

    res.json({ pickups });
  } catch (error) {
    console.error('Failed to list my pickups', error);
    res.status(500).json({ message: 'Unable to list my pickups' });
  }
}

export async function acceptPickup(req: AuthenticatedRequest, res: Response) {
  const { id: pickupId } = req.params;

  if (!req.user) {
    return res.status(401).json({ message: 'Unauthorized' });
  }

  try {
    const courier = await getCourierByUserId(req.user.id);

    if (!courier) {
      console.error('❌ No courier found for user_id:', req.user.id);
      return res.status(404).json({
        message: 'Courier profile not found',
        debug: {
          userId: req.user.id,
          walletAddress: req.user.walletAddress
        }
      });
    }

    const pickup = await getPickupById(pickupId);

    if (!pickup) {
      return res.status(404).json({ message: 'Pickup not found' });
    }

    const pickupOwner = await getUserById(pickup.userId);
    const userWallet = pickupOwner?.walletAddress;
    const courierWallet = courier.walletAddress || req.user.walletAddress;

    if (isBlockchainConfigured()) {
      if (!userWallet) {
        return res.status(400).json({
          message: 'Pickup owner must have a wallet address for blockchain sync'
        });
      }

      if (!courierWallet) {
        return res.status(400).json({
          message: 'Courier must have a wallet address for blockchain sync'
        });
      }
    }

    const { pickup: updatedPickup, blockchain } = await assignCourierAndSync(
      pickup,
      { id: courier.id, walletAddress: courierWallet },
      userWallet
    );

    res.json({
      message: 'Pickup accepted successfully',
      pickup: updatedPickup,
      blockchain
    });
  } catch (error) {
    console.error('Failed to accept pickup', error);
    res.status(500).json({ message: 'Unable to accept pickup' });
  }
}

export async function completePickupByCourier(
  req: AuthenticatedRequest,
  res: Response
) {
  const { id: pickupId } = req.params;

  if (!req.user) {
    return res.status(401).json({ message: 'Unauthorized' });
  }

  try {
    const pickup = await getPickupById(pickupId);

    if (!pickup) {
      return res.status(404).json({ message: 'Pickup not found' });
    }

    const pickupOwner = await getUserById(pickup.userId);
    const courierWallet = pickup.courierId
      ? (await getCourierByIdWithWallet(pickup.courierId))?.walletAddress ||
        req.user.walletAddress
      : req.user.walletAddress;

    if (isBlockchainConfigured() && !pickupOwner?.walletAddress) {
      return res.status(400).json({
        message: 'Pickup owner must have a wallet address for blockchain sync'
      });
    }

    const { pickup: completedPickup, carbon, points, blockchain } =
      await completePickupAndReward(
        pickup,
        pickupOwner?.walletAddress,
        courierWallet
      );

    res.json({
      message: 'Pickup completed successfully',
      pickup: completedPickup,
      carbon,
      points,
      blockchain
    });
  } catch (error) {
    console.error('Failed to complete pickup', error);
    res.status(500).json({ message: 'Unable to complete pickup' });
  }
}
