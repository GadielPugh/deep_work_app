import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple user profile state (name + email) persisted locally.
class UserState extends ChangeNotifier {
  UserState._();

  static final UserState instance = UserState._();

  static const _keyName = 'user_name';
  static const _keyEmail = 'user_email';

  String _name = '';
  String _email = '';

  String get name => _name;
  String get email => _email;

  String get initial =>
      _name.isNotEmpty ? _name[0].toUpperCase() : '?';

  bool get hasProfile => _name.isNotEmpty && _email.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _name = prefs.getString(_keyName) ?? '';
    _email = prefs.getString(_keyEmail) ?? '';
    notifyListeners();
  }

  Future<void> saveProfile({
    required String name,
    required String email,
  }) async {
    _name = name.trim();
    _email = email.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, _name);
    await prefs.setString(_keyEmail, _email);

    notifyListeners();
  }
}

