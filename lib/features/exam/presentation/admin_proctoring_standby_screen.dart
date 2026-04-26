import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/components/app_card.dart';
import '../model/exam_models.dart';
import '../state/exam_state.dart';
import 'widgets/admin_layout.dart';

final activeMonitoringAttemptsProvider =
    FutureProvider<List<ActiveMonitoringAttempt>>((ref) async {
  final service = ref.watch(examServiceProvider);
  return service.listActiveMonitoringAttempts();
});

class AdminProctoringStandbyScreen extends ConsumerStatefulWidget {
  const AdminProctoringStandbyScreen({super.key});

  @override
  ConsumerState<AdminProctoringStandbyScreen> createState() =>
      _AdminProctoringStandbyScreenState();
}

class _AdminProctoringStandbyScreenState
    extends ConsumerState<AdminProctoringStandbyScreen> {
  Timer? _refreshTimer;
  bool _standbyConfirmed = false;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    super.dispose();
  }

  void _activateStandby() {
    if (_standbyConfirmed) {
      return;
    }
    setState(() {
      _standbyConfirmed = true;
    });
    ref.invalidate(activeMonitoringAttemptsProvider);
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) {
        return;
      }
      ref.invalidate(activeMonitoringAttemptsProvider);
    });
  }

  Future<void> _refreshNow() async {
    ref.invalidate(activeMonitoringAttemptsProvider);
    await ref.read(activeMonitoringAttemptsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final attemptsAsync = ref.watch(activeMonitoringAttemptsProvider);

    return AdminLayout(
      title: 'Standby Pengawas',
      subtitle: 'Konfirmasi kesiapan pengawas dan pilih siswa untuk dipantau.',
      activeSection: AdminSection.proctoring,
      child: !_standbyConfirmed
          ? _buildStandbyConfirmation(context)
          : RefreshIndicator(
              onRefresh: _refreshNow,
              child: ListView(
                children: <Widget>[
                  _standbyInfoCard(context),
                  const SizedBox(height: AppSpacing.md),
                  attemptsAsync.when(
                    data: (items) {
                      final validItems = items
                          .where((item) => item.remainingSeconds > 0)
                          .toList();
                      if (validItems.isEmpty) {
                        return const AppCard(
                          title: 'Belum ada siswa ujian aktif',
                          subtitle:
                              'Halaman ini akan otomatis memuat ulang setiap 5 detik.',
                        );
                      }

                      return Column(
                        children: validItems.map((item) {
                          final classLabel = item.student.className?.trim();
                          final classText =
                              (classLabel == null || classLabel.isEmpty)
                                  ? '-'
                                  : classLabel;
                          final monitorReady = item.monitoring.enabled &&
                              (item.monitoring.agoraAppId?.trim().isNotEmpty ??
                                  false) &&
                              (item.monitoring.agoraChannel
                                      ?.trim()
                                      .isNotEmpty ??
                                  false) &&
                              item.monitoring.agoraUid != null;

                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: AppCard(
                              title: item.student.labelName,
                              subtitle:
                                  'Username: ${item.student.username} • Kelas: $classText',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Text(
                                    'Ujian: ${item.subjectName.isEmpty ? '-' : item.subjectName}',
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    'Sisa waktu: ${_formatRemaining(item.remainingSeconds)}',
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: monitorReady
                                              ? () {
                                                  context.push(
                                                    '/admin/proctoring/watch',
                                                    extra: item,
                                                  );
                                                }
                                              : null,
                                          child:
                                              const Text('Awasi Kamera Siswa'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!monitorReady) ...<Widget>[
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      item.monitoring.reason ??
                                          'Konfigurasi monitoring siswa belum siap.',
                                      style: TextStyle(
                                        color:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, _) => AppCard(
                      title: 'Data siswa aktif gagal dimuat',
                      subtitle:
                          error is ApiError ? error.message : error.toString(),
                      child: FilledButton(
                        onPressed: _refreshNow,
                        child: const Text('Muat Ulang'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStandbyConfirmation(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: AppCard(
          title: 'Konfirmasi Standby Pengawas',
          subtitle:
              'Tekan tombol standby jika Anda sudah siap mengawasi kamera siswa yang sedang ujian.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Setelah standby aktif, daftar siswa ujian akan otomatis diperbarui dan Anda bisa masuk ke layar pemantauan tiap siswa.',
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _activateStandby,
                icon: const Icon(Icons.verified_user_rounded),
                label: const Text('Saya Standby Mengawasi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _standbyInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.shield_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          const Expanded(
            child: Text(
              'Mode standby aktif. Daftar siswa ujian sedang dipantau realtime.',
            ),
          ),
          TextButton(
            onPressed: _refreshNow,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  String _formatRemaining(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final hh = (safe ~/ 3600).toString().padLeft(2, '0');
    final mm = ((safe % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (safe % 60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}
