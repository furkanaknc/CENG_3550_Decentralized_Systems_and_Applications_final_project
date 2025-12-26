bool isMetaMaskAvailable() => false;
Future<bool> isMetaMaskConnected() async => false;
Future<String?> connectMetaMask() async => null;
Future<String?> getChainId() async => null;
Future<bool> switchToSepoliaNetwork() async => false;
Future<List<String>> getAccounts() async => [];
Future<String?> signTypedDataMetaMask(
        String address, Map<String, dynamic> typedData) async =>
    null;
