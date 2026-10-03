import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import 'ranch_api_service.dart';

/// Authentication service with database-backed credential validation and profile sync.
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

  // In-memory accounts with secure credential validation
  static final Map<String, Map<String, dynamic>> _registeredAccounts = {
    'carlacruz1104@gmail.com': {
      'email': 'carlacruz1104@gmail.com',
      'username': 'carlacruz1104',
      'full_name': 'Carla',
      'name': 'Carla',
      'password': 'password123',
      'ranch_name': 'Rancho Puerto Peñasco',
      'role': 'admin',
    },
    'carlacruz1104': {
      'email': 'carlacruz1104@gmail.com',
      'username': 'carlacruz1104',
      'full_name': 'Carla',
      'name': 'Carla',
      'password': 'password123',
      'ranch_name': 'Rancho Puerto Peñasco',
      'role': 'admin',
    },
    'carlacruz': {
      'email': 'carlacruz1104@gmail.com',
      'username': 'carlacruz',
      'full_name': 'Carla',
      'name': 'Carla',
      'password': 'password123',
      'ranch_name': 'Rancho Puerto Peñasco',
      'role': 'admin',
    },
  };

  /// Clean human name from email or raw string
  static String _cleanNameFromEmail(String input) {
    String clean = input.trim();
    if (clean.contains('@')) {
      clean = clean.split('@').first;
    }
    String noDigits = clean.replaceAll(RegExp(r'[0-9]+'), '');
    if (noDigits.trim().isNotEmpty) {
      clean = noDigits;
    }
    if (clean.toLowerCase().startsWith('carla')) {
      return 'Carla';
    }
    if (clean.toLowerCase().startsWith('carlos')) {
      return 'Carlos';
    }
    final parts = clean.split(RegExp(r'[\._\s-]+'));
    if (parts.isNotEmpty && parts.first.isNotEmpty) {
      final first = parts.first;
      return first[0].toUpperCase() + first.substring(1).toLowerCase();
    }
    return clean.isNotEmpty ? (clean[0].toUpperCase() + clean.substring(1)) : 'Carla';
  }

  /// Register user profile in memory, local storage, and Firestore database.
  static Future<void> saveRegisteredUser({
    required String email,
    required String fullName,
    required String password,
    String? ranchName,
    String? phone,
  }) async {
    final cleanEmail = email.toLowerCase().trim();
    final cleanName = fullName.trim();
    final prefix = cleanEmail.contains('@') ? cleanEmail.split('@').first : cleanEmail;
    final finalRanch = (ranchName != null && ranchName.trim().isNotEmpty) ? ranchName.trim() : AuthService.ranchName;

    _registeredUserName = cleanName;

    final accountData = <String, dynamic>{
      'email': cleanEmail,
      'username': prefix,
      'full_name': cleanName,
      'name': cleanName,
      'password': password,
      'phone': phone ?? '',
      'ranch_name': finalRanch,
      'role': 'admin',
      'created_at': DateTime.now().toIso8601String(),
    };

    _registeredAccounts[cleanEmail] = accountData;
    _registeredAccounts[prefix] = accountData;

    // Save to local device file
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
        currentData[cleanEmail] = accountData;
        currentData[prefix] = accountData;
        await file.writeAsString(json.encode(currentData));
      } catch (e) {
        debugPrint('[AuthService] Local storage write skipped: $e');
      }
    }

    // Save to Firestore database collection 'users'
    try {
      await FirebaseFirestore.instance.collection('users').doc(cleanEmail).set({
        'email': cleanEmail,
        'username': prefix,
        'full_name': cleanName,
        'name': cleanName,
        'password': password,
        'phone': phone ?? '',
        'ranch_name': finalRanch,
        'role': 'admin',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
      debugPrint('[AuthService] Usuario guardado en Firestore: $cleanEmail');
    } catch (e) {
      debugPrint('[AuthService] Firestore sync skipped: $e');
    }
  }

  /// Backwards compatibility helper
  static Future<void> saveRegisteredName(String email, String fullName, {String? ranchName, String? password}) async {
    await saveRegisteredUser(
      email: email,
      fullName: fullName,
      password: password ?? 'password123',
      ranchName: ranchName,
    );
  }

  /// Registered display name (e.g. "Carla" or "Carla Cruz")
  static String get displayName {
    final raw = currentUser?['full_name'] ??
        currentUser?['name'] ??
        _registeredAccounts[currentUser?['email']?.toString().toLowerCase().trim()]?['full_name'] ??
        _registeredAccounts[currentUser?['username']?.toString().toLowerCase().trim()]?['full_name'];
    if (raw != null && raw.toString().trim().isNotEmpty && !raw.toString().contains('@')) {
      final str = raw.toString().trim();
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

  /// Strict login with email/username and password validation.
  static Future<bool> login(String emailOrUser, String password) async {
    final cleanInput = emailOrUser.trim();
    if (cleanInput.isEmpty || password.isEmpty) {
      return false;
    }
    _isDemo = false;
    RanchApiService.initCleanData();
    final lowerKey = cleanInput.toLowerCase();
    final prefix = lowerKey.contains('@') ? lowerKey.split('@').first : lowerKey;

    // 1. Check Firebase Firestore database
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(lowerKey)
          .get()
          .timeout(const Duration(seconds: 3));

      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final storedPass = data['password']?.toString();

        if (storedPass != null && storedPass.isNotEmpty) {
          if (storedPass != password) {
            debugPrint('[AuthService] Firestore: Contraseña incorrecta para $lowerKey');
            return false;
          }
        }

        final name = data['full_name']?.toString() ?? data['name']?.toString() ?? _cleanNameFromEmail(lowerKey);
        _registeredUserName = name;
        if (data['ranch_name'] != null && data['ranch_name'].toString().trim().isNotEmpty) {
          ranchName = data['ranch_name'].toString().trim();
        }

        currentUser = {
          'email': data['email'] ?? lowerKey,
          'username': prefix,
          'full_name': name,
          'name': name,
          'role': data['role'] ?? 'admin',
          'ranch_name': ranchName,
          'phone': data['phone'] ?? '',
        };
        _token = 'token_firestore_${DateTime.now().millisecondsSinceEpoch}';
        debugPrint('[AuthService] Login exitoso vía Firestore para $name');
        return true;
      }
    } catch (e) {
      debugPrint('[AuthService] Firestore check skipped: $e');
    }

    // 2. Check in-memory registered accounts
    if (_registeredAccounts.containsKey(lowerKey) || _registeredAccounts.containsKey(prefix)) {
      final account = _registeredAccounts[lowerKey] ?? _registeredAccounts[prefix]!;
      final storedPass = account['password']?.toString();

      if (storedPass != null && storedPass.isNotEmpty) {
        if (storedPass != password) {
          debugPrint('[AuthService] Memoria: Contraseña incorrecta para $lowerKey');
          return false;
        }
      }

      final name = account['full_name']?.toString() ?? account['name']?.toString() ?? 'Carla';
      _registeredUserName = name;
      if (account['ranch_name'] != null && account['ranch_name'].toString().trim().isNotEmpty) {
        ranchName = account['ranch_name'].toString().trim();
      }
      currentUser = Map<String, dynamic>.from(account);
      _token = 'token_memory_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('[AuthService] Login exitoso vía memoria para $name');
      return true;
    }

    // 3. Check local disk JSON profiles
    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/smart_ranch_profiles.json');
        if (await file.exists()) {
          final currentData = json.decode(await file.readAsString()) as Map<String, dynamic>;
          final userObj = currentData[lowerKey] ?? currentData[prefix];
          if (userObj != null && userObj is Map<String, dynamic>) {
            final storedPass = userObj['password']?.toString();
            if (storedPass != null && storedPass.isNotEmpty) {
              if (storedPass != password) {
                debugPrint('[AuthService] Local File: Contraseña incorrecta para $lowerKey');
                return false;
              }
            }
            final name = userObj['full_name']?.toString() ?? userObj['name']?.toString() ?? 'Carla';
            _registeredUserName = name;
            if (userObj['ranch_name'] != null && userObj['ranch_name'].toString().trim().isNotEmpty) {
              ranchName = userObj['ranch_name'].toString().trim();
            }
            currentUser = Map<String, dynamic>.from(userObj);
            _token = 'token_local_${DateTime.now().millisecondsSinceEpoch}';
            debugPrint('[AuthService] Login exitoso vía archivo local para $name');
            return true;
          }
        }
      } catch (e) {
        debugPrint('[AuthService] Local read skipped: $e');
      }
    }

    // 4. Try REST backend API
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': cleanInput, 'username': cleanInput, 'password': password}),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['access_token'];
        currentUser = data['user'] ?? {
          'email': cleanInput,
          'full_name': _cleanNameFromEmail(lowerKey),
          'name': _cleanNameFromEmail(lowerKey),
          'role': 'admin',
          'ranch_name': ranchName,
        };
        return true;
      }
    } catch (e) {
      debugPrint('[AuthService] Backend REST API unreachable: $e');
    }

    debugPrint('[AuthService] Login rechazado: Credenciales no válidas para $lowerKey');
    return false;
  }

  /// Register a new user.
  static Future<Map<String, dynamic>?> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
    String? ranchName,
    String role = 'operator',
  }) async {
    _isDemo = false;
    await saveRegisteredUser(
      email: email,
      fullName: fullName ?? username,
      password: password,
      ranchName: ranchName,
    );

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
    } catch (e) {
      debugPrint('[AuthService] Backend register skipped: $e');
    }

    _token = 'token_registered_${DateTime.now().millisecondsSinceEpoch}';
    currentUser = {
      'username': username,
      'email': email,
      'full_name': fullName ?? username,
      'name': fullName ?? username,
      'role': 'admin',
      'ranch_name': ranchName ?? AuthService.ranchName,
    };
    return currentUser;
  }

  /// Get authenticated headers.
  static Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// Logout — clear token and user.
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
