# Auth TODO

Complete auth: login, refresh, logout, session restore. Do in order.

Simple version done (interview scope): login, token attach, refresh on 401, logout, splash session check. Unchecked items are optional extras.

## 1. Cleanup existing code
- [x] Remove unused params from `BaseAuthStorage` / `AuthStorage` (`getAccessToken()`, `getRefreshToken()`, `clearTokens()`).
- [x] Make repository depend on `BaseAuthStorage` instead of concrete `AuthStorage`.
- [ ] Map `CacheException` to a `CacheFailure` instead of `UnknownFailure`.
- [ ] Fix `Failure.props` to `[message, code]`.
- [ ] Move `mocktail` and `bloc_test` to `dev_dependencies`.

## 2. Domain layer
- [x] Rename `LoginRepository` to `AuthRepository` with `login`, `logout`, `isLoggedIn`.
- [ ] (extra) Add `getCurrentUser` to `AuthRepository`.
- [ ] Rename `LoginEntity` to `UserEntity`.
- [x] Add use cases: `Logout`, `IsLoggedIn`.
- [ ] (extra) Add `GetCurrentUser` use case.

## 3. Data layer
- [x] Add `refresh` endpoint to `ApiEndpoints` (refresh call lives in `AuthInterceptor`, so no Retrofit/model needed).
- [ ] (extra) Add `me` endpoint (`/auth/me`).
- [ ] Add `refresh()` (POST `{refreshToken, expiresInMins}`) and `me()` (GET) to `AuthService`, then run build_runner.
- [ ] Add `RefreshResponseModel` (`accessToken`, `refreshToken`).
- [ ] Add `refresh()` and `getMe()` to `AuthRemoteDatasource` + impl.
- [ ] Implement `AuthRepositoryImpl` (login saves tokens, logout clears tokens, refresh saves new tokens, getCurrentUser calls `/auth/me`).

## 4. Network
- [x] Add `AuthInterceptor` that attaches `Authorization: Bearer <accessToken>` to requests.
- [x] On 401: refresh token, save new tokens, retry original request.
- [x] Use a lock/queue so only one refresh runs when many requests fail at once.
- [x] Use a separate plain Dio for the refresh call (no interceptor loop).
- [x] On refresh failure: clear tokens and go to `/login` (callback, no stream).
- [x] Skip auth header / refresh for `/auth/login` and `/auth/refresh`.

## 5. App-wide auth state
- [ ] Implement `AuthBloc` states: `unknown`, `authenticated(user)`, `unauthenticated`.
- [ ] Add events: `AuthCheckRequested`, `LoggedIn(user)`, `LogoutRequested`, `SessionExpired`.
- [ ] `AuthBloc` listens to interceptor's session-expired stream.
- [ ] Provide `AuthBloc` above `MaterialApp.router`.

## 6. Splash / session restore
- [x] `SplashCubit`: token stored → `/product`, else `/login` (expired token refreshed by interceptor on first request).
- [x] Remove hardcoded `if (false)` and fix both branches going to `/login`.

## 7. Router guard
- [ ] Add `redirect` to `GoRouter` based on `AuthBloc` state.
- [ ] Add `refreshListenable` so router reacts to login/logout.
- [ ] Block `/product` when unauthenticated; redirect `/login` to `/product` when authenticated.

## 8. Login page
- [ ] Obscure password field.
- [ ] Add form validation (use `fromKey`).
- [ ] Show `failure.message` in error snackbar.
- [ ] Use `droppable()` instead of `concurrent()` and disable button while loading.
- [ ] Dispatch `LoggedIn(user)` to `AuthBloc` on success.

## 9. Logout
- [x] Add logout button (product page app bar).
- [x] Logout clears tokens, resets state, navigates to `/login`.

## 10. DI
- [x] Register interceptor, `AuthRepository`, new use cases.
- [x] Remove `LoginBloc` registration (page creates its own).
- [x] Register product deps (service, datasource, repository, use case, `ProductBloc`).

## 11. Tests
- [ ] `AuthRepositoryImpl` tests (login, logout, refresh, errors).
- [ ] `AuthInterceptor` tests (attach header, 401 refresh + retry, refresh fail → logout).
- [ ] `LoginBloc` and `AuthBloc` tests with `bloc_test`.
