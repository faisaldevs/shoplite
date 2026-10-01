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
