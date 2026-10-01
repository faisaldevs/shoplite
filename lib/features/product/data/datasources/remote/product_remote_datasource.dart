import 'package:shoplite/features/product/data/models/product_response_model.dart';

abstract class ProductRemoteDatasource {
  Future<ProductResponseModel> getProducts({
    required int limit,
    required int skip,
  });

  Future<Product> getProduct(int id);
}
