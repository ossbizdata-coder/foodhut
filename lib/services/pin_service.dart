import 'package:shared_preferences/shared_preferences.dart';

class PinService {
  static const String _pinKey = 'user_pin';
  static const String _pinSetKey = 'pin_is_set';

  // Check if PIN is set
  static Future<bool> isPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinSetKey) ?? false;
  }

  // Set PIN
  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
    await prefs.setBool(_pinSetKey, true);
  }

  // Verify PIN
  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString(_pinKey);
    return storedPin == pin;
  }

  // Clear PIN (on logout or token expiry)
  static Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinKey);
    await prefs.remove(_pinSetKey);
  }

  // Check if token is valid
  static Future<bool> isTokenValid() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return token != null && token.isNotEmpty;
  }
}

