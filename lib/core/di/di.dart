import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shoplite/core/database/app_database.dart';
import 'package:shoplite/core/network/auth_interceptor.dart';
import 'package:shoplite/core/network/dio_client.dart';
import 'package:shoplite/core/router/app_router.dart';
import 'package:shoplite/core/storage/auth_storage.dart';
import 'package:shoplite/core/storage/base_auth_storage.dart';
import 'package:shoplite/features/auth/data/datasources/remote/auth_remote_datasource.dart';
import 'package:shoplite/features/auth/data/datasources/remote/auth_remote_datasource_impl.dart';
import 'package:shoplite/features/auth/data/datasources/remote/auth_service.dart';
import 'package:shoplite/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:shoplite/features/auth/domain/repositories/auth_repository.dart';
import 'package:shoplite/features/auth/domain/usecases/is_logged_in.dart';
import 'package:shoplite/features/auth/domain/usecases/login.dart';
import 'package:shoplite/features/auth/domain/usecases/logout.dart';
import 'package:shoplite/features/product/data/datasources/local/product_local_datasource.dart';
import 'package:shoplite/features/product/data/datasources/local/product_local_datasource_impl.dart';
import 'package:shoplite/features/product/data/datasources/remote/product_api_service.dart';
import 'package:shoplite/features/product/data/datasources/remote/product_remote_datasource.dart';
import 'package:shoplite/features/product/data/datasources/remote/product_remote_datasource_impl.dart';
import 'package:shoplite/features/product/data/repositories/product_repository_impl.dart';
import 'package:shoplite/features/product/domain/entities/product_entity.dart';
import 'package:shoplite/features/product/domain/repositories/product_repository.dart';
import 'package:shoplite/features/product/domain/usecases/get_product_details.dart';
import 'package:shoplite/features/product/domain/usecases/product_usecase.dart';
import 'package:shoplite/features/product/presentation/bloc/product_bloc.dart';
import 'package:shoplite/features/product/presentation/cubit/product_details_cubit.dart';

final sl = GetIt.instance;

Future<void> initializeDependencies() async {
  await _initCore();
  _authInit();
  _productInit();
}

Future<void> _initCore() async {
  sl.registerLazySingleton(() => const FlutterSecureStorage());
  sl.registerLazySingleton<BaseAuthStorage>(
    () => AuthStorage(sl<FlutterSecureStorage>()),
  );
  sl.registerLazySingleton(
    () => AuthInterceptor(
      storage: sl<BaseAuthStorage>(),
      // Refresh failed: tokens already cleared, send user to login.
      onSessionExpired: () => router.go(AppRouters.login),
    ),
  );
  sl.registerLazySingleton(() => DioClient.create(sl<AuthInterceptor>()));
  sl.registerLazySingleton(() => AppDatabase(), dispose: (db) => db.close());
}

void _authInit() {
  sl.registerLazySingleton(() => AuthService(sl<Dio>()));
  sl.registerLazySingleton<AuthRemoteDatasource>(
    () => AuthRemoteDatasourceImpl(sl<AuthService>()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDatasource: sl<AuthRemoteDatasource>(),
      authStorage: sl<BaseAuthStorage>(),
    ),
  );
  sl.registerLazySingleton(() => Login(sl<AuthRepository>()));
  sl.registerLazySingleton(() => Logout(sl<AuthRepository>()));
  sl.registerLazySingleton(() => IsLoggedIn(sl<AuthRepository>()));
}

void _productInit() {
  sl.registerLazySingleton(() => ProductApiService(sl<Dio>()));
  sl.registerLazySingleton<ProductRemoteDatasource>(
    () => ProductRemoteDatasourceImpl(sl<ProductApiService>()),
  );
  sl.registerLazySingleton<ProductLocalDatasource>(
    () => ProductLocalDatasourceImpl(sl<AppDatabase>()),
  );
  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(
      remote: sl<ProductRemoteDatasource>(),
      local: sl<ProductLocalDatasource>(),
    ),
  );
  sl.registerLazySingleton(() => ProductUseCase(sl<ProductRepository>()));
  sl.registerLazySingleton(() => GetProductDetails(sl<ProductRepository>()));
  // Factory: page closes the bloc on dispose, so each visit needs a new one.
  sl.registerFactory(() => ProductBloc(sl<ProductUseCase>()));
  sl.registerFactoryParam<ProductDetailsCubit, ProductEntity?, void>(
    (initial, _) =>
        ProductDetailsCubit(sl<GetProductDetails>(), initial: initial),
  );
}
