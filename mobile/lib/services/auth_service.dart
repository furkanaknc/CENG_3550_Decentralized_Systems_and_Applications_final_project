import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'wallet_service.dart';

class User {
  final String id;
  final String name;
  final String walletAddress;
  final String role;
  final int? greenPoints;

  User({
    required this.id,
    required this.name,
    required this.walletAddress,
    required this.role,
    this.greenPoints,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      walletAddress: json['walletAddress'] as String,
      role: json['role'] as String,
      greenPoints: json['greenPoints'] as int?,
    );
  }

  bool get isUser => role == 'user';
  bool get isCourier => role == 'courier';
  bool get isAdmin => role == 'admin';
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final WalletService _wallet = WalletService();
  final http.Client _client = http.Client();

  User? _currentUser;
  String? _cachedWalletAddress;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  String get _baseUrl {
    final apiUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:4000';
    return apiUrl.replaceAll(RegExp(r'/+$'), '');
  }

  Future<dynamic> loginWithWallet() async {
    try {
      await _wallet.init();

      return await _wallet.createSession();
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  Future<User?> completeLogin(dynamic connectResponse) async {
    try {
      print('🔄 Starting completeLogin...');

      final address = await _wallet.waitForConnection(connectResponse);

      print('📍 Address received: $address');

      if (address == null) {
        throw Exception('Cüzdan bağlantısı başarısız');
      }

      try {
        print('🔄 Switching to Sepolia...');
        await _wallet.switchToSepolia();
        print('✅ Network switched');
      } catch (e) {
        print('⚠️ Network switch failed (continuing anyway): $e');
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'walletAddress': address,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final userData = data['user'] as Map<String, dynamic>;
        _currentUser = User.fromJson(userData);
        _cachedWalletAddress = address;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(userData));

        return _currentUser;
      } else {
        throw Exception('Login failed: ${response.body}');
      }
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  Future<User?> loginWithAddress(String address) async {
    try {
      print('🦊 Logging in with MetaMask address: $address');

      final response = await _client.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'walletAddress': address,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final userData = data['user'] as Map<String, dynamic>;
        _currentUser = User.fromJson(userData);
        _cachedWalletAddress = address;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(userData));
        await prefs.setString('wallet_address', address);

        print('✅ MetaMask login successful: ${_currentUser?.name}');
        return _currentUser;
      } else {
        throw Exception('Login failed: ${response.body}');
      }
    } catch (e) {
      print('❌ MetaMask login error: $e');
      rethrow;
    }
  }

  Future<User?> restoreSession() async {
    try {
      await _wallet.init();
      final address = await _wallet.restoreSession();

      if (address == null) {
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');

      if (userDataString != null) {
        final userData = jsonDecode(userDataString) as Map<String, dynamic>;
        final savedAddress = userData['walletAddress'] as String?;

        if (savedAddress?.toLowerCase() == address.toLowerCase()) {
          _currentUser = User.fromJson(userData);
          _cachedWalletAddress = address;
          return _currentUser;
        }
      }

      return null;
    } catch (e) {
      print('Failed to restore session: $e');
      return null;
    }
  }

  Future<User?> getProfile() async {
    if (_cachedWalletAddress == null) {
      return null;
    }

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/auth/profile'),
        headers: {
          'x-wallet-address': _cachedWalletAddress!,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final userData = data['user'] as Map<String, dynamic>;
        _currentUser = User.fromJson(userData);
        return _currentUser;
      } else {
        throw Exception('Failed to get profile: ${response.body}');
      }
    } catch (e) {
      print('Get profile error: $e');
      return null;
    }
  }

  Future<void> logout() async {
    await _wallet.disconnect();
    _currentUser = null;
    _cachedWalletAddress = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
  }

  String? get walletAddress => _cachedWalletAddress ?? _wallet.currentAddress;

  Map<String, String> getAuthHeaders() {
    final address = walletAddress;
    if (address == null) {
      return {};
    }
    return {
      'x-wallet-address': address,
    };
  }
}
