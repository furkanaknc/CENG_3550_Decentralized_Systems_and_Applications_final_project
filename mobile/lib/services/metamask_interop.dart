// ignore_for_file: avoid_web_libraries_in_flutter
@JS()
library metamask_interop;

import 'dart:async';
// ignore: deprecated_member_use
import 'dart:js_util';
import 'package:js/js.dart';

@JS('window.ethereum')
external dynamic get _ethereum;

dynamic _getMetaMaskProvider() {
  if (_ethereum == null) return null;

  try {
    final providers = getProperty(_ethereum, 'providers');
    if (providers != null) {
      final providerList = providers as List<dynamic>;
      for (final provider in providerList) {
        final isMetaMask = getProperty(provider, 'isMetaMask');
        if (isMetaMask == true) {
          return provider;
        }
      }
    }
  } catch (e) {
    // No providers array, check if ethereum itself is MetaMask
  }

  try {
    final isMetaMask = getProperty(_ethereum, 'isMetaMask');
    if (isMetaMask == true) {
      return _ethereum;
    }
  } catch (e) {
    // Not MetaMask
  }

  return null;
}

bool isMetaMaskAvailable() {
  try {
    return _getMetaMaskProvider() != null;
  } catch (e) {
    return false;
  }
}

Future<bool> isMetaMaskConnected() async {
  final provider = _getMetaMaskProvider();
  if (provider == null) return false;

  try {
    final accounts =
        await promiseToFuture<List<dynamic>>(callMethod(provider, 'request', [
      jsify({'method': 'eth_accounts'})
    ]));
    return accounts.isNotEmpty;
  } catch (e) {
    return false;
  }
}

Future<String?> connectMetaMask() async {
  final provider = _getMetaMaskProvider();

  if (provider == null) {
    throw Exception(
        'MetaMask yüklü değil. Lütfen MetaMask eklentisini yükleyin.');
  }

  try {
    final accounts =
        await promiseToFuture<List<dynamic>>(callMethod(provider, 'request', [
      jsify({'method': 'eth_requestAccounts'})
    ]));

    if (accounts.isNotEmpty) {
      return (accounts.first as String).toLowerCase();
    }
    return null;
  } catch (e) {
    final errorStr = e.toString();
    if (errorStr.contains('4001')) {
      throw Exception('Kullanıcı bağlantıyı reddetti.');
    }
    throw Exception('MetaMask bağlantısı başarısız: $e');
  }
}

Future<String?> getChainId() async {
  final provider = _getMetaMaskProvider();
  if (provider == null) return null;

  try {
    final chainId =
        await promiseToFuture<String>(callMethod(provider, 'request', [
      jsify({'method': 'eth_chainId'})
    ]));
    return chainId;
  } catch (e) {
    return null;
  }
}

Future<bool> switchToSepoliaNetwork() async {
  final provider = _getMetaMaskProvider();
  if (provider == null) return false;

  const sepoliaChainId = '0xaa36a7';

  try {
    await promiseToFuture(callMethod(provider, 'request', [
      jsify({
        'method': 'wallet_switchEthereumChain',
        'params': [
          {'chainId': sepoliaChainId}
        ]
      })
    ]));
    return true;
  } catch (e) {
    final errorStr = e.toString();
    if (errorStr.contains('4902')) {
      return await _addSepoliaNetwork();
    }
    return false;
  }
}

Future<bool> _addSepoliaNetwork() async {
  final provider = _getMetaMaskProvider();
  if (provider == null) return false;

  try {
    await promiseToFuture(callMethod(provider, 'request', [
      jsify({
        'method': 'wallet_addEthereumChain',
        'params': [
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
        ]
      })
    ]));
    return true;
  } catch (e) {
    return false;
  }
}

Future<List<String>> getAccounts() async {
  final provider = _getMetaMaskProvider();
  if (provider == null) return [];

  try {
    final accounts =
        await promiseToFuture<List<dynamic>>(callMethod(provider, 'request', [
      jsify({'method': 'eth_accounts'})
    ]));
    return accounts.map((a) => (a as String).toLowerCase()).toList();
  } catch (e) {
    return [];
  }
}
