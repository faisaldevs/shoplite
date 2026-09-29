part of 'product_bloc.dart';

enum ProductStatus { initial, loading, loadingMore, success, failure }

class ProductState extends Equatable {
  const ProductState({
    this.status = ProductStatus.initial,
    this.products = const [],
    this.hasReachedMax = false,
    this.errorMessage,
  });

  final ProductStatus status;
  final List<ProductEntity> products;
  final bool hasReachedMax;
  final String? errorMessage;

  ProductState copyWith({
    ProductStatus? status,
    List<ProductEntity>? products,
    bool? hasReachedMax,
    String? errorMessage,
  }) {
    return ProductState(
      status: status ?? this.status,
      products: products ?? this.products,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, products, hasReachedMax, errorMessage];
}
