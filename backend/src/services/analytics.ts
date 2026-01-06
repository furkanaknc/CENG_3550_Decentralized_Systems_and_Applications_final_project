import { CarbonReport, PickupRequest } from "../models";

export function estimateCarbonSavings(pickup: PickupRequest): CarbonReport {
  const baselineEmissionPerKm = 0.21;
  const optimizedEmissionPerKm = 0.08;
  const estimatedDistanceKm = 3;

  const baseline = baselineEmissionPerKm * estimatedDistanceKm;
  const optimized = optimizedEmissionPerKm * estimatedDistanceKm;

  return {
    pickupId: pickup.id,
    estimatedSavingKg: Number((baseline - optimized).toFixed(2))
  };
}

export function calculateGreenPoints(pickup: PickupRequest): number {
  const materialMultiplier: Record<string, number> = {
    plastic: 1,
    glass: 1.2,
    paper: 0.8,
    metal: 1.5,
    electronics: 2
  };

  const basePoints = pickup.weightKg * 10;
  const multiplier = materialMultiplier[pickup.material] ?? 1;
  return Math.round(basePoints * multiplier);
}
