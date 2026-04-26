import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../exam/model/exam_models.dart';
import '../../exam/state/exam_state.dart';
import '../controllers/student_exam_controller.dart';
import '../models/exam_student_status.dart';
import '../models/student_exam_session_config.dart';
import '../services/agora_service.dart';

class StudentExamScreen extends ConsumerStatefulWidget {
  const StudentExamScreen({
    super.key,
    required this.config,
  });

  final StudentExamSessionConfig config;

  @override
  ConsumerState<StudentExamScreen> createState() => _StudentExamScreenState();
}

class _StudentExamScreenState extends ConsumerState<StudentExamScreen> {
  late final StudentExamController _controller;
  String? _lastErrorShown;
  bool _audioMuted = false;
  bool _videoMuted = false;
  bool _suppressCloseViolation = false;

  @override
  void initState() {
    super.initState();
    _controller = StudentExamController();
    _controller.addListener(_onControllerChanged);
    unawaited(_controller.start(widget.config));
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    unawaited(_controller.close());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop || _suppressCloseViolation) {
          return;
        }
        unawaited(
          _reportProctoringViolation(
            warning: 'Mode monitoring ditutup saat ujian masih berjalan.',
            value: 100,
          ),
        );
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Student Exam Screen'),
              actions: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: _StatusBadge(status: _controller.status),
                  ),
                ),
              ],
            ),
            body: Column(
              children: <Widget>[
                _buildMetadataCard(context),
                Expanded(
                  child: _buildVideoSection(context),
                ),
                _buildActionBar(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetadataCard(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Firebase Path: ${_controller.firebasePath ?? '-'}'),
          const SizedBox(height: 4),
          Text('Violations: ${_controller.violations}'),
          const SizedBox(height: 4),
          ValueListenableBuilder<AgoraServiceConnectionState>(
            valueListenable: _controller.agoraConnectionState,
            builder: (context, connectionState, _) {
              return Text('Agora Connection: ${connectionState.name}');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection(BuildContext context) {
    final engine = _controller.agoraEngine;
    final channel = _controller.agoraChannel;

    if (engine == null || channel == null || !_controller.isReady) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: engine,
                  canvas: const VideoCanvas(uid: 0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ValueListenableBuilder<Set<int>>(
              valueListenable: _controller.remoteUids,
              builder: (context, remoteUids, _) {
                if (remoteUids.isEmpty) {
                  return Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: const Text('Menunggu pengawas masuk channel...'),
                  );
                }

                return GridView.builder(
                  itemCount: remoteUids.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.2,
                  ),
                  itemBuilder: (context, index) {
                    final remoteUid = remoteUids.elementAt(index);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: engine,
                          canvas: VideoCanvas(uid: remoteUid),
                          connection: RtcConnection(channelId: channel),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: !_controller.isReady || _controller.isFinishing
                    ? null
                    : () async {
                        final nextMuted = !_audioMuted;
                        setState(() {
                          _audioMuted = nextMuted;
                        });
                        await _controller.setMicrophoneMuted(nextMuted);
                        if (nextMuted) {
                          await _reportProctoringViolation(
                            warning:
                                'Mikrofon dimatikan saat monitoring ujian berlangsung.',
                            value: 90,
                          );
                        }
                      },
                child: Text(_audioMuted ? 'Unmute Mic' : 'Mute Mic'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: !_controller.isReady || _controller.isFinishing
                    ? null
                    : () async {
                        final nextMuted = !_videoMuted;
                        setState(() {
                          _videoMuted = nextMuted;
                        });
                        await _controller.setCameraMuted(nextMuted);
                        if (nextMuted) {
                          await _reportProctoringViolation(
                            warning:
                                'Kamera dimatikan saat monitoring ujian berlangsung.',
                            value: 100,
                          );
                        }
                      },
                child: Text(_videoMuted ? 'Show Cam' : 'Hide Cam'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _controller.isFinishing
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        await _controller.finishExam();
                        if (!mounted || !navigator.mounted) {
                          return;
                        }
                        if (_controller.isFinished) {
                          _suppressCloseViolation = true;
                          navigator.pop();
                        }
                      },
                child: _controller.isFinishing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Finish'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }

    final error = _controller.errorMessage;
    if (error == null || error.isEmpty || _lastErrorShown == error) {
      return;
    }
    _lastErrorShown = error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  Future<void> _reportProctoringViolation({
    required String warning,
    required int value,
  }) async {
    final session = ref.read(examSessionProvider);
    if (!session.hasActiveAttempt ||
        session.submitState == SubmitState.submitting) {
      return;
    }

    await ref.read(examSessionProvider.notifier).reportProctoringSignal(
          type: ProctoringEventType.tabSwitch,
          value: value,
          warning: warning,
        );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
  });

  final ExamStudentStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      ExamStudentStatus.active => (
          Colors.green.shade100,
          Colors.green.shade800,
        ),
      ExamStudentStatus.leftApp => (
          Colors.orange.shade100,
          Colors.orange.shade900,
        ),
      ExamStudentStatus.finished => (
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
        ),
      ExamStudentStatus.offline => (
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.value,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
