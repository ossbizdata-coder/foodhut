import 'package:flutter/material.dart';
import '../services/pin_service.dart';
import 'pin_entry_screen.dart';
import 'menu_screen.dart';
import 'login.dart';

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  bool _isLoading = true;
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _determineStartScreen();
  }

  Future<void> _determineStartScreen() async {
    // Check if token is valid
    final tokenValid = await PinService.isTokenValid();

    if (!tokenValid) {
      // No valid token, go to login
      setState(() {
        _targetScreen = const LoginScreen();
        _isLoading = false;
      });
      return;
    }

    // Token is valid, check if PIN is set
    final pinSet = await PinService.isPinSet();

    setState(() {
      _targetScreen = pinSet ? const PinEntryScreen() : const MenuScreen();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _targetScreen!;
  }
}

