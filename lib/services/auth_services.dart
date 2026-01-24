import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const API = "http://74.208.132.78";

  // Login using email and password
  static Future<bool> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse("$API/api/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      if (res.statusCode == 200) {
        final js = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", js["token"]);
        await prefs.setInt("userId", js["userId"]);
        await prefs.setString("role", js["role"]); // store role
        await prefs.setString("name", js["name"]);
        await prefs.setString("email", js["email"]);
        return true;
      }
    } catch (e) {
      // Login failed
    }

    return false;
  }

  // Register a new user (default role STAFF)
  static Future<bool> register(String name, String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse("$API/api/auth/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "email": email,
          "password": password,
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        // Registration always adds STAFF by backend
        return true;
      }
    } catch (e) {
      // Registration failed
    }

    return false;
  }

  // Get stored role
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("role");
  }
}
