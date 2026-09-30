# Drift: Local Database & Caching Guide (ShopLite)

How to use [Drift](https://drift.simonbinder.eu/) in ShopLite for offline caching of **products** and **login/user data**, following the project's existing clean-architecture layout (`data` / `domain` / `presentation`, `get_it`, `fpdart`, BLoC).

> Status: this is a design + setup guide. Nothing here is wired into `lib/` yet. Code samples are written against the versions pinned in `pubspec.yaml` (see [Versions](#1-versions--why-drift-is-pinned)).

---

## Table of contents

1. [Versions & why drift is pinned](#1-versions--why-drift-is-pinned)
2. [What goes where (Drift vs secure storage)](#2-what-goes-where-drift-vs-secure-storage)
3. [Folder layout](#3-folder-layout)
4. [Setup](#4-setup)
5. [Schema: everything needed to fully cache products](#5-schema-everything-needed-to-fully-cache-products)
6. [Schema: login / user data](#6-schema-login--user-data)
7. [The database class](#7-the-database-class)
8. [DAOs (queries)](#8-daos-queries)
9. [Repository: offline-first flow](#9-repository-offline-first-flow)
10. [Login caching and logout cleanup](#10-login-caching-and-logout-cleanup)
11. [Dependency injection](#11-dependency-injection)
12. [Migrations](#12-migrations)
13. [Testing](#13-testing)
14. [Best practices](#14-best-practices)
15. [Common pitfalls](#15-common-pitfalls)
16. [Checklist](#16-checklist)

---

## 1. Versions & why drift is pinned

`pubspec.yaml` currently has:

```yaml
dependencies:
  drift: '>=2.34.0 <2.35.0'
  drift_flutter: ^0.3.1
  path_provider: ^2.1.6

dev_dependencies:
  drift_dev: '>=2.34.0 <2.34.6'
  build_runner: ^2.6.0
```

**Why the cap:** `drift_dev` 2.34.6+ requires `analyzer >=13`, but `bloc_test ^10.0.0` pulls in `test 1.31.0`, which requires `analyzer <13`, and `flutter_test` pins `test_api`, so the solver cannot satisfy both.

**When to lift it:** once a newer `flutter_test` / `bloc_test` allows `analyzer >=13`, set both back to `^2.35.0` (or later). `drift` and `drift_dev` **must always be a matching pair**. Check with `flutter pub outdated`.

The API in this guide is the same across 2.34 and 2.35.

---

## 2. What goes where (Drift vs secure storage)

| Data | Store | Why |
|---|---|---|
| `accessToken`, `refreshToken` | `flutter_secure_storage` (already done in `AuthStorage`) | Secrets. Drift/SQLite is an **unencrypted file**; never put tokens there. |
| User profile (id, username, email, name, gender, image) | Drift `cached_users` | Not secret, useful offline (profile header, greeting). |
| Products (+ reviews, dimensions, meta, tags, images) | Drift | Large, relational, queried, must work offline. |
| Product list position, `total` count, last-fetched time | Drift `cache_metadata` + `position` column | Needed to resume pagination and decide freshness. |
| Favorites, notes | Drift | User data, references products. |
| Downloaded image file paths | Drift (`product_images.localPath`) | Files live on disk, DB stores the path. |
| Password | **Nowhere** | Never persist it. |

Rule of thumb: **secrets in secure storage, everything else that should survive offline in Drift.**

---

## 3. Folder layout

Keep Drift in the **data layer** only. `domain` must not import `drift`.

```
lib/
├── core/
│   └── database/
│       ├── app_database.dart          # @DriftDatabase, migrations
│       ├── app_database.g.dart        # generated
│       ├── tables/
│       │   ├── products_table.dart
│       │   ├── product_reviews_table.dart
│       │   ├── product_images_table.dart
│       │   ├── favorites_table.dart
│       │   ├── cached_users_table.dart
│       │   └── cache_metadata_table.dart
│       └── converters/
│           └── string_list_converter.dart
└── features/
    ├── product/data/
    │   ├── datasources/local/
    │   │   ├── product_local_datasource.dart        # abstract
    │   │   ├── product_local_datasource_impl.dart   # uses ProductDao
    │   │   └── product_dao.dart (+ .g.dart)
    │   └── repositories/product_repository_impl.dart # remote + local
    └── auth/data/
        └── datasources/local/
            ├── user_local_datasource.dart
            ├── user_local_datasource_impl.dart
            └── user_dao.dart (+ .g.dart)
```

Drift `Table` classes and generated row classes (`ProductRow`, ...) stay in `data/`. Map them to your existing entities (`ProductEntity`, `LoginEntity`) before crossing into `domain`, exactly like the current `toEntity()` on the API models.

---

## 4. Setup

### 4.1 Dependencies

Already added. `drift_flutter` gives `driftDatabase(...)`, which picks the right SQLite setup per platform (native on mobile/desktop, WASM on web).

### 4.2 Code generation

Every file that declares tables/databases/DAOs needs a `part '<name>.g.dart';` and a generator run:

```bash
# one-off
dart run build_runner build --delete-conflicting-outputs

# while developing
dart run build_runner watch --delete-conflicting-outputs
```

Commit the generated `*.g.dart` files (the repo already commits `auth_service.g.dart` etc.), so a fresh clone builds without running the generator.

### 4.3 Optional `build.yaml`

Add at the project root to get strict, predictable generation and to enable schema tooling:

```yaml
targets:
  $default:
    builders:
      drift_dev:
        options:
          databases:
            app_database: lib/core/database/app_database.dart
          schema_dir: drift_schemas/
          test_dir: test/drift/
```

`drift_schemas/` is where migration snapshots live (see [Migrations](#12-migrations)). Commit it.

---

## 5. Schema: everything needed to fully cache products

The API model (`ProductResponseModel.Product`) contains: `id, title, description, category, price, discountPercentage, rating, stock, tags, brand, sku, weight, dimensions{width,height,depth}, warrantyInformation, shippingInformation, availabilityStatus, reviews[], returnPolicy, minimumOrderQuantity, meta{createdAt,updatedAt,barcode,qrCode}, images[], thumbnail`, plus pagination fields `total, skip, limit`.

To cache a product **completely** you need to store all of it. The domain `ProductEntity` today only uses a subset, but store everything so a detail screen works offline without another API call.

### Design decisions

| Field | Storage | Reason |
|---|---|---|
| Scalars (title, price, ...) | Columns on `products` | Queryable/sortable. |
| `dimensions`, `meta` | **Flattened columns** (`dimWidth`, `metaCreatedAt`, ...) | 1:1 and always loaded together, so no extra table/join. |
| `tags` | JSON text via a `TypeConverter` | Small, never queried individually. |
| `images` | Child table `product_images` | Each image needs its own `localPath` for "save for offline". |
| `reviews` | Child table `product_reviews` | 1:N, own rows, cascade delete. |
| List order | `position` column | API order must survive re-reads (`ORDER BY position`). |
| `total`, freshness | `cache_metadata` key/value table | Restores `hasReachedMax` offline. |

### `lib/core/database/converters/string_list_converter.dart`

```dart
import 'dart:convert';
import 'package:drift/drift.dart';

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (json.decode(fromDb) as List).cast<String>();

  @override
  String toSql(List<String> value) => json.encode(value);
}
```

### `products_table.dart`

```dart
import 'package:drift/drift.dart';
import 'package:shoplite/core/database/converters/string_list_converter.dart';

@DataClassName('ProductRow')
class Products extends Table {
  // Server id is the identity. NOT autoIncrement: we must upsert by it.
  IntColumn get id => integer()();

  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant(''))();
  RealColumn get price => real().withDefault(const Constant(0))();
  RealColumn get discountPercentage => real().withDefault(const Constant(0))();
  RealColumn get rating => real().withDefault(const Constant(0))();
  IntColumn get stock => integer().withDefault(const Constant(0))();

  TextColumn get brand => text().nullable()();
  TextColumn get sku => text().nullable()();
  IntColumn get weight => integer().nullable()();
  TextColumn get thumbnail => text().nullable()();
  TextColumn get tags => text().map(const StringListConverter())
      .withDefault(const Constant('[]'))();

  TextColumn get warrantyInformation => text().nullable()();
  TextColumn get shippingInformation => text().nullable()();
  TextColumn get availabilityStatus => text().nullable()();
  TextColumn get returnPolicy => text().nullable()();
  IntColumn get minimumOrderQuantity => integer().nullable()();

  // Flattened Dimensions
  RealColumn get dimWidth => real().nullable()();
  RealColumn get dimHeight => real().nullable()();
  RealColumn get dimDepth => real().nullable()();

  // Flattened Meta
  DateTimeColumn get metaCreatedAt => dateTime().nullable()();
  DateTimeColumn get metaUpdatedAt => dateTime().nullable()();
  TextColumn get metaBarcode => text().nullable()();
  TextColumn get metaQrCode => text().nullable()();

  // Position in the API list (skip + index). Keeps server ordering offline.
  IntColumn get position => integer()();

  // For staleness checks / eviction.
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

### `product_images_table.dart`

```dart
import 'package:drift/drift.dart';
import 'products_table.dart';

class ProductImages extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.cascade)();

  TextColumn get url => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  // Set by "Save for offline"; null = not downloaded.
  TextColumn get localPath => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [{productId, url}];
}
```

### `product_reviews_table.dart`

```dart
import 'package:drift/drift.dart';
import 'products_table.dart';

class ProductReviews extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.cascade)();

  IntColumn get rating => integer().nullable()();
  TextColumn get comment => text().nullable()();
  DateTimeColumn get date => dateTime().nullable()();
  TextColumn get reviewerName => text().nullable()();
  TextColumn get reviewerEmail => text().nullable()();
}
```

### `favorites_table.dart`

```dart
import 'package:drift/drift.dart';
import 'products_table.dart';

class Favorites extends Table {
  // productId is the PK => a product can be favorited at most once (1:0..1).
  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {productId};
}
```

Why this shape: one favorite per product, so `productId` is the primary key (no duplicate rows, no surrogate id). `onDelete: cascade` means deleting a product never leaves orphaned favorites. If favorites become per-user later, change the PK to `{userId, productId}`.

### `cache_metadata_table.dart`

```dart
import 'package:drift/drift.dart';

// Tiny key/value store: 'products_total', 'products_last_fetched_at', ...
class CacheMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
```

---

## 6. Schema: login / user data

`LoginResponseModel` returns `id, username, email, firstName, lastName, gender, image, accessToken, refreshToken`. Tokens already go to secure storage. Cache the **profile part** only.

### `cached_users_table.dart`

```dart
import 'package:drift/drift.dart';

class CachedUsers extends Table {
  IntColumn get id => integer()(); // server user id
  TextColumn get username => text()();
  TextColumn get email => text().withDefault(const Constant(''))();
  TextColumn get firstName => text().withDefault(const Constant(''))();
  TextColumn get lastName => text().withDefault(const Constant(''))();
  TextColumn get gender => text().withDefault(const Constant(''))();
  TextColumn get image => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

Only one user is logged in at a time; the table holds at most one row (cleared on logout). Keeping the server id as PK (rather than a fixed `1`) lets you tie future per-user tables to it.

---

## 7. The database class

`lib/core/database/app_database.dart`

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/cache_metadata_table.dart';
import 'tables/cached_users_table.dart';
import 'tables/favorites_table.dart';
import 'tables/product_images_table.dart';
import 'tables/product_reviews_table.dart';
import 'tables/products_table.dart';
import 'package:shoplite/features/auth/data/datasources/local/user_dao.dart';
import 'package:shoplite/features/product/data/datasources/local/product_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Products,
    ProductImages,
    ProductReviews,
    Favorites,
    CachedUsers,
    CacheMetadata,
  ],
  daos: [ProductDao, UserDao],
)
class AppDatabase extends _$AppDatabase {
  // Production: file-backed DB in the app documents dir.
  AppDatabase() : super(driftDatabase(name: 'shoplite'));

  // Tests: pass NativeDatabase.memory().
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // See section 12.
    },
    beforeOpen: (details) async {
      // SQLite ignores FOREIGN KEY constraints unless this is on.
      // Without it, cascade deletes DO NOT happen.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Wipes everything user-specific. Used on logout.
  Future<void> clearUserData() => transaction(() async {
    await delete(favorites).go();
    await delete(cachedUsers).go();
  });

  /// Wipes everything, including cached catalog. Used on logout if you want
  /// a fully clean device.
  Future<void> clearAll() => transaction(() async {
    for (final table in allTables) {
      await delete(table).go();
    }
  });
}
```

Notes:

- `PRAGMA foreign_keys = ON` in `beforeOpen` is **mandatory** for `references(...)` + `onDelete: cascade` to actually work.
- Create **one** `AppDatabase` for the whole app (singleton via `get_it`). Multiple instances on the same file cause "database is locked" races and stale streams.
- `driftDatabase(name: 'shoplite')` stores the file in the app's documents directory (via `path_provider`). It runs SQLite on a background isolate by default in drift_flutter, keeping the UI thread free.

---

## 8. DAOs (queries)

### `product_dao.dart`

```dart
import 'package:drift/drift.dart';
import 'package:shoplite/core/database/app_database.dart';
import 'package:shoplite/core/database/tables/cache_metadata_table.dart';
import 'package:shoplite/core/database/tables/favorites_table.dart';
import 'package:shoplite/core/database/tables/product_images_table.dart';
import 'package:shoplite/core/database/tables/product_reviews_table.dart';
import 'package:shoplite/core/database/tables/products_table.dart';

part 'product_dao.g.dart';

@DriftAccessor(
  tables: [Products, ProductImages, ProductReviews, Favorites, CacheMetadata],
)
class ProductDao extends DatabaseAccessor<AppDatabase> with _$ProductDaoMixin {
  ProductDao(super.db);

  // ---- Reads (reactive) ---------------------------------------------------

  /// The UI list. Emits again whenever any product row changes.
  Stream<List<ProductRow>> watchProducts() =>
      (select(products)..orderBy([(p) => OrderingTerm.asc(p.position)])).watch();

  Stream<ProductRow?> watchProduct(int id) =>
      (select(products)..where((p) => p.id.equals(id))).watchSingleOrNull();

  Stream<List<ProductImage>> watchImages(int productId) =>
      (select(productImages)
            ..where((i) => i.productId.equals(productId))
            ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
          .watch();

  Future<List<ProductReview>> getReviews(int productId) =>
      (select(productReviews)..where((r) => r.productId.equals(productId)))
          .get();

  /// Search runs in SQL, not in Dart, so it works on the whole cache.
  Stream<List<ProductRow>> watchSearch(String query) =>
      (select(products)
            ..where((p) => p.title.like('%$query%'))
            ..orderBy([(p) => OrderingTerm.asc(p.position)]))
          .watch();

  // ---- Writes -------------------------------------------------------------

  /// Upsert a whole API page atomically. One transaction => the UI stream
  /// emits once with a consistent result, and a crash can't leave half a page.
  Future<void> upsertPage({
    required List<ProductsCompanion> rows,
    required Map<int, List<ProductImagesCompanion>> imagesByProduct,
    required Map<int, List<ProductReviewsCompanion>> reviewsByProduct,
  }) => transaction(() async {
    await batch((b) {
      b.insertAllOnConflictUpdate(products, rows);
    });

    for (final row in rows) {
      final id = row.id.value;

      // Reviews: replace (they have no stable server id).
      await (delete(productReviews)..where((r) => r.productId.equals(id))).go();
      await batch((b) => b.insertAll(
            productReviews, reviewsByProduct[id] ?? const []));

      // Images: upsert by (productId, url) so `localPath` (offline copy)
      // survives a refresh. Do NOT delete-and-reinsert these.
      await batch((b) {
        for (final img in imagesByProduct[id] ?? const <ProductImagesCompanion>[]) {
          b.insert(
            productImages,
            img,
            onConflict: DoUpdate(
              (_) => ProductImagesCompanion(sortOrder: img.sortOrder),
              target: [productImages.productId, productImages.url],
            ),
          );
        }
      });
    }
  });

  // ---- Metadata -----------------------------------------------------------

  Future<void> setMeta(String key, String value) => into(cacheMetadata)
      .insertOnConflictUpdate(CacheMetadataCompanion.insert(key: key, value: value));

  Future<String?> getMeta(String key) async {
    final row = await (select(cacheMetadata)..where((m) => m.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  // ---- Favorites (CRUD) ---------------------------------------------------

  Future<void> addFavorite(int productId) => into(favorites).insertOnConflictUpdate(
        FavoritesCompanion.insert(productId: Value(productId)),
      );

  Future<void> removeFavorite(int productId) =>
      (delete(favorites)..where((f) => f.productId.equals(productId))).go();

  Future<void> clearFavorites() => delete(favorites).go();

  /// Favorites joined with product data, reactive.
  Stream<List<ProductRow>> watchFavoriteProducts() {
    final q = select(products).join([
      innerJoin(favorites, favorites.productId.equalsExp(products.id)),
    ])..orderBy([OrderingTerm.desc(favorites.addedAt)]);
    return q.watch().map((rows) => rows.map((r) => r.readTable(products)).toList());
  }

  Stream<Set<int>> watchFavoriteIds() =>
      select(favorites).watch().map((rows) => rows.map((f) => f.productId).toSet());
}
```

(`FavoritesCompanion.insert(productId: ...)` takes a plain value for required columns with no default. Adjust to whatever the generator emits; check the `.g.dart` after the first build.)

### `user_dao.dart`

```dart
import 'package:drift/drift.dart';
import 'package:shoplite/core/database/app_database.dart';
import 'package:shoplite/core/database/tables/cached_users_table.dart';

part 'user_dao.g.dart';

@DriftAccessor(tables: [CachedUsers])
class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
  UserDao(super.db);

  Future<void> saveUser(CachedUsersCompanion user) => transaction(() async {
    await delete(cachedUsers).go(); // single-user table
    await into(cachedUsers).insert(user);
  });

  Future<CachedUser?> getUser() => select(cachedUsers).getSingleOrNull();

  Stream<CachedUser?> watchUser() => select(cachedUsers).watchSingleOrNull();

  Future<void> clear() => delete(cachedUsers).go();
}
```

### Query rules of thumb

- **Reads for UI → `watch()`**, one-shot logic → `get()`.
- **Multi-row writes → `batch`**, **multi-step writes → `transaction`**.
- Filter/sort/paginate in **SQL** (`where`, `orderBy`, `limit`), not by loading everything and filtering in Dart.
- Escape user input in `like` searches if it may contain `%` / `_`.

---

## 9. Repository: offline-first flow

**Principle:** the database is the single source of truth. The network only *refreshes* the database; the UI only *reads* the database.

```
            ┌──────────── UI (ProductBloc) ────────────┐
            │  listens to  ▲                 │ triggers │
            │              │ watch()         ▼          │
            │        ProductRepository ── refresh(page) │
            │              │                 │          │
            │   ProductDao (Drift)      ProductApiService (Dio)
            │              ▲                 │          │
            │              └── upsertPage ◄──┘          │
            └───────────────────────────────────────────┘
```

### Domain contract (no Drift here)

```dart
abstract class ProductRepository {
  /// Cached products in server order. Emits on every DB change.
  Stream<List<ProductEntity>> watchProducts();

  /// Fetch a page from the API and write it to the DB.
  /// Right(hasReachedMax) on success; Left(failure) if the network failed.
  Future<Either<Failure, bool>> refreshPage({
    required int limit,
    required int skip,
  });
}
```

### Data layer

```dart
class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl(this._remote, this._local);

  final ProductRemoteDatasource _remote;
  final ProductLocalDatasource _local;

  @override
  Stream<List<ProductEntity>> watchProducts() =>
      _local.watchProducts().map((rows) => rows.map((r) => r.toEntity()).toList());

  @override
  Future<Either<Failure, bool>> refreshPage({
    required int limit,
    required int skip,
  }) async {
    try {
      final page = await _remote.getProducts(limit: limit, skip: skip);
      await _local.savePage(page, skip: skip);   // upsert in one transaction
      return Right(skip + limit >= (page.total ?? 0));
    } on DioException catch (e) {
      return Left(_mapDioError(e));               // existing mapper
    } on CacheException catch (e) {
      return Left(UnknownFailure(message: e.message));
    }
  }
}
```

Mapping a page to rows (`savePage`): `position = skip + index`; flatten `dimensions`/`meta`; build `ProductImagesCompanion`s (`sortOrder = index`) and `ProductReviewsCompanion`s; save `total` with `setMeta('products_total', '$total')` and `setMeta('products_last_fetched_at', DateTime.now().toIso8601String())`.

### Bloc (sketch)

```dart
on<ProductFetched>((event, emit) async {
  emit(state.copyWith(status: ProductStatus.loading));

  // 1. Cache first: DB emits immediately if data exists (even offline).
  // 2. Kick off network refresh in the background.
  final refresh = _repo.refreshPage(limit: _limit, skip: 0);

  await emit.forEach<List<ProductEntity>>(
    _repo.watchProducts(),
    onData: (products) => state.copyWith(
      status: ProductStatus.success,
      products: products,
    ),
  );
});
```

- On refresh failure with **cached data present** → keep showing cache, set a flag (`isOffline: true`) that drives the **offline banner**. Only show a full-screen error when the cache is empty **and** the fetch failed.
- Pull-to-refresh → `refreshPage(skip: 0)` (the stream updates the UI by itself; no manual list assignment).
- Load more → `refreshPage(skip: state.products.length)`; keep `droppable()` (already used).

### Cache policy

| Situation | Behavior |
|---|---|
| Cache exists, online | Show cache instantly, refresh in background (stale-while-revalidate). |
| Cache exists, offline | Show cache + offline banner. |
| No cache, online | Loading → network → DB → UI. |
| No cache, offline | Error state with retry. |
| Refresh page 0 | Upsert; stale rows beyond page 0 stay (they're still valid catalog data). If you need exact server parity, delete rows not in the refreshed range **except** favorited ones. |
| Freshness | `products_last_fetched_at` older than N minutes (e.g. 10) → refresh on open; otherwise skip the network call. |

---

## 10. Login caching and logout cleanup

### On login

`AuthRepositoryImpl.login` already saves tokens. Extend it to also save the profile:

```dart
final login = await _remoteDatasource.login(username, password);

await _authStorage.saveTokens(login.accessToken, login.refreshToken);
await _userLocal.saveUser(login);          // profile -> Drift (cached_users)

return Right(login.toEntity());
```

Do the token write **first**: if the profile cache write fails, the user is still logged in (a failed cache write should not fail login; catch and log it separately if you want).

### `isLoggedIn`

Keep it **token-based** (as it is now). Do not derive login state from the presence of a Drift row: DB rows can outlive a wiped keystore, and the reverse.

### Offline profile

`UserDao.watchUser()` feeds any profile UI, so it works without the network. There is no "get profile" endpoint call needed at startup.

### On logout (`AuthRepositoryImpl.logout`)

```dart
@override
Future<void> logout() async {
  await _authStorage.clearTokens();   // 1. secrets
  await _db.clearUserData();          // 2. cached_users + favorites (one transaction)
  // Optional: also delete downloaded image files (see below).
}
```

Requirement from the spec (R1.10): *logout clears tokens and all user-specific cached data.*

What counts as user-specific:

| Clear on logout | Keep on logout |
|---|---|
| tokens (secure storage) | Public catalog: `products`, `product_reviews`, `product_images` rows |
| `cached_users` | |
| `favorites` (+ notes) | |
| Saved-offline image **files** if you consider them user data | |

If the catalog is the same for everyone (dummyjson), keeping it makes the next login instantly populated. If the catalog can be personalised/permissioned, call `clearAll()` instead.

Also clear on **forced** logout: `AuthInterceptor.onSessionExpired` currently only clears tokens and navigates. Route it through the same `logout` use case so the DB is cleaned there too.

### Login-related test value to remove

`AuthRemoteDatasourceImpl.login` sends `"expiresInMins": 1`. That's handy for testing refresh, but must not ship; with a 1-minute token, cached-data flows will keep hitting the refresh path.

---

## 11. Dependency injection

In `lib/core/di/di.dart`, inside `_initCore()`:

```dart
sl.registerLazySingleton<AppDatabase>(
  () => AppDatabase(),
  dispose: (db) => db.close(),
);
sl.registerLazySingleton(() => sl<AppDatabase>().productDao);
sl.registerLazySingleton(() => sl<AppDatabase>().userDao);
```

Then:

```dart
void _productInit() {
  // ...existing remote registrations...
  sl.registerLazySingleton<ProductLocalDatasource>(
    () => ProductLocalDatasourceImpl(sl<ProductDao>()),
  );
  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(
      sl<ProductRemoteDatasource>(),
      sl<ProductLocalDatasource>(),
    ),
  );
}
```

`AuthRepositoryImpl` gets a `UserLocalDatasource` (and a way to call `clearUserData`, e.g. via the datasource) the same way.

Keep the database a **lazy singleton**, never a factory.

---

## 12. Migrations

Bump `schemaVersion` and add an `onUpgrade` step **every time** a table or column changes after the app has shipped. Never edit an old step.

### Example: add a nullable `note` to favorites (schema 1 → 2)

Table:

```dart
class Favorites extends Table {
  // ...
  TextColumn get note => text().nullable()();
}
```

Database:

```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) => m.createAll(),
  onUpgrade: (m, from, to) async {
    if (from < 2) {
      await m.addColumn(favorites, favorites.note);
    }
    // if (from < 3) { ... }
  },
  beforeOpen: (details) async {
    await customStatement('PRAGMA foreign_keys = ON');
  },
);
```

Use the `if (from < N)` pattern (not `else if`) so a user jumping 1 → 3 runs every step in order.

Adding a **nullable** column (or one with a default) keeps existing rows intact. Adding a non-null column without a default fails on existing data.

### Recommended: drift's schema tooling

```bash
# after finalising a schema version, snapshot it:
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/

# generate the step-by-step migration helper:
dart run drift_dev schema steps drift_schemas/ lib/core/database/schema_versions.dart

# generate migration test scaffolding:
dart run drift_dev schema generate drift_schemas/ test/drift/generated/
```

Commit `drift_schemas/drift_schema_v1.json`, `_v2.json`, ... then write a `SchemaVerifier` test that starts at v1, inserts data, migrates to v2 and asserts the data survived. See [Testing](#13-testing).

### Destructive dev shortcut (development only)

If you're pre-release and don't care about data: `onUpgrade: (m, from, to) async { for (final t in allTables.toList().reversed) { await m.deleteTable(t.actualTableName); } await m.createAll(); }`. **Never** ship this once users have favorites.

---

## 13. Testing

Use an **in-memory** database; no files, fast, isolated.

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('favorite is removed when its product is deleted (cascade)', () async {
    await db.into(db.products).insert(
      ProductsCompanion.insert(id: const Value(1), title: 'A', position: 0),
    );
    await db.productDao.addFavorite(1);

    await (db.delete(db.products)..where((p) => p.id.equals(1))).go();

    expect(await db.select(db.favorites).get(), isEmpty);
  });

  test('watchProducts emits in position order', () async {
    // insert rows at positions 2, 0, 1 -> expect ids sorted by position
  });
}
```

Things to cover:

1. **DAO CRUD** and `watch()` streams (`expectLater(stream, emitsInOrder([...]))`).
2. **Cascade**: deleting a product removes its favorites, reviews and images. This only passes because `beforeOpen` enables foreign keys; `forTesting` still runs your `migration`, so it works.
3. **Repository fallback**: API throws `DioException` → repository returns `Left`, and `watchProducts()` still yields cached rows (mock the remote with `mocktail`, use a real in-memory DB).
4. **Migration**: `SchemaVerifier` v1 → v2, existing favorites preserved.
5. **Logout**: after `clearUserData()`, `cached_users` and `favorites` are empty and `products` is untouched.

---

## 14. Best practices

**Architecture**

- Drift types (`ProductRow`, `Companion`, `Table`) never leave `data/`. Map to entities at the repository boundary.
- One database, one instance, injected via `get_it`. Close it via `dispose:`.
- Put queries in **DAOs**, not in repositories or blocs.
- The DB is the source of truth: UI ← DB ← network. Never render API responses directly.

**Schema**

- Give every table an explicit primary key. Use the server id as PK for cached server entities and upsert with `insertOnConflictUpdate`.
- Use foreign keys with explicit `onDelete` behavior, and enable `PRAGMA foreign_keys = ON`.
- Prefer nullable columns / defaults for anything the API may omit (this API model is all-nullable).
- Index columns you filter/join on a lot:
  ```dart
  @TableIndex(name: 'idx_products_category', columns: {#category})
  ```
  (annotation on the table class; `product_images(productId)` and `product_reviews(productId)` are good candidates).
- Store `DateTime` via `dateTime()` (drift stores unix seconds by default). Keep money as `real` only for display prices; use integer cents if you ever do arithmetic.
- Don't store large blobs (images) in SQLite. Store **files on disk + path in DB**.

**Queries**

- `watch()` for UI, `get()`/`getSingle()` for logic.
- `batch` for many inserts, `transaction` for multi-step consistency.
- Filter and sort in SQL.
- Keep streams alive only as long as needed: `emit.forEach` in a bloc cancels with the bloc; otherwise cancel your `StreamSubscription`.
- Avoid `select(...).watch()` on huge tables without `limit` for list UIs; add paging (`limit`/`offset` or keyset on `position`) if the cache grows.

**Caching**

- Stale-while-revalidate: show cache immediately, refresh in the background.
- Record `cachedAt` / `products_last_fetched_at` and define a TTL.
- Persisted user state (favorites, `localPath`) must **survive a refresh**: upsert, never wipe-and-reinsert those tables.
- Set an eviction policy if the cache can grow unbounded (e.g. delete non-favorited rows older than 30 days).
- Never cache tokens or passwords in Drift.

**Migrations**

- Bump `schemaVersion` with every schema change; never edit past steps.
- Snapshot each version with `drift_dev schema dump` and test upgrades.
- Additive changes (nullable column, new table) are cheap; destructive ones need data copying.

**Errors**

- Wrap DB calls so failures become `CacheException` (already defined in `core/error/excptions.dart`), then map to a `Failure` in the repository. Blocs should never see raw `SqliteException`.

**Codegen hygiene**

- Commit generated `*.g.dart`. Re-run `build_runner` after any table/DAO/query change; stale generated code is the #1 source of confusing compile errors.

---

## 15. Common pitfalls

| Symptom | Cause / fix |
|---|---|
| Cascade delete does nothing, orphaned favorites | Missing `PRAGMA foreign_keys = ON` in `beforeOpen`. |
| `insertOnConflictUpdate` on `images` wipes `localPath` | You upserted the whole row. Use `DoUpdate` that touches only the columns the API owns, as in `upsertPage`. |
| List order changes after refresh | No `orderBy`. Always order by `position`. |
| Offline shows nothing though data was fetched | UI reads API result instead of `watchProducts()`. |
| `database is locked` / streams don't update | Multiple `AppDatabase` instances. Register exactly one. |
| Users lose data on app update | Changed a table without bumping `schemaVersion` / writing `onUpgrade`. |
| `No such column` after editing a table | Forgot to re-run `build_runner`. |
| Non-null column added in migration crashes | Existing rows have no value. Make it nullable or give a `withDefault`. |
| Logout leaves previous user's favorites visible | `clearUserData()` not called on the **forced** logout path (`onSessionExpired`). |
| Tests pass but production cascade fails | Test DB and prod DB run different `beforeOpen` code. Use the same `migration` for both. |
| `pub get` fails on `analyzer` | `drift_dev` / `bloc_test` conflict, see [section 1](#1-versions--why-drift-is-pinned). |

---

## 16. Checklist

**Setup**
- [ ] `build.yaml` (optional) and `drift_schemas/` created
- [ ] Tables, converters, `AppDatabase`, DAOs written
- [ ] `dart run build_runner build --delete-conflicting-outputs` succeeds
- [ ] `AppDatabase` registered once in `get_it`, closed on dispose
- [ ] `PRAGMA foreign_keys = ON` in `beforeOpen`

**Products**
- [ ] Every API field is stored (scalars, dimensions, meta, tags, images, reviews)
- [ ] `position` preserves server order; `total` stored in `cache_metadata`
- [ ] UI reads `watchProducts()`, not API responses
- [ ] Refresh/load-more only write to the DB
- [ ] Offline banner when refresh fails and cache exists
- [ ] Search runs in SQL

**Login**
- [ ] Tokens only in secure storage
- [ ] Profile cached in `cached_users` on login
- [ ] `isLoggedIn` still token-based
- [ ] Logout **and** session-expired both clear tokens + user data
- [ ] `expiresInMins: 1` test value removed

**Favorites**
- [ ] FK to products with `onDelete: cascade`
- [ ] Add / remove / list / clear-all
- [ ] Favorites screen reactive (`watchFavoriteProducts()`)

**Quality**
- [ ] `schemaVersion` bumped for every change, migration tested
- [ ] In-memory DB tests: CRUD, cascade, repository fallback
- [ ] No Drift imports under `domain/`

---

### References

- Drift docs: https://drift.simonbinder.eu/
- Migrations: https://drift.simonbinder.eu/migrations/
- Testing: https://drift.simonbinder.eu/testing/
- `drift_flutter`: https://pub.dev/packages/drift_flutter
