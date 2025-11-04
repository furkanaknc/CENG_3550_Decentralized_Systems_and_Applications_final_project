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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    try {
      final summary = await ApiService().fetchRewardSummary();
      if (!mounted) {
        return;
      }
      setState(() {
        _points = summary.points;
        _carbon = summary.carbonSavings;
        _loading = false;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Ödül bilgileri alınamadı. Lütfen tekrar deneyiniz.';
        _loading = false;
      });
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
            FilledButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _errorMessage = null;
                });
                _loadRewards();
              },
              child: const Text('Tekrar dene'),
            )
          ],
        ),
      );
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
