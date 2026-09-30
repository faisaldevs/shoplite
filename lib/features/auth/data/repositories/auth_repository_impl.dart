import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
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
  @override
  Future<void> logout() => _authStorage.clearTokens();

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
  ) async {
    try {
      final login = await _remoteDatasource.login(username, password);

      await _authStorage.saveTokens(login.accessToken, login.refreshToken);

      return Right(login.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return const Left(UnknownFailure());
    }
  }

  Failure _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionTimeout:
        return const NetworkFailure();
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 401) return const UnauthorizedFailure();
        final data = e.response?.data;
        final message = data is Map && data['message'] is String
            ? data['message'] as String
            : 'Server error';
        return ServerFailure(message: message, code: code);
      default:
        return const UnknownFailure();
    }
  }
}
