import 'package:flutter_bloc/flutter_bloc.dart';

enum SplashStatus { loading, authenticated, unauthenticated, failure }

class SplashState {
  final SplashStatus status;
  final String? error;
  const SplashState({this.status = SplashStatus.loading, this.error});
}

class SplashCubit extends Cubit<SplashState> {
  SplashCubit() : super(const SplashState());

  // final AuthRepository _authRepository;

  Future<void> start() async {
    emit(const SplashState());
    await Future.delayed(const Duration(seconds: 2));
    try {
      // final isLoggedIn = await _authRepository.isLoggedIn();

      // if (!isLoggedIn) {
      //   emit(const SplashState(status: SplashStatus.unauthenticated));
      //   return;
      // }

      // Optional: load cached/remote data before entering home
      // await _productRepository.loadInitialData();
      if (false) {
        emit(const SplashState(status: SplashStatus.authenticated));
      } else {
        emit(const SplashState(status: SplashStatus.unauthenticated));
      }
    } catch (e) {
      emit(SplashState(status: SplashStatus.failure, error: e.toString()));
    }
  }
}
