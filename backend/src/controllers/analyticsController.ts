import { Request, Response } from "express";
import { aggregateMetrics } from "../jobs/metricAggregator";
import {
  listCompletedPickups,
  listCompletedPickupsForUser,
} from "../repositories/pickupsRepository";
import { getGreenPoints } from "../repositories/usersRepository";

export async function getAnalytics(req: Request, res: Response) {
  try {
    const userId =
      (req.query.userId as string | undefined) ||
      (req.headers["x-user-id"] as string | undefined);

    let pickups;
    let totalPoints = 0;

    if (userId) {
      pickups = await listCompletedPickupsForUser(userId);
      totalPoints = await getGreenPoints(userId);
    } else {
      pickups = await listCompletedPickups();
      const totals = aggregateMetrics(pickups);
      totalPoints = totals.totalPoints;
    }

    const totals = aggregateMetrics(pickups);

    res.json({
      totalWeight: totals.totalWeight,
      totalPoints: totalPoints,
      totalCarbon: totals.totalCarbon,
      pickups: pickups.length,
    });
  } catch (error) {
    console.error("Failed to load analytics", error);
    res.status(500).json({ message: "Unable to load analytics" });
  }
}
