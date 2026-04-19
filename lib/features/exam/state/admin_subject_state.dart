import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../model/exam_models.dart';
import 'exam_state.dart';

class AdminSubjectActionState {
  const AdminSubjectActionState({
    this.isCreating = false,
    this.isUpdating = false,
    this.isDeleting = false,
    this.errorMessage,
  });

  final bool isCreating;
  final bool isUpdating;
  final bool isDeleting;
  final String? errorMessage;

  AdminSubjectActionState copyWith({
    bool? isCreating,
    bool? isUpdating,
    bool? isDeleting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminSubjectActionState(
      isCreating: isCreating ?? this.isCreating,
      isUpdating: isUpdating ?? this.isUpdating,
      isDeleting: isDeleting ?? this.isDeleting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final adminSubjectActionProvider =
    NotifierProvider<AdminSubjectActionNotifier, AdminSubjectActionState>(
  AdminSubjectActionNotifier.new,
);

class AdminSubjectActionNotifier extends Notifier<AdminSubjectActionState> {
  @override
  AdminSubjectActionState build() {
    return const AdminSubjectActionState();
  }

  Future<ApiSubject?> quickCreate({
    required String name,
    required String description,
    required int durationMinutes,
  }) async {
    state = state.copyWith(isCreating: true, clearError: true);
    try {
      final service = ref.read(examServiceProvider);
      final created = await service.createSubject(
        name: name,
        description: description,
        durationMinutes: durationMinutes,
        attemptLimit: 1,
        allowReview: false,
      );
      state = state.copyWith(isCreating: false, clearError: true);
      ref.invalidate(subjectListProvider);
      return created;
    } on ApiError catch (error) {
      state = state.copyWith(
        isCreating: false,
        errorMessage: error.message,
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        isCreating: false,
        errorMessage: 'Mata pelajaran belum berhasil dibuat.',
      );
      return null;
    }
  }

  Future<ApiSubject?> update({
    required String id,
    required String name,
    required String description,
    required int durationMinutes,
    required int attemptLimit,
    required bool allowReview,
  }) async {
    state = state.copyWith(isUpdating: true, clearError: true);
    try {
      final service = ref.read(examServiceProvider);
      final updated = await service.updateSubject(
        id: id,
        name: name,
        description: description,
        durationMinutes: durationMinutes,
        attemptLimit: attemptLimit,
        allowReview: allowReview,
      );
      state = state.copyWith(isUpdating: false, clearError: true);
      ref.invalidate(subjectListProvider);
      return updated;
    } on ApiError catch (error) {
      state = state.copyWith(
        isUpdating: false,
        errorMessage: error.message,
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        isUpdating: false,
        errorMessage: 'Perubahan mata pelajaran belum berhasil disimpan.',
      );
      return null;
    }
  }

  Future<bool> delete(String id) async {
    state = state.copyWith(isDeleting: true, clearError: true);
    try {
      final service = ref.read(examServiceProvider);
      await service.deleteSubject(id);
      state = state.copyWith(isDeleting: false, clearError: true);
      ref.invalidate(subjectListProvider);
      return true;
    } on ApiError catch (error) {
      state = state.copyWith(
        isDeleting: false,
        errorMessage: error.message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isDeleting: false,
        errorMessage: 'Mata pelajaran belum berhasil dihapus.',
      );
      return false;
    }
  }
}
