import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/auth_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final http.Client _client = http.Client();
  late TabController _tabController;

  Map<String, dynamic>? _stats;
  List<dynamic>? _users;
  List<dynamic>? _pickups;
  Map<String, dynamic>? _materials;
  bool _loading = true;
  String? _error;

  String get _baseUrl {
    final apiUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:4000';
    return apiUrl.replaceAll(RegExp(r'/+$'), '');
  }

  bool _isCurrentUser(String? userId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null || userId == null) return false;
    return currentUser.id == userId;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Map<String, String> get _headers => {
        ..._auth.getAuthHeaders(),
        'Content-Type': 'application/json',
      };

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/admin/dashboard'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _stats = data['stats'];
          _loading = false;
        });
      } else {
        throw Exception('Failed to load dashboard');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/admin/users'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _users = data['users'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kullanıcılar yüklenemedi: $e')),
      );
    }
  }

  Future<void> _loadPickups() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/admin/pickups'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _pickups = data['pickups'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Talepler yüklenemedi: $e')),
      );
    }
  }

  Future<void> _loadMaterials() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/admin/blockchain/materials'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _materials = data['materials'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Materyaller yüklenemedi: $e')),
      );
    }
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      final response = await _client.patch(
        Uri.parse('$_baseUrl/api/admin/users/$userId/role'),
        headers: _headers,
        body: jsonEncode({'role': newRole, 'syncBlockchain': true}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rol güncellendi')),
        );
        _loadUsers();
      } else if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kendi rolünüzü değiştiremezsiniz')),
        );
      } else {
        throw Exception('Failed to update role');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rol güncellenemedi: $e')),
      );
    }
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.red, size: 48),
        title: const Text('Kullanıcıyı Sil'),
        content: Text(
            '"${user['name']}" kullanıcısını silmek istediğinize emin misiniz?\n\nBu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteUser(user['id'], user['name']);
    }
  }

  Future<void> _deleteUser(String userId, String userName) async {
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/api/admin/users/$userId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "$userName" silindi'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUsers();
      } else {
        throw Exception('Failed to delete user');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Silinemedi: $e')),
      );
    }
  }

  Future<void> _updateMaterialWeight(String material, int weight) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('${material.toUpperCase()} çarpanı güncelleniyor...'),
            const SizedBox(height: 8),
            const Text(
              '⛓️ Blockchain işlemi devam ediyor\nBu işlem 10-30 saniye sürebilir',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/api/admin/blockchain/materials/$material'),
        headers: _headers,
        body: jsonEncode({'weight': weight}),
      );

      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final txHash = data['txHash'] ?? 'N/A';

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
            title: const Text('Başarılı!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${material.toUpperCase()} çarpanı güncellendi.'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📦 Yeni Çarpan: ${weight}x',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                          '⛓️ TX Hash: ${txHash.length > 20 ? '${txHash.substring(0, 20)}...' : txHash}',
                          style: const TextStyle(
                              fontSize: 11, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '💡 Bu değişiklik artık blockchain üzerinde geçerli. '
                  'Yeni geri dönüşümler bu çarpanla hesaplanacak.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              ),
            ],
          ),
        );

        _loadMaterials();
      } else {
        throw Exception('Sunucu hatası: ${response.statusCode}');
      }
    } catch (e) {
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.error, color: Colors.red, size: 48),
          title: const Text('Hata!'),
          content: Text('Çarpan güncellenemedi:\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.green.shade700,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
              Tab(icon: Icon(Icons.people), text: 'Kullanıcılar'),
              Tab(icon: Icon(Icons.local_shipping), text: 'Talepler'),
              Tab(icon: Icon(Icons.token), text: 'Ödüller'),
            ],
            onTap: (index) {
              if (index == 1 && _users == null) _loadUsers();
              if (index == 2 && _pickups == null) _loadPickups();
              if (index == 3 && _materials == null) _loadMaterials();
            },
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildUsersTab(),
                _buildPickupsTab(),
                _buildMaterialsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Hata: $_error'),
            ElevatedButton(
              onPressed: _loadDashboard,
              child: const Text('Yeniden Dene'),
            ),
          ],
        ),
      );
    }

    if (_stats == null) {
      return const Center(child: Text('Veri yok'));
    }

    final users = _stats!['users'] as Map<String, dynamic>;
    final pickups = _stats!['pickups'] as Map<String, dynamic>;
    final couriers = _stats!['couriers'] as Map<String, dynamic>;
    final blockchain = _stats!['blockchain'] as Map<String, dynamic>;

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Kullanıcı İstatistikleri'),
          Row(
            children: [
              _buildStatCard('Toplam', users['total'].toString(), Icons.people),
              _buildStatCard(
                  'User', users['byRole']['user'].toString(), Icons.person),
              _buildStatCard('Kurye', users['byRole']['courier'].toString(),
                  Icons.delivery_dining),
              _buildStatCard('Admin', users['byRole']['admin'].toString(),
                  Icons.admin_panel_settings),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Pickup İstatistikleri'),
          Row(
            children: [
              _buildStatCard(
                  'Toplam', pickups['total'].toString(), Icons.recycling),
              _buildStatCard(
                  'Bekleyen', pickups['pending'].toString(), Icons.pending),
              _buildStatCard(
                  'Atanmış', pickups['assigned'].toString(), Icons.assignment),
              _buildStatCard('Tamamlanan', pickups['completed'].toString(),
                  Icons.check_circle),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Kurye Durumu'),
          Row(
            children: [
              _buildStatCard(
                  'Toplam', couriers['total'].toString(), Icons.local_shipping),
              _buildStatCard('Aktif', couriers['active'].toString(),
                  Icons.online_prediction),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Blockchain'),
          Card(
            child: ListTile(
              leading: Icon(
                blockchain['blockchainConfigured'] == true
                    ? Icons.check_circle
                    : Icons.error,
                color: blockchain['blockchainConfigured'] == true
                    ? Colors.green
                    : Colors.red,
              ),
              title: Text(
                blockchain['blockchainConfigured'] == true
                    ? 'Blockchain Bağlı'
                    : 'Blockchain Bağlı Değil',
              ),
              subtitle: Text(
                'On-chain Pickup: ${blockchain['totalPickups']}\n'
                'Dağıtılan Ödül: ${blockchain['totalRewardsDistributed']} GRT',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_users == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.builder(
        itemCount: _users!.length,
        itemBuilder: (context, index) {
          final user = _users![index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getRoleColor(user['role']),
                child: Text(user['name'][0].toUpperCase()),
              ),
              title: Text(user['name']),
              subtitle: Text(
                '${user['walletAddress']?.substring(0, 10)}...\n'
                'Rol: ${user['role']} | Puan: ${user['greenPoints']}',
              ),
              isThreeLine: true,
              trailing: _isCurrentUser(user['id'])
                  ? const Chip(
                      label: Text('Sen'),
                      backgroundColor: Colors.purple,
                      labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopupMenuButton<String>(
                          tooltip: 'Rol Değiştir',
                          onSelected: (role) =>
                              _updateUserRole(user['id'], role),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'user', child: Text('User')),
                            const PopupMenuItem(
                                value: 'courier', child: Text('Kurye')),
                            const PopupMenuItem(
                                value: 'admin', child: Text('Admin')),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Sil',
                          onPressed: () => _confirmDeleteUser(user),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPickupsTab() {
    if (_pickups == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadPickups,
      child: ListView.builder(
        itemCount: _pickups!.length,
        itemBuilder: (context, index) {
          final pickup = _pickups![index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: Icon(
                _getStatusIcon(pickup['status']),
                color: _getStatusColor(pickup['status']),
              ),
              title: Text('${pickup['material']} - ${pickup['weightKg']} kg'),
              subtitle: Text(
                'Kullanıcı: ${pickup['userName']}\n'
                'Durum: ${pickup['status']}',
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }

  Widget _buildMaterialsTab() {
    if (_materials == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadMaterials,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Materyal Ödül Çarpanları (Blockchain)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Her kg için kazanılan token = ağırlık × çarpan',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ..._materials!.entries.map((entry) {
            return Card(
              child: ListTile(
                leading: Icon(_getMaterialIcon(entry.key)),
                title: Text(entry.key.toUpperCase()),
                subtitle: Text('Çarpan: ${entry.value}x'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () =>
                      _showEditMaterialDialog(entry.key, entry.value),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showEditMaterialDialog(String material, int currentWeight) {
    final controller = TextEditingController(text: currentWeight.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${material.toUpperCase()} Çarpanı'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Yeni çarpan değeri (0-255)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final newWeight = int.tryParse(controller.text);
              if (newWeight != null && newWeight >= 0 && newWeight <= 255) {
                Navigator.pop(context);
                _updateMaterialWeight(material, newWeight);
              }
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, size: 28, color: Colors.green.shade700),
              const SizedBox(height: 8),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purple;
      case 'courier':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'assigned':
        return Icons.assignment;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getMaterialIcon(String material) {
    switch (material) {
      case 'plastic':
        return Icons.local_drink;
      case 'glass':
        return Icons.wine_bar;
      case 'paper':
        return Icons.description;
      case 'metal':
        return Icons.hardware;
      case 'electronics':
        return Icons.devices;
      default:
        return Icons.category;
    }
  }
}
