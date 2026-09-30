import 'package:shoplite/features/auth/domain/repositories/auth_repository.dart';

class IsLoggedIn {
  const IsLoggedIn(this._repo);

  final AuthRepository _repo;

  Future<bool> call() => _repo.isLoggedIn();
}
