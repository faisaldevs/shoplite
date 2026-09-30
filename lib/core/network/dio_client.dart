// import 'dart:developer';

// import 'package:dio/dio.dart';
// import 'package:flutter/foundation.dart';
// import 'package:shoplite/core/network/api_endpoints.dart';
// import 'package:shoplite/core/network/auth_interceptor.dart';

// class DioClient {
//   static Dio create(AuthInterceptor authInterceptor) {
//     final dio = Dio(
//       BaseOptions(
//         baseUrl: ApiEndpoints.baseUrl,
//         connectTimeout: const Duration(seconds: 30),
//         receiveTimeout: const Duration(seconds: 30),
//       ),
//     );
//     dio.interceptors.add(authInterceptor);

//     // Added after AuthInterceptor so the logged request includes the token.
//     if (kDebugMode) {
//       dio.interceptors.add(
//         LogInterceptor(
//           requestBody: true,
//           responseBody: true,
//           logPrint: (o) => log(o.toString()),
//         ),
//       );
//     }
//     return dio;
//   }
// }

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shoplite/core/network/api_endpoints.dart';
import 'package:shoplite/core/network/auth_interceptor.dart';

class DioClient {
  Dio create(AuthInterceptor auth) {
    return Dio(
        BaseOptions(
          baseUrl: ApiEndpoints.baseUrl,
          receiveTimeout: const Duration(seconds: 30),
          connectTimeout: const Duration(seconds: 30),
        ),
      )
      ..interceptors.addAll([
        auth,
        if (kDebugMode) LogInterceptor(requestBody: true, responseBody: true),
      ]);
  }
}
