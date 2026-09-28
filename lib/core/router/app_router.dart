import 'package:go_router/go_router.dart';
import 'package:shoplite/features/auth/presentation/pages/login_page.dart';
import 'package:shoplite/features/start/splash_page.dart';

class AppRouters {
  static const String splash = '/';
  static const String login = '/login';
}

final router = GoRouter(
  initialLocation: AppRouters.splash,
  routes: [
    GoRoute(
      path: AppRouters.splash,
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: AppRouters.login,
      builder: (context, state) => const LoginPage(),
    ),
  ],
);
