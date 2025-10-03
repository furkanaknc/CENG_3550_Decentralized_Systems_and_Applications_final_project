import 'package:flutter/material.dart';
import 'screens/map_screen.dart';
import 'screens/pickup_request_screen.dart';
import 'screens/rewards_screen.dart';

void main() {
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
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [MapScreen(), PickupRequestScreen(), RewardsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: 'Harita'),
          NavigationDestination(icon: Icon(Icons.recycling), label: 'Teslim'),
          NavigationDestination(icon: Icon(Icons.card_giftcard), label: 'Ödüller'),
        ],
        onDestinationSelected: (value) => setState(() => _index = value),
      ),
    );
  }
}
