import 'dart:async';

class RecyclingPoint {
  final String id;
  final String name;
  final List<String> acceptedMaterials;

  RecyclingPoint({required this.id, required this.name, required this.acceptedMaterials});
}

class RewardSummary {
  final int points;
  final double carbonSavings;

  RewardSummary({required this.points, required this.carbonSavings});
}

/// Simplified API client that mocks backend interactions until networking is wired up.
class ApiService {
  static final ApiService _singleton = ApiService._();

  factory ApiService() => _singleton;

  ApiService._();

  Future<List<RecyclingPoint>> fetchRecyclingPoints() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return [
      RecyclingPoint(
        id: 'loc-1',
        name: 'Kadıköy Belediyesi Geri Dönüşüm Merkezi',
        acceptedMaterials: const ['plastik', 'cam', 'metal'],
      ),
      RecyclingPoint(
        id: 'loc-2',
        name: 'Üsküdar Yeşil Nokta',
        acceptedMaterials: const ['kağıt', 'elektronik'],
      ),
    ];
  }

  Future<String> requestPickup({required String material, required double weightKg}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return 'Talebiniz alındı. $material için ${weightKg.toStringAsFixed(1)} kg geri dönüşüm kaydedildi.';
  }

  Future<RewardSummary> fetchRewardSummary() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return RewardSummary(points: 120, carbonSavings: 4.3);
  }
}
