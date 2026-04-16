import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/state/auth_provider.dart';

String? authRedirect(Ref ref, GoRouterState state) {
  final authState = ref.read(authProvider);
  final isLoginRoute = state.matchedLocation == '/login';

  if (authState.status == AuthStatus.checking) {
    return null;
  }

  if (authState.status == AuthStatus.unauthenticated && !isLoginRoute) {
    return '/login';
  }

  if (authState.status == AuthStatus.authenticated && isLoginRoute) {
    return '/exam';
  }

  return null;
}
