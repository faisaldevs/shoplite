import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:shoplite/core/network/api_endpoints.dart';
import 'package:shoplite/features/product/data/models/product_response_model.dart';

part 'product_api_service.g.dart';

@RestApi()
abstract class ProductApiService {
  factory ProductApiService(Dio dio, {String? baseUrl}) = _ProductApiService;

  @GET(ApiEndpoints.products)
  Future<ProductResponseModel> products({
    @Query("limit") required int limit,
    @Query("skip") required int skip,
  });

  @GET("${ApiEndpoints.products}/{id}")
  Future<Product> product(@Path("id") int id);
}
