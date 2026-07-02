import 'package:shared_preferences/shared_preferences.dart';

class AuthStorageService {
  static const String _userIdKey = 'userId';
  static const String _coachIdKey = 'coachId';
  static const String _authTokenKey = 'authToken';
  static const String _userRoleKey = 'userRole';

  static Future<void> saveAuthData(
      String coachId,
      String authToken, {
        String userId = '',
        String userRole = '',
      }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_coachIdKey, coachId);
    await prefs.setString(_authTokenKey, authToken);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userRoleKey, userRole);
  }

  static Future<Map<String, String?>> getAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      _coachIdKey: prefs.getString(_coachIdKey),
      _authTokenKey: prefs.getString(_authTokenKey),
      _userIdKey: prefs.getString(_userIdKey),
      _userRoleKey: prefs.getString(_userRoleKey),
    };
  }

  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_coachIdKey);
    await prefs.remove(_authTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userRoleKey);
  }
}