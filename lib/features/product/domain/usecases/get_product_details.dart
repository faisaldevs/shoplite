import 'package:fpdart/fpdart.dart';
import 'package:shoplite/core/error/failure.dart';
import 'package:shoplite/core/usecase/usecase.dart';
import 'package:shoplite/features/product/domain/entities/product_entity.dart';
import 'package:shoplite/features/product/domain/repositories/product_repository.dart';

class GetProductDetails implements UseCase<ProductEntity, int> {
  const GetProductDetails(this._productRepo);

  final ProductRepository _productRepo;

  @override
  Future<Either<Failure, ProductEntity>> call(int id) {
    return _productRepo.getProductDetails(id);
  }
}
