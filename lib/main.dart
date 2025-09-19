import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/app_config.dart';
import 'widgets/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
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
      ),
      home: AuthWrapper(),
    );
  }
}
