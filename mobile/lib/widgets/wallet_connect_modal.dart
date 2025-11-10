import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class WalletConnectModal extends StatelessWidget {
  final String uri;
  final VoidCallback onCancel;

  const WalletConnectModal({
    super.key,
    required this.uri,
    required this.onCancel,
  });

  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: uri));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı kopyalandı!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openInWallet() async {
    try {
      // MetaMask deep link
      final metamaskUri = Uri.parse('metamask://wc?uri=${Uri.encodeComponent(uri)}');
      if (await canLaunchUrl(metamaskUri)) {
        await launchUrl(metamaskUri, mode: LaunchMode.externalApplication);
        return;
      }

      // Trust Wallet deep link
      final trustUri = Uri.parse('trust://wc?uri=${Uri.encodeComponent(uri)}');
      if (await canLaunchUrl(trustUri)) {
        await launchUrl(trustUri, mode: LaunchMode.externalApplication);
        return;
      }

      // Generic WalletConnect deep link
      final wcUri = Uri.parse('wc://wc?uri=${Uri.encodeComponent(uri)}');
      if (await canLaunchUrl(wcUri)) {
        await launchUrl(wcUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Failed to launch wallet: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.qr_code_2,
                  color: Colors.green.shade700,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cüzdanınızla Bağlanın',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onCancel,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: QrImageView(
                data: uri,
                version: QrVersions.auto,
                size: 250,
                backgroundColor: Colors.white,
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.green.shade700,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.green.shade700,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Instructions
            Text(
              'Mobil cüzdan uygulamanızda WalletConnect ile QR kodu tarayın',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Supported wallets
            Text(
              'Desteklenen Cüzdanlar',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _WalletChip(name: 'MetaMask'),
                _WalletChip(name: 'Trust Wallet'),
                _WalletChip(name: 'Rainbow'),
                _WalletChip(name: 'Coinbase'),
              ],
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyToClipboard(context),
                    icon: const Icon(Icons.copy),
                    label: const Text('Kopyala'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openInWallet,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Cüzdan Aç'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Help text
            Text(
              'QR kod 5 dakika süre ile geçerlidir',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletChip extends StatelessWidget {
  final String name;

  const _WalletChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        name,
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

