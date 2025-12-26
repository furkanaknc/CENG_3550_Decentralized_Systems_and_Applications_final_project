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

Future<WebPosition?> getCurrentPositionWeb() async => null;
bool isGeolocationSupported() => false;
