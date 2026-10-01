import 'package:drift/drift.dart';
import 'package:shoplite/core/database/app_database.dart';
import 'package:shoplite/core/error/exceptions.dart';
import 'package:shoplite/features/product/data/datasources/local/product_local_datasource.dart';
import 'package:shoplite/features/product/data/models/product_mapper.dart';
import 'package:shoplite/features/product/data/models/product_response_model.dart';

class ProductLocalDatasourceImpl implements ProductLocalDatasource {
  final AppDatabase _db;

  const ProductLocalDatasourceImpl(this._db);

  @override
  Future<void> cacheProducts(
    List<Product> products, {
    required int skip,
  }) => _run(
    () => _db.transaction(() async {
      if (skip == 0) {
        // Keep the rows (details stay readable offline), only drop the order.
        await _db
            .update(_db.productsTable)
            .write(const ProductsTableCompanion(position: Value(null)));
      }
      await _db.batch((b) {
        for (var i = 0; i < products.length; i++) {
          b.insertAllOnConflictUpdate(_db.productsTable, [
            products[i].toCompanion(position: Value(skip + i)),
          ]);
        }
      });
    }),
  );

  @override
  Future<List<ProductRow>> getProducts({
    required int limit,
    required int skip,
  }) => _run(() {
    final query = _db.select(_db.productsTable)
      ..where((t) => t.position.isNotNull())
      ..orderBy([(t) => OrderingTerm.asc(t.position)])
      ..limit(limit, offset: skip);
    return query.get();
  });

  @override
  Future<int> countProducts() => _run(() {
    final count = _db.productsTable.id.count();
    final query = _db.selectOnly(_db.productsTable)
      ..addColumns([count])
      ..where(_db.productsTable.position.isNotNull());
    return query.map((row) => row.read(count)!).getSingle();
  });

  @override
  Future<void> cacheProduct(Product product) => _run(
    () => _db
        .into(_db.productsTable)
        .insertOnConflictUpdate(product.toCompanion()),
  );

  @override
  Future<ProductRow?> getProduct(int id) => _run(
    () => (_db.select(
      _db.productsTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull(),
  );

  /// Wraps drift/sqlite errors so `guard` maps them to a CacheFailure.
  Future<T> _run<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (e) {
      throw CacheException(message: 'Product cache error: $e');
    }
  }
}
