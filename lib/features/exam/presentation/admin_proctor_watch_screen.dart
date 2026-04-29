import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/spacing.dart';
import '../model/exam_models.dart';
import '../../exam_monitoring/controllers/admin_proctor_watch_controller.dart';
import '../../exam_monitoring/services/agora_service.dart';

class AdminProctorWatchScreen extends StatefulWidget {
  const AdminProctorWatchScreen({
    super.key,
    required this.attempt,
  });

  final ActiveMonitoringAttempt attempt;

  @override
  State<AdminProctorWatchScreen> createState() =>
      _AdminProctorWatchScreenState();
}

class _AdminProctorWatchScreenState extends State<AdminProctorWatchScreen> {
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
    if (appId.isEmpty || channel.isEmpty || uid == null || uid < 0) {
      return;
    }

    await _controller.start(
      appId: appId,
      channelName: channel,
      uid: uid,
      token: monitoring.agoraToken,
    );
  }

  Future<void> _retryWatching() async {
    await _controller.close();
    await _startWatching();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final engine = _controller.agoraEngine;
        final connection = _controller.connectionState.value;

        return Scaffold(
          appBar: AppBar(
            title: Text('Pantau ${widget.attempt.student.labelName}'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Ulangi koneksi',
                onPressed: _controller.isStarting ? null : _retryWatching,
                icon: const Icon(Icons.refresh_rounded),
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Center(
                  child: _ConnectionChip(state: connection),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Ujian: ${widget.attempt.subjectName.isEmpty ? '-' : widget.attempt.subjectName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Siswa: ${widget.attempt.student.labelName} (${widget.attempt.student.username})',
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: _buildVideoPanel(engine),
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildDiagnosticPanel(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiagnosticPanel() {
    final monitoring = widget.attempt.monitoring;
    final remoteUidText = _controller.remoteUids.value.isEmpty
        ? '-'
        : _controller.remoteUids.value.join(', ');
    final errorText = _controller.errorMessage?.trim();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Diagnostik Monitoring',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Channel: ${monitoring.agoraChannel ?? '-'}'),
          Text('UID Admin Viewer: ${monitoring.agoraUid ?? '-'}'),
          Text('UID Publisher Siswa: ${monitoring.agoraPublisherUid ?? '-'}'),
          Text('Remote UID Terdeteksi: $remoteUidText'),
          Text(
              'Koneksi: ${_connectionLabel(_controller.connectionState.value)}'),
          Text(
            'Token: ${monitoring.agoraToken == null || monitoring.agoraToken!.isEmpty ? 'Kosong' : 'Ada'}',
          ),
          if (errorText != null && errorText.isNotEmpty)
            Text(
              'Error: $errorText',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPanel(RtcEngine? engine) {
    if (_controller.isStarting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (engine == null || !_controller.isReady) {
      return const Center(
        child: Text('Menunggu ruang kamera siswa siap.'),
      );
    }

    return ValueListenableBuilder<Set<int>>(
      valueListenable: _controller.remoteUids,
      builder: (context, remoteUids, _) {
        if (remoteUids.isEmpty) {
          return Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Belum ada video siswa yang masuk.\nTunggu siswa menyalakan kamera dari halaman precheck.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final expectedUid = widget.attempt.monitoring.agoraPublisherUid;
        final expectedAvailable =
            expectedUid != null && remoteUids.contains(expectedUid);
        final preferredUid =
            expectedAvailable ? expectedUid : remoteUids.first;

        if (expectedUid != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: engine,
                    canvas: VideoCanvas(uid: preferredUid),
                    connection: RtcConnection(
                      channelId: _controller.channelName ?? '',
                    ),
                  ),
                ),
                if (!expectedAvailable)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'UID target $expectedUid belum tampil, menampilkan stream UID $preferredUid.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        return GridView.builder(
          itemCount: remoteUids.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final remoteUid = remoteUids.elementAt(index);
            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: engine,
                  canvas: VideoCanvas(uid: remoteUid),
                  connection: RtcConnection(
                    channelId: _controller.channelName ?? '',
                  ),
                ),
              ),
            );
          },
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
      SnackBar(content: Text(error)),
    );
  }

  String _connectionLabel(AgoraServiceConnectionState state) {
    switch (state) {
      case AgoraServiceConnectionState.connected:
        return 'Terhubung';
      case AgoraServiceConnectionState.connecting:
        return 'Menghubungkan';
      case AgoraServiceConnectionState.reconnecting:
        return 'Sambung ulang';
      case AgoraServiceConnectionState.disconnected:
        return 'Terputus';
      case AgoraServiceConnectionState.failed:
        return 'Gagal';
      case AgoraServiceConnectionState.idle:
        return 'Idle';
    }
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
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
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
        ),
      ),
    );
  }
}
