import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:shoplite/core/network/api_endpoints.dart';
import 'package:shoplite/features/auth/data/models/login_response_model.dart';

part 'auth_service.g.dart';

@RestApi()
abstract class AuthService {
  factory AuthService(Dio dio, {String? baseUrl}) = _AuthService;

  @POST(ApiEndpoints.login)
  Future<LoginResponseModel> login(@Body() Map<String, dynamic> credentials);
}
