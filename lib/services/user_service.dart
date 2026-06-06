import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/athlete.dart';

class UserService {
  final String _baseUrl = 'http://localhost:5000';
  final String _coachId;
  final String _authToken;

  UserService(this._coachId, this._authToken); // Constructor now accepts these

  Future<List<Athlete>> fetchAthletesForCoach() async {
    final url = Uri.parse('$_baseUrl/api/users/coach/$_coachId/athletes'); // Make sure this path is correct
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken', // Use the token here
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> athletesJson = json.decode(response.body);
        return athletesJson.map((json) => Athlete.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: You do not have permission.');
      } else {
        throw Exception('Failed to load athletes: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      // Re-throw the exception for the UI to catch
      throw Exception('Network error or server unreachable: $e');
    }
  }

// Other methods would also use _coachId and _authToken
}