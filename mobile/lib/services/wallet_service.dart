import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  Web3App? _web3App;
  String? _currentAddress;
  String? _currentSession;
  final _addressController = StreamController<String?>.broadcast();

  Stream<String?> get addressStream => _addressController.stream;
  String? get currentAddress => _currentAddress;
  bool get isConnected => _currentAddress != null && _currentSession != null;

  Future<void> init() async {
    if (_web3App != null) return;

    try {
      _web3App = await Web3App.createInstance(
        projectId: '274136f0aeb7d1332c2f2d0040584cfd',
        metadata: const PairingMetadata(
          name: 'Green Cycle',
          description: 'Blockchain Tabanlı Geri Dönüşüm Platformu',
          url: 'https://greencycle.app',
          icons: ['https://greencycle.app/icon.png'],
        ),
      );

      _web3App!.onSessionEvent.subscribe(_onSessionEvent);
      _web3App!.onSessionUpdate.subscribe(_onSessionUpdate);
      _web3App!.onSessionDelete.subscribe(_onSessionDelete);

      print('WalletConnect initialized');
    } catch (e) {
      print('WalletConnect initialization error: $e');
      rethrow;
    }
  }

  Future<ConnectResponse> createSession() async {
    if (_web3App == null) {
      await init();
    }

    try {
      final requiredNamespaces = {
        'eip155': const RequiredNamespace(
          chains: ['eip155:11155111'],
          methods: [
            'eth_sendTransaction',
            'eth_signTransaction',
            'eth_sign',
            'personal_sign',
            'eth_signTypedData',
          ],
          events: ['chainChanged', 'accountsChanged'],
        ),
      };

      final ConnectResponse response = await _web3App!.connect(
        requiredNamespaces: requiredNamespaces,
      );

      return response;
    } catch (e) {
      print('WalletConnect connection error: $e');
      rethrow;
    }
  }

  Future<String?> waitForConnection(ConnectResponse response) async {
    try {
      print('⏳ Waiting for session approval...');

      final SessionData session = await response.session.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          print('⏰ Session approval timeout');
          throw Exception(
              'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.');
        },
      );

      print('📝 Session received: ${session?.topic}');

      if (session != null) {
        _currentSession = session.topic;

        final accounts = session.namespaces['eip155']?.accounts ?? [];
        print('📋 Accounts: $accounts');

        if (accounts.isNotEmpty) {
          final parts = accounts.first.split(':');
          _currentAddress = parts.last.toLowerCase();

          print('✅ Connected address: $_currentAddress');

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('wallet_address', _currentAddress!);
          await prefs.setString('wallet_session', _currentSession!);

          _addressController.add(_currentAddress);
          return _currentAddress;
        } else {
          print('❌ No accounts in session');
        }
      } else {
        print('❌ Session is null');
      }

      return null;
    } catch (e) {
      print('❌ WalletConnect connection error: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (_web3App != null && _currentSession != null) {
      try {
        await _web3App!.disconnectSession(
          topic: _currentSession!,
          reason: Errors.getSdkError(Errors.USER_DISCONNECTED),
        );
      } catch (e) {
        print('Disconnect error: $e');
      }
    }

    _currentAddress = null;
    _currentSession = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wallet_address');
    await prefs.remove('wallet_session');

    _addressController.add(null);
  }

  Future<String?> restoreSession() async {
    if (_web3App == null) {
      await init();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAddress = prefs.getString('wallet_address');
      final savedSession = prefs.getString('wallet_session');

      if (savedAddress == null || savedSession == null) {
        return null;
      }

      final sessions = _web3App!.sessions.getAll();
      final session = sessions.firstWhere(
        (s) => s.topic == savedSession,
        orElse: () => throw Exception('Session not found'),
      );

      _currentSession = session.topic;
      _currentAddress = savedAddress;

      _addressController.add(_currentAddress);
      return _currentAddress;
    } catch (e) {
      print('Failed to restore session: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('wallet_address');
      await prefs.remove('wallet_session');
      return null;
    }
  }

  Future<bool> switchToSepolia() async {
    if (_web3App == null || _currentSession == null) {
      return false;
    }

    try {
      await _web3App!.request(
        topic: _currentSession!,
        chainId: 'eip155:11155111',
        request: const SessionRequestParams(
          method: 'wallet_switchEthereumChain',
          params: [
            {'chainId': '0xaa36a7'}
          ],
        ),
      );
      return true;
    } catch (e) {
      print('Failed to switch network: $e');

      if (e.toString().contains('4902')) {
        return await _addSepoliaNetwork();
      }

      return false;
    }
  }

  Future<bool> _addSepoliaNetwork() async {
    if (_web3App == null || _currentSession == null) {
      return false;
    }

    try {
      await _web3App!.request(
        topic: _currentSession!,
        chainId: 'eip155:11155111',
        request: const SessionRequestParams(
          method: 'wallet_addEthereumChain',
          params: [
            {
              'chainId': '0xaa36a7',
              'chainName': 'Sepolia Test Network',
              'nativeCurrency': {
                'name': 'Sepolia ETH',
                'symbol': 'ETH',
                'decimals': 18,
              },
              'rpcUrls': ['https://rpc.sepolia.org'],
              'blockExplorerUrls': ['https://sepolia.etherscan.io'],
            }
          ],
        ),
      );
      return true;
    } catch (e) {
      print('Failed to add Sepolia network: $e');
      return false;
    }
  }

  Future<String?> signMessage(String message) async {
    if (_web3App == null ||
        _currentSession == null ||
        _currentAddress == null) {
      return null;
    }

    try {
      final signature = await _web3App!.request(
        topic: _currentSession!,
        chainId: 'eip155:11155111',
        request: SessionRequestParams(
          method: 'personal_sign',
          params: [message, _currentAddress],
        ),
      );

      return signature.toString();
    } catch (e) {
      print('Failed to sign message: $e');
      return null;
    }
  }

  Future<String?> signTypedData(Map<String, dynamic> typedData) async {
    if (_web3App == null ||
        _currentSession == null ||
        _currentAddress == null) {
      return null;
    }

    try {
      final signature = await _web3App!.request(
        topic: _currentSession!,
        chainId: 'eip155:11155111',
        request: SessionRequestParams(
          method: 'eth_signTypedData',
          params: [_currentAddress, typedData],
        ),
      );

      return signature.toString();
    } catch (e) {
      print('Failed to sign typed data: $e');
      return null;
    }
  }

  void _onSessionEvent(SessionEvent? event) {
    print('Session event: ${event?.name}');
  }

  void _onSessionUpdate(SessionUpdate? update) {
    print('Session updated: ${update?.topic}');
  }

  void _onSessionDelete(SessionDelete? delete) {
    print('Session deleted: ${delete?.topic}');
    if (delete?.topic == _currentSession) {
      disconnect();
    }
  }

  void dispose() {
    _addressController.close();
    _web3App?.onSessionEvent.unsubscribe(_onSessionEvent);
    _web3App?.onSessionUpdate.unsubscribe(_onSessionUpdate);
    _web3App?.onSessionDelete.unsubscribe(_onSessionDelete);
  }
}
