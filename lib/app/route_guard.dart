import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/state/auth_provider.dart';
import '../features/exam/state/exam_state.dart';

String? authRedirect(Ref ref, GoRouterState state) {
  final authState = ref.read(authProvider);
  final sessionState = ref.read(examSessionProvider);
  final path = state.matchedLocation;
  final isPublicRoute = path == '/login' || path == '/privacy-policy';
  final isLoginRoute = path == '/login';
  final isAdminRoute = path.startsWith('/admin');
  final isExamSessionRoute = path.startsWith('/exam/session');
  final isMainExamRoute = path == '/exam/session';
  final isPrecheckRoute = path == '/exam/session/precheck';

  if (authState.status == AuthStatus.checking) {
    return null;
  }

  if (authState.status == AuthStatus.unauthenticated && !isPublicRoute) {
    return '/login';
  }

  if (authState.status == AuthStatus.authenticated && authState.user == null) {
    if (!isLoginRoute) {
      return '/login';
    }
    return null;
  }

  if (authState.status == AuthStatus.authenticated && authState.isAdmin) {
    if (isLoginRoute || !isAdminRoute) {
      return '/admin/dashboard';
    }
    return null;
  }

  if (authState.status == AuthStatus.authenticated && authState.isSiswa) {
    if (!sessionState.hasActiveAttempt &&
        sessionState.submitState == SubmitState.success &&
        isExamSessionRoute) {
      return '/result';
    }

    if (sessionState.hasActiveAttempt) {
      if (!sessionState.monitoringPrecheckConfirmed && !isPrecheckRoute) {
        return '/exam/session/precheck';
      }
      if (sessionState.monitoringPrecheckConfirmed && !isMainExamRoute) {
        return '/exam/session';
      }
    }

    if (isLoginRoute || isAdminRoute) {
      return '/exam';
    }
  }

  return null;
}
