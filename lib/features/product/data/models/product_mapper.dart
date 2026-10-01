import 'package:drift/drift.dart';
import 'package:shoplite/core/database/app_database.dart';
import 'package:shoplite/features/product/data/models/product_response_model.dart';
import 'package:shoplite/features/product/domain/entities/product_entity.dart';

extension ProductToCompanion on Product {
  /// Leave [position] absent to keep a row's existing place in the list.
  ProductsTableCompanion toCompanion({
    Value<int?> position = const Value.absent(),
  }) => ProductsTableCompanion.insert(
    id: Value(id ?? 0),
    title: title ?? '',
    category: Value(category ?? ''),
    description: Value(description ?? ''),
    price: Value(price ?? 0),
    discountPercentage: Value(discountPercentage ?? 0),
    rating: Value(rating ?? 0),
    stock: Value(stock ?? 0),
    thumbnail: Value(thumbnail),
    images: Value(images ?? const []),
    position: position,
    cachedAt: Value(DateTime.now()),
  );
}

extension ProductRowToEntity on ProductRow {
  ProductEntity toEntity() => ProductEntity(
    id: id,
    title: title,
    description: description,
    category: category,
    price: price,
    discountPercentage: discountPercentage,
    rating: rating,
    stock: stock,
    thumbnail: thumbnail,
    images: images,
  );
}
