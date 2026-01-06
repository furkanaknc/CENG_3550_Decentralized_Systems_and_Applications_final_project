import {
  Coupon,
  UserCoupon,
  getAllCoupons,
  getCouponById,
  purchaseCoupon as repoPurchaseCoupon,
  getUserCoupons as repoGetUserCoupons,
} from "../repositories/couponsRepository";
import {
  getGreenPoints,
  deductGreenPoints,
  getUserById,
} from "../repositories/usersRepository";

export interface PurchaseResult {
  success: boolean;
  userCoupon?: UserCoupon;
  message: string;
  remainingPoints?: number;
}

export async function listAvailableCoupons(): Promise<Coupon[]> {
  return getAllCoupons(true);
}

export async function purchaseCouponForUser(
  userId: string,
  couponId: string
): Promise<PurchaseResult> {
  const user = await getUserById(userId);
  if (!user) {
    return { success: false, message: "User not found" };
  }

  const coupon = await getCouponById(couponId);
  if (!coupon) {
    return { success: false, message: "Coupon not found" };
  }

  if (!coupon.isActive) {
    return { success: false, message: "Coupon is not active" };
  }

  const currentPoints = await getGreenPoints(userId);
  if (currentPoints < coupon.pointCost) {
    return {
      success: false,
      message: `Insufficient points. Required: ${coupon.pointCost}, Current: ${currentPoints}`,
      remainingPoints: currentPoints,
    };
  }

  const deducted = await deductGreenPoints(userId, coupon.pointCost);
  if (!deducted) {
    return {
      success: false,
      message: "Points deduction failed, please try again",
    };
  }

  const userCoupon = await repoPurchaseCoupon(userId, couponId);
  const remainingPoints = currentPoints - coupon.pointCost;

  return {
    success: true,
    userCoupon,
    message: `${coupon.name} successfully purchased!`,
    remainingPoints,
  };
}

export async function getUserPurchasedCoupons(
  userId: string
): Promise<UserCoupon[]> {
  return repoGetUserCoupons(userId);
}
