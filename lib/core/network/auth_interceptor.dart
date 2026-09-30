import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shoplite/core/network/api_endpoints.dart';
import 'package:shoplite/core/storage/base_auth_storage.dart';

/// Adds the access token to every request. On 401 it refreshes the token
/// once and retries the request. If refresh fails, the session is over.
///
/// QueuedInterceptor handles one request at a time, so parallel 401s
/// trigger only one refresh.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({required this.storage, required this.onSessionExpired});

  final BaseAuthStorage storage;
  final void Function() onSessionExpired;

  // No interceptors on this one, so refresh/retry can't loop back here.
  final Dio _plainDio = Dio(BaseOptions(baseUrl: ApiEndpoints.baseUrl));

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await storage.getAccessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final isLogin = err.requestOptions.path == ApiEndpoints.login;
    if (!isUnauthorized || isLogin) return handler.next(err);
    debugPrint('[Auth] 401 on ${err.requestOptions.path} -> refreshing token');
    final String accessToken;
    try {
      accessToken = await _getFreshAccessToken(err.requestOptions);
    } catch (e) {
      debugPrint('[Auth] Refresh failed ($e) -> logout');
      await storage.clearTokens();
      onSessionExpired();
      return handler.next(err);
    }

    try {
      final options = err.requestOptions
        ..headers['Authorization'] = 'Bearer $accessToken';
      handler.resolve(await _plainDio.fetch(options));
      debugPrint('[Auth] Retried ${options.path} with new token');
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<String> _getFreshAccessToken(RequestOptions failedRequest) async {
    // Another queued request may have refreshed already: reuse that token.
    final current = await storage.getAccessToken();

    if (current != null &&
        failedRequest.headers['Authorization'] != 'Bearer $current') {
      debugPrint('[Auth] Token already refreshed by another request');
      return current;
    }

    final refreshToken = await storage.getRefreshToken();

    if (refreshToken == null) throw StateError('No refresh token');

    final response = await _plainDio.post<Map<String, dynamic>>(
      ApiEndpoints.refresh,
      data: {'refreshToken': refreshToken},
    );
    final newAccess = response.data!['accessToken'] as String;
    final newRefresh = response.data!['refreshToken'] as String;
    await storage.saveTokens(newAccess, newRefresh);
    debugPrint('[Auth] Token refreshed');
    return newAccess;
  }
}

// import 'package:dio/dio.dart';
// import 'package:shoplite/core/storage/base_auth_storage.dart';

// class AuthInterceptor extends QueuedInterceptor {
//   final BaseAuthStorage _storage;

//   AuthInterceptor(this._storage);

//   /// Called when the request is about to be sent.
//   @override
//   void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
//     handler.next(options);
//   }

//   // /// Called when the response is about to be resolved.
//   // @override
//   // void onResponse(Response response, ResponseInterceptorHandler handler) {
//   //   handler.next(response);
//   // }

//   /// Called when an exception was occurred during the request.
//   @override
//   void onError(DioException err, ErrorInterceptorHandler handler) {
//     handler.next(err);
//   }
// }
