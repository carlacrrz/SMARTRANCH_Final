import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/app_config.dart';
import 'ranch_api_service.dart';

/// Authentication service for JWT-based login/register and ranch metadata.
class AuthService {
  static final String _baseUrl = '${AppConfig.apiBaseUrl}/api/auth';
  static String? _token;
  static Map<String, dynamic>? _currentUser;
  static bool _isDemo = false;

  // Default Ranch in Puerto Peñasco, Sonora
  static LatLng ranchLocation = const LatLng(31.3172, -113.5377);
  static String ranchName = 'Rancho Puerto Peñasco';
  static List<LatLng> geofencePolygon = [];

  static bool get isAuthenticated => _token != null || _currentUser != null;
  static bool get isDemoMode => _isDemo;
  static String? get token => _token;
  static Map<String, dynamic>? get currentUser => _currentUser;
  static set currentUser(Map<String, dynamic>? user) => _currentUser = user;

  static final Map<String, String> _registeredNames = {};

  static void saveRegisteredName(String email, String fullName, {String? ranchName}) {
    if (fullName.trim().isNotEmpty) {
      final cleanEmail = email.toLowerCase().trim();
      final cleanName = fullName.trim();
      _registeredNames[cleanEmail] = cleanName;

      // Sync user profile to Firestore
      try {
        FirebaseFirestore.instance.collection('users').doc(cleanEmail).set({
          'full_name': cleanName,
          'name': cleanName,
          'email': cleanEmail,
          if (ranchName != null && ranchName.trim().isNotEmpty) 'ranch_name': ranchName.trim(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Registered display name (e.g. "Carla Cruz" or "Carla")
  static String get displayName {
    final raw = _currentUser?['full_name'] ??
        _currentUser?['name'] ??
        _registeredNames[_currentUser?['email']?.toString().toLowerCase().trim()];
    if (raw != null && raw.toString().trim().isNotEmpty && !raw.toString().contains('@')) {
      return raw.toString().trim();
    }
    final uname = _currentUser?['username'];
    if (uname != null && uname.toString().trim().isNotEmpty && !uname.toString().contains('@')) {
      return uname.toString().trim();
    }
    return _isDemo ? 'Carlos Ganadero' : 'Carlos';
  }

  /// First name only (e.g. "Carla")
  static String get userName {
    final name = displayName;
    if (name.contains(' ')) {
      return name.split(' ').first;
    }
    return name;
  }

  /// Login with email/username and password.
  static Future<bool> login(String emailOrUser, String password) async {
    _isDemo = false;
    RanchApiService.initCleanData();
    final lowerKey = emailOrUser.toLowerCase().trim();
    String storedName = _registeredNames[lowerKey] ?? '';

    // Check Firestore for user profile
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(lowerKey)
          .get()
          .timeout(const Duration(seconds: 2));
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        if (data['full_name'] != null && data['full_name'].toString().trim().isNotEmpty) {
          storedName = data['full_name'].toString().trim();
          _registeredNames[lowerKey] = storedName;
        }
        if (data['ranch_name'] != null && data['ranch_name'].toString().trim().isNotEmpty) {
          ranchName = data['ranch_name'].toString().trim();
        }
      }
    } catch (_) {}

    if (storedName.isEmpty) {
      if (!emailOrUser.contains('@')) {
        storedName = emailOrUser[0].toUpperCase() + emailOrUser.substring(1);
      } else {
        final prefix = emailOrUser.split('@').first;
        storedName = prefix[0].toUpperCase() + prefix.substring(1);
      }
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': emailOrUser, 'username': emailOrUser, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['access_token'];
        _currentUser = data['user'] ?? {
          'email': emailOrUser,
          'full_name': storedName,
          'name': storedName,
          'role': 'admin',
          'ranch_name': ranchName,
        };
        return true;
      }
      return false;
    } catch (_) {
      // Offline fallback for testing
      _token = 'token_local_${DateTime.now().millisecondsSinceEpoch}';
      _currentUser = {
        'email': emailOrUser,
        'username': emailOrUser.split('@').first,
        'full_name': storedName,
        'name': storedName,
        'role': 'admin',
        'ranch_name': ranchName,
      };
      return true;
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
    _isDemo = false;
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
      // Local fallback
      _token = 'token_registered_${DateTime.now().millisecondsSinceEpoch}';
      _currentUser = {
        'username': username,
        'email': email,
        'full_name': fullName ?? username,
        'role': 'admin',
        'ranch_name': ranchName,
      };
      return _currentUser;
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
    _isDemo = false;
  }

  /// Skip login (use demo mode without auth).
  static void enterDemoMode() {
    _isDemo = true;
    _token = null;
    _currentUser = {
      'username': 'demo',
      'name': 'Carlos',
      'full_name': 'Carlos Ganadero',
      'role': 'admin',
      'ranch_name': 'Rancho Puerto Peñasco Demo',
    };
    RanchApiService.initDemoData();
  }
}
