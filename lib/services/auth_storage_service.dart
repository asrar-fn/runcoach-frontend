import 'package:shared_preferences/shared_preferences.dart';

class AuthStorageService {
  static const String _coachIdKey = 'coachId';
  static const String _authTokenKey = 'authToken';

  static Future<void> saveAuthData(String coachId, String authToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_coachIdKey, coachId);
    await prefs.setString(_authTokenKey, authToken);
  }

  static Future<Map<String, String?>> getAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    final coachId = prefs.getString(_coachIdKey);
    final authToken = prefs.getString(_authTokenKey);
    return {_coachIdKey: coachId, _authTokenKey: authToken};
  }

  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_coachIdKey);
    await prefs.remove(_authTokenKey);
  }
}