import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shoplite/core/network/dio_client.dart';
import 'package:shoplite/core/storage/auth_storage.dart';
import 'package:shoplite/features/auth/data/datasources/remote/auth_remote_datasource_impl.dart';
import 'package:shoplite/features/auth/data/datasources/remote/auth_service.dart';
import 'package:shoplite/features/auth/data/repositories/login_repository_impl.dart';
import 'package:shoplite/features/auth/domain/usecases/login.dart';
import 'package:shoplite/features/auth/presentation/bloc/login/login_bloc.dart';

final sl = GetIt.instance;

Future<void> initializeDependencies() async {
  await _initCore();
  _authInit();
}

Future<void> _initCore() async {
  sl.registerLazySingleton(() => FlutterSecureStorage());
  sl.registerLazySingleton(() => AuthStorage(sl<FlutterSecureStorage>()));
  sl.registerLazySingleton(() => DioClient.create());
}

void _authInit() {
  sl.registerLazySingleton(() => AuthService(sl<Dio>()));
  sl.registerLazySingleton(() => AuthRemoteDatasourceImpl(sl<AuthService>()));
  sl.registerLazySingleton(
    () => LoginRepositoryImpl(
      remoteDatasource: sl<AuthRemoteDatasourceImpl>(),
      authStorage: sl<AuthStorage>(),
    ),
  );
  sl.registerLazySingleton(() => Login(sl<LoginRepositoryImpl>()));
  sl.registerLazySingleton(() => LoginBloc(sl<Login>()));
}
