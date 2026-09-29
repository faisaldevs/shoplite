import 'package:equatable/equatable.dart';
import 'package:shoplite/features/product/domain/entities/product_entity.dart';

class PaginatedProducts extends Equatable {
  const PaginatedProducts({
    required this.products,
    required this.total,
    required this.limit,
    required this.skip,
  });

  final List<ProductEntity> products;

  final int total;
  final int limit;
  final int skip;

  bool get hasReachedMax => (skip + limit) >= total;

  @override
  List<Object?> get props => [total, skip, limit, products];
}
