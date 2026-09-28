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
    } on ServerFailure catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    }
  }
}
