import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/ranch_models.dart';
import 'auth_service.dart';

/// Service for communicating with the PostgreSQL-backed REST API (v2 endpoints).
class RanchApiService {
  static final String _baseUrl = '${AppConfig.apiBaseUrl}/api/v2';

  static Map<String, String> get _headers => AuthService.authHeaders;

  static Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode >= 400) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> _getList(String path,
      {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode >= 400) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }
    return json.decode(response.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: _headers,
      body: json.encode(body),
    );
    if (response.statusCode >= 400) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _put(
      String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('$_baseUrl$path'),
      headers: _headers,
      body: json.encode(body),
    );
    if (response.statusCode >= 400) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  static Future<void> _delete(String path) async {
    final response = await http.delete(Uri.parse('$_baseUrl$path'), headers: _headers);
    if (response.statusCode >= 400) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }
  }

  // ---- Dashboard ----

  static Future<DashboardStats> getDashboardStats() async {
    final data = await _get('/dashboard');
    return DashboardStats.fromJson(data);
  }

  // ---- Animals ----

  static Future<List<Animal>> getAnimals({
    String? status,
    String? category,
    String? sex,
    String? search,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (category != null) params['category'] = category;
    if (sex != null) params['sex'] = sex;
    if (search != null) params['search'] = search;

    final list = await _getList('/animals', queryParams: params);
    return list
        .map((e) => Animal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Animal> getAnimal(int id) async {
    final data = await _get('/animals/$id');
    return Animal.fromJson(data);
  }

  static Future<Animal> createAnimal(Map<String, dynamic> animalData) async {
    final data = await _post('/animals', animalData);
    return Animal.fromJson(data);
  }

  static Future<Animal> updateAnimal(
      int id, Map<String, dynamic> updates) async {
    final data = await _put('/animals/$id', updates);
    return Animal.fromJson(data);
  }

  static Future<void> deleteAnimal(int id) async {
    await _delete('/animals/$id');
  }

  static Future<Map<String, dynamic>> getAnimalFullProfile(int id) async {
    return await _get('/animals/$id/full');
  }

  // ---- Medical Records ----

  static Future<List<MedicalRecord>> getMedicalRecords(
      {int? animalId, String? recordType}) async {
    final params = <String, String>{};
    if (animalId != null) params['animal_id'] = animalId.toString();
    if (recordType != null) params['record_type'] = recordType;

    final list = await _getList('/medical', queryParams: params);
    return list
        .map((e) => MedicalRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<MedicalRecord> createMedicalRecord(
      Map<String, dynamic> data) async {
    final result = await _post('/medical', data);
    return MedicalRecord.fromJson(result);
  }

  static Future<List<Map<String, dynamic>>> getUpcomingMedical(
      {int days = 7}) async {
    final list =
        await _getList('/medical/upcoming', queryParams: {'days': '$days'});
    return list.cast<Map<String, dynamic>>();
  }

  // ---- Reproductive Events ----

  static Future<List<ReproductiveEvent>> getReproductiveEvents(
      {int? animalId, String? eventType}) async {
    final params = <String, String>{};
    if (animalId != null) params['animal_id'] = animalId.toString();
    if (eventType != null) params['event_type'] = eventType;

    final list = await _getList('/reproductive', queryParams: params);
    return list
        .map((e) => ReproductiveEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<ReproductiveEvent> createReproductiveEvent(
      Map<String, dynamic> data) async {
    final result = await _post('/reproductive', data);
    return ReproductiveEvent.fromJson(result);
  }

  // ---- Weight Records ----

  static Future<List<WeightRecord>> getWeightRecords({int? animalId}) async {
    final params = <String, String>{};
    if (animalId != null) params['animal_id'] = animalId.toString();

    final list = await _getList('/weights', queryParams: params);
    return list
        .map((e) => WeightRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<WeightRecord> createWeightRecord(
      Map<String, dynamic> data) async {
    final result = await _post('/weights', data);
    return WeightRecord.fromJson(result);
  }

  static Future<Map<String, dynamic>> getGrowthCurve(int animalId) async {
    return await _get('/weights/$animalId/growth');
  }

  // ---- Alerts ----

  static Future<List<AlertLog>> getAlerts(
      {int? animalId, String? alertType, bool unacknowledged = false}) async {
    final params = <String, String>{};
    if (animalId != null) params['animal_id'] = animalId.toString();
    if (alertType != null) params['alert_type'] = alertType;
    if (unacknowledged) params['unacknowledged'] = 'true';

    final list = await _getList('/alerts', queryParams: params);
    return list
        .map((e) => AlertLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<AlertLog> acknowledgeAlert(int alertId, String by) async {
    final data =
        await _put('/alerts/$alertId/acknowledge', {'acknowledged_by': by});
    return AlertLog.fromJson(data);
  }

  // ---- GPS ----

  static Future<List<Map<String, dynamic>>> getCurrentPositions() async {
    final list = await _getList('/gps/current');
    return list.cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> getGeofenceViolations() async {
    final list = await _getList('/gps/geofence-check');
    return list.cast<Map<String, dynamic>>();
  }

  // ---- Financial Events ----

  static Future<Map<String, dynamic>> createFinancialEvent(
      Map<String, dynamic> data) async {
    return await _post('/financial', data);
  }

  // ---- Feed Records ----

  static Future<Map<String, dynamic>> createFeedRecord(
      Map<String, dynamic> data) async {
    return await _post('/feed', data);
  }
}
