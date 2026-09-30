import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shoplite/core/di/di.dart';
import 'package:shoplite/core/router/app_router.dart';
import 'package:shoplite/features/auth/domain/usecases/is_logged_in.dart';
import 'package:shoplite/features/start/cubit/splash_cubit.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SplashCubit(sl<IsLoggedIn>())..start(),
      child: const SplashPageView(),
    );
  }
}

class SplashPageView extends StatelessWidget {
  const SplashPageView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SplashCubit, SplashState>(
      listener: (context, state) {
        if (state.status == SplashStatus.loading) return;
        if (state.status == SplashStatus.authenticated) {
          context.go(AppRouters.product);
        } else {
          context.go(AppRouters.login);
        }
      },
      child: Container(
        height: double.infinity,
        width: double.infinity,
        color: Colors.white,
      ),
    );
  }
}
