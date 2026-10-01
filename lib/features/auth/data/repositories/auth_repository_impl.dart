import 'dart:developer';

import 'package:fpdart/fpdart.dart';
import 'package:shoplite/core/error/error_handler.dart';
import 'package:shoplite/core/error/failure.dart';
import 'package:shoplite/core/storage/base_auth_storage.dart';
import 'package:shoplite/features/auth/data/datasources/remote/auth_remote_datasource.dart';
import 'package:shoplite/features/auth/domain/entities/login_entity.dart';
import 'package:shoplite/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _remoteDatasource;

  final BaseAuthStorage _authStorage;

  AuthRepositoryImpl({
    required this._remoteDatasource,
    required this._authStorage,
  });

  // dummyjson has no logout endpoint, so logout = forget the tokens.
  // Never throws: the user must always be able to leave, even if
  // clearing storage fails.
  @override
  Future<void> logout() async {
    try {
      await _authStorage.clearTokens();
    } catch (e) {
      log('[Auth] Clearing tokens on logout failed ($e)');
    }
  }

  // Only checks a token exists. If it expired, AuthInterceptor refreshes it
  // on the first request.
  @override
  Future<bool> isLoggedIn() async {
    return await _authStorage.getAccessToken() != null;
  }

  @override
  Future<Either<Failure, LoginEntity>> login(
    String username,
    String password,
  ) => guard(() async {
    final login = await _remoteDatasource.login(username, password);

    await _authStorage.saveTokens(login.accessToken, login.refreshToken);

    return login.toEntity();
  });
}
