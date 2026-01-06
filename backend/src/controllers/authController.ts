import { Request, Response } from 'express';
import {
  createOrUpdateUser,
  getUserByWallet
} from '../repositories/usersRepository';
import { AuthenticatedRequest } from '../middleware/auth';

export async function login(req: Request, res: Response) {
  const { walletAddress, name } = req.body;

  if (!walletAddress) {
    return res.status(400).json({ message: 'Wallet address is required' });
  }

  try {
    let user = await getUserByWallet(walletAddress.toLowerCase());

    if (!user) {
      user = await createOrUpdateUser({
        walletAddress,
        name: name || undefined,
        role: 'user'
      });
    } else {
      if (user.role === 'courier') {
        await ensureCourierExistsForLogin(user.id, user.name);
      }
    }

    res.json({
      user: {
        id: user.id,
        name: user.name,
        walletAddress: user.walletAddress,
        role: user.role,
        greenPoints: user.greenPoints
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Login failed' });
  }
}

async function ensureCourierExistsForLogin(
  userId: string,
  userName: string
): Promise<void> {
  const { query } = await import('../db/client');
  const courierId = 'courier-' + userId.substring(5);

  await query(
    `INSERT INTO couriers (id, name, active, latitude, longitude, user_id)
     VALUES ($1, $2, TRUE, 41.0082, 28.9784, $3)
     ON CONFLICT (id) DO UPDATE SET
       user_id = EXCLUDED.user_id,
       name = EXCLUDED.name`,
    [courierId, userName + ' (Courier)', userId]
  );
}

export async function getProfile(req: AuthenticatedRequest, res: Response) {
  if (!req.user) {
    return res.status(401).json({ message: 'Unauthorized' });
  }

  res.json({
    user: {
      id: req.user.id,
      name: req.user.name,
      walletAddress: req.user.walletAddress,
      role: req.user.role
    }
  });
}
