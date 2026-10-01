part of 'product_details_cubit.dart';

enum ProductDetailsStatus { initial, loading, success, failure }

class ProductDetailsState extends Equatable {
  const ProductDetailsState({
    this.status = ProductDetailsStatus.initial,
    this.product,
    this.errorMessage,
  });

  final ProductDetailsStatus status;
  final ProductEntity? product;
  final String? errorMessage;

  ProductDetailsState copyWith({
    ProductDetailsStatus? status,
    ProductEntity? product,
    String? errorMessage,
  }) {
    return ProductDetailsState(
      status: status ?? this.status,
      product: product ?? this.product,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, product, errorMessage];
}
