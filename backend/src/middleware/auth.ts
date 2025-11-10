import { Request, Response, NextFunction } from 'express';
import { getUserByWallet } from '../repositories/usersRepository';

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    walletAddress: string;
    role: 'user' | 'courier' | 'admin';
    name: string;
  };
}

/**
 * Middleware to authenticate requests using wallet address
 * Expects 'x-wallet-address' header
 */
export async function authenticateWallet(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  const walletAddress = req.headers['x-wallet-address'] as string;

  if (!walletAddress) {
    res.status(401).json({ message: 'Wallet address required' });
    return;
  }

  try {
    const user = await getUserByWallet(walletAddress.toLowerCase());

    if (!user) {
      res.status(401).json({ message: 'User not found' });
      return;
    }

    req.user = user;
    next();
  } catch (error) {
    console.error('Authentication error:', error);
    res.status(500).json({ message: 'Authentication failed' });
  }
}

/**
 * Middleware to check if user has required role
 */
export function requireRole(...allowedRoles: Array<'user' | 'courier' | 'admin'>) {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({ message: 'Authentication required' });
      return;
    }

    if (!allowedRoles.includes(req.user.role)) {
      res.status(403).json({ 
        message: `Access denied. Required role: ${allowedRoles.join(' or ')}` 
      });
      return;
    }

    next();
  };
}

/**
 * Optional authentication - attaches user if wallet provided but doesn't fail
 */
export async function optionalAuth(
  req: AuthenticatedRequest,
  _res: Response,
  next: NextFunction
): Promise<void> {
  const walletAddress = req.headers['x-wallet-address'] as string;

  if (walletAddress) {
    try {
      const user = await getUserByWallet(walletAddress.toLowerCase());
      if (user) {
        req.user = user;
      }
    } catch (error) {
      console.error('Optional auth error:', error);
    }
  }

  next();
}

