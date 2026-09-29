import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shoplite/core/error/failure.dart';
import 'package:shoplite/features/product/data/datasources/remote/product_remote_datasource.dart';
import 'package:shoplite/features/product/domain/entities/paginated_products.dart';
import 'package:shoplite/features/product/domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDatasource _datasource;

  const ProductRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, PaginatedProducts>> getProducts({
    required int limit,
    required int skip,
  }) async {
    try {
      final products = await _datasource.getProducts(limit: limit, skip: skip);

      return Right(products.toEntity());
    } on DioException catch (e) {
      log(e.toString());
      return left(_mapDioError(e));
    } catch (e) {
      return const Left(UnknownFailure());
    }
  }

  Failure _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
        return const NetworkFailure();
      case DioExceptionType.receiveTimeout:
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
