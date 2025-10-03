import { Request, Response } from 'express';
import { calculateGreenPoints, estimateCarbonSavings } from '../services/analytics';
import { PickupRequest } from '../models';

// Placeholder dataset for analytics endpoints
const completedPickups: PickupRequest[] = [];

export function registerCompletedPickup(pickup: PickupRequest) {
  completedPickups.push(pickup);
}

export function getAnalytics(_req: Request, res: Response) {
  const totals = completedPickups.reduce(
    (acc, pickup) => {
      acc.totalWeight += pickup.weightKg;
      acc.totalPoints += calculateGreenPoints(pickup);
      acc.totalCarbon += estimateCarbonSavings(pickup).estimatedSavingKg;
      return acc;
    },
    { totalWeight: 0, totalPoints: 0, totalCarbon: 0 }
  );

  res.json({
    ...totals,
    pickups: completedPickups.length
  });
}
