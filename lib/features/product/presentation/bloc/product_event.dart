part of 'product_bloc.dart';

abstract class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object> get props => [];
}

class ProductFetched extends ProductEvent {
  const ProductFetched();
  
}

class ProductRefreshed extends ProductEvent {
  const ProductRefreshed();
}

class ProductLoadMore extends ProductEvent {
  const ProductLoadMore();
}
