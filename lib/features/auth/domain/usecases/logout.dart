import 'package:shoplite/features/auth/domain/repositories/auth_repository.dart';

class Logout {
  const Logout(this._repo);

  final AuthRepository _repo;

  Future<void> call() => _repo.logout();
}
