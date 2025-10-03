import { Router } from 'express';
import { getNearbyRecyclingCenters, reverseGeocode, searchAddress } from '../controllers/mapController';

const router = Router();

router.get('/search', searchAddress);
router.get('/reverse', reverseGeocode);
router.get('/recycling-centers', getNearbyRecyclingCenters);

export default router;
