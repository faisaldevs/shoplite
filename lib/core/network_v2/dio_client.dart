import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shoplite/core/network/api_endpoints.dart';
import 'package:shoplite/core/network_v2/auth_interceptor.dart';

class DioClient {
  DioClient._();

  static Dio dioCreate(AuthInterceptor auth) {
    return Dio(
        BaseOptions(
          baseUrl: ApiEndpoints.baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      )
      ..interceptors.addAll([
        // Log after auth so the logged request includes the token.
        auth,
        if (kDebugMode) LogInterceptor(requestBody: true, responseBody: true),
      ]);
  }
}
