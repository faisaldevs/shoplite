import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:shoplite/core/network/api_endpoints.dart';
import 'package:shoplite/core/storage/base_auth_storage.dart';

/// Adds the access token to every request. On 401 it refreshes the token
/// once and retries the request. If refresh fails, the session is over.
///
/// QueuedInterceptor runs onError one at a time, so parallel 401s never
/// refresh concurrently. The token check in [_getNewAccessToken] stops
/// queued 401s from refreshing again after the first one succeeded.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this._storage,
    required this.onSessionExpired,
    Dio? plainDio,
  }) : _plainDio = plainDio ?? _createPlainDio();

  // No interceptors on this one, so refresh/retry can't loop back here.
  final Dio _plainDio;

  final BaseAuthStorage _storage;
  final void Function() onSessionExpired;

  // Set once the session is ended, so queued 401s don't notify again.
  // Reset when a request goes out with a token (user logged in again).
  bool _sessionExpired = false;

  static Dio _createPlainDio() {
    return Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final accessToken = await _storage.getAccessToken();

      if (accessToken != null && accessToken.isNotEmpty) {
        options.headers["Authorization"] = "Bearer $accessToken";
        _sessionExpired = false;
      }

      handler.next(options);
    } catch (e) {
      handler.reject(DioException(requestOptions: options, error: e));
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnAuthorized = err.response?.statusCode == 401;
    final isLogin = err.requestOptions.path == ApiEndpoints.login;

    if (!isUnAuthorized || isLogin) return handler.next(err);
    log('[Auth] 401 on ${err.requestOptions.path} -> refreshing token');

    final String accessToken;

    try {
      accessToken = await _getNewAccessToken(err.requestOptions);
    } on DioException catch (e) {
      // Only a server rejection ends the session. Offline/timeout keeps the
      // tokens so the user stays logged in and can retry later.
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        log('[Auth] Refresh rejected ($status) -> logout');
        await _endSession();
      } else {
        log('[Auth] Refresh failed (${e.type}) -> keep session');
      }
      return handler.next(err);
    } catch (e) {
      // No refresh token, or unexpected refresh response shape.
      log('[Auth] Refresh failed ($e) -> logout');
      await _endSession();
      return handler.next(err);
    }

    try {
      final options = err.requestOptions
        ..headers["Authorization"] = "Bearer $accessToken";

      handler.resolve(await _plainDio.fetch(options));
      log('[Auth] Retried ${options.path} with new token');
    } on DioException catch (e) {
      // Fresh token still rejected: session is unusable.
      if (e.response?.statusCode == 401) {
        log('[Auth] Retry got 401 -> logout');
        await _endSession();
      }
      handler.next(e);
    }
  }

  // Must never throw: a throw here would leave the handler uncalled and
  // block the interceptor queue for every later request.
  Future<void> _endSession() async {
    try {
      await _storage.clearTokens();
    } catch (e) {
      log('[Auth] Clearing tokens failed ($e)');
    }

    if (_sessionExpired) return;
    _sessionExpired = true;
    onSessionExpired();
  }

  Future<String> _getNewAccessToken(RequestOptions failedRequest) async {
    // Another queued request may have refreshed already: reuse that token.
    final currentAccessToken = await _storage.getAccessToken();

    if (currentAccessToken != null &&
        failedRequest.headers["Authorization"] !=
            "Bearer $currentAccessToken") {
      log('[Auth] Token already refreshed by another request');
      return currentAccessToken;
    }

    final refreshToken = await _storage.getRefreshToken();

    if (refreshToken == null) throw StateError("No Refresh Token");

    final response = await _plainDio.post(
      ApiEndpoints.refresh,
      data: {"refreshToken": refreshToken},
    );

    final newAccess = response.data["accessToken"] as String;
    final newRefresh = response.data["refreshToken"] as String;

    await _storage.saveTokens(newAccess, newRefresh);
    log('[Auth] Access & refresh tokens saved');

    return newAccess;
  }
}
