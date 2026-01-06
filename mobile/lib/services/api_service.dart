import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'wallet_service.dart';
import 'metamask_platform.dart' as metamask;

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
    this.address,
  });

  final String id;
  final String material;
  final double weightKg;
  final String status;
  final double latitude;
  final double longitude;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final PickupAddress? address;
}

class PickupAddress {
  final String? neighborhood;
  final String? district;
  final String? city;
  final String? street;
  final String? building;

  PickupAddress({
    this.neighborhood,
    this.district,
    this.city,
    this.street,
    this.building,
  });

  String get summary {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (building != null && building!.isNotEmpty) parts.add('No: $building');
    if (neighborhood != null && neighborhood!.isNotEmpty)
      parts.add(neighborhood!);
    if (district != null && district!.isNotEmpty) parts.add(district!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    return parts.join(', ');
  }
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
      response = await _client.get(_uri('/api/maps/all'));
    } else {
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
    Map<String, String?>? address,
  }) async {
    final userId = _auth.currentUser?.id ?? 'demo-user';
    final headers = {
      'Content-Type': 'application/json',
      ..._auth.getAuthHeaders(),
    };

    final body = <String, dynamic>{
      'userId': userId,
      'material': material,
      'weightKg': weightKg,
      'pickupLocation': {
        'id': 'user-location',
        'coordinates': {
          'latitude': latitude ?? _defaultLatitude,
          'longitude': longitude ?? _defaultLongitude,
        },
      },
    };

    if (address != null) {
      body['address'] = address;
    }

    final response = await _client.post(
      _uri('/api/pickups'),
      headers: headers,
      body: jsonEncode(body),
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

  Future<PickupSummary> acceptPickup(String pickupId) async {
    Map<String, dynamic>? courierApproval;

    final pickupManagerAddress = dotenv.env['PICKUP_MANAGER_ADDRESS'] ?? '';

    final isMetaMaskReady = metamask.isMetaMaskAvailable();
    final isWalletConnectReady = _wallet.isConnected;

    print(
        '🔐 Signature check: MetaMask=$isMetaMaskReady, WalletConnect=$isWalletConnectReady, Address=$pickupManagerAddress');

    if ((isMetaMaskReady || isWalletConnectReady) &&
        pickupManagerAddress.isNotEmpty) {
      try {
        courierApproval =
            await createAcceptPickupSignature(pickupId, pickupManagerAddress);
        print('✅ Signature created: $courierApproval');
      } catch (e) {
        print('❌ Failed to create signature: $e');
      }
    } else {
      print(
          '⚠️ Skipping signature: MetaMask=$isMetaMaskReady, WalletConnect=$isWalletConnectReady, Address=${pickupManagerAddress.isNotEmpty}');
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

  Future<PickupSummary> completePickup(String pickupId) async {
    Map<String, dynamic>? courierApproval;

    final pickupManagerAddress = dotenv.env['PICKUP_MANAGER_ADDRESS'] ?? '';

    final isMetaMaskReady = metamask.isMetaMaskAvailable();
    final isWalletConnectReady = _wallet.isConnected;

    print(
        '🔐 Complete Signature check: MetaMask=$isMetaMaskReady, WalletConnect=$isWalletConnectReady, Address=$pickupManagerAddress');

    if ((isMetaMaskReady || isWalletConnectReady) &&
        pickupManagerAddress.isNotEmpty) {
      try {
        courierApproval =
            await createCompletePickupSignature(pickupId, pickupManagerAddress);
        print('✅ Complete Signature created: $courierApproval');
      } catch (e) {
        print('❌ Failed to create complete signature: $e');
      }
    } else {
      print(
          '⚠️ Skipping complete signature: MetaMask=$isMetaMaskReady, WalletConnect=$isWalletConnectReady, Address=${pickupManagerAddress.isNotEmpty}');
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

  Future<Map<String, dynamic>?> createAcceptPickupSignature(
      String pickupId, String pickupManagerAddress) async {
    try {
      final nonceData = await getCourierNonce();
      final blockchainEnabled =
          nonceData['blockchainEnabled'] as bool? ?? false;

      if (!blockchainEnabled) {
        return null;
      }

      final nonce = int.parse(nonceData['nonce'].toString());
      final courierAddress = nonceData['address'] as String;

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
          'chainId': 11155111,
          'verifyingContract': pickupManagerAddress,
        },
        'message': {
          'pickupId': pickupId,
          'courier': courierAddress,
          'nonce': nonce,
          'deadline': deadline,
        },
      };

      String? signature;

      if (metamask.isMetaMaskAvailable()) {
        signature =
            await metamask.signTypedDataMetaMask(courierAddress, typedData);
      }

      if (signature == null && _wallet.isConnected) {
        signature = await _wallet.signTypedData(typedData);
      }

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

  Future<Map<String, dynamic>?> createCompletePickupSignature(
      String pickupId, String pickupManagerAddress) async {
    try {
      final nonceData = await getCourierNonce();
      final blockchainEnabled =
          nonceData['blockchainEnabled'] as bool? ?? false;

      if (!blockchainEnabled) {
        return null;
      }

      final nonce = int.parse(nonceData['nonce'].toString());
      final courierAddress = nonceData['address'] as String;

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
          'chainId': 11155111,
          'verifyingContract': pickupManagerAddress,
        },
        'message': {
          'pickupId': pickupId,
          'courier': courierAddress,
          'nonce': nonce,
          'deadline': deadline,
        },
      };

      String? signature;

      if (metamask.isMetaMaskAvailable()) {
        signature =
            await metamask.signTypedDataMetaMask(courierAddress, typedData);
      }

      if (signature == null && _wallet.isConnected) {
        signature = await _wallet.signTypedData(typedData);
      }

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
    final addressData = pickup['address'] as Map<String, dynamic>?;

    PickupAddress? address;
    if (addressData != null) {
      address = PickupAddress(
        neighborhood: addressData['neighborhood'] as String?,
        district: addressData['district'] as String?,
        city: addressData['city'] as String?,
        street: addressData['street'] as String?,
        building: addressData['building'] as String?,
      );
    }

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
      address: address,
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
