import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shoplite/features/auth/domain/usecases/is_logged_in.dart';

enum SplashStatus { loading, authenticated, unauthenticated, failure }

class SplashState {
  final SplashStatus status;
  final String? error;
  const SplashState({this.status = SplashStatus.loading, this.error});
}

class SplashCubit extends Cubit<SplashState> {
  SplashCubit(this._isLoggedIn) : super(const SplashState());

  final IsLoggedIn _isLoggedIn;

  Future<void> start() async {
    emit(const SplashState());
    await Future.delayed(const Duration(seconds: 2));
    try {
      if (await _isLoggedIn()) {
        emit(const SplashState(status: SplashStatus.authenticated));
      } else {
        emit(const SplashState(status: SplashStatus.unauthenticated));
      }
    } catch (e) {
      emit(SplashState(status: SplashStatus.failure, error: e.toString()));
    }
  }
}
