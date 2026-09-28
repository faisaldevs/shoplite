import 'package:dio/dio.dart';
import 'package:shoplite/core/network/api_endpoints.dart';

class DioClient {
  static Dio create() {
    return Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }
}
