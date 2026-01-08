import { Response } from "express";
import { AuthenticatedRequest } from "../middleware/auth";
import {
  listAllUsers,
  updateUserRole,
  deleteUser,
  getUserById,
} from "../repositories/usersRepository";
import { listPickups } from "../repositories/pickupsRepository";
import { getCouriers } from "../repositories/couriersRepository";
import {
  getAllMaterialWeights,
  setMaterialWeight,
  getBlockchainStats,
  assignRoleOnChain,
} from "../services/adminBlockchain";
import { isBlockchainConfigured } from "../services/blockchain";

export async function getDashboard(req: AuthenticatedRequest, res: Response) {
  try {
    const [users, pickups, couriers, blockchainStats] = await Promise.all([
      listAllUsers(),
      listPickups(),
      getCouriers(),
      getBlockchainStats(),
    ]);

    const stats = {
      users: {
        total: users.length,
        byRole: {
          user: users.filter((u) => u.role === "user").length,
          courier: users.filter((u) => u.role === "courier").length,
          admin: users.filter((u) => u.role === "admin").length,
        },
      },
      pickups: {
        total: pickups.length,
        pending: pickups.filter((p) => p.status === "pending").length,
        assigned: pickups.filter((p) => p.status === "assigned").length,
        completed: pickups.filter((p) => p.status === "completed").length,
      },
      couriers: {
        total: couriers.length,
        active: couriers.filter((c) => c.active).length,
      },
      blockchain: blockchainStats,
    };

    res.json({ stats });
  } catch (error) {
    console.error("Failed to get dashboard:", error);
    res.status(500).json({ message: "Failed to load dashboard" });
  }
}

export async function getUsers(req: AuthenticatedRequest, res: Response) {
  try {
    const users = await listAllUsers();
    res.json({ users });
  } catch (error) {
    console.error("Failed to list users:", error);
    res.status(500).json({ message: "Failed to list users" });
  }
}

export async function updateRole(req: AuthenticatedRequest, res: Response) {
  const { id } = req.params;
  const { role, syncBlockchain } = req.body;

  if (!["user", "courier", "admin"].includes(role)) {
    return res.status(400).json({ message: "Invalid role" });
  }

  if (req.user && req.user.id === id) {
    return res.status(403).json({ message: "You cannot change your own role" });
  }

  try {
    const user = await updateUserRole(id, role);

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    let blockchainResult = null;

    if (syncBlockchain && isBlockchainConfigured() && user.walletAddress) {
      try {
        const chainRole =
          role === "user" ? "User" : role === "courier" ? "Courier" : "Admin";
        blockchainResult = await assignRoleOnChain(
          user.walletAddress,
          chainRole
        );
      } catch (blockchainError) {
        console.error("Blockchain role sync failed:", blockchainError);
        blockchainResult = { error: "Blockchain sync failed" };
      }
    }

    res.json({
      message: "Role updated successfully",
      user,
      blockchain: blockchainResult,
    });
  } catch (error) {
    console.error("Failed to update role:", error);
    res.status(500).json({ message: "Failed to update role" });
  }
}

export async function removeUser(req: AuthenticatedRequest, res: Response) {
  const { id } = req.params;

  if (req.user?.id === id) {
    return res.status(400).json({ message: "Cannot delete your own account" });
  }

  try {
    const deleted = await deleteUser(id);

    if (!deleted) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json({ message: "User deleted successfully" });
  } catch (error) {
    console.error("Failed to delete user:", error);
    res.status(500).json({ message: "Failed to delete user" });
  }
}

export async function getAllPickups(req: AuthenticatedRequest, res: Response) {
  try {
    const pickups = await listPickups();

    const pickupsWithUsers = await Promise.all(
      pickups.map(async (pickup) => {
        const user = await getUserById(pickup.userId);
        return {
          ...pickup,
          userName: user?.name || "Unknown",
          userWallet: user?.walletAddress,
        };
      })
    );

    res.json({ pickups: pickupsWithUsers });
  } catch (error) {
    console.error("Failed to list pickups:", error);
    res.status(500).json({ message: "Failed to list pickups" });
  }
}

export async function getAllCouriers(req: AuthenticatedRequest, res: Response) {
  try {
    const couriers = await getCouriers();
    res.json({ couriers });
  } catch (error) {
    console.error("Failed to list couriers:", error);
    res.status(500).json({ message: "Failed to list couriers" });
  }
}

export async function getMaterialWeights(
  req: AuthenticatedRequest,
  res: Response
) {
  try {
    if (!isBlockchainConfigured()) {
      return res.status(503).json({ message: "Blockchain not configured" });
    }

    const weights = await getAllMaterialWeights();
    res.json({ materials: weights });
  } catch (error) {
    console.error("Failed to get material weights:", error);
    res.status(500).json({ message: "Failed to get material weights" });
  }
}

export async function updateMaterialWeight(
  req: AuthenticatedRequest,
  res: Response
) {
  const { name } = req.params;
  const { weight } = req.body;

  if (typeof weight !== "number" || weight < 0 || weight > 255) {
    return res
      .status(400)
      .json({ message: "Weight must be a number between 0 and 255" });
  }

  try {
    if (!isBlockchainConfigured()) {
      return res.status(503).json({ message: "Blockchain not configured" });
    }

    const result = await setMaterialWeight(name, weight);
    res.json({
      message: "Material weight updated on blockchain",
      ...result,
    });
  } catch (error) {
    console.error("Failed to update material weight:", error);
    res.status(500).json({ message: "Failed to update material weight" });
  }
}

export async function getBlockchainStatsEndpoint(
  req: AuthenticatedRequest,
  res: Response
) {
  try {
    const stats = await getBlockchainStats();
    res.json(stats);
  } catch (error) {
    console.error("Failed to get blockchain stats:", error);
    res.status(500).json({ message: "Failed to get blockchain stats" });
  }
}

export async function syncUserRole(req: AuthenticatedRequest, res: Response) {
  const { userId } = req.params;

  try {
    if (!isBlockchainConfigured()) {
      return res.status(503).json({ message: "Blockchain not configured" });
    }

    const user = await getUserById(userId);

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    if (!user.walletAddress) {
      return res.status(400).json({ message: "User has no wallet address" });
    }

    const chainRole =
      user.role === "user"
        ? "User"
        : user.role === "courier"
        ? "Courier"
        : "Admin";
    const result = await assignRoleOnChain(user.walletAddress, chainRole);

    res.json({
      message: "Role synced to blockchain",
      user: {
        id: user.id,
        name: user.name,
        role: user.role,
      },
      blockchain: result,
    });
  } catch (error) {
    console.error("Failed to sync role:", error);
    res.status(500).json({ message: "Failed to sync role to blockchain" });
  }
}

import {
  listAllLocations,
  upsertRecyclingLocation,
  deleteLocation,
  findLocationById,
} from "../repositories/recyclingLocationsRepository";
import type { RecyclingLocation } from "../models";
import { v4 as uuid } from "uuid";

export async function getLocations(req: AuthenticatedRequest, res: Response) {
  try {
    const locations = await listAllLocations();
    res.json({ locations });
  } catch (error) {
    console.error("Failed to list locations:", error);
    res.status(500).json({ message: "Failed to list locations" });
  }
}

export async function createLocation(req: AuthenticatedRequest, res: Response) {
  const { name, latitude, longitude, acceptedMaterials } = req.body;

  if (!name || typeof latitude !== "number" || typeof longitude !== "number") {
    return res.status(400).json({
      message: "Name, latitude, and longitude are required",
    });
  }

  const materials = acceptedMaterials || ["plastic", "glass", "paper", "metal"];

  try {
    const location: RecyclingLocation = {
      id: `loc-${uuid()}`,
      name,
      coordinates: { latitude, longitude },
      acceptedMaterials: materials,
    };

    await upsertRecyclingLocation(location);

    res.status(201).json({
      message: "Location created successfully",
      location,
    });
  } catch (error) {
    console.error("Failed to create location:", error);
    res.status(500).json({ message: "Failed to create location" });
  }
}

export async function removeLocation(req: AuthenticatedRequest, res: Response) {
  const { id } = req.params;

  try {
    const deleted = await deleteLocation(id);

    if (!deleted) {
      return res.status(404).json({ message: "Location not found" });
    }

    res.json({ message: "Location deleted successfully" });
  } catch (error) {
    console.error("Failed to delete location:", error);
    res.status(500).json({ message: "Failed to delete location" });
  }
}

export async function updateLocation(req: AuthenticatedRequest, res: Response) {
  const { id } = req.params;
  const { name, acceptedMaterials } = req.body;

  try {
    const existing = await findLocationById(id);

    if (!existing) {
      return res.status(404).json({ message: "Location not found" });
    }

    const updatedLocation: RecyclingLocation = {
      id,
      name: name ?? existing.name,
      coordinates: existing.coordinates,
      acceptedMaterials: acceptedMaterials ?? existing.acceptedMaterials,
    };

    await upsertRecyclingLocation(updatedLocation);

    res.json({
      message: "Location updated successfully",
      location: updatedLocation,
    });
  } catch (error) {
    console.error("Failed to update location:", error);
    res.status(500).json({ message: "Failed to update location" });
  }
}

import {
  getAllCoupons,
  createCoupon,
  updateCoupon,
  deleteCoupon,
} from "../repositories/couponsRepository";

export async function getCoupons(req: AuthenticatedRequest, res: Response) {
  try {
    const coupons = await getAllCoupons(false);
    res.json({ coupons });
  } catch (error) {
    console.error("Failed to list coupons:", error);
    res.status(500).json({ message: "Failed to list coupons" });
  }
}

export async function addCoupon(req: AuthenticatedRequest, res: Response) {
  const {
    name,
    description,
    partner,
    discountType,
    discountValue,
    pointCost,
    imageUrl,
  } = req.body;

  if (
    !name ||
    !partner ||
    !discountType ||
    discountValue === undefined ||
    pointCost === undefined
  ) {
    return res.status(400).json({
      message:
        "Name, partner, discountType, discountValue, and pointCost are required",
    });
  }

  if (!["percentage", "fixed"].includes(discountType)) {
    return res
      .status(400)
      .json({ message: "discountType must be 'percentage' or 'fixed'" });
  }

  try {
    const coupon = await createCoupon({
      name,
      description,
      partner,
      discountType,
      discountValue,
      pointCost,
      imageUrl,
    });

    res.status(201).json({
      message: "Coupon created successfully",
      coupon,
    });
  } catch (error) {
    console.error("Failed to create coupon:", error);
    res.status(500).json({ message: "Failed to create coupon" });
  }
}

export async function editCoupon(req: AuthenticatedRequest, res: Response) {
  const { id } = req.params;
  const {
    name,
    description,
    partner,
    discountType,
    discountValue,
    pointCost,
    isActive,
    imageUrl,
  } = req.body;

  try {
    const coupon = await updateCoupon(id, {
      name,
      description,
      partner,
      discountType,
      discountValue,
      pointCost,
      isActive,
      imageUrl,
    });

    if (!coupon) {
      return res.status(404).json({ message: "Coupon not found" });
    }

    res.json({
      message: "Coupon updated successfully",
      coupon,
    });
  } catch (error) {
    console.error("Failed to update coupon:", error);
    res.status(500).json({ message: "Failed to update coupon" });
  }
}

export async function removeCoupon(req: AuthenticatedRequest, res: Response) {
  const { id } = req.params;

  try {
    const deleted = await deleteCoupon(id);

    if (!deleted) {
      return res.status(404).json({ message: "Coupon not found" });
    }

    res.json({ message: "Coupon deleted successfully" });
  } catch (error) {
    console.error("Failed to delete coupon:", error);
    res.status(500).json({ message: "Failed to delete coupon" });
  }
}
