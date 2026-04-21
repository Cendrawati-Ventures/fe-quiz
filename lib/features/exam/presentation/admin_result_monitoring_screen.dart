import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/spacing.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/components/app_card.dart';
import '../model/exam_models.dart';
import '../state/exam_state.dart';
import 'widgets/admin_layout.dart';

class AdminResultMonitoringScreen extends ConsumerStatefulWidget {
  const AdminResultMonitoringScreen({super.key});

  @override
  ConsumerState<AdminResultMonitoringScreen> createState() =>
      _AdminResultMonitoringScreenState();
}

class _AdminResultMonitoringScreenState
    extends ConsumerState<AdminResultMonitoringScreen> {
  String? _deletingResultId;

  Future<void> _deleteResult(ResultResponse result) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus hasil ujian'),
          content: Text(
            'Hasil ujian untuk peserta "${result.username ?? '-'}" '
            'pada "${result.examTitle ?? 'Ujian'}" akan dihapus permanen.\n\n'
            'Data ini tidak bisa dikembalikan. Lanjutkan?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ya, Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _deletingResultId = result.id;
    });

    final service = ref.read(examServiceProvider);
    try {
      await service.deleteAdminResult(result.id);
      ref.invalidate(adminResultsProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hasil ujian berhasil dihapus.')),
      );
    } on ApiError catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingResultId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(adminResultsProvider);
    return AdminLayout(
      title: 'Pantau Hasil Ujian',
      subtitle: 'Pantau nilai dan tingkat risiko peserta ujian.',
      activeSection: AdminSection.results,
      child: resultsAsync.when(
        data: (results) {
          if (results.isEmpty) {
            return const AppCard(
              title: 'Belum ada hasil',
              subtitle: 'Belum ada hasil ujian yang masuk.',
            );
          }
          return ListView.separated(
            itemCount: results.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final result = results[index];
              final deleting = _deletingResultId == result.id;
              return AppCard(
                title: result.examTitle ?? 'Ujian',
                subtitle:
                    'Peserta: ${result.username ?? '-'}\nNilai: ${result.score}\nRisiko: ${riskLevelLabel(result.riskLevel)}',
                status: result.subjectName,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: deleting ? null : () => _deleteResult(result),
                    icon: deleting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.delete_outline_rounded),
                    label: Text(deleting ? 'Menghapus...' : 'Hapus Hasil'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const AppCard(
          title: 'Gagal memuat hasil',
          subtitle: 'Data hasil belum bisa dimuat. Coba lagi sebentar.',
        ),
      ),
    );
  }
}
