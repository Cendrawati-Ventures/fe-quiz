import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/state/auth_provider.dart';
import '../features/exam/presentation/admin_dashboard_screen.dart';
import '../features/exam/presentation/admin_question_management_screen.dart';
import '../features/exam/presentation/admin_result_monitoring_screen.dart';
import '../features/exam/presentation/admin_subject_management_screen.dart';
import '../features/exam/presentation/exam_detail_start_screen.dart';
import '../features/exam/presentation/exam_list_screen.dart';
import '../features/exam/presentation/exam_screen.dart';
import '../features/exam/presentation/result_screen.dart';
import '../features/exam/state/exam_state.dart';
import 'route_guard.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(authProvider.select((value) => value.status));
  ref.watch(authProvider.select((value) => value.user?.role));
  ref.watch(examSessionProvider.select((value) => value.attempt?.status));

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
        name: 'exam-list',
        builder: (context, state) => const ExamListScreen(),
      ),
      GoRoute(
        path: '/exam/:examId/start',
        name: 'exam-start',
        builder: (context, state) {
          final examId = state.pathParameters['examId']!;
          return ExamDetailStartScreen(examId: examId);
        },
      ),
      GoRoute(
        path: '/exam/session',
        name: 'exam-session',
        builder: (context, state) => const ExamScreen(),
      ),
      GoRoute(
        path: '/result',
        name: 'result',
        builder: (context, state) => const ResultScreen(),
      ),
      GoRoute(
        path: '/admin/dashboard',
        name: 'admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/subjects',
        name: 'admin-subjects',
        builder: (context, state) => const AdminSubjectManagementScreen(),
      ),
      GoRoute(
        path: '/admin/questions',
        name: 'admin-questions',
        builder: (context, state) => const AdminQuestionManagementScreen(),
      ),
      GoRoute(
        path: '/admin/results',
        name: 'admin-results',
        builder: (context, state) => const AdminResultMonitoringScreen(),
      ),
    ],
    redirect: (context, state) => authRedirect(ref, state),
  );
});
