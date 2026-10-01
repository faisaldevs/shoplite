import 'package:equatable/equatable.dart';

/// What the domain/UI layer sees when something goes wrong.
///
/// Sealed, so a `switch` over a Failure must handle every type.
sealed class Failure extends Equatable {
  const Failure({required this.message, this.code});

  final String message;
  final int? code;

  @override
  List<Object?> get props => [message, code];
}

class ServerFailure extends Failure {
  const ServerFailure({super.message = 'Server error', super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No internet connection'});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.message = 'Session expired'})
    : super(code: 401);
}

class CacheFailure extends Failure {
  const CacheFailure({super.message = 'Could not access local storage'});
}

class UnknownFailure extends Failure {
  const UnknownFailure({super.message = 'Something went wrong'});
}
