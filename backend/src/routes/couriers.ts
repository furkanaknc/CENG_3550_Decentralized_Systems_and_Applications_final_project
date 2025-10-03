import { Router } from 'express';
import { listCouriers, updateCourierLocation } from '../controllers/courierController';

const router = Router();

router.get('/', listCouriers);
router.patch('/:id', updateCourierLocation);

export default router;
