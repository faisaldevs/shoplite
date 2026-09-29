import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shoplite/core/error/failure.dart';
import 'package:shoplite/core/storage/base_auth_storage.dart';
import 'package:shoplite/features/auth/data/datasources/remote/auth_remote_datasource.dart';
import 'package:shoplite/features/auth/domain/entities/login_entity.dart';
import 'package:shoplite/features/auth/domain/repositories/login_repository.dart';

class LoginRepositoryImpl implements LoginRepository {
  final AuthRemoteDatasource _remoteDatasource;

  final BaseAuthStorage _authStorage;

  LoginRepositoryImpl({
    required this._remoteDatasource,
    required this._authStorage,
  });

  @override
  Future<Either<Failure, LoginEntity>> call(
    String username,
    String password,
  ) async {
    try {
      final login = await _remoteDatasource.login(username, password);

      _authStorage.saveTokens(login.accessToken, login.refreshToken);
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
