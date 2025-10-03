import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _loading = true;
  List<RecyclingPoint> _points = const [];

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    final points = await ApiService().fetchRecyclingPoints();
    setState(() {
      _points = points;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: _points.length,
      itemBuilder: (context, index) {
        final point = _points[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.location_pin),
            title: Text(point.name),
            subtitle: Text('Kabul edilen: ${point.acceptedMaterials.join(', ')}'),
          ),
        );
      },
    );
  }
}
