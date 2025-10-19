// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../config/app_config.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'plant_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const LibraryScreen(),
    const PlantScreen(),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: AppConfig.getShadowColor(isDark),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          backgroundColor: Colors.transparent,
          indicatorColor: isDark
              ? AppConfig.getTitleColor(context).withValues(alpha: 0.2)
              : AppConfig.primaryColor.withValues(alpha: 0.1),
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          height: 70,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppConfig.getTitleColor(context)),
              label: "Home",
            ),
            NavigationDestination(
              icon: const Icon(Icons.local_library_outlined),
              selectedIcon: Icon(Icons.local_library, color: AppConfig.getTitleColor(context)),
              label: "Library",
            ),
            NavigationDestination(
              icon: const Icon(Icons.camera_alt_outlined),
              selectedIcon: Icon(Icons.camera_alt, color: AppConfig.getTitleColor(context)),
              label: "Scan",
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history, color: AppConfig.getTitleColor(context)),
              label: "History",
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppConfig.getTitleColor(context)),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}
