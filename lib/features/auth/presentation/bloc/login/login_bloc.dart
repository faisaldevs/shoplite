import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shoplite/features/auth/domain/usecases/login.dart';
import 'package:shoplite/features/auth/presentation/bloc/login/login_event.dart';
import 'package:shoplite/features/auth/presentation/bloc/login/login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc(this._login) : super(LoginState(status: LoginStatus.initial)) {
    on<LoginButtonPressed>(eventHandler, transformer: concurrent());
  }

  final Login _login;

  Future<void> eventHandler(
    LoginButtonPressed event,
    Emitter<LoginState> emit,
  ) async {
    emit(state.copyWith(status: LoginStatus.loading));

    // return _login(username: event.username, password: event.password).then((
    //   result,
    // ) {
    //   result.fold(
    //     (failure) => emit(
    //       state.copyWith(status: LoginStatus.failure, error: failure.message),
    //     ),
    //     (_) => emit(state.copyWith(status: LoginStatus.success)),
    //   );
    // });
    final login = await _login(
      username: event.username,
      password: event.password,
    );

    login.fold(
      (failure) => emit(
        state.copyWith(status: LoginStatus.failure, error: failure.message),
      ),
      (_) => emit(state.copyWith(status: LoginStatus.success)),
    );
  }
}
