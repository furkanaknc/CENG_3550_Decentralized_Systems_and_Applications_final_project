import { Request, Response } from 'express';
import { aggregateMetrics } from '../jobs/metricAggregator';
import { listCompletedPickups } from '../repositories/pickupsRepository';

export async function getAnalytics(_req: Request, res: Response) {
  try {
    const pickups = await listCompletedPickups();
    const totals = aggregateMetrics(pickups);

    res.json({
      ...totals,
      pickups: pickups.length
    });
  } catch (error) {
    console.error('Failed to load analytics', error);
    res.status(500).json({ message: 'Unable to load analytics' });
  }
}
