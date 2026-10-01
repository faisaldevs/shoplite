import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shoplite/core/error/exceptions.dart';
import 'package:shoplite/core/error/failure.dart';

/// Runs [body] and turns any thrown error into a [Failure].
///
/// Use it in every repository method so error mapping lives in one place:
/// ```dart
/// Future<Either<Failure, Foo>> getFoo() => guard(() async {
///   final model = await _datasource.getFoo();
///   return model.toEntity();
/// });
/// ```
Future<Either<Failure, T>> guard<T>(Future<T> Function() body) async {
  try {
    return Right(await body());
  } catch (e, st) {
    log('[Error] $e', stackTrace: st);
    return Left(mapError(e));
  }
}

/// Maps any error (Dio, storage, or unknown) to a [Failure].
Failure mapError(Object error) {
  return switch (error) {
    // AuthInterceptor wraps storage errors in a DioException.
    DioException(error: final CacheException e) => CacheFailure(
      message: e.message,
    ),
    DioException() => _mapDio(error),
    CacheException() => CacheFailure(message: error.message),
    _ => const UnknownFailure(),
  };
}

Failure _mapDio(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const NetworkFailure();
    case DioExceptionType.badResponse:
      final code = e.response?.statusCode;
      final message = _serverMessage(e.response?.data);
      // Prefer the server's text (e.g. "Invalid credentials" on login).
      if (code == 401 && message == null) return const UnauthorizedFailure();
      return ServerFailure(message: message ?? 'Server error', code: code);
    // cancel, badCertificate, unknown, and any type newer Dio versions add.
    default:
      return const UnknownFailure();
  }
}

String? _serverMessage(Object? data) {
  if (data is Map && data['message'] is String) return data['message'];
  return null;
}
