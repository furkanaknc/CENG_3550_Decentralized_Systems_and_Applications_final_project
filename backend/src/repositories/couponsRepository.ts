import { query } from "../db/client";
import { v4 as uuid } from "uuid";

export interface Coupon {
  id: string;
  name: string;
  description: string | null;
  partner: string;
  discountType: "percentage" | "fixed";
  discountValue: number;
  pointCost: number;
  isActive: boolean;
  imageUrl: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface UserCoupon {
  id: string;
  userId: string;
  couponId: string;
  couponCode: string;
  purchasedAt: Date;
  usedAt: Date | null;
  expiresAt: Date | null;
  coupon?: Coupon;
}

type CouponRow = {
  id: string;
  name: string;
  description: string | null;
  partner: string;
  discount_type: "percentage" | "fixed";
  discount_value: string;
  point_cost: number;
  is_active: boolean;
  image_url: string | null;
  created_at: Date;
  updated_at: Date;
};

type UserCouponRow = {
  id: string;
  user_id: string;
  coupon_id: string;
  coupon_code: string;
  purchased_at: Date;
  used_at: Date | null;
  expires_at: Date | null;
};

function mapCoupon(row: CouponRow): Coupon {
  return {
    id: row.id,
    name: row.name,
    description: row.description,
    partner: row.partner,
    discountType: row.discount_type,
    discountValue: parseFloat(row.discount_value),
    pointCost: row.point_cost,
    isActive: row.is_active,
    imageUrl: row.image_url,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function mapUserCoupon(row: UserCouponRow & Partial<CouponRow>): UserCoupon {
  const userCoupon: UserCoupon = {
    id: row.id,
    userId: row.user_id,
    couponId: row.coupon_id,
    couponCode: row.coupon_code,
    purchasedAt: row.purchased_at,
    usedAt: row.used_at,
    expiresAt: row.expires_at,
  };

  if (row.name) {
    userCoupon.coupon = mapCoupon(row as CouponRow);
  }

  return userCoupon;
}

function generateCouponCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  for (let i = 0; i < 12; i++) {
    if (i > 0 && i % 4 === 0) code += "-";
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

export async function getAllCoupons(activeOnly = true): Promise<Coupon[]> {
  const sql = activeOnly
    ? "SELECT * FROM coupons WHERE is_active = TRUE ORDER BY point_cost ASC"
    : "SELECT * FROM coupons ORDER BY point_cost ASC";

  const { rows } = await query<CouponRow>(sql);
  return rows.map(mapCoupon);
}

export async function getCouponById(couponId: string): Promise<Coupon | null> {
  const { rows } = await query<CouponRow>(
    "SELECT * FROM coupons WHERE id = $1 LIMIT 1",
    [couponId]
  );

  if (rows.length === 0) return null;
  return mapCoupon(rows[0]);
}

export async function createCoupon(data: {
  name: string;
  description?: string;
  partner: string;
  discountType: "percentage" | "fixed";
  discountValue: number;
  pointCost: number;
  imageUrl?: string;
}): Promise<Coupon> {
  const id = `coupon-${uuid().substring(0, 8)}`;

  const { rows } = await query<CouponRow>(
    `INSERT INTO coupons (id, name, description, partner, discount_type, discount_value, point_cost, image_url)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [
      id,
      data.name,
      data.description || null,
      data.partner,
      data.discountType,
      data.discountValue,
      data.pointCost,
      data.imageUrl || null,
    ]
  );

  return mapCoupon(rows[0]);
}

export async function updateCoupon(
  couponId: string,
  data: Partial<{
    name: string;
    description: string;
    partner: string;
    discountType: "percentage" | "fixed";
    discountValue: number;
    pointCost: number;
    isActive: boolean;
    imageUrl: string;
  }>
): Promise<Coupon | null> {
  const updates: string[] = [];
  const values: unknown[] = [];
  let paramIndex = 1;

  if (data.name !== undefined) {
    updates.push(`name = $${paramIndex++}`);
    values.push(data.name);
  }
  if (data.description !== undefined) {
    updates.push(`description = $${paramIndex++}`);
    values.push(data.description);
  }
  if (data.partner !== undefined) {
    updates.push(`partner = $${paramIndex++}`);
    values.push(data.partner);
  }
  if (data.discountType !== undefined) {
    updates.push(`discount_type = $${paramIndex++}`);
    values.push(data.discountType);
  }
  if (data.discountValue !== undefined) {
    updates.push(`discount_value = $${paramIndex++}`);
    values.push(data.discountValue);
  }
  if (data.pointCost !== undefined) {
    updates.push(`point_cost = $${paramIndex++}`);
    values.push(data.pointCost);
  }
  if (data.isActive !== undefined) {
    updates.push(`is_active = $${paramIndex++}`);
    values.push(data.isActive);
  }
  if (data.imageUrl !== undefined) {
    updates.push(`image_url = $${paramIndex++}`);
    values.push(data.imageUrl);
  }

  if (updates.length === 0) {
    return getCouponById(couponId);
  }

  updates.push("updated_at = NOW()");
  values.push(couponId);

  const { rows } = await query<CouponRow>(
    `UPDATE coupons SET ${updates.join(
      ", "
    )} WHERE id = $${paramIndex} RETURNING *`,
    values
  );

  if (rows.length === 0) return null;
  return mapCoupon(rows[0]);
}

export async function deleteCoupon(couponId: string): Promise<boolean> {
  const { rowCount } = await query("DELETE FROM coupons WHERE id = $1", [
    couponId,
  ]);
  return (rowCount ?? 0) > 0;
}

export async function purchaseCoupon(
  userId: string,
  couponId: string
): Promise<UserCoupon> {
  const couponCode = generateCouponCode();
  const expiresAt = new Date();
  expiresAt.setMonth(expiresAt.getMonth() + 3);

  const { rows } = await query<UserCouponRow>(
    `INSERT INTO user_coupons (user_id, coupon_id, coupon_code, expires_at)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [userId, couponId, couponCode, expiresAt]
  );

  return mapUserCoupon(rows[0]);
}

export async function getUserCoupons(userId: string): Promise<UserCoupon[]> {
  const { rows } = await query<UserCouponRow & CouponRow>(
    `SELECT uc.*, c.name, c.description, c.partner, c.discount_type, c.discount_value, 
            c.point_cost, c.is_active, c.image_url, c.created_at, c.updated_at
     FROM user_coupons uc
     JOIN coupons c ON c.id = uc.coupon_id
     WHERE uc.user_id = $1
     ORDER BY uc.purchased_at DESC`,
    [userId]
  );

  return rows.map(mapUserCoupon);
}

export async function markCouponAsUsed(
  userCouponId: string,
  userId: string
): Promise<boolean> {
  const { rowCount } = await query(
    `UPDATE user_coupons SET used_at = NOW() WHERE id = $1 AND user_id = $2 AND used_at IS NULL`,
    [userCouponId, userId]
  );
  return (rowCount ?? 0) > 0;
}
