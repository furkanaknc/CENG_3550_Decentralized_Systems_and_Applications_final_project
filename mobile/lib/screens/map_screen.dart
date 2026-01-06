import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'pickup_request_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final AuthService _auth = AuthService();
  final LocationService _location = LocationService();
  final http.Client _client = http.Client();
  bool _loading = true;
  List<RecyclingPoint> _points = const [];
  RecyclingPoint? _selectedPoint;
  String? _errorMessage;
  static const double _minZoom = 3;
  static const double _maxZoom = 18;
  static const double _zoomStep = 1.2;
  bool _showWebHint = kIsWeb;
  bool _isSelectingLocation = false;

  bool get _isAdmin => _auth.currentUser?.isAdmin ?? false;

  String get _baseUrl {
    final apiUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:4000';
    return apiUrl.replaceAll(RegExp(r'/+$'), '');
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (!_isAdmin) {
      await _location.getCurrentLocation();
    }
    await _loadPoints();
  }

  Future<void> _loadPoints() async {
    try {
      final points = await ApiService().fetchRecyclingPoints(
        showAll: _isAdmin,
        latitude: _location.latitude,
        longitude: _location.longitude,
        radiusKm: 15,
      );
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
        _errorMessage =
            'Geri dönüşüm noktaları yüklenemedi. Lütfen tekrar deneyin.';
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

  void _setUserLocation(LatLng point) async {
    await _location.setManualLocation(point.latitude, point.longitude);
    setState(() {
      _isSelectingLocation = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '📍 Konumunuz ayarlandı: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}'),
        backgroundColor: Colors.green,
      ),
    );
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

  void _focusOnPoint(RecyclingPoint point) {
    final target = LatLng(point.latitude, point.longitude);
    final camera = _mapController.camera;
    final zoom = camera.zoom.isFinite ? camera.zoom : 14;
    _mapController.move(target, zoom.clamp(10, _maxZoom).toDouble());
    setState(() {
      _selectedPoint = point;
      _showWebHint = false;
    });
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final targetZoom =
        (camera.zoom + delta).clamp(_minZoom, _maxZoom).toDouble();
    _mapController.move(camera.center, targetZoom);
    if (_showWebHint) {
      setState(() => _showWebHint = false);
    }
  }

  void _zoomIn() => _zoomBy(_zoomStep);

  void _zoomOut() => _zoomBy(-_zoomStep);

  void _showAddLocationDialog(LatLng point) {
    final nameController = TextEditingController();
    final materials = ['plastic', 'glass', 'paper', 'metal', 'electronics'];
    final selectedMaterials = <String>{'plastic', 'glass', 'paper', 'metal'};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Yeni Geri Dönüşüm Noktası'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📍 Konum: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nokta Adı',
                    hintText: 'Örn: Kadıköy Geri Dönüşüm Merkezi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Kabul Edilen Materyaller:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: materials.map((m) {
                    final selected = selectedMaterials.contains(m);
                    return FilterChip(
                      label: Text(m),
                      selected: selected,
                      onSelected: (v) {
                        setDialogState(() {
                          if (v) {
                            selectedMaterials.add(m);
                          } else {
                            selectedMaterials.remove(m);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen bir isim girin')),
                  );
                  return;
                }
                Navigator.pop(context);
                _createLocation(
                  nameController.text.trim(),
                  point,
                  selectedMaterials.toList(),
                );
              },
              child: const Text('Oluştur'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createLocation(
      String name, LatLng point, List<String> materials) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Nokta oluşturuluyor...'),
          ],
        ),
      ),
    );

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/admin/locations'),
        headers: {
          ..._auth.getAuthHeaders(),
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'latitude': point.latitude,
          'longitude': point.longitude,
          'acceptedMaterials': materials,
        }),
      );

      Navigator.pop(context);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "$name" oluşturuldu!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPoints();
      } else {
        throw Exception('Sunucu hatası: ${response.statusCode}');
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Oluşturulamadı: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                setState(() {
                  _selectedPoint = point;
                  _showWebHint = false;
                });
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

    if (!_isAdmin && _location.currentPosition != null) {
      markers.add(
        Marker(
          width: 60,
          height: 60,
          point: LatLng(_location.latitude, _location.longitude),
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.3),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: const Icon(
              Icons.my_location,
              color: Colors.blue,
              size: 24,
            ),
          ),
        ),
      );
    }

    final initialCenter = _location.currentPosition != null && !_isAdmin
        ? LatLng(_location.latitude, _location.longitude)
        : _points.isNotEmpty
            ? LatLng(_points.first.latitude, _points.first.longitude)
            : const LatLng(39.0, 35.0);

    final hasSelection = _selectedPoint != null;

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
            onTap: (_, point) {
              if (_isSelectingLocation && !_isAdmin) {
                _setUserLocation(point);
              } else {
                setState(() {
                  _selectedPoint = null;
                  _showWebHint = false;
                });
              }
            },
            onLongPress: _isAdmin
                ? (tapPosition, point) => _showAddLocationDialog(point)
                : null,
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
        if (_isSelectingLocation)
          Positioned(
            top: 80,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Haritaya dokunarak konumunuzu seçin',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () =>
                        setState(() => _isSelectingLocation = false),
                  ),
                ],
              ),
            ),
          ),
        if (!_isAdmin)
          Positioned(
            bottom: 24,
            left: 16,
            child: FloatingActionButton.small(
              heroTag: 'location_fab',
              backgroundColor:
                  _isSelectingLocation ? Colors.orange : Colors.blue,
              onPressed: () {
                setState(() => _isSelectingLocation = !_isSelectingLocation);
              },
              child: Icon(
                _isSelectingLocation ? Icons.close : Icons.my_location,
                color: Colors.white,
              ),
            ),
          ),
        if (_points.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final point = _points[index];
                      final selected = point.id == _selectedPoint?.id;
                      return ChoiceChip(
                        selected: selected,
                        label:
                            Text(point.name, overflow: TextOverflow.ellipsis),
                        avatar: const Icon(Icons.recycling, size: 18),
                        onSelected: (_) => _focusOnPoint(point),
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        labelStyle: TextStyle(
                          color: selected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemCount: _points.length,
                  ),
                ),
              ),
            ),
          ),
        if (_showWebHint)
          Positioned(
            left: 16,
            top: 16,
            right: 16,
            child: SafeArea(
              child: _WebHelpCard(
                  onClose: () => setState(() => _showWebHint = false)),
            ),
          ),
        Positioned(
          right: 16,
          bottom: hasSelection ? 160 : 24,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapControlButton(
                  icon: Icons.add,
                  tooltip: 'Yakınlaştır',
                  onPressed: _zoomIn,
                ),
                const SizedBox(height: 12),
                _MapControlButton(
                  icon: Icons.remove,
                  tooltip: 'Uzaklaştır',
                  onPressed: _zoomOut,
                ),
                if (_points.length > 1) ...[
                  const SizedBox(height: 12),
                  _MapControlButton(
                    icon: Icons.center_focus_strong,
                    tooltip: 'Tüm noktaları göster',
                    onPressed: () => _fitCameraToPoints(_points),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: hasSelection ? 180 : 96,
          child: SafeArea(
            top: false,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PickupRequestScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
              icon: const Icon(Icons.delivery_dining),
              label: const Text('Kurye talep et'),
            ),
          ),
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
            Row(
              children: [
                Expanded(
                  child: Text(point.name, style: textTheme.titleMedium),
                ),
                if (_isAdmin)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Noktayı Sil',
                    onPressed: () => _confirmDeleteLocation(point),
                  ),
              ],
            ),
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

  void _confirmDeleteLocation(RecyclingPoint point) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.orange, size: 48),
        title: const Text('Noktayı Sil'),
        content:
            Text('"${point.name}" noktasını silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteLocation(point);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLocation(RecyclingPoint point) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Siliniyor...'),
          ],
        ),
      ),
    );

    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/api/admin/locations/${point.id}'),
        headers: _auth.getAuthHeaders(),
      );

      Navigator.pop(context);

      if (response.statusCode == 200) {
        setState(() => _selectedPoint = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${point.name}" silindi'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPoints();
      } else {
        throw Exception('Sunucu hatası: ${response.statusCode}');
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Silinemedi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _WebHelpCard extends StatelessWidget {
  const _WebHelpCard({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Chrome üzerinde haritayı incelemek için fare ile sürükleyebilir, '
                'yakınlaştırma butonlarını kullanabilir veya Ctrl tuşuna basıp '
                'mouse tekerleğini çevirebilirsin.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton(
              tooltip: 'Kapat',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 44,
            width: 44,
            child: Icon(icon, size: 22),
          ),
        ),
      ),
    );
  }
}
