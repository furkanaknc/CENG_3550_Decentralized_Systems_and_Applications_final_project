import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_platform.dart' as platform;

class Position {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  Position({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });
}

class AddressDetails {
  final String? neighborhood;
  final String? district;
  final String? city;
  final String? displayName;

  AddressDetails({
    this.neighborhood,
    this.district,
    this.city,
    this.displayName,
  });

  String get summary {
    final parts = <String>[];
    if (neighborhood != null) parts.add(neighborhood!);
    if (district != null) parts.add(district!);
    if (city != null) parts.add(city!);
    return parts.join(', ');
  }
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final http.Client _client = http.Client();
  Position? _currentPosition;
  AddressDetails? _addressDetails;
  final _positionController = StreamController<Position?>.broadcast();

  Position? get currentPosition => _currentPosition;
  AddressDetails? get addressDetails => _addressDetails;
  Stream<Position?> get positionStream => _positionController.stream;

  String get _baseUrl {
    final apiUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:4000';
    return apiUrl.replaceAll(RegExp(r'/+$'), '');
  }

  static const double defaultLatitude = 41.0082;
  static const double defaultLongitude = 28.9784;

  double get latitude => _currentPosition?.latitude ?? defaultLatitude;
  double get longitude => _currentPosition?.longitude ?? defaultLongitude;

  Future<Position?> getCurrentLocation() async {
    try {
      final webPosition = await platform.getCurrentPositionWeb();

      if (webPosition != null) {
        _currentPosition = Position(
          latitude: webPosition.latitude,
          longitude: webPosition.longitude,
          accuracy: webPosition.accuracy,
          timestamp: DateTime.now(),
        );

        print(
            '📍 Got location: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('last_latitude', _currentPosition!.latitude);
        await prefs.setDouble('last_longitude', _currentPosition!.longitude);

        _positionController.add(_currentPosition);
        return _currentPosition;
      } else {
        print('📍 Location not available, using default');
        return null;
      }
    } catch (e) {
      print('📍 Error getting location: $e');
      return null;
    }
  }

  Future<Position?> restoreLastLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('last_latitude');
      final lon = prefs.getDouble('last_longitude');

      if (lat != null && lon != null) {
        _currentPosition = Position(
          latitude: lat,
          longitude: lon,
          accuracy: 0,
          timestamp: DateTime.now(),
        );
        _positionController.add(_currentPosition);
        await fetchAddressDetails();
        return _currentPosition;
      }
    } catch (e) {
      print('📍 Error restoring location: $e');
    }
    return null;
  }

  bool get isSupported => platform.isGeolocationSupported();

  Future<void> setManualLocation(double latitude, double longitude) async {
    _currentPosition = Position(
      latitude: latitude,
      longitude: longitude,
      accuracy: 0,
      timestamp: DateTime.now(),
    );

    print('📍 Manual location set: $latitude, $longitude');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_latitude', latitude);
    await prefs.setDouble('last_longitude', longitude);

    _positionController.add(_currentPosition);
    await fetchAddressDetails();
  }

  Future<AddressDetails?> fetchAddressDetails() async {
    if (_currentPosition == null) return null;

    try {
      final response = await _client.get(
        Uri.parse(
            '$_baseUrl/api/maps/reverse?lat=${_currentPosition!.latitude}&lon=${_currentPosition!.longitude}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};

        _addressDetails = AddressDetails(
          neighborhood: address['neighbourhood'] as String? ??
              address['suburb'] as String? ??
              address['quarter'] as String?,
          district: address['city_district'] as String? ??
              address['district'] as String? ??
              address['town'] as String?,
          city: address['city'] as String? ??
              address['province'] as String? ??
              address['state'] as String?,
          displayName: data['displayName'] as String?,
        );

        print('📍 Address fetched: ${_addressDetails?.summary}');
        return _addressDetails;
      }
    } catch (e) {
      print('📍 Error fetching address: $e');
    }
    return null;
  }

  void dispose() {
    _positionController.close();
  }
}
