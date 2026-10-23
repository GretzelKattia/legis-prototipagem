import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token de sessão do backend. Senhas nunca são persistidas no dispositivo.
class AuthTokenStore {
  AuthTokenStore._();
  static final AuthTokenStore instance = AuthTokenStore._();
  static const _storage = FlutterSecureStorage();
  static const _key = 'legis_access_token';

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
}
