# Product Data Layer

Complete `lib/features/product/data/` code: Retrofit + Dio → datasource → repository → `Either<Failure, PaginatedProducts>`.

## Structure

```
data/
├── datasources/remote/
│   ├── product_api_service.dart            # Retrofit client (generates .g.dart)
│   ├── product_remote_datasource.dart      # contract
│   └── product_remote_datasource_impl.dart # calls api service
├── models/
│   └── product_response_model.dart         # JSON parsing + toEntity()
└── repositories/
    └── product_repository_impl.dart        # errors → Failure, model → entity
```

## Changes vs current code

| File | Change | Why |
|---|---|---|
| `core/network/api_endpoints.dart` | `products` → `'/products'` | `/auth/products` needs a Bearer token; public list is `/products` |
| `product_repository_impl.dart` | Rewritten | Was missing `async`/`await`/return, wrong return type (`ProductEntity`) |
| `product_response_model.dart` | `images ?? [""]` → `images ?? []` | `""` is not a valid image URL → `Image.network` crash |

---

## `core/network/api_endpoints.dart`

```dart
class ApiEndpoints {
  static const String baseUrl = 'https://dummyjson.com';

  static const String login = '/auth/login';
  static const String products = '/products';
}
```

## `data/datasources/remote/product_api_service.dart`

```dart
import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:shoplite/core/network/api_endpoints.dart';
import 'package:shoplite/features/product/data/models/product_response_model.dart';

part 'product_api_service.g.dart';

@RestApi()
abstract class ProductApiService {
  factory ProductApiService(Dio dio, {String? baseUrl}) = _ProductApiService;

  @GET(ApiEndpoints.products)
  Future<ProductResponseModel> products({
    @Query("limit") required int limit,
    @Query("skip") required int skip,
  });
}
```

## `data/datasources/remote/product_remote_datasource.dart`

```dart
import 'package:shoplite/features/product/data/models/product_response_model.dart';

abstract class ProductRemoteDatasource {
  Future<ProductResponseModel> getProducts({
    required int limit,
    required int skip,
  });
}
```

## `data/datasources/remote/product_remote_datasource_impl.dart`

```dart
import 'package:shoplite/features/product/data/datasources/remote/product_api_service.dart';
import 'package:shoplite/features/product/data/datasources/remote/product_remote_datasource.dart';
import 'package:shoplite/features/product/data/models/product_response_model.dart';

class ProductRemoteDatasourceImpl implements ProductRemoteDatasource {
  final ProductApiService _api;

  const ProductRemoteDatasourceImpl(this._api);

  @override
  Future<ProductResponseModel> getProducts({
    required int limit,
    required int skip,
  }) {
    return _api.products(limit: limit, skip: skip);
  }
}
```

## `data/repositories/product_repository_impl.dart`

```dart
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shoplite/core/error/failure.dart';
import 'package:shoplite/features/product/data/datasources/remote/product_remote_datasource.dart';
import 'package:shoplite/features/product/domain/entities/paginated_products.dart';
import 'package:shoplite/features/product/domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDatasource _datasource;

  const ProductRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, PaginatedProducts>> getProducts({
    required int limit,
    required int skip,
  }) async {
    try {
      final response = await _datasource.getProducts(limit: limit, skip: skip);
      return Right(response.toEntity());
    } on DioException catch (e) {
      log(e.toString());
      return Left(_mapDioError(e));
    } catch (e) {
      log(e.toString());
      return const Left(UnknownFailure());
    }
  }

  Failure _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure();
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 401) return const UnauthorizedFailure();
        final data = e.response?.data;
        final message = data is Map && data['message'] is String
            ? data['message'] as String
            : 'Server error';
        return ServerFailure(message: message, code: code);
      default:
        return const UnknownFailure();
    }
  }
}
```

## `data/models/product_response_model.dart`

```dart
import 'dart:convert';

import 'package:shoplite/features/product/domain/entities/paginated_products.dart';
import 'package:shoplite/features/product/domain/entities/product_entity.dart';

class ProductResponseModel {
  final List<Product>? products;
  final int? total;
  final int? skip;
  final int? limit;

  ProductResponseModel({this.products, this.total, this.skip, this.limit});

  ProductResponseModel copyWith({
    List<Product>? products,
    int? total,
    int? skip,
    int? limit,
  }) => ProductResponseModel(
    products: products ?? this.products,
    total: total ?? this.total,
    skip: skip ?? this.skip,
    limit: limit ?? this.limit,
  );

  factory ProductResponseModel.fromRawJson(String str) =>
      ProductResponseModel.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory ProductResponseModel.fromJson(Map<String, dynamic> json) =>
      ProductResponseModel(
        products: json["products"] == null
            ? []
            : List<Product>.from(
                json["products"]!.map((x) => Product.fromJson(x)),
              ),
        total: json["total"],
        skip: json["skip"],
        limit: json["limit"],
      );

  Map<String, dynamic> toJson() => {
    "products": products == null
        ? []
        : List<dynamic>.from(products!.map((x) => x.toJson())),
    "total": total,
    "skip": skip,
    "limit": limit,
  };

  PaginatedProducts toEntity() => PaginatedProducts(
    products: products?.map((p) => p.toEntity()).toList() ?? [],
    total: total ?? 0,
    limit: limit ?? 0,
    skip: skip ?? 0,
  );
}

class Product {
  final int? id;
  final String? title;
  final String? description;
  final String? category;
  final double? price;
  final double? discountPercentage;
  final double? rating;
  final int? stock;
  final List<String>? tags;
  final String? brand;
  final String? sku;
  final int? weight;
  final Dimensions? dimensions;
  final String? warrantyInformation;
  final String? shippingInformation;
  final String? availabilityStatus;
  final List<Review>? reviews;
  final String? returnPolicy;
  final int? minimumOrderQuantity;
  final Meta? meta;
  final List<String>? images;
  final String? thumbnail;

  Product({
    this.id,
    this.title,
    this.description,
    this.category,
    this.price,
    this.discountPercentage,
    this.rating,
    this.stock,
    this.tags,
    this.brand,
    this.sku,
    this.weight,
    this.dimensions,
    this.warrantyInformation,
    this.shippingInformation,
    this.availabilityStatus,
    this.reviews,
    this.returnPolicy,
    this.minimumOrderQuantity,
    this.meta,
    this.images,
    this.thumbnail,
  });

  Product copyWith({
    int? id,
    String? title,
    String? description,
    String? category,
    double? price,
    double? discountPercentage,
    double? rating,
    int? stock,
    List<String>? tags,
    String? brand,
    String? sku,
    int? weight,
    Dimensions? dimensions,
    String? warrantyInformation,
    String? shippingInformation,
    String? availabilityStatus,
    List<Review>? reviews,
    String? returnPolicy,
    int? minimumOrderQuantity,
    Meta? meta,
    List<String>? images,
    String? thumbnail,
  }) => Product(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    category: category ?? this.category,
    price: price ?? this.price,
    discountPercentage: discountPercentage ?? this.discountPercentage,
    rating: rating ?? this.rating,
    stock: stock ?? this.stock,
    tags: tags ?? this.tags,
    brand: brand ?? this.brand,
    sku: sku ?? this.sku,
    weight: weight ?? this.weight,
    dimensions: dimensions ?? this.dimensions,
    warrantyInformation: warrantyInformation ?? this.warrantyInformation,
    shippingInformation: shippingInformation ?? this.shippingInformation,
    availabilityStatus: availabilityStatus ?? this.availabilityStatus,
    reviews: reviews ?? this.reviews,
    returnPolicy: returnPolicy ?? this.returnPolicy,
    minimumOrderQuantity: minimumOrderQuantity ?? this.minimumOrderQuantity,
    meta: meta ?? this.meta,
    images: images ?? this.images,
    thumbnail: thumbnail ?? this.thumbnail,
  );

  factory Product.fromRawJson(String str) => Product.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json["id"],
    title: json["title"],
    description: json["description"],
    category: json["category"],
    price: json["price"]?.toDouble(),
    discountPercentage: json["discountPercentage"]?.toDouble(),
    rating: json["rating"]?.toDouble(),
    stock: json["stock"],
    tags: json["tags"] == null
        ? []
        : List<String>.from(json["tags"]!.map((x) => x)),
    brand: json["brand"],
    sku: json["sku"],
    weight: json["weight"],
    dimensions: json["dimensions"] == null
        ? null
        : Dimensions.fromJson(json["dimensions"]),
    warrantyInformation: json["warrantyInformation"],
    shippingInformation: json["shippingInformation"],
    availabilityStatus: json["availabilityStatus"],
    reviews: json["reviews"] == null
        ? []
        : List<Review>.from(json["reviews"]!.map((x) => Review.fromJson(x))),
    returnPolicy: json["returnPolicy"],
    minimumOrderQuantity: json["minimumOrderQuantity"],
    meta: json["meta"] == null ? null : Meta.fromJson(json["meta"]),
    images: json["images"] == null
        ? []
        : List<String>.from(json["images"]!.map((x) => x)),
    thumbnail: json["thumbnail"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "description": description,
    "category": category,
    "price": price,
    "discountPercentage": discountPercentage,
    "rating": rating,
    "stock": stock,
    "tags": tags == null ? [] : List<dynamic>.from(tags!.map((x) => x)),
    "brand": brand,
    "sku": sku,
    "weight": weight,
    "dimensions": dimensions?.toJson(),
    "warrantyInformation": warrantyInformation,
    "shippingInformation": shippingInformation,
    "availabilityStatus": availabilityStatus,
    "reviews": reviews == null
        ? []
        : List<dynamic>.from(reviews!.map((x) => x.toJson())),
    "returnPolicy": returnPolicy,
    "minimumOrderQuantity": minimumOrderQuantity,
    "meta": meta?.toJson(),
    "images": images == null ? [] : List<dynamic>.from(images!.map((x) => x)),
    "thumbnail": thumbnail,
  };

  ProductEntity toEntity() => ProductEntity(
    id: id ?? 0,
    title: title ?? "",
    description: description ?? "",
    category: category ?? "",
    price: price ?? 0,
    discountPercentage: discountPercentage ?? 0,
    rating: rating ?? 0,
    stock: stock ?? 0,
    images: images ?? [],
    thumbnail: thumbnail,
  );
}

class Dimensions {
  final double? width;
  final double? height;
  final double? depth;

  Dimensions({this.width, this.height, this.depth});

  Dimensions copyWith({double? width, double? height, double? depth}) =>
      Dimensions(
        width: width ?? this.width,
        height: height ?? this.height,
        depth: depth ?? this.depth,
      );

  factory Dimensions.fromRawJson(String str) =>
      Dimensions.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Dimensions.fromJson(Map<String, dynamic> json) => Dimensions(
    width: json["width"]?.toDouble(),
    height: json["height"]?.toDouble(),
    depth: json["depth"]?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    "width": width,
    "height": height,
    "depth": depth,
  };
}

class Meta {
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? barcode;
  final String? qrCode;

  Meta({this.createdAt, this.updatedAt, this.barcode, this.qrCode});

  Meta copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    String? barcode,
    String? qrCode,
  }) => Meta(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    barcode: barcode ?? this.barcode,
    qrCode: qrCode ?? this.qrCode,
  );

  factory Meta.fromRawJson(String str) => Meta.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Meta.fromJson(Map<String, dynamic> json) => Meta(
    createdAt: json["createdAt"] == null
        ? null
        : DateTime.parse(json["createdAt"]),
    updatedAt: json["updatedAt"] == null
        ? null
        : DateTime.parse(json["updatedAt"]),
    barcode: json["barcode"],
    qrCode: json["qrCode"],
  );

  Map<String, dynamic> toJson() => {
    "createdAt": createdAt?.toIso8601String(),
    "updatedAt": updatedAt?.toIso8601String(),
    "barcode": barcode,
    "qrCode": qrCode,
  };
}

class Review {
  final int? rating;
  final String? comment;
  final DateTime? date;
  final String? reviewerName;
  final String? reviewerEmail;

  Review({
    this.rating,
    this.comment,
    this.date,
    this.reviewerName,
    this.reviewerEmail,
  });

  Review copyWith({
    int? rating,
    String? comment,
    DateTime? date,
    String? reviewerName,
    String? reviewerEmail,
  }) => Review(
    rating: rating ?? this.rating,
    comment: comment ?? this.comment,
    date: date ?? this.date,
    reviewerName: reviewerName ?? this.reviewerName,
    reviewerEmail: reviewerEmail ?? this.reviewerEmail,
  );

  factory Review.fromRawJson(String str) => Review.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    rating: json["rating"],
    comment: json["comment"],
    date: json["date"] == null ? null : DateTime.parse(json["date"]),
    reviewerName: json["reviewerName"],
    reviewerEmail: json["reviewerEmail"],
  );

  Map<String, dynamic> toJson() => {
    "rating": rating,
    "comment": comment,
    "date": date?.toIso8601String(),
    "reviewerName": reviewerName,
    "reviewerEmail": reviewerEmail,
  };
}
```

---

## DI (`core/di/di.dart`)

Call `_productInit();` inside `initializeDependencies()`:

```dart
void _productInit() {
  sl.registerLazySingleton(() => ProductApiService(sl<Dio>()));
  sl.registerLazySingleton<ProductRemoteDatasource>(
    () => ProductRemoteDatasourceImpl(sl<ProductApiService>()),
  );
  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(sl<ProductRemoteDatasource>()),
  );
  sl.registerLazySingleton(() => ProductUseCase(sl<ProductRepository>()));
}
```

Register by **abstract type** (`<ProductRepository>`) so the domain depends on the contract, not the impl.

## Generate

```bash
dart run build_runner build --delete-conflicting-outputs
```
