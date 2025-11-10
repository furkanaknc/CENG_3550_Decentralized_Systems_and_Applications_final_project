import type { PickupRequest, RecyclingLocation } from '../models';
import {
  assignCourierToPickup,
  completePickup as completePickupRecord,
  saveCarbonReport
} from '../repositories/pickupsRepository';
import { addGreenPoints } from '../repositories/usersRepository';
import {
  isBlockchainConfigured,
  OnChainActionResult,
  syncPickupAssignment,
  syncPickupCompletion
} from './blockchain';
import { calculateGreenPoints, estimateCarbonSavings } from './analytics';

export interface CourierContext {
  id: string;
  walletAddress?: string;
}

export interface AssignmentResult {
  pickup: PickupRequest;
  blockchain?: OnChainActionResult;
}

export interface CompletionResult {
  pickup: PickupRequest;
  blockchain?: OnChainActionResult;
  points: number;
  carbon: { pickupId: string; estimatedSavingKg: number };
}

export async function assignCourierAndSync(
  pickup: PickupRequest,
  courier: CourierContext,
  userWallet?: string,
  dropoff?: RecyclingLocation
): Promise<AssignmentResult> {
  if (isBlockchainConfigured()) {
    if (!userWallet) {
      throw new Error('User wallet address is required to sync pickup assignment to blockchain');
    }

    if (!courier.walletAddress) {
      throw new Error('Courier wallet address is required to sync pickup assignment to blockchain');
    }
  }

  const blockchain = await syncPickupAssignment(
    pickup,
    userWallet,
    courier.walletAddress
  );

  const updatedPickup = await assignCourierToPickup(
    pickup.id,
    courier.id,
    dropoff
  );

  return { pickup: updatedPickup, blockchain };
}

export async function completePickupAndReward(
  pickup: PickupRequest,
  userWallet?: string,
  courierWallet?: string
): Promise<CompletionResult> {
  if (isBlockchainConfigured() && !userWallet) {
    throw new Error('User wallet address is required to finalize pickup on blockchain');
  }

  const blockchain = await syncPickupCompletion(
    pickup,
    userWallet,
    courierWallet
  );

  const completedPickup = await completePickupRecord(pickup.id);
  if (!completedPickup) {
    throw new Error(`Pickup ${pickup.id} could not be marked as completed`);
  }

  const carbon = estimateCarbonSavings(completedPickup);
  const points = calculateGreenPoints(completedPickup);

  await saveCarbonReport(completedPickup.id, carbon.estimatedSavingKg);
  await addGreenPoints(completedPickup.userId, points);

  return { pickup: completedPickup, blockchain, points, carbon };
}
