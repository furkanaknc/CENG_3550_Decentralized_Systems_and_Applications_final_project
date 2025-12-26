import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/location_service.dart';

class PickupRequestScreen extends StatefulWidget {
  const PickupRequestScreen({super.key});

  @override
  State<PickupRequestScreen> createState() => _PickupRequestScreenState();
}

class _PickupRequestScreenState extends State<PickupRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _streetController = TextEditingController();
  final _buildingController = TextEditingController();
  final LocationService _location = LocationService();

  String _material = 'plastic';
  String? _statusMessage;
  bool _statusIsError = false;
  bool _submitting = false;
  bool _loadingAddress = true;
  PickupRequestResult? _result;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    setState(() => _loadingAddress = true);

    if (_location.currentPosition == null) {
      await _location.restoreLastLocation();
    }

    if (_location.addressDetails == null && _location.currentPosition != null) {
      await _location.fetchAddressDetails();
    }

    if (mounted) {
      setState(() => _loadingAddress = false);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _streetController.dispose();
    _buildingController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_location.currentPosition == null) {
      setState(() {
        _statusMessage = 'Lütfen önce haritadan konumunuzu seçin.';
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
      final addressDetails = _location.addressDetails;
      final result = await ApiService().requestPickup(
        material: _material,
        weightKg: weight,
        latitude: _location.latitude,
        longitude: _location.longitude,
        address: {
          'neighborhood': addressDetails?.neighborhood,
          'district': addressDetails?.district,
          'city': addressDetails?.city,
          'street':
              _streetController.text.isNotEmpty ? _streetController.text : null,
          'building': _buildingController.text.isNotEmpty
              ? _buildingController.text
              : null,
        },
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
        _statusMessage =
            'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyiniz.';
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
      _weightController.clear();
      _streetController.clear();
      _buildingController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Kapat',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Kurye talep et'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Geri dönüşüm atıklarını kapınızdan aldırmak için adres bilgilerinizi girin.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              _buildAddressSection(context),
              const SizedBox(height: 24),
              Text('Toplama detayları', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Material(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _material,
                        decoration:
                            const InputDecoration(labelText: 'Atık türü'),
                        items: const [
                          DropdownMenuItem(
                              value: 'plastic', child: Text('Plastik')),
                          DropdownMenuItem(value: 'glass', child: Text('Cam')),
                          DropdownMenuItem(
                              value: 'paper', child: Text('Kağıt')),
                          DropdownMenuItem(
                              value: 'metal', child: Text('Metal')),
                          DropdownMenuItem(
                              value: 'electronics', child: Text('Elektronik')),
                        ],
                        onChanged: (value) =>
                            setState(() => _material = value ?? 'plastic'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _weightController,
                        decoration:
                            const InputDecoration(labelText: 'Ağırlık (kg)'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Lütfen ağırlık giriniz';
                          }
                          final parsed =
                              double.tryParse(value.replaceAll(',', '.'));
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delivery_dining),
                        label: Text(
                            _submitting ? 'Gönderiliyor...' : 'Kurye talep et'),
                      ),
                    ],
                  ),
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
      ),
    );
  }

  Widget _buildAddressSection(BuildContext context) {
    final theme = Theme.of(context);
    final address = _location.addressDetails;
    final hasLocation = _location.currentPosition != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Adres Bilgileri', style: theme.textTheme.titleMedium),
              ],
            ),
            const Divider(height: 24),
            if (_loadingAddress)
              const Center(child: CircularProgressIndicator())
            else if (!hasLocation)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Konumunuz henüz belirlenmedi. Geri dönüp haritadan konum seçin.',
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Otomatik adres bilgisi (read-only)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Konum',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (address != null && address.summary.isNotEmpty)
                      Text(address.summary, style: theme.textTheme.bodyLarge)
                    else
                      Text(
                        '${_location.latitude.toStringAsFixed(4)}, ${_location.longitude.toStringAsFixed(4)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Kullanıcı input alanları
              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(
                  labelText: 'Sokak / Cadde',
                  hintText: 'Örn: Atatürk Caddesi',
                  prefixIcon: Icon(Icons.signpost),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _buildingController,
                decoration: const InputDecoration(
                  labelText: 'Bina No / Daire',
                  hintText: 'Örn: No: 45 / Daire: 3',
                  prefixIcon: Icon(Icons.home),
                ),
              ),
            ],
          ],
        ),
      ),
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
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
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
              value:
                  '${pickup.weightKg.toStringAsFixed(1)} kg ${pickup.material}',
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
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
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
