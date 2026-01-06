import { Router } from "express";
import { authenticateWallet, requireRole } from "../middleware/auth";
import {
  getDashboard,
  getUsers,
  updateRole,
  removeUser,
  getAllPickups,
  getAllCouriers,
  getMaterialWeights,
  updateMaterialWeight,
  getBlockchainStatsEndpoint,
  syncUserRole,
  getLocations,
  createLocation,
  removeLocation,
  getCoupons,
  addCoupon,
  editCoupon,
  removeCoupon,
} from "../controllers/adminController";

const router = Router();

router.use(authenticateWallet);
router.use(requireRole("admin"));

router.get("/dashboard", getDashboard);

router.get("/users", getUsers);
router.patch("/users/:id/role", updateRole);
router.delete("/users/:id", removeUser);

router.get("/pickups", getAllPickups);

router.get("/couriers", getAllCouriers);

router.get("/locations", getLocations);
router.post("/locations", createLocation);
router.delete("/locations/:id", removeLocation);

router.get("/blockchain/stats", getBlockchainStatsEndpoint);
router.get("/blockchain/materials", getMaterialWeights);
router.put("/blockchain/materials/:name", updateMaterialWeight);
router.post("/blockchain/sync-role/:userId", syncUserRole);

router.get("/coupons", getCoupons);
router.post("/coupons", addCoupon);
router.patch("/coupons/:id", editCoupon);
router.delete("/coupons/:id", removeCoupon);

export default router;
