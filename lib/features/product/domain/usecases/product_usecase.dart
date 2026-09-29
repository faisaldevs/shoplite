import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shoplite/core/error/failure.dart';
import 'package:shoplite/core/usecase/usecase.dart';
import 'package:shoplite/features/product/domain/entities/paginated_products.dart';
import 'package:shoplite/features/product/domain/repositories/product_repository.dart';

class ProductUseCase implements UseCase<PaginatedProducts, ProductParams> {
  const ProductUseCase(this._productRepo);

  final ProductRepository _productRepo;

  @override
  Future<Either<Failure, PaginatedProducts>> call(ProductParams params) {
    return _productRepo.getProducts(limit: params.limit, skip: params.skip);
  }
}

class ProductParams extends Equatable {
  const ProductParams({required this.limit, required this.skip});

  final int limit;
  final int skip;

  @override
  List<Object?> get props => [limit, skip];
}
