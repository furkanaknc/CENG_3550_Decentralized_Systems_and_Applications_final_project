import { Coordinates, RecyclingLocation } from '../models';

type Route = {
  distanceKm: number;
  durationMinutes: number;
  path: Coordinates[];
};

const MOCK_LOCATIONS: RecyclingLocation[] = [
  {
    id: 'loc-istanbul-01',
    name: 'Kadıköy Belediyesi Geri Dönüşüm Merkezi',
    coordinates: { latitude: 40.989, longitude: 29.028 },
    acceptedMaterials: ['plastic', 'glass', 'paper', 'metal']
  },
  {
    id: 'loc-istanbul-02',
    name: 'Üsküdar Yeşil Nokta',
    coordinates: { latitude: 41.025, longitude: 29.015 },
    acceptedMaterials: ['plastic', 'paper', 'electronics']
  }
];

export class MapService {
  public async findNearbyLocations(origin: Coordinates, radiusKm = 5): Promise<RecyclingLocation[]> {
    // In production this would call Google Maps Places or a municipal GIS API.
    return MOCK_LOCATIONS.filter(() => true);
  }

  public async calculateRoute(origin: Coordinates, destination: Coordinates): Promise<Route> {
    // Simulated route calculation.
    const distanceKm = this.haversineDistance(origin, destination);
    const averageCourierSpeedKph = 20;
    const durationMinutes = (distanceKm / averageCourierSpeedKph) * 60;

    return {
      distanceKm: Number(distanceKm.toFixed(2)),
      durationMinutes: Number(durationMinutes.toFixed(1)),
      path: [origin, destination]
    };
  }

  private haversineDistance(a: Coordinates, b: Coordinates): number {
    const toRad = (value: number) => (value * Math.PI) / 180;
    const R = 6371; // Earth radius in km
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
}

const mapService = new MapService();
export default mapService;
