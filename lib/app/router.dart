import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/state/auth_provider.dart';
import '../features/exam/presentation/exam_screen.dart';
import 'route_guard.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(authProvider.select((value) => value.status));

  return GoRouter(
    initialLocation: '/login',
    routes: <GoRoute>[
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/exam',
        name: 'exam',
        builder: (context, state) => const ExamScreen(),
      ),
    ],
    redirect: (context, state) => authRedirect(ref, state),
  );
});
