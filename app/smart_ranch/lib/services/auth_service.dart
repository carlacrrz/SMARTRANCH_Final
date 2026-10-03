import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import 'ranch_api_service.dart';

/// Authentication service for JWT-based login/register and ranch metadata.
class AuthService {
  static final String _baseUrl = '${AppConfig.apiBaseUrl}/api/auth';
  static String? _token;
  static Map<String, dynamic>? currentUser;
  static bool _isDemo = false;

  // Default Ranch in Puerto Peñasco, Sonora
  static LatLng ranchLocation = const LatLng(31.3172, -113.5377);
  static String ranchName = 'Rancho Puerto Peñasco';
  static List<LatLng> geofencePolygon = [];

  static bool get isAuthenticated => _token != null || currentUser != null;
  static bool get isDemoMode => _isDemo;
  static String? get token => _token;
  static String? _registeredUserName;
  static String get registeredUserName {
    if (_registeredUserName != null && _registeredUserName!.trim().isNotEmpty) {
      return _registeredUserName!.trim();
    }
    return userName;
  }
  static set registeredUserName(String name) {
    if (name.trim().isNotEmpty) {
      _registeredUserName = name.trim();
    }
  }

  static final Map<String, String> _registeredNames = {
    'carlacruz1104@gmail.com': 'Carla',
    'carlacruz1104': 'Carla',
    'carlacruz': 'Carla',
  };

  /// Clean human name from email or raw string (e.g. "carlacruz1104@gmail.com" -> "Carla")
  static String _cleanNameFromEmail(String input) {
    String clean = input.trim();
    if (clean.contains('@')) {
      clean = clean.split('@').first;
    }
    // Remove digits (e.g. "carlacruz1104" -> "carlacruz")
    String noDigits = clean.replaceAll(RegExp(r'[0-9]+'), '');
    if (noDigits.trim().isNotEmpty) {
      clean = noDigits;
    }
    // Specific check for carla / carlacruz
    if (clean.toLowerCase().startsWith('carla')) {
      return 'Carla';
    }
    if (clean.toLowerCase().startsWith('carlos')) {
      return 'Carlos';
    }
    // Split by dots, underscores, dashes
    final parts = clean.split(RegExp(r'[\._\s-]+'));
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      final first = parts.first;
      return first[0].toUpperCase() + first.substring(1).toLowerCase();
    }
    return clean.isNotEmpty ? (clean[0].toUpperCase() + clean.substring(1)) : 'Carla';
  }

  static Future<void> saveRegisteredName(String email, String fullName, {String? ranchName}) async {
    if (fullName.trim().isNotEmpty) {
      final cleanEmail = email.toLowerCase().trim();
      final cleanName = fullName.trim();
      final prefix = cleanEmail.contains('@') ? cleanEmail.split('@').first : cleanEmail;

      _registeredUserName = cleanName;
      _registeredNames[cleanEmail] = cleanName;
      _registeredNames[prefix] = cleanName;

      // Also save to local file on device if not running on Web
      if (!kIsWeb) {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/smart_ranch_profiles.json');
          Map<String, dynamic> currentData = {};
          if (await file.exists()) {
            try {
              currentData = json.decode(await file.readAsString()) as Map<String, dynamic>;
            } catch (e) {
              debugPrint('[AuthService] Error reading local profiles: $e');
            }
          }
          currentData[cleanEmail] = cleanName;
          currentData[prefix] = cleanName;
          await file.writeAsString(json.encode(currentData));
        } catch (e) {
          debugPrint('[AuthService] Local storage write skipped: $e');
        }
      }

      // Sync user profile to Firestore
      try {
        await FirebaseFirestore.instance.collection('users').doc(cleanEmail).set({
          'full_name': cleanName,
          'name': cleanName,
          'email': cleanEmail,
          if (ranchName != null && ranchName.trim().isNotEmpty) 'ranch_name': ranchName.trim(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('[AuthService] Firestore sync skipped: $e');
      }
    }
  }

  /// Registered display name (e.g. "Carla" or "Carla Cruz")
  static String get displayName {
    final raw = currentUser?['full_name'] ??
        currentUser?['name'] ??
        _registeredNames[currentUser?['email']?.toString().toLowerCase().trim()] ??
        _registeredNames[currentUser?['username']?.toString().toLowerCase().trim()];
    if (raw != null && raw.toString().trim().isNotEmpty && !raw.toString().contains('@')) {
      final str = raw.toString().trim();
      // If it has numbers or email format, clean it
      if (RegExp(r'[0-9]').hasMatch(str) || str.contains('@')) {
        return _cleanNameFromEmail(str);
      }
      return str;
    }
    final email = currentUser?['email']?.toString() ?? currentUser?['username']?.toString();
    if (email != null && email.isNotEmpty) {
      return _cleanNameFromEmail(email);
    }
    return _isDemo ? 'Carlos Ganadero' : 'Carla';
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
    if (emailOrUser.trim().isEmpty || password.isEmpty) {
      return false;
    }
    _isDemo = false;
    RanchApiService.initCleanData();
    final lowerKey = emailOrUser.toLowerCase().trim();
    final prefix = lowerKey.contains('@') ? lowerKey.split('@').first : lowerKey;

    String storedName = _registeredNames[lowerKey] ?? _registeredNames[prefix] ?? '';

    // Check local disk profile if not in memory and not on web
    if (storedName.isEmpty && !kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/smart_ranch_profiles.json');
        if (await file.exists()) {
          final data = json.decode(await file.readAsString()) as Map<String, dynamic>;
          if (data[lowerKey] != null) {
            storedName = data[lowerKey].toString();
            _registeredNames[lowerKey] = storedName;
          } else if (data[prefix] != null) {
            storedName = data[prefix].toString();
            _registeredNames[prefix] = storedName;
          }
        }
      } catch (e) {
        debugPrint('[AuthService] Local read skipped: $e');
      }
    }

    // Check Firestore for user profile
    if (storedName.isEmpty) {
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
      } catch (e) {
        debugPrint('[AuthService] Firestore user lookup skipped: $e');
      }
    }

    if (storedName.isEmpty || RegExp(r'[0-9]').hasMatch(storedName)) {
      storedName = _cleanNameFromEmail(storedName.isNotEmpty ? storedName : emailOrUser);
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': emailOrUser, 'username': emailOrUser, 'password': password}),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['access_token'];
        currentUser = data['user'] ?? {
          'email': emailOrUser,
          'full_name': storedName,
          'name': storedName,
          'role': 'admin',
          'ranch_name': ranchName,
        };
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AuthService] Backend login unreachable: $e. Using local authenticated session.');
      // Local fallback for standalone demo / offline mode
      _token = 'token_local_${DateTime.now().millisecondsSinceEpoch}';
      currentUser = {
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
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        _token = data['access_token'];
        currentUser = data['user'];
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('[AuthService] Backend register unreachable: $e. Storing locally.');
      // Local fallback
      _token = 'token_registered_${DateTime.now().millisecondsSinceEpoch}';
      currentUser = {
        'username': username,
        'email': email,
        'full_name': fullName ?? username,
        'role': 'admin',
        'ranch_name': ranchName,
      };
      return currentUser;
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
    currentUser = null;
    _isDemo = false;
  }

  /// Skip login (use demo mode without auth).
  static void enterDemoMode() {
    _isDemo = true;
    _token = null;
    currentUser = {
      'username': 'demo',
      'name': 'Carlos',
      'full_name': 'Carlos Ganadero',
      'role': 'admin',
      'ranch_name': 'Rancho Puerto Peñasco Demo',
    };
    RanchApiService.initDemoData();
  }
}
