//main.dart
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/settings_screen.dart';
import 'services/settings_service.dart';
import 'services/data_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _performStartupCleanup(); //Run retention cleanup on startup
  runApp(const OrivisApp()); //Start the app
}

Future<void> _performStartupCleanup() async {
  try {
    final settings = SettingsService(); //Access settings storage
    final data = DataService(); //Access data storage
    final policy = await settings.getRetentionPolicy(); //Read retention policy
    if (policy == 'forever') return; //Skip cleanup if set to Forever

    DateTime cutoff; //Compute cutoff date based on policy
    final now = DateTime.now();
    if (policy == '30d') {
      cutoff = now.subtract(const Duration(days: 30));
    } else if (policy == '1yr') {
      cutoff = now.subtract(const Duration(days: 365));
    } else {
      return;
    }

    await data.deleteOlderThan(cutoff); //Purge old records and images
  } catch (_) {
  }
}

class OrivisApp extends StatelessWidget {
  const OrivisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orivis', //App title
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo), //Material 3 theme
      home: const MainNavigator(), //Root navigator
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0; //Track selected tab
  late final List<Widget> _screens; //Keep tab screens

  void switchToTab(int index) {
    setState(() {
      _currentIndex = index; //Programmatic tab switch
    });
  }

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onStartInspection: () => switchToTab(1)), //Home tab
      const CameraScreen(), //Inspect tab
      const SettingsScreen(), //Settings tab
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex], //Render active tab
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index; //Handle tab taps
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Inspect',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}