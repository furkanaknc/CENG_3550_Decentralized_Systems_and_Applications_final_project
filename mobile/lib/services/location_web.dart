// ignore_for_file: avoid_web_libraries_in_flutter
@JS()
library location_web;

import 'dart:async';
// ignore: deprecated_member_use
import 'dart:js_util';
import 'package:js/js.dart';

@JS('navigator.geolocation')
external dynamic get _geolocation;

class WebPosition {
  final double latitude;
  final double longitude;
  final double accuracy;

  WebPosition({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });
}

Future<WebPosition?> getCurrentPositionWeb() async {
  if (_geolocation == null) {
    print('📍 Geolocation not supported');
    return null;
  }

  final completer = Completer<WebPosition?>();

  void onSuccess(dynamic position) {
    try {
      final coords = getProperty(position, 'coords');
      final lat = getProperty(coords, 'latitude') as double;
      final lon = getProperty(coords, 'longitude') as double;
      final acc = getProperty(coords, 'accuracy') as double;
      completer
          .complete(WebPosition(latitude: lat, longitude: lon, accuracy: acc));
    } catch (e) {
      completer.complete(null);
    }
  }

  void onError(dynamic error) {
    print('📍 Geolocation error: $error');
    completer.complete(null);
  }

  try {
    callMethod(_geolocation, 'getCurrentPosition', [
      allowInterop(onSuccess),
      allowInterop(onError),
      jsify(
          {'enableHighAccuracy': true, 'timeout': 10000, 'maximumAge': 60000}),
    ]);
  } catch (e) {
    print('📍 Error calling geolocation: $e');
    return null;
  }

  return completer.future.timeout(
    const Duration(seconds: 15),
    onTimeout: () => null,
  );
}

bool isGeolocationSupported() {
  try {
    return _geolocation != null;
  } catch (e) {
    return false;
  }
}
