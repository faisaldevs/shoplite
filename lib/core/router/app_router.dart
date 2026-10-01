import 'package:go_router/go_router.dart';
import 'package:shoplite/features/auth/presentation/pages/login_page.dart';
import 'package:shoplite/features/product/domain/entities/product_entity.dart';
import 'package:shoplite/features/product/presentation/pages/product_details_screen.dart';
import 'package:shoplite/features/product/presentation/pages/product_page.dart';
import 'package:shoplite/features/start/splash_page.dart';

class AppRouters {
  static const String splash = '/';
  static const String login = '/login';
  static const String product = '/product';
  static const String productDetails = '/product_details/:id';

  static String productDetailsPath(int id) => '/product_details/$id';
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
    GoRoute(
      path: AppRouters.product,
      builder: (context, state) => const ProductPage(),
    ),
    GoRoute(
      path: AppRouters.productDetails,
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        // extra is lost on deep links / app restore; the page reloads by id.
        final initial = state.extra as ProductEntity?;
        return ProductDetailsPage(id: id, initial: initial);
      },
    ),
  ],
);
