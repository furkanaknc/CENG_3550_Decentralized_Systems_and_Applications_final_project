import dotenv from 'dotenv';

dotenv.config();

export interface OpenStreetMapSearchResult {
  place_id: number;
  osm_type: 'node' | 'way' | 'relation';
  osm_id: number;
  boundingbox: [string, string, string, string];
  lat: string;
  lon: string;
  display_name: string;
  class: string;
  type: string;
  importance: number;
  icon?: string;
  address?: Record<string, string>;
  name?: string;
}

export interface OpenStreetMapReverseResult {
  place_id: number;
  lat: string;
  lon: string;
  display_name: string;
  address?: Record<string, string>;
  osm_type: 'node' | 'way' | 'relation';
  osm_id: number;
}

export type SearchOptions = {
  limit?: number;
  countrycodes?: string;
  viewbox?: string;
  bounded?: boolean;
};

class OpenStreetMapClient {
  private readonly baseUrl: string;
  private readonly userAgent: string;

  constructor() {
    this.baseUrl = process.env.OPENSTREETMAP_BASE_URL ?? 'https://nominatim.openstreetmap.org';
    this.userAgent = 'recycle-backend/1.0 (+https://example.com/contact)';
  }

  public async search(query: string, options: SearchOptions = {}): Promise<OpenStreetMapSearchResult[]> {
    const params = new URLSearchParams({
      q: query,
      format: 'jsonv2',
      addressdetails: '1'
    });

    if (options.limit) {
      params.set('limit', options.limit.toString());
    }
    if (options.countrycodes) {
      params.set('countrycodes', options.countrycodes);
    }
    if (options.viewbox) {
      params.set('viewbox', options.viewbox);
    }
    if (options.bounded) {
      params.set('bounded', '1');
    }

    const response = await fetch(`${this.baseUrl}/search?${params.toString()}`, {
      headers: this.buildHeaders()
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`OpenStreetMap search failed: ${response.status} ${text}`);
    }

    return (await response.json()) as OpenStreetMapSearchResult[];
  }

  public async reverse(latitude: number, longitude: number): Promise<OpenStreetMapReverseResult> {
    const params = new URLSearchParams({
      lat: latitude.toString(),
      lon: longitude.toString(),
      format: 'jsonv2',
      addressdetails: '1'
    });

    const response = await fetch(`${this.baseUrl}/reverse?${params.toString()}`, {
      headers: this.buildHeaders()
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`OpenStreetMap reverse failed: ${response.status} ${text}`);
    }

    return (await response.json()) as OpenStreetMapReverseResult;
  }

  private buildHeaders(): Record<string, string> {
    return {
      'User-Agent': this.userAgent,
      Accept: 'application/json'
    };
  }
}

const openStreetMapClient = new OpenStreetMapClient();
export default openStreetMapClient;
