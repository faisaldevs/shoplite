import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shoplite/features/product/domain/entities/product_entity.dart';
import 'package:shoplite/features/product/domain/usecases/product_usecase.dart';

part 'product_event.dart';
part 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final ProductUseCase _productUsecase;

  static const int _limit = 20;

  ProductBloc(this._productUsecase) : super(ProductState()) {
    on<ProductFetched>(_onFatched);

    on<ProductLoadMore>(_onLoadMore, transformer: droppable());

    on<ProductRefreshed>(_onRefreshed);
  }

  Future<void> _onFatched(
    ProductFetched event,
    Emitter<ProductState> emit,
  ) async {
    emit(state.copyWith(status: ProductStatus.loading));

    final result = await _productUsecase(ProductParams(limit: _limit, skip: 0));

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ProductStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: ProductStatus.success,
          products: success.products,
          hasReachedMax: success.hasReachedMax,
        ),
      ),
    );
  }

  Future<void> _onRefreshed(
    ProductRefreshed event,
    Emitter<ProductState> emit,
  ) async {
    final result = await _productUsecase(ProductParams(limit: _limit, skip: 0));

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ProductStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: ProductStatus.success,
          products: success.products,
          hasReachedMax: success.hasReachedMax,
        ),
      ),
    );
  }

  Future<void> _onLoadMore(
    ProductLoadMore event,
    Emitter<ProductState> emit,
  ) async {
    if (state.hasReachedMax ||
        state.status == ProductStatus.loadingMore ||
        state.status == ProductStatus.loading) {
      return;
    }

    emit(state.copyWith(status: ProductStatus.loadingMore));

    final result = await _productUsecase(
      ProductParams(limit: _limit, skip: state.products.length),
    );
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ProductStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (success) => emit(
        state.copyWith(
          status: ProductStatus.success,
          products: [...state.products, ...success.products],
          hasReachedMax: success.hasReachedMax,
        ),
      ),
    );
  }
}
