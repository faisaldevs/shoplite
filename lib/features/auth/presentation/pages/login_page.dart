import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shoplite/core/di/di.dart';
import 'package:shoplite/core/router/app_router.dart';
import 'package:shoplite/features/auth/domain/usecases/login.dart';
import 'package:shoplite/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:shoplite/features/auth/presentation/bloc/login/login_event.dart';
import 'package:shoplite/features/auth/presentation/bloc/login/login_state.dart';
import 'package:shoplite/features/auth/presentation/widgets/login_widgets.dart';

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
              CustomTextFieldWidget(
                controller: username,
                labelText: "Enter your username",
              ),
              CustomTextFieldWidget(
                controller: password,
                labelText: "Enter your password",
              ),

              SizedBox(height: 24),

              // Container(
              //   height: 54,
              //   width: double.infinity,
              //   decoration: BoxDecoration(
              //     color: Colors.blueAccent,
              //     borderRadius: BorderRadius.circular(8),
              //   ),
              // ),
              BlocConsumer<LoginBloc, LoginState>(
                listener: (context, state) {
                  if (state.status == LoginStatus.success) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Login Successful")));
                    context.go(AppRouters.product);
                  } else if (state.status == LoginStatus.failure) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Login Failed")));
                  }
                },
                builder: (context, state) {
                  return ElevatedButton(
                    onPressed: () {
                      context.read<LoginBloc>().add(
                        LoginButtonPressed(
                          username: username.text,
                          password: password.text,
                        ),
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
