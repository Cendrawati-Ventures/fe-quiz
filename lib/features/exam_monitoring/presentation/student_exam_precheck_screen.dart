import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/spacing.dart';
import '../../auth/state/auth_provider.dart';
import '../../exam/state/exam_state.dart';
import '../services/agora_service.dart';
import '../state/student_monitoring_state.dart';

class StudentExamPrecheckScreen extends ConsumerStatefulWidget {
  const StudentExamPrecheckScreen({super.key});

  @override
  ConsumerState<StudentExamPrecheckScreen> createState() =>
      _StudentExamPrecheckScreenState();
}

class _StudentExamPrecheckScreenState
    extends ConsumerState<StudentExamPrecheckScreen> {
  String? _lastEnsuredAttemptId;
  String? _disclosureAcceptedAttemptId;
  String? _lastErrorShown;
  bool _isPreparing = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final sessionState = ref.watch(examSessionProvider);
    final notifier = ref.read(examSessionProvider.notifier);
    final monitoringSession = ref.watch(studentMonitoringSessionProvider);

    if (!sessionState.hasActiveAttempt || sessionState.attempt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pemeriksaan Perangkat')),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('Tidak ada sesi ujian aktif untuk diperiksa.'),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => context.go('/exam'),
                child: const Text('Kembali ke Daftar Ujian'),
              ),
            ],
          ),
        ),
      );
    }

    if (sessionState.monitoringPrecheckConfirmed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        context.go('/exam/session');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final config = resolveStudentMonitoringConfig(
      user: authState.user,
      sessionState: sessionState,
    );

    if (config == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pemeriksaan Perangkat')),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                sessionState.monitoring?.reason ??
                    'Konfigurasi monitoring kamera/mikrofon belum tersedia.',
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Hubungi pengawas/admin jika konfigurasi monitoring belum siap.',
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => context.go('/exam'),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    final hasAcceptedDisclosure =
        _disclosureAcceptedAttemptId == config.sessionId;
    if (!hasAcceptedDisclosure) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Izin Monitoring Ujian'),
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            const _MonitoringDisclosureCard(),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton(
                    onPressed: _isPreparing
                        ? null
                        : () async {
                            final discardError =
                                await notifier.discardAttemptBeforeStart();
                            if (discardError != null) {
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(discardError)),
                              );
                              return;
                            }
                            await monitoringSession.stop(markFinished: false);
                            if (!context.mounted) {
                              return;
                            }
                            context.go('/exam');
                          },
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _isPreparing
                        ? null
                        : () {
                            setState(() {
                              _disclosureAcceptedAttemptId = config.sessionId;
                            });
                          },
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text(
                      'Setuju & Izinkan Kamera/Mikrofon',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    _ensureMonitoringStarted(
      attemptId: config.sessionId,
      onEnsure: () => monitoringSession.ensureStarted(config),
      monitoringSession: monitoringSession,
    );

    final connectionState = monitoringSession.controller.agoraConnectionState;
    final currentConnection = connectionState.value;
    final errorMessage = monitoringSession.errorMessage;
    if (errorMessage != null && errorMessage != _lastErrorShown) {
      _lastErrorShown = errorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      });
    }

    return AnimatedBuilder(
      animation: monitoringSession,
      builder: (context, _) {
        final engine = monitoringSession.controller.agoraEngine;
        final isReady = monitoringSession.isReady;
        final isStarting = monitoringSession.isStarting || _isPreparing;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Cek Kamera & Mikrofon'),
            automaticallyImplyLeading: false,
          ),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              Text(
                'Sebelum mulai ujian, pastikan kamera dan mikrofon aktif. Pengawas akan memantau dari halaman standby.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              _PreviewCard(
                engine: engine,
                ready: isReady,
                starting: isStarting,
              ),
              const SizedBox(height: AppSpacing.md),
              _StatusTile(
                title: 'Koneksi Monitoring',
                value: _connectionLabel(currentConnection),
                ok: currentConnection == AgoraServiceConnectionState.connected,
              ),
              const SizedBox(height: AppSpacing.xs),
              _StatusTile(
                title: 'Kamera & Mikrofon',
                value: isReady
                    ? 'Aktif dan siap dipakai.'
                    : 'Belum siap, sedang memulai perangkat.',
                ok: isReady,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton(
                      onPressed: isStarting
                          ? null
                          : () async {
                              final discardError =
                                  await notifier.discardAttemptBeforeStart();
                              if (discardError != null) {
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(discardError)),
                                );
                                return;
                              }
                              await monitoringSession.stop(markFinished: false);
                              if (!context.mounted) {
                                return;
                              }
                              context.go('/exam');
                            },
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isStarting
                          ? null
                          : () async {
                              setState(() {
                                _lastEnsuredAttemptId = null;
                              });
                            },
                      child: const Text('Cek Ulang'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: isReady
                          ? () async {
                              await notifier.markMonitoringPrecheckConfirmed();
                              if (!context.mounted) {
                                return;
                              }
                              context.go('/exam/session');
                            }
                          : null,
                      child: const Text('Saya Siap, Mulai Ujian'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _ensureMonitoringStarted({
    required String attemptId,
    required Future<void> Function() onEnsure,
    required StudentMonitoringSession monitoringSession,
  }) {
    if (_isPreparing || _lastEnsuredAttemptId == attemptId) {
      return;
    }
    _isPreparing = true;
    _lastEnsuredAttemptId = attemptId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await onEnsure();
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparing = false;
      });
      final error = monitoringSession.errorMessage;
      if (error == null || error.isEmpty || error == _lastErrorShown) {
        return;
      }
      _lastErrorShown = error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    });
  }

  String _connectionLabel(AgoraServiceConnectionState state) {
    switch (state) {
      case AgoraServiceConnectionState.idle:
        return 'Belum terhubung';
      case AgoraServiceConnectionState.connecting:
        return 'Sedang menghubungkan';
      case AgoraServiceConnectionState.connected:
        return 'Terhubung';
      case AgoraServiceConnectionState.reconnecting:
        return 'Menyambung ulang';
      case AgoraServiceConnectionState.disconnected:
        return 'Terputus';
      case AgoraServiceConnectionState.failed:
        return 'Gagal';
    }
  }
}

class _MonitoringDisclosureCard extends StatelessWidget {
  const _MonitoringDisclosureCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.camera_alt_outlined, color: colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Penggunaan kamera, mikrofon, dan data monitoring',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Jika Anda menyetujui dan melanjutkan, selama sesi ujian aplikasi akan:',
            ),
            const SizedBox(height: AppSpacing.sm),
            const _DisclosureItem(
              text:
                  'mengakses kamera dan mengirim video secara real-time kepada pengawas;',
            ),
            const _DisclosureItem(
              text:
                  'mengakses mikrofon, mengirim audio secara real-time, dan merekam potongan audio untuk evaluasi indikasi pelanggaran;',
            ),
            const _DisclosureItem(
              text:
                  'mengirim status perangkat, koneksi, dan kejadian proctoring ke layanan Quiz QTA, Firebase, dan Agora.',
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Data tersebut digunakan untuk memverifikasi peserta, memungkinkan pengawasan, dan menjaga integritas ujian. Akses kamera dan mikrofon hanya digunakan saat monitoring ujian berlangsung.',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Anda dapat memilih Batal. Ujian yang mewajibkan monitoring tidak dapat dilanjutkan tanpa izin kamera dan mikrofon. Informasi selengkapnya tersedia pada Kebijakan Privasi Quiz QTA.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclosureItem extends StatelessWidget {
  const _DisclosureItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(Icons.circle, size: 6),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.engine,
    required this.ready,
    required this.starting,
  });

  final RtcEngine? engine;
  final bool ready;
  final bool starting;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Builder(
          builder: (context) {
            if (engine == null || (!ready && starting)) {
              return const Center(child: CircularProgressIndicator());
            }
            if (engine == null || !ready) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    'Preview kamera belum tersedia. Pastikan izin kamera/mikrofon sudah diberikan.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: engine!,
                canvas: const VideoCanvas(uid: 0),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.title,
    required this.value,
    required this.ok,
  });

  final String title;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        color: color.withValues(alpha: 0.08),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_rounded,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
