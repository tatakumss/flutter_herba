import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/theme_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Preferences',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, _) {
              Widget radioTile(IconData icon, String label, ThemeMode value) {
                final selected = mode == value;
                return ListTile(
                  leading: Icon(icon),
                  title: Text(label),
                  trailing: selected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.circle_outlined),
                  onTap: () => ThemeController.setThemeMode(value),
                );
              }
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    radioTile(Icons.brightness_auto_outlined, 'System theme', ThemeMode.system),
                    const Divider(height: 1),
                    radioTile(Icons.light_mode_outlined, 'Light', ThemeMode.light),
                    const Divider(height: 1),
                    radioTile(Icons.dark_mode_outlined, 'Dark', ThemeMode.dark),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
