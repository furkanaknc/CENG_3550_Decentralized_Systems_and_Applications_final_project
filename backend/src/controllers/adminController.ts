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
  getUserRoleOnChain,
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

// ============ Location Management ============

import {
  listAllLocations,
  upsertRecyclingLocation,
  deleteLocation,
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
