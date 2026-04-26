import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/state/auth_provider.dart';
import '../../exam/state/exam_state.dart';
import '../models/student_exam_session_config.dart';
import 'student_exam_screen.dart';

class StudentExamGateScreen extends ConsumerWidget {
  const StudentExamGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final sessionState = ref.watch(examSessionProvider);
    final user = authState.user;
    final attempt = sessionState.attempt;
    final monitoring = sessionState.monitoring;

    if (authState.status != AuthStatus.authenticated || user == null) {
      return const _MonitoringErrorScreen(
        title: 'Sesi login tidak ditemukan',
        message: 'Silakan login ulang untuk membuka mode monitoring.',
      );
    }

    if (!sessionState.hasActiveAttempt || attempt == null) {
      return const _MonitoringErrorScreen(
        title: 'Sesi ujian tidak aktif',
        message: 'Mulai ujian terlebih dahulu sebelum membuka monitoring.',
      );
    }

    if (monitoring == null) {
      return const _MonitoringErrorScreen(
        title: 'Konfigurasi monitoring belum tersedia',
        message:
            'Response backend belum mengirim konfigurasi monitoring untuk sesi ini.',
      );
    }

    if (!monitoring.enabled) {
      return _MonitoringErrorScreen(
        title: 'Monitoring tidak aktif',
        message: monitoring.reason ??
            'Konfigurasi Agora dari backend belum siap untuk sesi ini.',
      );
    }

    final appId = monitoring.agoraAppId?.trim() ?? '';
    final channel = monitoring.agoraChannel?.trim() ?? '';
    final uid = monitoring.agoraUid ?? -1;

    if (appId.isEmpty || channel.isEmpty || uid < 0) {
      return const _MonitoringErrorScreen(
        title: 'Konfigurasi monitoring tidak valid',
        message:
            'Data Agora (appId/channel/uid) masih kosong atau tidak valid.',
      );
    }

    final config = StudentExamSessionConfig(
      sessionId: attempt.id,
      studentId: user.id,
      studentName: user.effectiveDisplayName,
      agoraAppId: appId,
      agoraChannel: channel,
      agoraUid: uid,
      agoraToken: monitoring.agoraToken,
      firebaseDatabaseUrl: monitoring.firebaseDatabaseUrl,
      device: null,
      initialViolations: 0,
    );

    return StudentExamScreen(config: config);
  }
}

class _MonitoringErrorScreen extends StatelessWidget {
  const _MonitoringErrorScreen({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monitoring')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    context.go('/exam/session');
                  },
                  child: const Text('Kembali ke Ujian'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
