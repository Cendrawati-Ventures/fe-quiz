import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/spacing.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/components/app_card.dart';
import '../../exam_monitoring/controllers/admin_proctor_watch_controller.dart';
import '../../exam_monitoring/services/agora_service.dart';
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
  static const String _allClassValue = '__all__';

  Timer? _refreshTimer;
  bool _isTogglingStandby = false;
  String _selectedClassId = _allClassValue;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    super.dispose();
  }

  Future<void> _activateStandby() async {
    if (_isTogglingStandby) {
      return;
    }
    setState(() {
      _isTogglingStandby = true;
    });
    try {
      await ref.read(examServiceProvider).activateProctoringStandby();
      ref.invalidate(proctoringStandbyStatusProvider);
      ref.invalidate(activeMonitoringAttemptsProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Standby pengawas aktif. Siswa bisa mulai ujian.'),
        ),
      );
    } on ApiError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktivasi standby belum berhasil. Coba lagi.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingStandby = false;
        });
      }
    }
  }

  Future<void> _deactivateStandby() async {
    if (_isTogglingStandby) {
      return;
    }
    setState(() {
      _isTogglingStandby = true;
    });
    try {
      await ref.read(examServiceProvider).deactivateProctoringStandby();
      ref.invalidate(proctoringStandbyStatusProvider);
      ref.invalidate(activeMonitoringAttemptsProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Standby pengawas dinonaktifkan.'),
        ),
      );
    } on ApiError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Menonaktifkan standby belum berhasil. Coba lagi.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingStandby = false;
        });
      }
    }
  }

  void _syncRefreshTimer({required bool standbyActive}) {
    if (!standbyActive) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      return;
    }

    if (_refreshTimer != null) {
      return;
    }

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) {
        return;
      }
      ref.invalidate(proctoringStandbyStatusProvider);
      ref.invalidate(activeMonitoringAttemptsProvider);
    });
  }

  Future<void> _refreshNow() async {
    ref.invalidate(proctoringStandbyStatusProvider);
    ref.invalidate(activeMonitoringAttemptsProvider);
    try {
      await ref.read(activeMonitoringAttemptsProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final standbyAsync = ref.watch(proctoringStandbyStatusProvider);
    final standbyActive = standbyAsync.maybeWhen(
      data: (value) => value.isActive,
      orElse: () => false,
    );
    final attemptsAsync = standbyActive
        ? ref.watch(activeMonitoringAttemptsProvider)
        : const AsyncValue<List<ActiveMonitoringAttempt>>.data(
            <ActiveMonitoringAttempt>[],
          );
    _syncRefreshTimer(standbyActive: standbyActive);

    return AdminLayout(
      title: 'Standby Pengawas',
      subtitle: 'Pantau kamera siswa aktif per kelas secara langsung.',
      activeSection: AdminSection.proctoring,
      child: standbyAsync.when(
        data: (standby) {
          if (!standby.isActive) {
            return _buildStandbyConfirmation();
          }

          return RefreshIndicator(
            onRefresh: _refreshNow,
            child: ListView(
              children: <Widget>[
                _standbyInfoCard(context, standby),
                const SizedBox(height: AppSpacing.md),
                attemptsAsync.when(
                  data: (items) => _buildMonitoringWall(context, items),
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
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, _) => AppCard(
          title: 'Status standby gagal dimuat',
          subtitle: error is ApiError ? error.message : error.toString(),
          child: FilledButton(
            onPressed: _refreshNow,
            child: const Text('Muat Ulang'),
          ),
        ),
      ),
    );
  }

  Widget _buildMonitoringWall(
    BuildContext context,
    List<ActiveMonitoringAttempt> items,
  ) {
    final validItems = items.where((item) => item.remainingSeconds > 0).toList()
      ..sort((a, b) {
        final classA = _classLabel(a.student).toLowerCase();
        final classB = _classLabel(b.student).toLowerCase();
        final classCompare = classA.compareTo(classB);
        if (classCompare != 0) {
          return classCompare;
        }
        return a.student.labelName
            .toLowerCase()
            .compareTo(b.student.labelName.toLowerCase());
      });

    final classOptions = _buildClassOptions(validItems);
    final hasSelectedClass =
        classOptions.any((item) => item.id == _selectedClassId);
    final selectedClassId =
        hasSelectedClass ? _selectedClassId : _allClassValue;
    final selectedItems = selectedClassId == _allClassValue
        ? validItems
        : validItems
            .where((item) => (item.student.classId ?? '') == selectedClassId)
            .toList();

    if (validItems.isEmpty) {
      return const AppCard(
        title: 'Belum ada siswa ujian aktif',
        subtitle: 'Halaman ini memuat ulang otomatis setiap 5 detik.',
      );
    }

    return Column(
      children: <Widget>[
        AppCard(
          title: 'Filter Pantauan',
          subtitle:
              'Pilih kelas untuk menampilkan seluruh tampilan siswa yang sedang ujian.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DropdownButtonFormField<String>(
                key: ValueKey<String>(selectedClassId),
                initialValue: selectedClassId,
                decoration: const InputDecoration(
                  labelText: 'Kelas',
                  border: OutlineInputBorder(),
                ),
                items: classOptions
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option.id,
                        child: Text('${option.name} (${option.totalStudents})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null || value == _selectedClassId) {
                    return;
                  }
                  setState(() {
                    _selectedClassId = value;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Total siswa aktif terpilih: ${selectedItems.length}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (selectedItems.isEmpty)
          const AppCard(
            title: 'Tidak ada siswa aktif di kelas ini',
            subtitle: 'Pilih kelas lain atau tunggu siswa memulai ujian.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 1700
                  ? 4
                  : width >= 1200
                      ? 3
                      : width >= 760
                          ? 2
                          : 1;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: selectedItems.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  childAspectRatio: width >= 760 ? 1.12 : 0.92,
                ),
                itemBuilder: (context, index) {
                  final attempt = selectedItems[index];
                  return _StudentMonitoringCard(
                    key: ValueKey(attempt.attemptId),
                    attempt: attempt,
                  );
                },
              );
            },
          ),
      ],
    );
  }

  List<_ClassFilterOption> _buildClassOptions(
      List<ActiveMonitoringAttempt> items) {
    final grouped = <String, _ClassFilterOption>{};
    for (final item in items) {
      final classId = item.student.classId?.trim();
      if (classId == null || classId.isEmpty) {
        continue;
      }
      final className = _classLabel(item.student);
      final existing = grouped[classId];
      if (existing == null) {
        grouped[classId] = _ClassFilterOption(
          id: classId,
          name: className,
          totalStudents: 1,
        );
        continue;
      }
      grouped[classId] =
          existing.copyWith(totalStudents: existing.totalStudents + 1);
    }

    final options = grouped.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return <_ClassFilterOption>[
      _ClassFilterOption(
        id: _allClassValue,
        name: 'Semua Kelas',
        totalStudents: items.length,
      ),
      ...options,
    ];
  }

  Widget _buildStandbyConfirmation() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: AppCard(
          title: 'Konfirmasi Standby Pengawas',
          subtitle:
              'Tekan tombol standby jika Anda siap mengawasi kamera siswa secara realtime.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Selama standby belum aktif, siswa akan ditahan dan belum bisa mulai ujian.',
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _isTogglingStandby ? null : _activateStandby,
                icon: const Icon(Icons.verified_user_rounded),
                label: Text(
                  _isTogglingStandby
                      ? 'Memproses...'
                      : 'Saya Standby Mengawasi',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _standbyInfoCard(
    BuildContext context,
    ProctoringStandbyStatus standbyStatus,
  ) {
    final confirmedAt = standbyStatus.confirmedAt?.toLocal();
    final confirmedAtLabel = confirmedAt == null
        ? '-'
        : '${confirmedAt.day.toString().padLeft(2, '0')}/'
            '${confirmedAt.month.toString().padLeft(2, '0')}/'
            '${confirmedAt.year} '
            '${confirmedAt.hour.toString().padLeft(2, '0')}:'
            '${confirmedAt.minute.toString().padLeft(2, '0')}:'
            '${confirmedAt.second.toString().padLeft(2, '0')}';

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
          Expanded(
            child: Text(
              'Mode standby aktif (konfirmasi: $confirmedAtLabel). Pantauan akan diperbarui otomatis setiap 5 detik.',
            ),
          ),
          TextButton(
            onPressed: _refreshNow,
            child: const Text('Refresh'),
          ),
          const SizedBox(width: AppSpacing.xs),
          OutlinedButton(
            onPressed: _isTogglingStandby ? null : _deactivateStandby,
            child: Text(_isTogglingStandby ? 'Memproses...' : 'Nonaktifkan'),
          ),
        ],
      ),
    );
  }
}

class _StudentMonitoringCard extends StatefulWidget {
  const _StudentMonitoringCard({
    super.key,
    required this.attempt,
  });

  final ActiveMonitoringAttempt attempt;

  @override
  State<_StudentMonitoringCard> createState() => _StudentMonitoringCardState();
}

class _StudentMonitoringCardState extends State<_StudentMonitoringCard> {
  late final AdminProctorWatchController _controller;
  String? _lastErrorShown;

  @override
  void initState() {
    super.initState();
    _controller = AdminProctorWatchController();
    _controller.addListener(_onControllerChanged);
    unawaited(_startWatching());
  }

  @override
  void didUpdateWidget(covariant _StudentMonitoringCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attempt.monitoring.agoraChannel !=
            widget.attempt.monitoring.agoraChannel ||
        oldWidget.attempt.monitoring.agoraUid !=
            widget.attempt.monitoring.agoraUid ||
        oldWidget.attempt.monitoring.agoraAppId !=
            widget.attempt.monitoring.agoraAppId) {
      unawaited(_controller.close());
      unawaited(_startWatching());
      return;
    }

    if (oldWidget.attempt.monitoring.agoraToken !=
        widget.attempt.monitoring.agoraToken) {
      unawaited(_controller.renewToken(widget.attempt.monitoring.agoraToken));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    unawaited(_controller.close());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startWatching() async {
    final monitoring = widget.attempt.monitoring;
    final appId = monitoring.agoraAppId?.trim() ?? '';
    final channel = monitoring.agoraChannel?.trim() ?? '';
    final uid = monitoring.agoraUid;
    if (!_monitorReady(monitoring) || uid == null || uid < 0) {
      return;
    }

    await _controller.start(
      appId: appId,
      channelName: channel,
      uid: uid,
      token: monitoring.agoraToken,
    );
  }

  @override
  Widget build(BuildContext context) {
    final classText = _classLabel(widget.attempt.student);
    final monitoring = widget.attempt.monitoring;
    final monitorReady = _monitorReady(monitoring);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.attempt.student.labelName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.attempt.student.username} | $classText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _ConnectionChip(
                    state: monitorReady
                        ? _controller.connectionState.value
                        : AgoraServiceConnectionState.idle,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Ujian: ${widget.attempt.subjectName.isEmpty ? '-' : widget.attempt.subjectName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Sisa: ${_formatRemaining(widget.attempt.remainingSeconds)}',
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: monitorReady
                    ? _buildVideoPanel(context)
                    : _InfoPanel(
                        message: monitoring.reason ??
                            'Konfigurasi monitoring siswa belum siap.',
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoPanel(BuildContext context) {
    final engine = _controller.agoraEngine;
    if (_controller.isStarting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (engine == null || !_controller.isReady) {
      return const _InfoPanel(
        message: 'Menunggu ruang kamera siswa siap.',
      );
    }

    return ValueListenableBuilder<Set<int>>(
      valueListenable: _controller.remoteUids,
      builder: (context, remoteUids, _) {
        if (remoteUids.isEmpty) {
          return const _InfoPanel(
            message:
                'Belum ada video siswa masuk.\nPastikan siswa menyalakan kamera di halaman precheck.',
          );
        }

        final expectedUid = widget.attempt.monitoring.agoraPublisherUid;
        if (expectedUid != null && !remoteUids.contains(expectedUid)) {
          return _InfoPanel(
            message:
                'Menunggu stream siswa ini.\nStream aktif lain terdeteksi: ${remoteUids.length}.',
          );
        }

        final preferredUid = expectedUid ?? remoteUids.first;
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: engine,
              canvas: VideoCanvas(uid: preferredUid),
              connection: RtcConnection(
                channelId: _controller.channelName ?? '',
              ),
            ),
          ),
        );
      },
    );
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }

    final error = _controller.errorMessage;
    if (error == null || error.isEmpty || error == _lastErrorShown) {
      return;
    }

    _lastErrorShown = error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.attempt.student.labelName}: $error'),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.state});

  final AgoraServiceConnectionState state;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, text) = switch (state) {
      AgoraServiceConnectionState.connected => (
          Colors.green.shade100,
          Colors.green.shade800,
          'Terhubung'
        ),
      AgoraServiceConnectionState.connecting => (
          Colors.orange.shade100,
          Colors.orange.shade900,
          'Menghubungkan'
        ),
      AgoraServiceConnectionState.reconnecting => (
          Colors.orange.shade100,
          Colors.orange.shade900,
          'Sambung Ulang'
        ),
      AgoraServiceConnectionState.failed => (
          Colors.red.shade100,
          Colors.red.shade900,
          'Gagal'
        ),
      AgoraServiceConnectionState.disconnected => (
          Colors.grey.shade300,
          Colors.grey.shade800,
          'Terputus'
        ),
      AgoraServiceConnectionState.idle => (
          Colors.grey.shade300,
          Colors.grey.shade800,
          'Idle'
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: bg,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ClassFilterOption {
  const _ClassFilterOption({
    required this.id,
    required this.name,
    required this.totalStudents,
  });

  final String id;
  final String name;
  final int totalStudents;

  _ClassFilterOption copyWith({
    String? id,
    String? name,
    int? totalStudents,
  }) {
    return _ClassFilterOption(
      id: id ?? this.id,
      name: name ?? this.name,
      totalStudents: totalStudents ?? this.totalStudents,
    );
  }
}

String _classLabel(ActiveMonitoringStudent student) {
  final className = student.className?.trim();
  if (className != null && className.isNotEmpty) {
    return className;
  }
  return 'Tanpa Kelas';
}

String _formatRemaining(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final hh = (safe ~/ 3600).toString().padLeft(2, '0');
  final mm = ((safe % 3600) ~/ 60).toString().padLeft(2, '0');
  final ss = (safe % 60).toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

bool _monitorReady(AttemptMonitoringConfig monitoring) {
  return monitoring.enabled &&
      (monitoring.agoraAppId?.trim().isNotEmpty ?? false) &&
      (monitoring.agoraChannel?.trim().isNotEmpty ?? false) &&
      monitoring.agoraUid != null;
}
