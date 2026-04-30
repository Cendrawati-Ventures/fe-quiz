import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/state/auth_provider.dart';
import '../features/exam/presentation/admin_dashboard_screen.dart';
import '../features/exam/presentation/admin_proctor_watch_screen.dart';
import '../features/exam/presentation/admin_proctoring_standby_screen.dart';
import '../features/exam/presentation/admin_class_management_screen.dart';
import '../features/exam/presentation/admin_class_student_assignment_screen.dart';
import '../features/exam/presentation/admin_class_subject_assignment_screen.dart';
import '../features/exam/presentation/admin_question_edit_screen.dart';
import '../features/exam/presentation/admin_subject_edit_screen.dart';
import '../features/exam/presentation/admin_question_management_screen.dart';
import '../features/exam/presentation/admin_result_monitoring_screen.dart';
import '../features/exam/presentation/admin_student_account_management_screen.dart';
import '../features/exam/presentation/admin_subject_management_screen.dart';
import '../features/exam/presentation/exam_detail_start_screen.dart';
import '../features/exam/presentation/exam_list_screen.dart';
import '../features/exam/presentation/exam_screen.dart';
import '../features/exam/model/exam_models.dart';
import '../features/exam/presentation/result_screen.dart';
import '../features/exam/state/exam_state.dart';
import '../features/exam_monitoring/presentation/student_exam_precheck_screen.dart';
import '../features/legal/presentation/privacy_policy_screen.dart';
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
        path: '/privacy-policy',
        name: 'privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
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
        path: '/exam/session/precheck',
        name: 'exam-session-precheck',
        builder: (context, state) => const StudentExamPrecheckScreen(),
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
        path: '/admin/classes',
        name: 'admin-classes',
        builder: (context, state) => const AdminClassManagementScreen(),
      ),
      GoRoute(
        path: '/admin/classes/:id/students',
        name: 'admin-class-students',
        builder: (context, state) {
          final classId = state.pathParameters['id']!;
          return AdminClassStudentAssignmentScreen(classId: classId);
        },
      ),
      GoRoute(
        path: '/admin/classes/:id/subjects',
        name: 'admin-class-subjects',
        builder: (context, state) {
          final classId = state.pathParameters['id']!;
          return AdminClassSubjectAssignmentScreen(classId: classId);
        },
      ),
      GoRoute(
        path: '/admin/subjects',
        name: 'admin-subjects',
        builder: (context, state) => const AdminSubjectManagementScreen(),
      ),
      GoRoute(
        path: '/admin/subjects/:id/edit',
        name: 'admin-subject-edit',
        builder: (context, state) {
          final subjectId = state.pathParameters['id']!;
          return AdminSubjectEditScreen(subjectId: subjectId);
        },
      ),
      GoRoute(
        path: '/admin/questions',
        name: 'admin-questions',
        builder: (context, state) {
          final initialSubjectId = state.uri.queryParameters['subjectId'];
          return AdminQuestionManagementScreen(
            initialSubjectId: initialSubjectId,
          );
        },
      ),
      GoRoute(
        path: '/admin/questions/:subjectId/:questionId/edit',
        name: 'admin-question-edit',
        builder: (context, state) {
          final subjectId = state.pathParameters['subjectId']!;
          final questionId = state.pathParameters['questionId']!;
          return AdminQuestionEditScreen(
            subjectId: subjectId,
            questionId: questionId,
          );
        },
      ),
      GoRoute(
        path: '/admin/students',
        name: 'admin-students',
        builder: (context, state) =>
            const AdminStudentAccountManagementScreen(),
      ),
      GoRoute(
        path: '/admin/results',
        name: 'admin-results',
        builder: (context, state) => const AdminResultMonitoringScreen(),
      ),
      GoRoute(
        path: '/admin/proctoring',
        name: 'admin-proctoring',
        builder: (context, state) => const AdminProctoringStandbyScreen(),
      ),
      GoRoute(
        path: '/admin/proctoring/watch',
        name: 'admin-proctoring-watch',
        builder: (context, state) {
          final payload = state.extra;
          if (payload is! ActiveMonitoringAttempt) {
            return const AdminProctoringStandbyScreen();
          }
          return AdminProctorWatchScreen(attempt: payload);
        },
      ),
    ],
    redirect: (context, state) => authRedirect(ref, state),
  );
});
