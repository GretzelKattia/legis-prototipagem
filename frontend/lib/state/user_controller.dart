import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/security/auth_token_store.dart';

/// Estado de apresentação da conta autenticada no FastAPI.
/// Senhas não são guardadas; o token opaco fica no armazenamento seguro.
class UserController extends ChangeNotifier {
  static const _kLogged = 'legis_logged_in';
  static const _kName = 'legis_user_name';
  static const _kEmail = 'legis_user_email';

  String _name = '';
  String _email = '';
  String get name => _name;
  String get email => _email;
  String get displayName => _name.isNotEmpty ? _name : 'Usuário do LEGIS';
  String get initial => displayName.trim().isEmpty ? 'L' : displayName.trim()[0].toUpperCase();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await AuthTokenStore.instance.read();
    _name = prefs.getString(_kName) ?? '';
    _email = prefs.getString(_kEmail) ?? '';
    await prefs.setBool(_kLogged, token != null && token.isNotEmpty);
    notifyListeners();
  }

  Future<void> saveSession({required String email, required String name, required String token}) async {
    final prefs = await SharedPreferences.getInstance();
    _email = email.trim();
    _name = name.trim();
    await AuthTokenStore.instance.write(token);
    await prefs.setBool(_kLogged, true);
    await prefs.setString(_kName, _name);
    await prefs.setString(_kEmail, _email);
    notifyListeners();
  }

  Future<void> updateProfile({required String name, required String email}) async {
    final prefs = await SharedPreferences.getInstance();
    _name = name.trim();
    _email = email.trim();
    await prefs.setString(_kName, _name);
    await prefs.setString(_kEmail, _email);
    notifyListeners();
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await AuthTokenStore.instance.clear();
    await prefs.setBool(_kLogged, false);
    await prefs.setBool('tutorial_concluido', false);
    notifyListeners();
  }
}
