import 'package:fpdart/fpdart.dart';
import 'package:shoplite/core/error/failure.dart';
import 'package:shoplite/features/product/domain/entities/paginated_products.dart';
import 'package:shoplite/features/product/domain/entities/product_entity.dart';

abstract class ProductRepository {
  Future<Either<Failure, PaginatedProducts>> getProducts({
    required int limit,
    required int skip,
  });

  Future<Either<Failure, ProductEntity>> getProductDetails(int id);
}
