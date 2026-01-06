import { Request, Response } from "express";
import { v4 as uuid } from "uuid";
import mapService from "../services/maps";
import {
  createPickup as createPickupRecord,
  getPickupById,
  listPickups as listPickupRecords,
} from "../repositories/pickupsRepository";
import { ensureUserExists, getUserById } from "../repositories/usersRepository";
import { getCourierByIdWithWallet } from "../repositories/couriersRepository";
import {
  assignCourierAndSync,
  completePickupAndReward,
} from "../services/pickupLifecycle";
import { isBlockchainConfigured } from "../services/blockchain";
import { parseCourierApprovalPayload } from "../utils/courierApproval";

export async function createPickup(req: Request, res: Response) {
  const { userId, material, weightKg, pickupLocation, address } = req.body;

  if (!userId || !material || !weightKg || !pickupLocation) {
    return res.status(400).json({ message: "Missing pickup fields" });
  }

  const coordinates = pickupLocation.coordinates || pickupLocation;

  if (!coordinates.latitude || !coordinates.longitude) {
    return res.status(400).json({ message: "Missing pickup coordinates" });
  }

  try {
    const pickupId = uuid();
    await ensureUserExists(userId);
    const pickup = await createPickupRecord({
      id: pickupId,
      userId,
      material,
      weightKg,
      pickupLocation: coordinates,
      address: address || undefined,
    });
    const locations = await mapService.findNearbyLocations(coordinates);

    return res.status(201).json({
      pickup,
      nearbyLocations: locations,
    });
  } catch (error) {
    console.error("Failed to create pickup", error);
    return res.status(500).json({ message: "Pickup could not be created" });
  }
}

export async function assignCourier(req: Request, res: Response) {
  const { id } = req.params;
  const { courierId, dropoffLocation } = req.body;

  if (!courierId) {
    return res.status(400).json({ message: "courierId is required" });
  }

  if (
    dropoffLocation &&
    (!dropoffLocation.id ||
      !dropoffLocation.coordinates ||
      dropoffLocation.coordinates.latitude === undefined ||
      dropoffLocation.coordinates.longitude === undefined)
  ) {
    return res
      .status(400)
      .json({ message: "dropoffLocation requires id and coordinates" });
  }

  let courierApproval;

  try {
    courierApproval = parseCourierApprovalPayload(req.body?.courierApproval);
  } catch (error) {
    return res.status(400).json({ message: (error as Error).message });
  }

  try {
    const pickup = await getPickupById(id);
    if (!pickup) {
      return res.status(404).json({ message: "Pickup not found" });
    }

    const courier = await getCourierByIdWithWallet(courierId);
    if (!courier) {
      return res.status(404).json({ message: "Courier not found" });
    }

    const user = await getUserById(pickup.userId);
    const userWallet = user?.walletAddress;

    if (isBlockchainConfigured()) {
      if (!userWallet) {
        return res.status(400).json({
          message:
            "Pickup owner must have a wallet address for blockchain sync",
        });
      }

      if (!courier.walletAddress) {
        return res.status(400).json({
          message: "Courier must have a wallet address for blockchain sync",
        });
      }
    }

    const { pickup: updatedPickup, blockchain } = await assignCourierAndSync(
      pickup,
      { id: courier.id, walletAddress: courier.walletAddress },
      userWallet,
      dropoffLocation,
      courierApproval
    );

    const route = dropoffLocation
      ? await mapService.calculateRoute(
          updatedPickup.pickupLocation,
          dropoffLocation.coordinates
        )
      : undefined;

    res.json({ pickup: updatedPickup, route, blockchain });
  } catch (error) {
    console.error("Failed to assign courier", error);
    res.status(500).json({ message: "Unable to assign courier" });
  }
}

export async function completePickup(req: Request, res: Response) {
  const { id } = req.params;

  let courierApproval;

  try {
    courierApproval = parseCourierApprovalPayload(req.body?.courierApproval);
  } catch (error) {
    return res.status(400).json({ message: (error as Error).message });
  }

  try {
    const pickup = await getPickupById(id);
    if (!pickup) {
      return res.status(404).json({ message: "Pickup not found" });
    }

    const user = await getUserById(pickup.userId);
    const courierWallet = pickup.courierId
      ? (await getCourierByIdWithWallet(pickup.courierId))?.walletAddress
      : undefined;

    if (isBlockchainConfigured() && !user?.walletAddress) {
      return res.status(400).json({
        message: "Pickup owner must have a wallet address for blockchain sync",
      });
    }

    const {
      pickup: completedPickup,
      carbon,
      points,
      blockchain,
    } = await completePickupAndReward(
      pickup,
      user?.walletAddress,
      courierWallet,
      courierApproval
    );

    res.json({ pickup: completedPickup, carbon, points, blockchain });
  } catch (error) {
    console.error("Failed to complete pickup", error);
    res.status(500).json({ message: "Unable to complete pickup" });
  }
}

export function listPickups(_req: Request, res: Response) {
  listPickupRecords()
    .then((pickups) => res.json({ pickups }))
    .catch((error) => {
      console.error("Failed to list pickups", error);
      res.status(500).json({ message: "Unable to list pickups" });
    });
}
