import 'package:flutter/material.dart';
import 'screens/app_entry_point.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Staff Item Entry',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppEntryPoint(),
    );
  }
}
