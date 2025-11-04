import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _loading = true;
  List<RecyclingPoint> _points = const [];
  RecyclingPoint? _selectedPoint;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    try {
      final points = await ApiService().fetchRecyclingPoints();
      if (!mounted) {
        return;
      }
      setState(() {
        _points = points;
        _loading = false;
        _errorMessage = null;
      });

      if (points.isNotEmpty) {
        Future.microtask(() {
          if (mounted) {
            _fitCameraToPoints(points);
          }
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Geri dönüşüm noktaları yüklenemedi. Lütfen tekrar deneyin.';
        _loading = false;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    await _loadPoints();
  }

  void _fitCameraToPoints(List<RecyclingPoint> points) {
    final latLngPoints =
        points.map((point) => LatLng(point.latitude, point.longitude)).toList();
    if (latLngPoints.length == 1) {
      _mapController.move(latLngPoints.first, 14);
      return;
    }

    final bounds = LatLngBounds.fromPoints(latLngPoints);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _retry, child: const Text('Tekrar dene')),
          ],
        ),
      );
    }

    final markers = _points
        .map(
          (point) => Marker(
            width: 48,
            height: 48,
            point: LatLng(point.latitude, point.longitude),
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedPoint = point);
              },
              child: Icon(
                Icons.location_on,
                color: point.id == _selectedPoint?.id
                    ? Theme.of(context).colorScheme.primary
                    : Colors.redAccent,
                size: point.id == _selectedPoint?.id ? 44 : 36,
              ),
            ),
          ),
        )
        .toList();

    final initialCenter = _points.isNotEmpty
        ? LatLng(_points.first.latitude, _points.first.longitude)
        : const LatLng(39.0, 35.0);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 12,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, __) => setState(() => _selectedPoint = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.greencycle.app',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        if (_selectedPoint != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _buildInfoCard(context, _selectedPoint!),
          ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, RecyclingPoint point) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(point.name, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.recycling, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kabul edilen materyaller: ${point.acceptedMaterials.join(', ')}',
                    style: textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Konum: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
