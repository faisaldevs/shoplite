# Auth Login Setup

Full login flow in `lib/features/auth/`, plus the `lib/core/` files it depends on.

Stack: **Retrofit + Dio** → datasource → repository → `Either<Failure, LoginEntity>` → use case → **LoginBloc** → `LoginPage`. DI via **get_it**, tokens in **flutter_secure_storage**, navigation via **go_router**.

API: `POST https://dummyjson.com/auth/login` with `{ "username", "password" }` (server default token lifetime).

---

## Flow

```
LoginPage (TextFields + button)
   │  add(LoginButtonPressed(username, password))
   ▼
LoginBloc ── emit(loading)
   │  _login(username:, password:)
   ▼
Login (use case)
   │  _repo(username, password)
   ▼
LoginRepositoryImpl
   │  _remoteDatasource.login(...)        ── DioException → _mapDioError → Left(Failure)
   │  await _authStorage.saveTokens(access, refresh)
   │  Right(model.toEntity())
   ▼
AuthRemoteDatasourceImpl → AuthService (Retrofit) → Dio → dummyjson.com
   ▲
LoginBloc ── fold: Left → emit(failure, error) / Right → emit(success)
   ▼
LoginPage BlocConsumer listener → SnackBar + context.go('/product')
```

App startup: `main()` → `initializeDependencies()` → `MyApp` (`MaterialApp.router`) → `/` `SplashPage` → `/login`.

---

## Structure

```
lib/
├── main.dart                                   # awaits DI, runs app
├── app.dart                                    # MaterialApp.router(routerConfig: router)
├── core/
│   ├── di/di.dart                              # get_it registrations
│   ├── error/excptions.dart                    # CacheException
│   ├── error/failure.dart                      # Failure hierarchy
│   ├── network/api_endpoints.dart              # baseUrl + paths
│   ├── network/dio_client.dart                 # Dio factory
│   ├── router/app_router.dart                  # GoRouter routes
│   ├── storage/base_auth_storage.dart          # token storage contract
│   ├── storage/auth_storage.dart               # FlutterSecureStorage impl
│   └── usecase/usecase.dart                    # UseCase<T, Params> base (not used by Login yet)
└── features/auth/
    ├── data/
    │   ├── datasources/remote/
    │   │   ├── auth_service.dart               # Retrofit client (→ auth_service.g.dart)
    │   │   ├── auth_remote_datasource.dart     # contract
    │   │   └── auth_remote_datasource_impl.dart
    │   ├── models/login_response_model.dart    # JSON + toEntity() (→ .g.dart)
    │   └── repositories/login_repository_impl.dart
    ├── domain/
    │   ├── entities/login_entity.dart
    │   ├── repositories/login_repository.dart
    │   └── usecases/login.dart
    └── presentation/
        ├── bloc/login/                         # LoginBloc / LoginEvent / LoginState
        ├── bloc/auth/                          # AuthBloc — empty stub
        ├── pages/login_page.dart
        └── widgets/login_widgets.dart          # CustomTextFieldWidget
```

Codegen (after editing `auth_service.dart` or `login_response_model.dart`):

```bash
dart run build_runner build --delete-conflicting-outputs
```

Packages: `dio`, `retrofit`, `json_annotation`, `fpdart`, `equatable`, `flutter_bloc`, `bloc_concurrency`, `get_it`, `flutter_secure_storage`, `go_router` · dev: `retrofit_generator`, `json_serializable`, `build_runner`.

---

# Core files

## `main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDependencies();
  runApp(const MyApp());
}
```

## `app.dart`

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: router,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
    );
  }
}
```

## `core/di/di.dart`

```dart
final sl = GetIt.instance;

Future<void> initializeDependencies() async {
  await _initCore();
  _authInit();
}

Future<void> _initCore() async {
  sl.registerLazySingleton(() => FlutterSecureStorage());
  sl.registerLazySingleton(() => AuthStorage(sl<FlutterSecureStorage>()));
  sl.registerLazySingleton(() => DioClient.create()); // registered as Dio
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
```

## `core/network/api_endpoints.dart`

```dart
class ApiEndpoints {
  static const String baseUrl = 'https://dummyjson.com';

  static const String login = '/auth/login';
  static const String products = '/auth/products';
}
```

## `core/network/dio_client.dart`

```dart
class DioClient {
  static Dio create() {
    return Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }
}
```

## `core/error/failure.dart`

```dart
class Failure extends Equatable {
  const Failure({required this.message, this.code});

  final String message;
  final int? code;

  @override
  List<Object?> get props => [];
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, required super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message = "No Internet Connection"});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.message = 'Session expired'});
}

class UnknownFailure extends Failure {
  const UnknownFailure({super.message = 'Something went wrong'});
}
```

## `core/error/excptions.dart`

```dart
class CacheException implements Exception {
  const CacheException({this.message = "Cache Oparation Failed"});
  final String message;

  @override
  String toString() => "Exception: $message";
}
```

## `core/storage/base_auth_storage.dart`

```dart
abstract class BaseAuthStorage {
  Future<void> saveTokens(String accessToken, String refreshToken);
  Future<void> clearTokens(String accessToken, String refreshToken);
  Future<String?> getAccessToken(String accessToken);
  Future<String?> getRefreshToken(String refreshToken);
}
```

## `core/storage/auth_storage.dart`

```dart
class AuthStorage implements BaseAuthStorage {
  const AuthStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = "access_token_key";
  static const String _refreshTokenKey = "refresh_token_key";

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    try {
      await Future.wait([
        _storage.write(key: _accessTokenKey, value: accessToken),
        _storage.write(key: _refreshTokenKey, value: refreshToken),
      ]);
    } on PlatformException catch (e) {
      throw CacheException(message: "Could Not Save Tokens: ${e.message}");
    }
  }

  @override
  Future<String?> getAccessToken(String accessToken) async {
    try {
      return await _storage.read(key: _accessTokenKey);
    } on PlatformException catch (e) {
      throw CacheException(message: "Could Not Read Access Tokens: ${e.message}");
    }
  }

  @override
  Future<String?> getRefreshToken(String refreshToken) async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } on PlatformException catch (e) {
      throw CacheException(message: "Could Not Read Refresh Tokens: ${e.message}");
    }
  }

  @override
  Future<void> clearTokens(String accessToken, String refreshToken) async {
    try {
      await Future.wait([
        _storage.delete(key: _accessTokenKey),
        _storage.delete(key: _refreshTokenKey),
      ]);
    } on PlatformException catch (e) {
      throw CacheException(message: "Could Not Clear Tokens: ${e.message}");
    }
  }
}
```

## `core/router/app_router.dart`

```dart
class AppRouters {
  static const String splash = '/';
  static const String login = '/login';
  static const String product = '/product';
}

final router = GoRouter(
  initialLocation: AppRouters.splash,
  routes: [
    GoRoute(path: AppRouters.splash, builder: (context, state) => const SplashPage()),
    GoRoute(path: AppRouters.login, builder: (context, state) => const LoginPage()),
    GoRoute(path: AppRouters.product, builder: (context, state) => const ProductPage()),
  ],
);
```

`SplashPage` (`features/start/`) currently routes to `/login` for both authenticated and unauthenticated states.

## `core/usecase/usecase.dart`

```dart
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
```

---

# Auth feature — data

## `data/datasources/remote/auth_service.dart`

A single `@Body()` map; the generated code does `_data.addAll(credentials)`, so the JSON body contains both fields.

```dart
part 'auth_service.g.dart';

@RestApi()
abstract class AuthService {
  factory AuthService(Dio dio, {String? baseUrl}) = _AuthService;

  @POST(ApiEndpoints.login)
  Future<LoginResponseModel> login(
    @Body() Map<String, dynamic> credentials,
  );
}
```

## `data/datasources/remote/auth_remote_datasource.dart`

```dart
abstract class AuthRemoteDatasource {
  Future<LoginResponseModel> login(String username, String password);
}
```

## `data/datasources/remote/auth_remote_datasource_impl.dart`

```dart
class AuthRemoteDatasourceImpl implements AuthRemoteDatasource {
  final AuthService _authService;

  AuthRemoteDatasourceImpl(this._authService);

  @override
  Future<LoginResponseModel> login(String username, String password) {
    return _authService.login({'username': username, 'password': password});
  }
}
```

## `data/models/login_response_model.dart`

```dart
part 'login_response_model.g.dart';

@JsonSerializable()
class LoginResponseModel {
  final int id;
  final String username;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? gender;
  final String? image;
  final String accessToken;
  final String refreshToken;

  const LoginResponseModel({
    required this.id,
    required this.username,
    this.email,
    this.firstName,
    this.lastName,
    this.gender,
    this.image,
    required this.accessToken,
    required this.refreshToken,
  });

  LoginEntity toEntity() => LoginEntity(
    id: id,
    username: username,
    email: email ?? '',
    firstName: firstName ?? '',
    lastName: lastName ?? '',
    gender: gender ?? '',
    image: image ?? '',
  );

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseModelFromJson(json);
}
```

## `data/repositories/login_repository_impl.dart`

Depends on the concrete `AuthStorage` (see issue #11). Maps `DioException` → `Failure`: timeouts/connection → `NetworkFailure`, 401 → `UnauthorizedFailure`, other bad responses → `ServerFailure(message from body['message'])`, anything else → `UnknownFailure`.

```dart
class LoginRepositoryImpl implements LoginRepository {
  final AuthRemoteDatasource _remoteDatasource;
  final AuthStorage _authStorage;

  LoginRepositoryImpl({
    required this._remoteDatasource,
    required this._authStorage,
  });

  @override
  Future<Either<Failure, LoginEntity>> call(String username, String password) async {
    try {
      final login = await _remoteDatasource.login(username, password);

      await _authStorage.saveTokens(login.accessToken, login.refreshToken);

      return Right(login.toEntity());
    } on DioException catch (e) {
      return Left(_mapDioError(e));
    } catch (e) {
      return const Left(UnknownFailure());
    }
  }

  Failure _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionTimeout:
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

---

# Auth feature — domain

## `domain/entities/login_entity.dart`

```dart
class LoginEntity extends Equatable {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String gender;
  final String image;

  const LoginEntity({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.image,
  });

  @override
  List<Object?> get props => [id, username, email, firstName, lastName, gender, image];
}
```

## `domain/repositories/login_repository.dart`

```dart
abstract class LoginRepository {
  Future<Either<Failure, LoginEntity>> call(String username, String password);
}
```

## `domain/usecases/login.dart`

```dart
class Login {
  const Login(this._repo);

  final LoginRepository _repo;

  Future<Either<Failure, LoginEntity>> call({
    required String username,
    required String password,
  }) {
    return _repo(username, password);
  }
}
```

---

# Auth feature — presentation

## `presentation/bloc/login/login_event.dart`

```dart
sealed class LoginEvent {
  const LoginEvent();
}

class LoginButtonPressed extends LoginEvent {
  final String username;
  final String password;

  const LoginButtonPressed({required this.username, required this.password});
}
```

## `presentation/bloc/login/login_state.dart`

```dart
enum LoginStatus { initial, loading, success, failure }

class LoginState {
  final LoginStatus status;
  final String? error;
  const LoginState({this.status = LoginStatus.initial, this.error});

  LoginState copyWith({LoginStatus? status, String? error}) {
    return LoginState(
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}
```

## `presentation/bloc/login/login_bloc.dart`

```dart
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc(this._login) : super(LoginState(status: LoginStatus.initial)) {
    on<LoginButtonPressed>(eventHandler, transformer: concurrent());
  }

  final Login _login;

  Future<void> eventHandler(LoginButtonPressed event, Emitter<LoginState> emit) async {
    emit(state.copyWith(status: LoginStatus.loading));

    final login = await _login(username: event.username, password: event.password);

    login.fold(
      (failure) => emit(state.copyWith(status: LoginStatus.failure, error: failure.message)),
      (_) => emit(state.copyWith(status: LoginStatus.success)),
    );
  }
}
```

## `presentation/bloc/auth/*`

`AuthBloc` / `AuthEvent` / `AuthState(AuthInitial)` — scaffolded stub, no handlers yet. Intended home for session state (check stored token, logout).

## `presentation/widgets/login_widgets.dart`

```dart
class CustomTextFieldWidget extends StatelessWidget {
  const CustomTextFieldWidget({
    super.key,
    required this.controller,
    this.labelText = 'Enter your username',
  });

  final TextEditingController controller;
  final String labelText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        labelText: labelText,
      ),
    );
  }
}
```

## `presentation/pages/login_page.dart`

```dart
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginBloc(sl<Login>()),
      child: const LoginPageView(),
    );
  }
}

class LoginPageView extends StatefulWidget {
  const LoginPageView({super.key});

  @override
  State<LoginPageView> createState() => _LoginPageViewState();
}

class _LoginPageViewState extends State<LoginPageView> {
  final username = TextEditingController();
  final password = TextEditingController();
  final fromKey = GlobalKey<FormState>();

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login"), centerTitle: true),
      body: Center(
        child: Form(
          key: fromKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomTextFieldWidget(controller: username, labelText: "Enter your username"),
              CustomTextFieldWidget(controller: password, labelText: "Enter your password"),
              SizedBox(height: 24),
              BlocConsumer<LoginBloc, LoginState>(
                listener: (context, state) {
                  if (state.status == LoginStatus.success) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text("Login Successful")));
                    context.go(AppRouters.product);
                  } else if (state.status == LoginStatus.failure) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text("Login Failed")));
                  }
                },
                builder: (context, state) {
                  return ElevatedButton(
                    onPressed: () {
                      context.read<LoginBloc>().add(
                        LoginButtonPressed(username: username.text, password: password.text),
                      );
                    },
                    child: state.status == LoginStatus.loading
                        ? CircularProgressIndicator()
                        : Text("Login"),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

# Known issues & fixes

| # | File | Issue | Effect |
|---|---|---|---|
| 1 | `auth_service.dart` | ~~3× `@Body()` on primitives~~ | **Fixed** — single `Map` body, `.g.dart` regenerated |
| 2 | `auth_storage.dart` | ~~`saveTokens`/`clearTokens` swapped~~ | **Fixed** |
| 3 | `auth_storage.dart` | ~~`_refreshTokenKey = ""`~~ | **Fixed** → `"refresh_token_key"` |
| 4 | `base_auth_storage.dart` | `clearTokens` / `getAccessToken` / `getRefreshToken` take unused params | Open — awkward API |
| 5 | `login_repository_impl.dart` | ~~`saveTokens` not awaited~~ **Fixed**. Still open: `CacheException` is swallowed as `UnknownFailure` | Storage errors misreported |
| 6 | `auth_remote_datasource_impl.dart` | ~~`expiresInMins: 1`~~ | **Fixed** — no longer sent; server default applies |
| 7 | `failure.dart` | `props => []` | All `Failure`s compare equal (breaks tests / Equatable dedupe) |
| 8 | `login_state.dart` | Not `Equatable`; `copyWith` can't clear `error` | Stale error after retry |
| 9 | `login_bloc.dart` | `concurrent()` | Double tap = two login requests. Use `droppable()` |
| 10 | `login_page.dart` | Password not obscured; no validators though `Form` key exists; snackbar ignores `state.error`; button tappable while loading | UX / security |
| 11 | `di.dart`, `login_repository_impl.dart` | Registers/depends on concrete types (`AuthRemoteDatasourceImpl`, `LoginRepositoryImpl`, `AuthStorage`) not abstractions (`sl<BaseAuthStorage>()` was unregistered and would throw, so the repo now takes `AuthStorage`); `LoginBloc` registered as singleton but page builds its own | Harder to mock; unused registration (and a singleton bloc would be closed by `BlocProvider`) |
| 12 | `login.dart` | Doesn't implement `UseCase<T, Params>` | Inconsistent with `core/usecase` |
| 13 | `splash_page.dart` | Both branches go to `/login` | No auto-login |

### Fix 4 — storage signatures (remaining)

Swap/key bugs are already fixed; this removes the unused params.

```dart
abstract class BaseAuthStorage {
  Future<void> saveTokens(String accessToken, String refreshToken);
  Future<void> clearTokens();
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
}
```

```dart
class AuthStorage implements BaseAuthStorage {
  const AuthStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    try {
      await Future.wait([
        _storage.write(key: _accessTokenKey, value: accessToken),
        _storage.write(key: _refreshTokenKey, value: refreshToken),
      ]);
    } on PlatformException catch (e) {
      throw CacheException(message: 'Could Not Save Tokens: ${e.message}');
    }
  }

  @override
  Future<void> clearTokens() async {
    try {
      await Future.wait([
        _storage.delete(key: _accessTokenKey),
        _storage.delete(key: _refreshTokenKey),
      ]);
    } on PlatformException catch (e) {
      throw CacheException(message: 'Could Not Clear Tokens: ${e.message}');
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _accessTokenKey);
    } on PlatformException catch (e) {
      throw CacheException(message: 'Could Not Read Access Token: ${e.message}');
    }
  }

  @override
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } on PlatformException catch (e) {
      throw CacheException(message: 'Could Not Read Refresh Token: ${e.message}');
    }
  }
}
```

Add a `CacheFailure` to `failure.dart` and catch it in the repository:

```dart
final login = await _remoteDatasource.login(username, password);
await _authStorage.saveTokens(login.accessToken, login.refreshToken);
return Right(login.toEntity());
// ...
} on CacheException catch (e) {
  return Left(CacheFailure(message: e.message));
}
```

### Fix 7 — Failure equality

```dart
@override
List<Object?> get props => [message, code];
```

### Fix 9–10 — bloc + page

```dart
on<LoginButtonPressed>(eventHandler, transformer: droppable());
```

```dart
// listener
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text(state.error ?? 'Login Failed')),
);

// button
onPressed: state.status == LoginStatus.loading
    ? null
    : () {
        if (!fromKey.currentState!.validate()) return;
        context.read<LoginBloc>().add(
          LoginButtonPressed(username: username.text.trim(), password: password.text),
        );
      },
```

Add `obscureText` + `validator` params to `CustomTextFieldWidget` and pass `obscureText: true` for the password field.

### Fix 11 — DI against abstractions

```dart
sl.registerLazySingleton<AuthRemoteDatasource>(() => AuthRemoteDatasourceImpl(sl()));
sl.registerLazySingleton<BaseAuthStorage>(() => AuthStorage(sl()));
sl.registerLazySingleton<LoginRepository>(
  () => LoginRepositoryImpl(remoteDatasource: sl(), authStorage: sl()),
);
sl.registerLazySingleton(() => Login(sl()));
sl.registerFactory(() => LoginBloc(sl()));   // factory, not singleton
```

`LoginPage` then uses `create: (_) => sl<LoginBloc>()`.

---

## Test credentials (dummyjson)

```
username: emilys
password: emilyspass
```
