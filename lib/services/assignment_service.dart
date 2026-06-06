// lib/services/assignment_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_storage_service.dart';

class AssignmentService {
  // ✅ Replace with your actual API base URL
  static const String _baseUrl = 'http://localhost:5000/api';

  /// Create a new assignment (coach → athlete)
  static Future<Map<String, dynamic>> createAssignment({
    required String athleteId,
    required String workoutType,
    required String title,
    required String distance,
    required String duration,
    required String scheduledDate,
    String instructions = '',
    String targetPace = '',
  }) async {
    final authData = await AuthStorageService.getAuthData();
    final token = authData['authToken'] ?? '';

    final response = await http.post(
      Uri.parse('$_baseUrl/assignments'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'athleteId': athleteId,
        'workoutType': workoutType,
        'title': title,
        'distance': distance,
        'duration': duration,
        'scheduledDate': scheduledDate,
        'instructions': instructions,
        'targetPace': targetPace,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['message'] ?? 'Failed to create assignment');
    }
  }

  /// Get all assignments for a specific athlete
  static Future<List<Map<String, dynamic>>> getAssignmentsByAthlete(
      String athleteId) async {
    final authData = await AuthStorageService.getAuthData();
    final token = authData['authToken'] ?? '';

    final response = await http.get(
      Uri.parse('$_baseUrl/assignments/athlete/$athleteId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load assignments');
    }
  }

  /// Get all assignments created by a coach
  static Future<List<Map<String, dynamic>>> getAssignmentsByCoach(
      String coachId) async {
    final authData = await AuthStorageService.getAuthData();
    final token = authData['authToken'] ?? '';

    final response = await http.get(
      Uri.parse('$_baseUrl/assignments/coach/$coachId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load coach assignments');
    }
  }

  /// Delete an assignment
  static Future<void> deleteAssignment(String assignmentId) async {
    final authData = await AuthStorageService.getAuthData();
    final token = authData['authToken'] ?? '';

    final response = await http.delete(
      Uri.parse('$_baseUrl/assignments/$assignmentId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete assignment');
    }
  }
}