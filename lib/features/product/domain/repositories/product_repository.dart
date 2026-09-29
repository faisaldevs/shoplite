import 'package:fpdart/fpdart.dart';
import 'package:shoplite/core/error/failure.dart';
import 'package:shoplite/features/product/domain/entities/paginated_products.dart';

abstract class ProductRepository {
  Future<Either<Failure, PaginatedProducts>> getProducts({
    required int limit,
    required int skip,
  });
}
