import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Authentication service for JWT-based login/register.
class AuthService {
  static final String _baseUrl = '${AppConfig.apiBaseUrl}/api/auth';
  static String? _token;
  static Map<String, dynamic>? _currentUser;

  static bool get isAuthenticated => _token != null;
  static String? get token => _token;
  static Map<String, dynamic>? get currentUser => _currentUser;
  static set currentUser(Map<String, dynamic>? user) => _currentUser = user;
  static String get userName => _currentUser?['name'] ?? _currentUser?['full_name'] ?? _currentUser?['username'] ?? 'Carlos';

  /// Login with username and password.
  static Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['access_token'];
        _currentUser = data['user'];
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Register a new user.
  static Future<Map<String, dynamic>?> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
    String role = 'operator',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
          'full_name': fullName,
          'role': role,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _token = data['access_token'];
        _currentUser = data['user'];
        return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get authenticated headers.
  static Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// Logout — clear token.
  static void logout() {
    _token = null;
    _currentUser = null;
  }

  /// Skip login (use demo mode without auth).
  static void enterDemoMode() {
    _token = null;
    _currentUser = {
      'username': 'demo',
      'name': 'Carlos',
      'full_name': 'Carlos Ganadero',
      'role': 'admin',
      'ranch_name': 'Rancho Cananea',
    };
  }
}
