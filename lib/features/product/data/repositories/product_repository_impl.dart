import 'dart:developer';

import 'package:fpdart/fpdart.dart';
import 'package:shoplite/core/error/error_handler.dart';
import 'package:shoplite/core/error/failure.dart';
import 'package:shoplite/features/product/data/datasources/local/product_local_datasource.dart';
import 'package:shoplite/features/product/data/datasources/remote/product_remote_datasource.dart';
import 'package:shoplite/features/product/data/models/product_mapper.dart';
import 'package:shoplite/features/product/domain/entities/paginated_products.dart';
import 'package:shoplite/features/product/domain/entities/product_entity.dart';
import 'package:shoplite/features/product/domain/repositories/product_repository.dart';

/// Network first. When the device is offline, falls back to the local cache.
class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDatasource _remote;
  final ProductLocalDatasource _local;

  const ProductRepositoryImpl({required this._remote, required this._local});

  @override
  Future<Either<Failure, PaginatedProducts>> getProducts({
    required int limit,
    required int skip,
  }) => guard(() async {
    try {
      final response = await _remote.getProducts(limit: limit, skip: skip);
      await _cacheSafely(
        () => _local.cacheProducts(response.products ?? [], skip: skip),
      );
      return response.toEntity();
    } catch (e) {
      if (mapError(e) is! NetworkFailure) rethrow;

      final rows = await _local.getProducts(limit: limit, skip: skip);
      // Nothing cached yet: show the original "no internet" error.
      if (rows.isEmpty && skip == 0) rethrow;

      return PaginatedProducts(
        products: rows.map((r) => r.toEntity()).toList(),
        // Offline, the cached list is all there is, so paging stops at its end.
        total: await _local.countProducts(),
        limit: limit,
        skip: skip,
      );
    }
  });

  @override
  Future<Either<Failure, ProductEntity>> getProductDetails(int id) =>
      guard(() async {
        try {
          final product = await _remote.getProduct(id);
          await _cacheSafely(() => _local.cacheProduct(product));
          return product.toEntity();
        } catch (e) {
          if (mapError(e) is! NetworkFailure) rethrow;

          final row = await _local.getProduct(id);
          if (row == null) rethrow;
          return row.toEntity();
        }
      });

  /// A failed cache write must not fail a request that already succeeded.
  Future<void> _cacheSafely(Future<void> Function() write) async {
    try {
      await write();
    } catch (e, st) {
      log('[ProductCache] write failed: $e', stackTrace: st);
    }
  }
}
