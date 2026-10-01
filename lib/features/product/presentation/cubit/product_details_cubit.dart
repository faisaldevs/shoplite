import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shoplite/features/product/domain/entities/product_entity.dart';
import 'package:shoplite/features/product/domain/usecases/get_product_details.dart';

part 'product_details_state.dart';

class ProductDetailsCubit extends Cubit<ProductDetailsState> {
  final GetProductDetails _getProductDetails;

  /// [initial] is the product passed from the list, shown right away while
  /// fresh data loads. Null when the page is opened by URL.
  ProductDetailsCubit(this._getProductDetails, {ProductEntity? initial})
    : super(ProductDetailsState(product: initial));

  Future<void> load(int id) async {
    emit(state.copyWith(status: ProductDetailsStatus.loading));

    final result = await _getProductDetails(id);

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ProductDetailsStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (product) => emit(
        state.copyWith(status: ProductDetailsStatus.success, product: product),
      ),
    );
  }
}
