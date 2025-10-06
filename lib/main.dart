import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'config/app_config.dart';
import 'widgets/auth_wrapper.dart';
import 'screens/settings_screen.dart';
import 'services/theme_controller.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Splash preservation removed (flutter_native_splash not required here)
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize Firestore
    await FirestoreService.initialize();
    
    // Initialize theme controller
    await ThemeController.init();
    
    // Initialize auth service
    await AuthService().init();
    
  } catch (e) {
    // Continue anyway to show error to user
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppConfig.appName,
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppConfig.primaryColor,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: AppConfig.backgroundColor,
            appBarTheme: const AppBarTheme(
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: AppConfig.primaryDark,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            textTheme: ThemeData().textTheme.copyWith(
                  titleLarge: const TextStyle(color: AppConfig.primaryDark),
                  titleMedium: const TextStyle(color: AppConfig.primaryDark),
                ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppConfig.primaryColor,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF37353E),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
            ),
            cardColor: const Color(0xFF2F2D36),
            dividerColor: Colors.white12,
            listTileTheme: const ListTileThemeData(
              iconColor: Colors.white70,
              textColor: Colors.white,
              dense: false,
            ),
            textTheme: ThemeData(brightness: Brightness.dark).textTheme.copyWith(
                  titleLarge: const TextStyle(color: Color(0xFF81C784)),
                  titleMedium: const TextStyle(color: Color(0xFF81C784)),
                ),
          ),
          home: AuthWrapper(),
          routes: {
            '/settings': (context) => const SettingsScreen(),
          },
        );
      },
    );
  }
}
