import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

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
  List<Coupon>? _coupons;
  List<dynamic>? _locations;
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
    _tabController = TabController(length: 6, vsync: this);
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
        SnackBar(content: Text('Failed to load users: $e')),
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
        SnackBar(content: Text('Failed to load pickups: $e')),
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
        SnackBar(content: Text('Failed to load materials: $e')),
      );
    }
  }

  Future<void> _loadCoupons() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/admin/coupons'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coupons = (data['coupons'] as List<dynamic>?) ?? [];
        setState(() {
          _coupons = coupons
              .map((c) => Coupon.fromJson(c as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load coupons: $e')),
      );
    }
  }

  Future<void> _loadLocations() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/admin/locations'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _locations = (data['locations'] as List<dynamic>?) ?? [];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load locations: $e')),
      );
    }
  }

  Future<void> _addLocation({
    required String name,
    required double latitude,
    required double longitude,
    required List<String> acceptedMaterials,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/admin/locations'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
          'acceptedMaterials': acceptedMaterials,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location created'), backgroundColor: Colors.green),
        );
        _loadLocations();
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to create location');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _updateLocation(
    String id, {
    String? name,
    List<String>? acceptedMaterials,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (acceptedMaterials != null)
        body['acceptedMaterials'] = acceptedMaterials;

      final response = await _client.patch(
        Uri.parse('$_baseUrl/api/admin/locations/$id'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location updated'), backgroundColor: Colors.green),
        );
        _loadLocations();
      } else {
        throw Exception('Failed to update location');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteLocation(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Location'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/api/admin/locations/$id'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location deleted'), backgroundColor: Colors.green),
        );
        _loadLocations();
      } else {
        throw Exception('Failed to delete location');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showAddLocationDialog() {
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lonController = TextEditingController();
    final materials = ['plastic', 'glass', 'paper', 'metal', 'electronics'];
    final selectedMaterials = <String>{'plastic', 'glass', 'paper', 'metal'};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Recycling Center'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    hintText: 'e.g. Downtown Recycling Center',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: latController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Latitude *',
                    hintText: 'e.g. 41.0082',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lonController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Longitude *',
                    hintText: 'e.g. 28.9784',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Accepted Materials:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: materials.map((m) {
                    final isSelected = selectedMaterials.contains(m);
                    return FilterChip(
                      label: Text(m),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final lat = double.tryParse(latController.text);
                final lon = double.tryParse(lonController.text);

                if (name.isEmpty || lat == null || lon == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please fill all required fields')),
                  );
                  return;
                }

                Navigator.pop(context);
                _addLocation(
                  name: name,
                  latitude: lat,
                  longitude: lon,
                  acceptedMaterials: selectedMaterials.toList(),
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLocationDialog(Map<String, dynamic> location) {
    final nameController = TextEditingController(text: location['name'] ?? '');
    final materials = ['plastic', 'glass', 'paper', 'metal', 'electronics'];
    final currentMaterials = (location['acceptedMaterials'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final selectedMaterials = Set<String>.from(currentMaterials);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Recycling Center'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                const Text('Accepted Materials:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: materials.map((m) {
                    final isSelected = selectedMaterials.contains(m);
                    return FilterChip(
                      label: Text(m),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateLocation(
                  location['id'],
                  name: nameController.text.trim(),
                  acceptedMaterials: selectedMaterials.toList(),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
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
          const SnackBar(content: Text('Role updated')),
        );
        _loadUsers();
      } else if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot change your own role')),
        );
      } else {
        throw Exception('Failed to update role');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update role: $e')),
      );
    }
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.red, size: 48),
        title: const Text('Delete User'),
        content: Text(
            'Are you sure you want to delete "${user['name']}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
            content: Text('✅ "$userName" deleted'),
            backgroundColor: Colors.green,
          ),
        );
        _loadUsers();
      } else {
        throw Exception('Failed to delete user');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Delete failed: $e')),
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
            Text('Updating ${material.toUpperCase()} multiplier...'),
            const SizedBox(height: 8),
            const Text(
              '⛓️ Blockchain transaction in progress\nThis may take 10-30 seconds',
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
            title: const Text('Success!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${material.toUpperCase()} multiplier updated.'),
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
                      Text('📦 New Multiplier: ${weight}x',
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
                  '💡 This change is now active on blockchain. '
                  'New recycling will use this multiplier.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        _loadMaterials();
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.error, color: Colors.red, size: 48),
          title: const Text('Error!'),
          content: Text('Failed to update multiplier:\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _deleteCoupon(Coupon coupon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Coupon'),
        content: Text('Are you sure you want to delete "${coupon.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/api/admin/coupons/${coupon.id}'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Coupon deleted'), backgroundColor: Colors.green),
        );
        _loadCoupons();
      } else {
        throw Exception('Failed to delete coupon');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _updateCouponPointCost(Coupon coupon, int newPointCost) async {
    try {
      final response = await _client.patch(
        Uri.parse('$_baseUrl/api/admin/coupons/${coupon.id}'),
        headers: _headers,
        body: jsonEncode({'pointCost': newPointCost}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Coupon updated'), backgroundColor: Colors.green),
        );
        _loadCoupons();
      } else {
        throw Exception('Failed to update coupon');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showEditCouponDialog(Coupon coupon) {
    final controller = TextEditingController(text: coupon.pointCost.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${coupon.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Point Cost',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newCost = int.tryParse(controller.text);
              if (newCost != null && newCost > 0) {
                Navigator.pop(context);
                _updateCouponPointCost(coupon, newCost);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCoupon({
    required String name,
    required String partner,
    required String discountType,
    required int discountValue,
    required int pointCost,
    String? description,
    String? imageUrl,
  }) async {
    try {
      final body = {
        'name': name,
        'partner': partner,
        'discountType': discountType,
        'discountValue': discountValue,
        'pointCost': pointCost,
      };
      if (description != null && description.isNotEmpty) {
        body['description'] = description;
      }
      if (imageUrl != null && imageUrl.isNotEmpty) {
        body['imageUrl'] = imageUrl;
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/api/admin/coupons'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Coupon created successfully'),
              backgroundColor: Colors.green),
        );
        _loadCoupons();
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to create coupon');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showAddCouponDialog() {
    final nameController = TextEditingController();
    final partnerController = TextEditingController();
    final descriptionController = TextEditingController();
    final discountValueController = TextEditingController();
    final pointCostController = TextEditingController();
    final imageUrlController = TextEditingController();
    String discountType = 'percentage';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Coupon'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    hintText: 'e.g. 10% Off Coffee',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: partnerController,
                  decoration: const InputDecoration(
                    labelText: 'Partner *',
                    hintText: 'e.g. Starbucks',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional description',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: discountType,
                  decoration: const InputDecoration(
                    labelText: 'Discount Type *',
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'percentage', child: Text('Percentage (%)')),
                    DropdownMenuItem(
                        value: 'fixed', child: Text('Fixed Amount')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => discountType = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: discountValueController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Discount Value *',
                    hintText:
                        discountType == 'percentage' ? 'e.g. 10' : 'e.g. 5',
                    suffixText: discountType == 'percentage' ? '%' : '₺',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pointCostController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Point Cost *',
                    hintText: 'e.g. 100',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    hintText: 'Optional image URL',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final partner = partnerController.text.trim();
                final discountValue =
                    int.tryParse(discountValueController.text);
                final pointCost = int.tryParse(pointCostController.text);

                if (name.isEmpty ||
                    partner.isEmpty ||
                    discountValue == null ||
                    pointCost == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please fill all required fields')),
                  );
                  return;
                }

                Navigator.pop(context);
                _addCoupon(
                  name: name,
                  partner: partner,
                  discountType: discountType,
                  discountValue: discountValue,
                  pointCost: pointCost,
                  description: descriptionController.text.trim(),
                  imageUrl: imageUrlController.text.trim(),
                );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.green.shade700,
            isScrollable: true,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
              Tab(icon: Icon(Icons.people), text: 'Users'),
              Tab(icon: Icon(Icons.local_shipping), text: 'Pickups'),
              Tab(icon: Icon(Icons.token), text: 'Rewards'),
              Tab(icon: Icon(Icons.card_giftcard), text: 'Coupons'),
              Tab(icon: Icon(Icons.location_on), text: 'Locations'),
            ],
            onTap: (index) {
              if (index == 1 && _users == null) _loadUsers();
              if (index == 2 && _pickups == null) _loadPickups();
              if (index == 3 && _materials == null) _loadMaterials();
              if (index == 4 && _coupons == null) _loadCoupons();
              if (index == 5 && _locations == null) _loadLocations();
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
                _buildCouponsTab(),
                _buildLocationsTab(),
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
            Text('Error: $_error'),
            ElevatedButton(
              onPressed: _loadDashboard,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_stats == null) {
      return const Center(child: Text('No data'));
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
          _buildSectionTitle('User Statistics'),
          Row(
            children: [
              _buildStatCard('Total', users['total'].toString(), Icons.people),
              _buildStatCard(
                  'User', users['byRole']['user'].toString(), Icons.person),
              _buildStatCard('Courier', users['byRole']['courier'].toString(),
                  Icons.delivery_dining),
              _buildStatCard('Admin', users['byRole']['admin'].toString(),
                  Icons.admin_panel_settings),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Pickup Statistics'),
          Row(
            children: [
              _buildStatCard(
                  'Total', pickups['total'].toString(), Icons.recycling),
              _buildStatCard(
                  'Pending', pickups['pending'].toString(), Icons.pending),
              _buildStatCard(
                  'Assigned', pickups['assigned'].toString(), Icons.assignment),
              _buildStatCard('Completed', pickups['completed'].toString(),
                  Icons.check_circle),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Courier Status'),
          Row(
            children: [
              _buildStatCard(
                  'Total', couriers['total'].toString(), Icons.local_shipping),
              _buildStatCard('Active', couriers['active'].toString(),
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
                    ? 'Blockchain Connected'
                    : 'Blockchain Not Connected',
              ),
              subtitle: Text(
                'On-chain Pickups: ${blockchain['totalPickups']}\n'
                'Rewards Distributed: ${blockchain['totalRewardsDistributed']} GRT',
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
                'Role: ${user['role']} | Points: ${user['greenPoints']}',
              ),
              isThreeLine: true,
              trailing: _isCurrentUser(user['id'])
                  ? const Chip(
                      label: Text('You'),
                      backgroundColor: Colors.purple,
                      labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopupMenuButton<String>(
                          tooltip: 'Change Role',
                          onSelected: (role) =>
                              _updateUserRole(user['id'], role),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'user', child: Text('User')),
                            const PopupMenuItem(
                                value: 'courier', child: Text('Courier')),
                            const PopupMenuItem(
                                value: 'admin', child: Text('Admin')),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Delete',
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
                'User: ${pickup['userName']}\n'
                'Status: ${pickup['status']}',
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
            'Material Reward Multipliers (Blockchain)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tokens earned per kg = weight × multiplier',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ..._materials!.entries.map((entry) {
            return Card(
              child: ListTile(
                leading: Icon(_getMaterialIcon(entry.key)),
                title: Text(entry.key.toUpperCase()),
                subtitle: Text('Multiplier: ${entry.value}x'),
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

  Widget _buildCouponsTab() {
    if (_coupons == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        if (_coupons!.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.card_giftcard, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No coupons available'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showAddCouponDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Coupon'),
                ),
              ],
            ),
          )
        else
          RefreshIndicator(
            onRefresh: _loadCoupons,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _coupons!.length,
              itemBuilder: (context, index) {
                final coupon = _coupons![index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: coupon.isActive
                            ? Colors.green[50]
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          coupon.displayDiscount,
                          style: TextStyle(
                            color: coupon.isActive
                                ? Colors.green[700]
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(coupon.name)),
                        if (!coupon.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Inactive',
                                style:
                                    TextStyle(fontSize: 10, color: Colors.red)),
                          ),
                      ],
                    ),
                    subtitle:
                        Text('${coupon.partner} • ${coupon.pointCost} points'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditCouponDialog(coupon),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteCoupon(coupon),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (_coupons!.isNotEmpty)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _showAddCouponDialog,
              backgroundColor: Colors.green,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationsTab() {
    if (_locations == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        if (_locations!.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No recycling centers'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showAddLocationDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Location'),
                ),
              ],
            ),
          )
        else
          RefreshIndicator(
            onRefresh: _loadLocations,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _locations!.length,
              itemBuilder: (context, index) {
                final location = _locations![index] as Map<String, dynamic>;
                final name = location['name'] ?? 'Unknown';
                final coords = location['coordinates'] as Map<String, dynamic>?;
                final lat = coords?['latitude'] ?? 0;
                final lon = coords?['longitude'] ?? 0;
                final materials =
                    (location['acceptedMaterials'] as List<dynamic>?) ?? [];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.green),
                    ),
                    title: Text(name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lat: ${lat.toStringAsFixed(4)}, Lon: ${lon.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: materials
                              .map((m) => Chip(
                                    label: Text(m.toString(),
                                        style: const TextStyle(fontSize: 10)),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditLocationDialog(location),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () =>
                              _deleteLocation(location['id'], name),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (_locations!.isNotEmpty)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: _showAddLocationDialog,
              backgroundColor: Colors.green,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
      ],
    );
  }

  void _showEditMaterialDialog(String material, int currentWeight) {
    final controller = TextEditingController(text: currentWeight.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${material.toUpperCase()} Multiplier'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'New multiplier value (0-255)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newWeight = int.tryParse(controller.text);
              if (newWeight != null && newWeight >= 0 && newWeight <= 255) {
                Navigator.pop(context);
                _updateMaterialWeight(material, newWeight);
              }
            },
            child: const Text('Update'),
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
