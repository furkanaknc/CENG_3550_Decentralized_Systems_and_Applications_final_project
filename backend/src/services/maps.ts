import { Coordinates, RecyclingLocation } from "../models";
import openStreetMapClient, {
  OpenStreetMapSearchResult,
} from "./openStreetMap";
import {
  findNearbyLocations as findNearbyLocationsFromDb,
  listAllLocations,
} from "../repositories/recyclingLocationsRepository";

type Route = {
  distanceKm: number;
  durationMinutes: number;
  path: Coordinates[];
};

const DEFAULT_ACCEPTED_MATERIALS: RecyclingLocation["acceptedMaterials"] = [
  "plastic",
  "glass",
  "paper",
  "metal",
];

export class MapService {
  public async findAllLocations(): Promise<RecyclingLocation[]> {
    try {
      return await listAllLocations();
    } catch (error) {
      console.error("Failed to fetch all recycling locations", error);
      return [];
    }
  }

  public async findNearbyLocations(
    origin: Coordinates,
    radiusKm = 5
  ): Promise<RecyclingLocation[]> {
    try {
      const dbLocations = await findNearbyLocationsFromDb(
        origin.latitude,
        origin.longitude,
        radiusKm
      );

      if (dbLocations.length > 0) {
        return dbLocations;
      }

      const viewbox = this.buildViewbox(origin, radiusKm);
      const results = await openStreetMapClient.search("recycling centre", {
        viewbox,
        bounded: true,
        limit: 10,
      });

      return results.map((result) => this.toRecyclingLocation(result));
    } catch (error) {
      console.error("Failed to fetch nearby recycling locations", error);
      return [];
    }
  }

  public async calculateRoute(
    origin: Coordinates,
    destination: Coordinates
  ): Promise<Route> {
    const distanceKm = this.haversineDistance(origin, destination);
    const averageCourierSpeedKph = 20;
    const durationMinutes = (distanceKm / averageCourierSpeedKph) * 60;

    return {
      distanceKm: Number(distanceKm.toFixed(2)),
      durationMinutes: Number(durationMinutes.toFixed(1)),
      path: [origin, destination],
    };
  }

  private haversineDistance(a: Coordinates, b: Coordinates): number {
    const toRad = (value: number) => (value * Math.PI) / 180;
    const R = 6371;
    const dLat = toRad(b.latitude - a.latitude);
    const dLon = toRad(b.longitude - a.longitude);
    const lat1 = toRad(a.latitude);
    const lat2 = toRad(b.latitude);

    const h =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.sin(dLon / 2) * Math.sin(dLon / 2) * Math.cos(lat1) * Math.cos(lat2);
    const c = 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
    return R * c;
  }

  private buildViewbox(origin: Coordinates, radiusKm: number): string {
    const latRadius = radiusKm / 111;
    const lonFactor = Math.cos((origin.latitude * Math.PI) / 180);
    const lonRadius = radiusKm / (111 * Math.max(Math.abs(lonFactor), 0.00001));

    const minLat = this.clampLatitude(origin.latitude - latRadius);
    const maxLat = this.clampLatitude(origin.latitude + latRadius);
    const minLon = this.clampLongitude(origin.longitude - lonRadius);
    const maxLon = this.clampLongitude(origin.longitude + lonRadius);

    return `${minLon},${maxLat},${maxLon},${minLat}`;
  }

  private clampLatitude(value: number): number {
    return Math.max(-90, Math.min(90, value));
  }

  private clampLongitude(value: number): number {
    return Math.max(-180, Math.min(180, value));
  }

  private toRecyclingLocation(
    result: OpenStreetMapSearchResult
  ): RecyclingLocation {
    const latitude = Number(result.lat);
    const longitude = Number(result.lon);

    return {
      id: `osm-${result.place_id}`,
      name: result.name || result.display_name,
      coordinates: { latitude, longitude },
      acceptedMaterials: DEFAULT_ACCEPTED_MATERIALS,
    };
  }
}

const mapService = new MapService();
export default mapService;
