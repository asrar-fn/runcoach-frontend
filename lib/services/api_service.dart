import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
   Future<Map<String, dynamic>> registerUser(
      Map<String, dynamic> payload) async {

    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/api/auth/register"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(payload),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data["message"]);
    }
  }

  //login
   Future<Map<String, dynamic>> loginUser(
       String email, String password) async {

     final response = await http.post(
       Uri.parse("${ApiConfig.baseUrl}/api/auth/login"),
       headers: {
         "Content-Type": "application/json",
       },
       body: jsonEncode({
         "email": email,
         "password": password,
       }),
     );

     final data = jsonDecode(response.body);

     if (response.statusCode == 200) {
       return data;
     } else {
       throw Exception(data["message"]);
     }
   }

   Future<List<dynamic>> getCoaches() async {
     final response = await http.get(
       Uri.parse("${ApiConfig.baseUrl}/api/users?role=coach"),
       headers: {
         "Content-Type": "application/json",
       },
     );

     final data = jsonDecode(response.body);

     if (response.statusCode == 200) {
       return data;
     } else {
       throw Exception("Failed to fetch coaches: ${data['message'] ?? response.reasonPhrase}");
     }
   }
}