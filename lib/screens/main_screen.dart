import 'package:flutter/material.dart';
import '../config/app_config.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'plant_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomeScreen(),
    LibraryScreen(),
    PlantScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          backgroundColor: Colors.transparent,
          indicatorColor: AppConfig.primaryColor.withOpacity(0.1),
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          height: 70,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppConfig.primaryColor),
              label: "Home",
            ),
            NavigationDestination(
              icon: Icon(Icons.local_library_outlined),
              selectedIcon: Icon(Icons.local_library, color: AppConfig.primaryColor),
              label: "Library",
            ),
            NavigationDestination(
              icon: Icon(Icons.camera_alt_outlined),
              selectedIcon: Icon(Icons.camera_alt, color: AppConfig.primaryColor),
              label: "Scan",
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history, color: AppConfig.primaryColor),
              label: "History",
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppConfig.primaryColor),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}
