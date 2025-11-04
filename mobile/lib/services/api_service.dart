import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class RecyclingPoint {
  final String id;
  final String name;
  final List<String> acceptedMaterials;
  final double latitude;
  final double longitude;

  RecyclingPoint({
    required this.id,
    required this.name,
    required this.acceptedMaterials,
    required this.latitude,
    required this.longitude,
  });
}

class RewardSummary {
  final int points;
  final double carbonSavings;

  RewardSummary({required this.points, required this.carbonSavings});
}

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() {
    final code = statusCode != null ? ' (status: $statusCode)' : '';
    return 'ApiException$code: $message';
  }
}

/// API istemcisi backend ile haberleşmeyi üstlenir.
class ApiService {
  ApiService._internal() {
    _baseUrl = _sanitizeBaseUrl(
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:4000'
    );
  }

  static final ApiService _singleton = ApiService._internal();

  factory ApiService() => _singleton;

  static const double _defaultLatitude = 41.0082;
  static const double _defaultLongitude = 28.9784;

  final http.Client _client = http.Client();
  late String _baseUrl;

  /// Manuel olarak backend adresini değiştirmek isteyenler için yardımcı metot.
  void configure({String? baseUrl}) {
    if (baseUrl == null || baseUrl.isEmpty) {
      return;
    }
    _baseUrl = _sanitizeBaseUrl(baseUrl);
  }

  static String _sanitizeBaseUrl(String value) {
    return value.replaceAll(RegExp(r'/+$'), '');
  }

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$_baseUrl$normalizedPath').replace(queryParameters: queryParameters);
  }

  Future<List<RecyclingPoint>> fetchRecyclingPoints({
    double? latitude,
    double? longitude,
    double radiusKm = 5,
  }) async {
    final lat = latitude ?? _defaultLatitude;
    final lon = longitude ?? _defaultLongitude;

    final response = await _client.get(
      _uri('/api/maps/nearby', {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'radiusKm': radiusKm.toString(),
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException('Geri dönüşüm merkezleri alınamadı', response.statusCode);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final locations = payload['locations'] as List<dynamic>? ?? <dynamic>[];

    return locations.map((dynamic item) {
      final map = item as Map<String, dynamic>;
      final coordinates = map['coordinates'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final acceptedMaterials =
          (map['acceptedMaterials'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic material) => material.toString())
              .toList();

      return RecyclingPoint(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? 'Geri dönüşüm noktası',
        acceptedMaterials: acceptedMaterials,
        latitude: (coordinates['latitude'] as num?)?.toDouble() ?? _defaultLatitude,
        longitude: (coordinates['longitude'] as num?)?.toDouble() ?? _defaultLongitude,
      );
    }).toList();
  }

  Future<String> requestPickup({
    required String material,
    required double weightKg,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.post(
      _uri('/api/pickups'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': 'demo-user',
        'material': material,
        'weightKg': weightKg,
        'pickupLocation': {
          'id': 'user-location',
          'coordinates': {
            'latitude': latitude ?? _defaultLatitude,
            'longitude': longitude ?? _defaultLongitude,
          },
        }
      }),
    );

    if (response.statusCode != 201) {
      throw ApiException('Kurye talebi oluşturulamadı', response.statusCode);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final pickup = payload['pickup'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final id = pickup['id']?.toString() ?? 'bilinmiyor';
    final savedWeight = (pickup['weightKg'] as num?)?.toDouble() ?? weightKg;
    final savedMaterial = pickup['material']?.toString() ?? material;

    return 'Talebiniz alındı (#$id). ${savedWeight.toStringAsFixed(1)} kg $savedMaterial kaydedildi.';
  }

  Future<RewardSummary> fetchRewardSummary() async {
    final response = await _client.get(_uri('/api/analytics'));

    if (response.statusCode != 200) {
      throw ApiException('Ödül bilgileri alınamadı', response.statusCode);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final totalPoints = (payload['totalPoints'] as num?)?.round() ?? 0;
    final totalCarbon = (payload['totalCarbon'] as num?)?.toDouble() ?? 0.0;

    return RewardSummary(points: totalPoints, carbonSavings: totalCarbon);
  }
}
