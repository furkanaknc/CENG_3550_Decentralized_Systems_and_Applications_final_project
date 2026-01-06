import { Router, Request, Response } from "express";
import {
  listAvailableCoupons,
  purchaseCouponForUser,
  getUserPurchasedCoupons,
} from "../services/coupons";

const router = Router();

router.get("/", async (_req: Request, res: Response) => {
  try {
    const coupons = await listAvailableCoupons();
    res.json({ coupons });
  } catch (error) {
    console.error("Failed to fetch coupons:", error);
    res.status(500).json({ message: "Coupons could not be fetched" });
  }
});

router.post("/:id/purchase", async (req: Request, res: Response) => {
  try {
    const couponId = req.params.id;
    const userId = req.body.userId || req.headers["x-user-id"];

    if (!userId) {
      res.status(401).json({ message: "User ID is required" });
      return;
    }

    const result = await purchaseCouponForUser(userId as string, couponId);

    if (!result.success) {
      res.status(400).json({
        message: result.message,
        remainingPoints: result.remainingPoints,
      });
      return;
    }

    res.json({
      message: result.message,
      userCoupon: result.userCoupon,
      remainingPoints: result.remainingPoints,
    });
  } catch (error) {
    console.error("Failed to purchase coupon:", error);
    res.status(500).json({ message: "Coupon could not be purchased" });
  }
});

router.get("/my", async (req: Request, res: Response) => {
  try {
    const userId = req.query.userId || req.headers["x-user-id"];

    if (!userId) {
      res.status(401).json({ message: "User ID is required" });
      return;
    }

    const userCoupons = await getUserPurchasedCoupons(userId as string);
    res.json({ userCoupons });
  } catch (error) {
    console.error("Failed to fetch user coupons:", error);
    res.status(500).json({ message: "Coupons could not be fetched" });
  }
});

export default router;
