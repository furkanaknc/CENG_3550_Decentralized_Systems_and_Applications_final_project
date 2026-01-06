import { PickupRequest } from '../models';
import { calculateGreenPoints, estimateCarbonSavings } from '../services/analytics';

type Aggregate = {
  totalWeight: number;
  totalPoints: number;
  totalCarbon: number;
};

export function aggregateMetrics(pickups: PickupRequest[]): Aggregate {
  return pickups.reduce(
    (acc, pickup) => {
      acc.totalWeight += pickup.weightKg;
      acc.totalPoints += calculateGreenPoints(pickup);
      acc.totalCarbon += estimateCarbonSavings(pickup).estimatedSavingKg;
      return acc;
    },
    { totalWeight: 0, totalPoints: 0, totalCarbon: 0 }
  );
}
