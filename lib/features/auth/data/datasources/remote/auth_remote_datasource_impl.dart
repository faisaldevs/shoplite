import 'package:shoplite/features/auth/data/datasources/remote/auth_remote_datasource.dart';
import 'package:shoplite/features/auth/data/datasources/remote/auth_service.dart';
import 'package:shoplite/features/auth/data/models/login_response_model.dart';

class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  final AuthService _authService;

  AuthRemoteDatasourceImpl(this._authService);

  @override
  Future<LoginResponseModel> login(String username, String password) {
    return _authService.login({
      'username': username,
      'password': password,
      "expiresInMins": 1,
    });
  }
}
