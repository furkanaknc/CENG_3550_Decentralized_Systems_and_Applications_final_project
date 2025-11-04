import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_service.dart';

class PickupRequestScreen extends StatefulWidget {
  const PickupRequestScreen({super.key});

  @override
  State<PickupRequestScreen> createState() => _PickupRequestScreenState();
}

class _PickupRequestScreenState extends State<PickupRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final MapController _mapController = MapController();

  String _material = 'plastic';
  String? _statusMessage;
  bool _statusIsError = false;
  bool _submitting = false;
  bool _locationError = false;
  LatLng? _selectedLocation;
  PickupRequestResult? _result;

  static const LatLng _initialCenter = LatLng(41.0082, 28.9784);

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _onLocationSelected(LatLng location) {
    final camera = _mapController.camera;
    final currentZoom = camera.zoom.isFinite ? camera.zoom : 13;
    final targetZoom = currentZoom < 14 ? 14.0 : currentZoom;
    _mapController.move(location, targetZoom);

    setState(() {
      _selectedLocation = location;
      _locationError = false;
      if (_result != null) {
        _result = null;
        _statusMessage = null;
        _statusIsError = false;
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedLocation == null) {
      setState(() {
        _locationError = true;
        _statusMessage = 'Harita üzerinden teslim alınacak konumu seçmelisiniz.';
        _statusIsError = true;
      });
      return;
    }

    setState(() {
      _statusMessage = null;
      _statusIsError = false;
      _submitting = true;
    });

    try {
      final weight = double.parse(_weightController.text.replaceAll(',', '.'));
      final result = await ApiService().requestPickup(
        material: _material,
        weightKg: weight,
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
        _statusMessage = result.confirmationMessage;
        _statusIsError = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _result = null;
        _statusMessage = error.message;
        _statusIsError = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _result = null;
        _statusMessage = 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyiniz.';
        _statusIsError = true;
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
      });
    }
  }

  void _startNewRequest() {
    setState(() {
      _result = null;
      _statusMessage = null;
      _statusIsError = false;
      _locationError = false;
      _weightController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kurye talep et', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Geri dönüşüm atıklarını kapınızdan aldırmak için konumunuzu işaretleyin ve talep detaylarını paylaşın.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _buildMapSection(context),
            const SizedBox(height: 24),
            Text('Toplama detayları', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _material,
                    decoration: const InputDecoration(labelText: 'Atık türü'),
                    items: const [
                      DropdownMenuItem(value: 'plastic', child: Text('Plastik')),
                      DropdownMenuItem(value: 'glass', child: Text('Cam')),
                      DropdownMenuItem(value: 'paper', child: Text('Kağıt')),
                      DropdownMenuItem(value: 'metal', child: Text('Metal')),
                      DropdownMenuItem(value: 'electronics', child: Text('Elektronik')),
                    ],
                    onChanged: (value) => setState(() => _material = value ?? 'plastic'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _weightController,
                    decoration: const InputDecoration(labelText: 'Ağırlık (kg)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Lütfen ağırlık giriniz';
                      }
                      final parsed = double.tryParse(value.replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) {
                        return 'Geçerli bir değer giriniz';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delivery_dining),
                    label: Text(_submitting ? 'Gönderiliyor...' : 'Kurye talep et'),
                  ),
                ],
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _statusIsError
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 20),
              _PickupSummaryCard(
                result: _result!,
                statusLabel: _statusLabel(_result!.pickup.status),
                createdAtLabel: _formatDate(_result!.pickup.createdAt),
                onStartNew: _startNewRequest,
              ),
              if (_result!.nearbyLocations.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Yakınınızdaki geri dönüşüm noktaları',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ..._buildNearbySuggestionCards(_result!.nearbyLocations),
              ],
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedLocation ?? _initialCenter,
                initialZoom: _selectedLocation != null ? 15 : 12,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onLongPress: (_, latLng) => _onLocationSelected(latLng),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.greencycle.app',
                ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 40,
                        height: 40,
                        alignment: Alignment.bottomCenter,
                        child: const Icon(
                          Icons.person_pin_circle,
                          color: Colors.blueAccent,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.touch_app, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Teslim alınacak noktayı işaretlemek için harita üzerinde uzun basın. '
                'Konumu güncellemek istediğinizde tekrar uzun basabilirsiniz.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        if (_selectedLocation != null) ...[
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
            child: ListTile(
              leading: const Icon(Icons.place),
              title: const Text('Seçilen konum'),
              subtitle: Text(
                '${_selectedLocation!.latitude.toStringAsFixed(4)}, '
                '${_selectedLocation!.longitude.toStringAsFixed(4)}',
              ),
              trailing: IconButton(
                tooltip: 'Konumu temizle',
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedLocation = null;
                    _locationError = false;
                  });
                },
              ),
            ),
          ),
        ],
        if (_locationError) ...[
          const SizedBox(height: 8),
          Text(
            'Lütfen teslim alınacak konumu seçiniz.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildNearbySuggestionCards(List<RecyclingPoint> points) {
    final widgets = <Widget>[];
    for (final point in points) {
      widgets.add(_NearbyLocationCard(point: point));
      widgets.add(const SizedBox(height: 12));
    }
    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }
    return widgets;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Kurye ataması bekleniyor';
      case 'assigned':
        return 'Kurye yolda';
      case 'completed':
        return 'Tamamlandı';
      default:
        return status;
    }
  }

  String? _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return null;
    }
    final local = dateTime.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(local.day)}.${twoDigits(local.month)}.${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

class _PickupSummaryCard extends StatelessWidget {
  const _PickupSummaryCard({
    required this.result,
    required this.statusLabel,
    required this.onStartNew,
    this.createdAtLabel,
  });

  final PickupRequestResult result;
  final String statusLabel;
  final VoidCallback onStartNew;
  final String? createdAtLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pickup = result.pickup;
    final locationLabel =
        '${pickup.latitude.toStringAsFixed(4)}, ${pickup.longitude.toStringAsFixed(4)}';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Talep özeti', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              result.confirmationMessage,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _SummaryRow(
              icon: Icons.badge,
              label: 'Talep numarası',
              value: pickup.id,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              icon: Icons.hourglass_bottom,
              label: 'Durum',
              value: statusLabel,
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              icon: Icons.scale,
              label: 'Ağırlık',
              value: '${pickup.weightKg.toStringAsFixed(1)} kg ${pickup.material}',
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              icon: Icons.place,
              label: 'Alım konumu',
              value: locationLabel,
            ),
            if (createdAtLabel != null) ...[
              const SizedBox(height: 8),
              _SummaryRow(
                icon: Icons.schedule,
                label: 'Oluşturulma',
                value: createdAtLabel!,
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onStartNew,
              icon: const Icon(Icons.refresh),
              label: const Text('Yeni talep oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NearbyLocationCard extends StatelessWidget {
  const _NearbyLocationCard({required this.point});

  final RecyclingPoint point;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(point.name, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: point.acceptedMaterials
                  .map(
                    (material) => Chip(
                      label: Text(material),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${point.latitude.toStringAsFixed(4)}, '
                    '${point.longitude.toStringAsFixed(4)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
