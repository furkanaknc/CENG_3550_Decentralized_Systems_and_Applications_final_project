import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PickupRequestScreen extends StatefulWidget {
  const PickupRequestScreen({super.key});

  @override
  State<PickupRequestScreen> createState() => _PickupRequestScreenState();
}

class _PickupRequestScreenState extends State<PickupRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  String _material = 'plastic';
  String? _statusMessage;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final result = await ApiService().requestPickup(
      material: _material,
      weightKg: double.parse(_weightController.text),
    );

    setState(() {
      _statusMessage = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
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
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(labelText: 'Ağırlık (kg)'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Lütfen ağırlık giriniz';
                }
                final parsed = double.tryParse(value);
                if (parsed == null || parsed <= 0) {
                  return 'Geçerli bir değer giriniz';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _submit, child: const Text('Kurye Talep Et')),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(_statusMessage!, style: Theme.of(context).textTheme.bodyMedium)
            ]
          ],
        ),
      ),
    );
  }
}
