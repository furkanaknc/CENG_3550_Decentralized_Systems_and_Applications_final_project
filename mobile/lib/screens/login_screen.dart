import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/metamask.dart' as metamask;
import '../widgets/wallet_connect_modal.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();

  bool _isLoading = false;
  bool _isMetaMaskLoading = false;
  String? _errorMessage;
  bool _hasMetaMask = false;

  @override
  void initState() {
    super.initState();
    _checkMetaMask();
    _tryRestoreSession();
  }

  void _checkMetaMask() {
    if (kIsWeb) {
      setState(() {
        _hasMetaMask = metamask.isMetaMaskAvailable();
      });
    }
  }

  Future<void> _tryRestoreSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _auth.restoreSession();

      if (user != null && mounted) {
        _navigateToHome();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _connectWithMetaMask() async {
    setState(() {
      _isMetaMaskLoading = true;
      _errorMessage = null;
    });

    try {
      final address = await metamask.connectMetaMask();

      if (address != null) {
        await metamask.switchToSepoliaNetwork();

        final response = await _auth.loginWithAddress(address);

        if (response != null && mounted) {
          _navigateToHome();
        } else {
          setState(() {
            _errorMessage = 'Giriş başarısız oldu.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isMetaMaskLoading = false;
        });
      }
    }
  }

  Future<void> _connectWallet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    ConnectResponse? connectResponse;

    try {
      print('🔄 Creating WalletConnect session...');
      connectResponse = await _auth.loginWithWallet();

      if (connectResponse is ConnectResponse && mounted) {
        setState(() {
          _isLoading = false;
        });

        final uri = connectResponse.uri;
        if (uri != null) {
          print('✅ QR URI created: ${uri.toString().substring(0, 50)}...');

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => WalletConnectModal(
              uri: uri.toString(),
              onCancel: () {
                print('❌ User cancelled connection');
                Navigator.of(context).pop();
                setState(() {
                  _errorMessage = 'Bağlantı iptal edildi';
                });
              },
            ),
          );

          print('⏳ Waiting for wallet approval...');
          final user = await _auth.completeLogin(connectResponse);

          if (mounted) {
            Navigator.of(context).pop();
          }

          print('✅ Login completed, user: ${user?.walletAddress}');

          if (user != null && mounted) {
            _navigateToHome();
          } else {
            setState(() {
              _errorMessage = 'Giriş başarısız oldu.';
            });
          }
        }
      } else {
        print('❌ ConnectResponse is null or invalid');
        setState(() {
          _errorMessage = 'Bağlantı oluşturulamadı.';
        });
      }
    } catch (e) {
      print('❌ Error during connection: $e');

      if (mounted && connectResponse != null) {
        Navigator.of(context).pop();
      }

      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade700,
              Colors.green.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.recycling,
                      size: 80,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Green Cycle',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Blockchain Tabanlı Geri Dönüşüm',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Text(
                            'Giriş Yap',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Cüzdanınızla giriş yapın',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 24),

                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.red.shade700),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style:
                                          TextStyle(color: Colors.red.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (_hasMetaMask) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _isMetaMaskLoading
                                    ? null
                                    : _connectWithMetaMask,
                                icon: _isMetaMaskLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Image.network(
                                        'https://upload.wikimedia.org/wikipedia/commons/3/36/MetaMask_Fox.svg',
                                        width: 24,
                                        height: 24,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                                Icons.account_balance_wallet),
                                      ),
                                label: Text(
                                  _isMetaMaskLoading
                                      ? 'Bağlanıyor...'
                                      : 'MetaMask ile Giriş',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF6851B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                    child:
                                        Divider(color: Colors.grey.shade300)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text('veya',
                                      style: TextStyle(
                                          color: Colors.grey.shade500)),
                                ),
                                Expanded(
                                    child:
                                        Divider(color: Colors.grey.shade300)),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],

                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _connectWallet,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.qr_code),
                              label: Text(
                                _isLoading
                                    ? 'Bağlanıyor...'
                                    : 'QR Kod ile Bağlan',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Sepolia Test Network kullanılmaktadır',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
