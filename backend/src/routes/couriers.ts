import { Router } from 'express';
import {
  listCouriers,
  updateCourierLocation,
  getPendingPickups,
  getMyPickups,
  acceptPickup,
  completePickupByCourier
} from '../controllers/courierController';
import { authenticateWallet, requireRole } from '../middleware/auth';

const router = Router();

// Public endpoints
router.get('/', listCouriers);

// Courier-only endpoints
router.get(
  '/pickups/pending',
  authenticateWallet,
  requireRole('courier', 'admin'),
  getPendingPickups
);
router.get(
  '/my-pickups',
  authenticateWallet,
  requireRole('courier', 'admin'),
  getMyPickups
);
router.post(
  '/pickups/:id/accept',
  (req, _res, next) => {
    next();
  },
  authenticateWallet,
  requireRole('courier', 'admin'),
  acceptPickup
);
router.post(
  '/pickups/:id/complete',
  authenticateWallet,
  requireRole('courier', 'admin'),
  completePickupByCourier
);
router.patch(
  '/:id',
  authenticateWallet,
  requireRole('courier', 'admin'),
  updateCourierLocation
);

export default router;
