import { Router } from "express";
import {
  getNearbyRecyclingCenters,
  getAllRecyclingCenters,
  reverseGeocode,
  searchAddress,
} from "../controllers/mapController";

const router = Router();

router.get("/search", searchAddress);
router.get("/reverse", reverseGeocode);
router.get("/nearby", getNearbyRecyclingCenters);
router.get("/all", getAllRecyclingCenters);

export default router;
