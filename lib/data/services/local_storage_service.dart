import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/user_model.dart';

class LocalStorageService {
  static const String _userKey = 'cached_user';

  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toLocalMap()));
  }

  Future<UserModel?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      try {
        final Map<String, dynamic> userMap = jsonDecode(userStr);
        return UserModel.fromJson(userMap, userMap['uid'] ?? '');
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
