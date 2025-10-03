import { calculateGreenPoints, estimateCarbonSavings } from '../src/services/analytics';
import { aggregateMetrics } from '../src/jobs/metricAggregator';
import { PickupRequest } from '../src/models';

describe('Analytics services', () => {
  const basePickup: PickupRequest = {
    id: 'pickup-1',
    userId: 'user-1',
    material: 'plastic',
    weightKg: 2,
    status: 'completed',
    pickupLocation: { latitude: 41.0, longitude: 29.0 },
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };

  it('calculates green points based on material multipliers', () => {
    expect(calculateGreenPoints(basePickup)).toBe(20);
    expect(
      calculateGreenPoints({ ...basePickup, id: 'pickup-2', material: 'electronics', weightKg: 1 })
    ).toBe(20);
  });

  it('estimates carbon savings for pickups', () => {
    const report = estimateCarbonSavings(basePickup);
    expect(report.pickupId).toBe(basePickup.id);
    expect(report.estimatedSavingKg).toBeGreaterThan(0);
  });

  it('aggregates metrics for reporting jobs', () => {
    const totals = aggregateMetrics([
      basePickup,
      { ...basePickup, id: 'pickup-3', material: 'metal', weightKg: 3 }
    ]);

    expect(totals.totalWeight).toBeCloseTo(5);
    expect(totals.totalPoints).toBeGreaterThan(20);
    expect(totals.totalCarbon).toBeGreaterThan(0);
  });
});
