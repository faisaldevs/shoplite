import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shoplite/core/error/excptions.dart';
import 'package:shoplite/core/storage/base_auth_storage.dart';

class AuthStorage implements BaseAuthStorage {
  const AuthStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = "access_token_key";
  static const String _refreshTokenKey = "refresh_token_key";

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    try {
      await Future.wait([
        _storage.write(key: _accessTokenKey, value: accessToken),
        _storage.write(key: _refreshTokenKey, value: refreshToken),
      ]);
    } on PlatformException catch (e) {
      throw CacheException(message: "Could Not Save Tokens: ${e.message}");
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _accessTokenKey);
    } on PlatformException catch (e) {
      throw CacheException(
        message: "Could Not Read Access Tokens: ${e.message}",
      );
    }
  }

  @override
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } on PlatformException catch (e) {
      throw CacheException(
        message: "Could Not Read Refresh Tokens: ${e.message}",
      );
    }
  }

  @override
  Future<void> clearTokens() async {
    try {
      await Future.wait([
        _storage.delete(key: _accessTokenKey),
        _storage.delete(key: _refreshTokenKey),
      ]);
    } on PlatformException catch (e) {
      throw CacheException(message: "Could Not Clear Tokens: ${e.message}");
    }
  }
}
