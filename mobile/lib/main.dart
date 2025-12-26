import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'screens/pickup_request_screen.dart';
import 'screens/rewards_screen.dart';
import 'screens/courier_pickups_screen.dart';
import 'screens/admin_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const GreenCycleApp());
}

class GreenCycleApp extends StatelessWidget {
  const GreenCycleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Green Cycle',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/home': (context) => const HomeShell(),
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final AuthService _auth = AuthService();
  int _index = 0;

  List<Widget> get _userPages => const [
        MapScreen(),
        PickupRequestScreen(),
        RewardsScreen(),
      ];

  List<Widget> get _courierPages => const [
        CourierPickupsScreen(),
        MapScreen(),
      ];

  List<Widget> get _adminPages => const [
        AdminScreen(),
        MapScreen(),
      ];

  List<NavigationDestination> get _userDestinations => const [
        NavigationDestination(icon: Icon(Icons.map), label: 'Harita'),
        NavigationDestination(icon: Icon(Icons.recycling), label: 'Teslim'),
        NavigationDestination(icon: Icon(Icons.card_giftcard), label: 'Ödüller'),
      ];

  List<NavigationDestination> get _courierDestinations => const [
        NavigationDestination(icon: Icon(Icons.local_shipping), label: 'Talepler'),
        NavigationDestination(icon: Icon(Icons.map), label: 'Harita'),
      ];

  List<NavigationDestination> get _adminDestinations => const [
        NavigationDestination(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
        NavigationDestination(icon: Icon(Icons.map), label: 'Harita'),
      ];

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    if (!_auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Çıkış yapmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _auth.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isAdmin = user?.isAdmin ?? false;
    final isCourier = user?.isCourier ?? false;
    
    final List<Widget> pages;
    final List<NavigationDestination> destinations;
    
    if (isAdmin) {
      pages = _adminPages;
      destinations = _adminDestinations;
    } else if (isCourier) {
      pages = _courierPages;
      destinations = _courierDestinations;
    } else {
      pages = _userPages;
      destinations = _userDestinations;
    }

    if (_index >= pages.length) {
      _index = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Green Cycle'),
        backgroundColor: isAdmin ? Colors.purple.shade700 : Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              user?.role.toUpperCase() ?? 'USER',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: destinations,
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}

