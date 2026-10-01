import 'package:shoplite/core/database/app_database.dart';
import 'package:shoplite/features/product/data/models/product_response_model.dart';

abstract class ProductLocalDatasource {
  /// Saves one page of the product list. When [skip] is 0 the old list order
  /// is dropped first, so a refresh never mixes with stale pages.
  Future<void> cacheProducts(List<Product> products, {required int skip});

  Future<List<ProductRow>> getProducts({required int limit, required int skip});

  /// Number of products in the cached list.
  Future<int> countProducts();

  /// Saves a single product without changing its place in the list.
  Future<void> cacheProduct(Product product);

  Future<ProductRow?> getProduct(int id);
}
