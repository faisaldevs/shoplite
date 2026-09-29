import 'package:shoplite/features/product/data/datasources/remote/product_api_service.dart';
import 'package:shoplite/features/product/data/datasources/remote/product_remote_datasource.dart';
import 'package:shoplite/features/product/data/models/product_response_model.dart';

class ProductRemoteDatasourceImpl implements ProductRemoteDatasource {
  final ProductApiService _api;

  const ProductRemoteDatasourceImpl(this._api);

  @override
  Future<ProductResponseModel> getProducts({
    required int limit,
    required int skip,
  }) {
    return _api.products(limit: limit, skip: skip);
  }
}
