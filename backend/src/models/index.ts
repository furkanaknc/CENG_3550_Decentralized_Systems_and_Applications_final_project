export type RecyclingMaterial = 'plastic' | 'glass' | 'paper' | 'metal' | 'electronics';

export interface User {
  id: string;
  name: string;
  email: string;
  greenPoints: number;
}

export interface Courier {
  id: string;
  name: string;
  active: boolean;
  currentLocation: Coordinates;
  userId?: string;
  walletAddress?: string;
}

export interface RecyclingLocation {
  id: string;
  name: string;
  coordinates: Coordinates;
  acceptedMaterials: RecyclingMaterial[];
}

export interface Coordinates {
  latitude: number;
  longitude: number;
}

export interface PickupRequest {
  id: string;
  userId: string;
  courierId?: string;
  material: RecyclingMaterial;
  weightKg: number;
  status: 'pending' | 'assigned' | 'completed';
  pickupLocation: Coordinates;
  dropoffLocation?: RecyclingLocation;
  createdAt: string;
  updatedAt: string;
}

export interface CarbonReport {
  pickupId: string;
  estimatedSavingKg: number;
}
