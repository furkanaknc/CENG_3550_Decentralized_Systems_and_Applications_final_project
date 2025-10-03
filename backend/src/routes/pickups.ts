import { Router } from 'express';
import {
  assignCourier,
  completePickup,
  createPickup,
  listPickups
} from '../controllers/pickupController';

const router = Router();

router.get('/', listPickups);
router.post('/', createPickup);
router.post('/:id/assign', assignCourier);
router.post('/:id/complete', completePickup);

export default router;
