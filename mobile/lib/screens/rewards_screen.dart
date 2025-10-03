import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  int _points = 0;
  double _carbon = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    final summary = await ApiService().fetchRewardSummary();
    setState(() {
      _points = summary.points;
      _carbon = summary.carbonSavings;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Yeşil Puanlarınız', style: Theme.of(context).textTheme.headlineSmall),
          Text('$_points puan'),
          const SizedBox(height: 24),
          Text('Tahmini Karbon Tasarrufu', style: Theme.of(context).textTheme.headlineSmall),
          Text('${_carbon.toStringAsFixed(2)} kg CO₂'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {},
            child: const Text('Hediye Çeki Kullan'),
          )
        ],
      ),
    );
  }
}
