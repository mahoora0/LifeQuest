import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage(this._storage);

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  Future<String?> readRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<void> writeAccessToken(String token) {
    return _storage.write(key: _accessTokenKey, value: token);
  }

  Future<void> writeRefreshToken(String token) {
    return _storage.write(key: _refreshTokenKey, value: token);
  }

  Future<void> clear() {
    return _storage.deleteAll();
  }
}
