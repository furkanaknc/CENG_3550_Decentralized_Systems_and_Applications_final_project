import { Request, Response } from 'express';
import mapService from '../services/maps';
import openStreetMapClient from '../services/openStreetMap';

export async function searchAddress(req: Request, res: Response) {
  const query = req.query.q as string | undefined;
  const limitParam = req.query.limit as string | undefined;
  const countrycodes = req.query.countrycodes as string | undefined;

  if (!query) {
    return res.status(400).json({ message: 'q parametresi zorunludur' });
  }

  const limit = limitParam ? Number(limitParam) : undefined;

  if (limit !== undefined && Number.isNaN(limit)) {
    return res.status(400).json({ message: 'limit sayısal olmalıdır' });
  }

  try {
    const results = await openStreetMapClient.search(query, {
      limit,
      countrycodes
    });

    const payload = results.map((result) => ({
      id: result.place_id,
      name: result.name || result.display_name,
      displayName: result.display_name,
      coordinates: {
        latitude: Number(result.lat),
        longitude: Number(result.lon)
      },
      category: result.class,
      type: result.type,
      address: result.address ?? {}
    }));

    return res.json({ results: payload });
  } catch (error) {
    console.error('OpenStreetMap araması başarısız oldu', error);
    return res.status(502).json({ message: 'OpenStreetMap araması sırasında hata oluştu' });
  }
}

export async function reverseGeocode(req: Request, res: Response) {
  const latParam = req.query.lat as string | undefined;
  const lonParam = req.query.lon as string | undefined;

  if (!latParam || !lonParam) {
    return res.status(400).json({ message: 'lat ve lon parametreleri zorunludur' });
  }

  const latitude = Number(latParam);
  const longitude = Number(lonParam);

  if (Number.isNaN(latitude) || Number.isNaN(longitude)) {
    return res.status(400).json({ message: 'lat ve lon sayısal olmalıdır' });
  }

  try {
    const result = await openStreetMapClient.reverse(latitude, longitude);

    return res.json({
      id: result.place_id,
      displayName: result.display_name,
      coordinates: {
        latitude: Number(result.lat),
        longitude: Number(result.lon)
      },
      address: result.address ?? {},
      osmType: result.osm_type,
      osmId: result.osm_id
    });
  } catch (error) {
    console.error('OpenStreetMap reverse geocode başarısız oldu', error);
    return res.status(502).json({ message: 'OpenStreetMap reverse geocode sırasında hata oluştu' });
  }
}

export async function getNearbyRecyclingCenters(req: Request, res: Response) {
  const latParam = req.query.lat as string | undefined;
  const lonParam = req.query.lon as string | undefined;
  const radiusParam = req.query.radiusKm as string | undefined;

  if (!latParam || !lonParam) {
    return res.status(400).json({ message: 'lat ve lon parametreleri zorunludur' });
  }

  const latitude = Number(latParam);
  const longitude = Number(lonParam);
  const radiusKm = radiusParam ? Number(radiusParam) : 5;

  if (Number.isNaN(latitude) || Number.isNaN(longitude) || Number.isNaN(radiusKm)) {
    return res.status(400).json({ message: 'lat, lon ve radiusKm sayısal olmalıdır' });
  }

  try {
    const locations = await mapService.findNearbyLocations({ latitude, longitude }, radiusKm);
    return res.json({ locations });
  } catch (error) {
    console.error('Yakın geri dönüşüm merkezi araması başarısız oldu', error);
    return res.status(502).json({ message: 'Yakındaki geri dönüşüm merkezleri alınamadı' });
  }
}
