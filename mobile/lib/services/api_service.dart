import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'wallet_service.dart';

class RecyclingPoint {
  final String id;
  final String name;
  final List<String> acceptedMaterials;
  final double latitude;
  final double longitude;

  RecyclingPoint({
    required this.id,
    required this.name,
    required List<String> acceptedMaterials,
    required this.latitude,
    required this.longitude,
  }) : acceptedMaterials = List.unmodifiable(acceptedMaterials);
}

class PickupSummary {
  PickupSummary({
    required this.id,
    required this.material,
    required this.weightKg,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String material;
  final double weightKg;
  final String status;
  final double latitude;
  final double longitude;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class PickupRequestResult {
  PickupRequestResult({
    required this.pickup,
    required List<RecyclingPoint> nearbyLocations,
  }) : nearbyLocations = List.unmodifiable(nearbyLocations);

  final PickupSummary pickup;
  final List<RecyclingPoint> nearbyLocations;

  String get confirmationMessage => 'Talebiniz alındı (#${pickup.id}). '
      '${pickup.weightKg.toStringAsFixed(1)} kg ${pickup.material} kaydedildi.';
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
    _baseUrl =
        _sanitizeBaseUrl(dotenv.env['API_BASE_URL'] ?? 'http://localhost:4000');
  }

  static final ApiService _singleton = ApiService._internal();

  factory ApiService() => _singleton;

  final AuthService _auth = AuthService();
  final WalletService _wallet = WalletService();

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
    return Uri.parse('$_baseUrl$normalizedPath')
        .replace(queryParameters: queryParameters);
  }

  Future<List<RecyclingPoint>> fetchRecyclingPoints({
    double? latitude,
    double? longitude,
    double radiusKm = 10,
    bool showAll = false,
  }) async {
    late final http.Response response;

    if (showAll) {
      // Admin mode: get all locations
      response = await _client.get(_uri('/api/maps/all'));
    } else {
      // User mode: get nearby locations
      final lat = latitude ?? _defaultLatitude;
      final lon = longitude ?? _defaultLongitude;
      response = await _client.get(
        _uri('/api/maps/nearby', {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'radiusKm': radiusKm.toString(),
        }),
      );
    }

    if (response.statusCode != 200) {
      throw ApiException(
          'Geri dönüşüm merkezleri alınamadı', response.statusCode);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return _mapRecyclingPoints(payload['locations'] as List<dynamic>?);
  }

  Future<PickupRequestResult> requestPickup({
    required String material,
    required double weightKg,
    double? latitude,
    double? longitude,
  }) async {
    final userId = _auth.currentUser?.id ?? 'demo-user';
    final headers = {
      'Content-Type': 'application/json',
      ..._auth.getAuthHeaders(),
    };

    final response = await _client.post(
      _uri('/api/pickups'),
      headers: headers,
      body: jsonEncode({
        'userId': userId,
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
    final pickup =
        payload['pickup'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final pickupLocation = pickup['pickupLocation'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final suggestions =
        _mapRecyclingPoints(payload['nearbyLocations'] as List<dynamic>?);

    final summary = PickupSummary(
      id: pickup['id']?.toString() ?? 'bilinmiyor',
      material: pickup['material']?.toString() ?? material,
      weightKg: (pickup['weightKg'] as num?)?.toDouble() ?? weightKg,
      status: pickup['status']?.toString() ?? 'pending',
      latitude: (pickupLocation['latitude'] as num?)?.toDouble() ??
          latitude ??
          _defaultLatitude,
      longitude: (pickupLocation['longitude'] as num?)?.toDouble() ??
          longitude ??
          _defaultLongitude,
      createdAt: _parseDateTime(pickup['createdAt']),
      updatedAt: _parseDateTime(pickup['updatedAt']),
    );

    return PickupRequestResult(pickup: summary, nearbyLocations: suggestions);
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

  DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  /// Kurye için bekleyen talepleri getir
  Future<List<PickupSummary>> getPendingPickups() async {
    final headers = _auth.getAuthHeaders();

    final response = await _client.get(
      _uri('/api/couriers/pickups/pending'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('Bekleyen talepler alınamadı', response.statusCode);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final pickups = payload['pickups'] as List<dynamic>? ?? [];

    return pickups.map(_parsePickupSummary).whereType<PickupSummary>().toList();
  }

  /// Kurye için kabul edilmiş (assigned) talepleri getir
  Future<List<PickupSummary>> getMyPickups() async {
    final headers = _auth.getAuthHeaders();

    final response = await _client.get(
      _uri('/api/couriers/my-pickups'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw ApiException(
          'Kabul edilmiş talepler alınamadı', response.statusCode);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final pickups = payload['pickups'] as List<dynamic>? ?? [];

    return pickups.map(_parsePickupSummary).whereType<PickupSummary>().toList();
  }

  /// Kurye için talep kabul etme
  Future<PickupSummary> acceptPickup(String pickupId) async {
    // Try to create signature if wallet is connected
    Map<String, dynamic>? courierApproval;

    final pickupManagerAddress = dotenv.env['PICKUP_MANAGER_ADDRESS'] ?? '';

    if (_wallet.isConnected && pickupManagerAddress.isNotEmpty) {
      try {
        courierApproval =
            await createAcceptPickupSignature(pickupId, pickupManagerAddress);
      } catch (e) {
        print('Failed to create signature, continuing without it: $e');
        // If blockchain is not configured on backend, continue without signature
      }
    }

    final headers = {
      'Content-Type': 'application/json',
      ..._auth.getAuthHeaders(),
    };

    final body = courierApproval != null
        ? jsonEncode({'courierApproval': courierApproval})
        : '{}';

    final response = await _client.post(
      _uri('/api/couriers/pickups/$pickupId/accept'),
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final message = payload['message'] as String? ?? 'Talep kabul edilemedi';
      throw ApiException(message, response.statusCode);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final pickup = payload['pickup'] as Map<String, dynamic>;
    return _parsePickupSummary(pickup)!;
  }

  /// Kurye için talep tamamlama
  Future<PickupSummary> completePickup(String pickupId) async {
    // Try to create signature if wallet is connected
    Map<String, dynamic>? courierApproval;

    final pickupManagerAddress = dotenv.env['PICKUP_MANAGER_ADDRESS'] ?? '';

    if (_wallet.isConnected && pickupManagerAddress.isNotEmpty) {
      try {
        courierApproval =
            await createCompletePickupSignature(pickupId, pickupManagerAddress);
      } catch (e) {
        print('Failed to create signature, continuing without it: $e');
        // If blockchain is not configured on backend, continue without signature
      }
    }

    final headers = {
      'Content-Type': 'application/json',
      ..._auth.getAuthHeaders(),
    };

    final body = courierApproval != null
        ? jsonEncode({'courierApproval': courierApproval})
        : '{}';

    final response = await _client.post(
      _uri('/api/couriers/pickups/$pickupId/complete'),
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200) {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final message = payload['message'] as String? ?? 'Talep tamamlanamadı';
      throw ApiException(message, response.statusCode);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final pickup = payload['pickup'] as Map<String, dynamic>;
    return _parsePickupSummary(pickup)!;
  }

  /// Get courier nonce from backend for signing
  Future<Map<String, dynamic>> getCourierNonce() async {
    final headers = _auth.getAuthHeaders();

    final response = await _client.get(
      _uri('/api/couriers/nonce'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('Nonce alınamadı', response.statusCode);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Create courier approval signature for accepting pickup
  Future<Map<String, dynamic>?> createAcceptPickupSignature(
      String pickupId, String pickupManagerAddress) async {
    if (!_wallet.isConnected) {
      return null;
    }

    try {
      final nonceData = await getCourierNonce();
      final blockchainEnabled =
          nonceData['blockchainEnabled'] as bool? ?? false;

      if (!blockchainEnabled) {
        return null; // Blockchain not configured, no signature needed
      }

      final nonce = int.parse(nonceData['nonce'].toString());
      final courierAddress = nonceData['address'] as String;

      // Deadline: 1 hour from now
      final deadline = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;

      final typedData = {
        'types': {
          'EIP712Domain': [
            {'name': 'name', 'type': 'string'},
            {'name': 'version', 'type': 'string'},
            {'name': 'chainId', 'type': 'uint256'},
            {'name': 'verifyingContract', 'type': 'address'},
          ],
          'AcceptPickup': [
            {'name': 'pickupId', 'type': 'string'},
            {'name': 'courier', 'type': 'address'},
            {'name': 'nonce', 'type': 'uint256'},
            {'name': 'deadline', 'type': 'uint256'},
          ],
        },
        'primaryType': 'AcceptPickup',
        'domain': {
          'name': 'PickupManager',
          'version': '1',
          'chainId': 11155111, // Sepolia
          'verifyingContract': pickupManagerAddress,
        },
        'message': {
          'pickupId': pickupId,
          'courier': courierAddress,
          'nonce': nonce,
          'deadline': deadline,
        },
      };

      final signature = await _wallet.signTypedData(typedData);

      if (signature == null) {
        throw ApiException('İmza oluşturulamadı');
      }

      return {
        'signature': signature,
        'deadline': deadline,
      };
    } catch (e) {
      print('Failed to create accept pickup signature: $e');
      rethrow;
    }
  }

  /// Create courier approval signature for completing pickup
  Future<Map<String, dynamic>?> createCompletePickupSignature(
      String pickupId, String pickupManagerAddress) async {
    if (!_wallet.isConnected) {
      return null;
    }

    try {
      final nonceData = await getCourierNonce();
      final blockchainEnabled =
          nonceData['blockchainEnabled'] as bool? ?? false;

      if (!blockchainEnabled) {
        return null; // Blockchain not configured, no signature needed
      }

      final nonce = int.parse(nonceData['nonce'].toString());
      final courierAddress = nonceData['address'] as String;

      // Deadline: 1 hour from now
      final deadline = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;

      final typedData = {
        'types': {
          'EIP712Domain': [
            {'name': 'name', 'type': 'string'},
            {'name': 'version', 'type': 'string'},
            {'name': 'chainId', 'type': 'uint256'},
            {'name': 'verifyingContract', 'type': 'address'},
          ],
          'CompletePickup': [
            {'name': 'pickupId', 'type': 'string'},
            {'name': 'courier', 'type': 'address'},
            {'name': 'nonce', 'type': 'uint256'},
            {'name': 'deadline', 'type': 'uint256'},
          ],
        },
        'primaryType': 'CompletePickup',
        'domain': {
          'name': 'PickupManager',
          'version': '1',
          'chainId': 11155111, // Sepolia
          'verifyingContract': pickupManagerAddress,
        },
        'message': {
          'pickupId': pickupId,
          'courier': courierAddress,
          'nonce': nonce,
          'deadline': deadline,
        },
      };

      final signature = await _wallet.signTypedData(typedData);

      if (signature == null) {
        throw ApiException('İmza oluşturulamadı');
      }

      return {
        'signature': signature,
        'deadline': deadline,
      };
    } catch (e) {
      print('Failed to create complete pickup signature: $e');
      rethrow;
    }
  }

  PickupSummary? _parsePickupSummary(dynamic raw) {
    final pickup = raw as Map<String, dynamic>?;
    if (pickup == null) return null;

    final pickupLocation = pickup['pickupLocation'] as Map<String, dynamic>?;

    return PickupSummary(
      id: pickup['id']?.toString() ?? '',
      material: pickup['material']?.toString() ?? '',
      weightKg: (pickup['weightKg'] as num?)?.toDouble() ?? 0.0,
      status: pickup['status']?.toString() ?? 'pending',
      latitude:
          (pickupLocation?['latitude'] as num?)?.toDouble() ?? _defaultLatitude,
      longitude: (pickupLocation?['longitude'] as num?)?.toDouble() ??
          _defaultLongitude,
      createdAt: _parseDateTime(pickup['createdAt']),
      updatedAt: _parseDateTime(pickup['updatedAt']),
    );
  }

  List<RecyclingPoint> _mapRecyclingPoints(List<dynamic>? rawLocations) {
    if (rawLocations == null) {
      return const [];
    }

    return rawLocations
        .map(_parseRecyclingPoint)
        .whereType<RecyclingPoint>()
        .toList(growable: false);
  }

  RecyclingPoint? _parseRecyclingPoint(dynamic raw) {
    final location = raw as Map<String, dynamic>?;
    if (location == null) {
      return null;
    }

    final coordinates = location['coordinates'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final acceptedMaterials =
        (location['acceptedMaterials'] as List<dynamic>? ?? const <dynamic>[])
            .map((dynamic material) => material.toString())
            .where((material) => material.isNotEmpty)
            .toList();

    final latitude =
        (coordinates['latitude'] as num?)?.toDouble() ?? _defaultLatitude;
    final longitude =
        (coordinates['longitude'] as num?)?.toDouble() ?? _defaultLongitude;

    return RecyclingPoint(
      id: location['id']?.toString() ??
          'point-${latitude.toStringAsFixed(4)}-${longitude.toStringAsFixed(4)}',
      name: location['name']?.toString() ?? 'Geri dönüşüm noktası',
      acceptedMaterials: acceptedMaterials,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
