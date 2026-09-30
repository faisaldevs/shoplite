import 'package:fpdart/fpdart.dart';
import 'package:shoplite/core/error/failure.dart';
import 'package:shoplite/features/auth/domain/entities/login_entity.dart';
import 'package:shoplite/features/auth/domain/repositories/auth_repository.dart';

class Login {
  const Login(this._repo);

  final AuthRepository _repo;

  Future<Either<Failure, LoginEntity>> call({
    required String username,
    required String password,
  }) {
    return _repo.login(username, password);
  }
}
