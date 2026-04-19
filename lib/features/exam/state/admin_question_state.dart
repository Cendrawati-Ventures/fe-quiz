import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../model/exam_models.dart';
import 'exam_state.dart';

final questionListBySubjectProvider =
    FutureProvider.family<List<AdminQuestion>, String>((ref, subjectId) async {
  if (subjectId.trim().isEmpty) {
    return const <AdminQuestion>[];
  }
  final service = ref.watch(examServiceProvider);
  return service.listQuestionsBySubject(subjectId);
});

class AdminQuestionActionState {
  const AdminQuestionActionState({
    this.isCreating = false,
    this.isUpdating = false,
    this.isDeleting = false,
    this.isReordering = false,
    this.errorMessage,
  });

  final bool isCreating;
  final bool isUpdating;
  final bool isDeleting;
  final bool isReordering;
  final String? errorMessage;

  AdminQuestionActionState copyWith({
    bool? isCreating,
    bool? isUpdating,
    bool? isDeleting,
    bool? isReordering,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminQuestionActionState(
      isCreating: isCreating ?? this.isCreating,
      isUpdating: isUpdating ?? this.isUpdating,
      isDeleting: isDeleting ?? this.isDeleting,
      isReordering: isReordering ?? this.isReordering,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final adminQuestionActionProvider =
    NotifierProvider<AdminQuestionActionNotifier, AdminQuestionActionState>(
  AdminQuestionActionNotifier.new,
);

class AdminQuestionActionNotifier extends Notifier<AdminQuestionActionState> {
  @override
  AdminQuestionActionState build() {
    return const AdminQuestionActionState();
  }

  Future<AdminQuestion?> create({
    required String subjectId,
    required QuestionType type,
    required String text,
    required num weight,
    required Object options,
    required Object correctAnswer,
    String? imageData,
  }) async {
    state = state.copyWith(isCreating: true, clearError: true);
    try {
      final service = ref.read(examServiceProvider);
      final created = await service.createQuestion(
        subjectId: subjectId,
        type: type,
        text: text,
        weight: weight,
        options: options,
        correctAnswer: correctAnswer,
        imageData: imageData,
      );
      state = state.copyWith(isCreating: false, clearError: true);
      ref.invalidate(questionListBySubjectProvider(subjectId));
      return created;
    } on ApiError catch (error) {
      state = state.copyWith(isCreating: false, errorMessage: error.message);
      return null;
    } catch (_) {
      state = state.copyWith(
        isCreating: false,
        errorMessage: 'Pertanyaan belum berhasil dibuat.',
      );
      return null;
    }
  }

  Future<AdminQuestion?> update({
    required String subjectId,
    required String questionId,
    required QuestionType type,
    required String text,
    required num weight,
    required Object options,
    required Object correctAnswer,
    String? imageData,
  }) async {
    state = state.copyWith(isUpdating: true, clearError: true);
    try {
      final service = ref.read(examServiceProvider);
      final updated = await service.updateQuestion(
        id: questionId,
        type: type,
        text: text,
        weight: weight,
        options: options,
        correctAnswer: correctAnswer,
        imageData: imageData,
      );
      state = state.copyWith(isUpdating: false, clearError: true);
      ref.invalidate(questionListBySubjectProvider(subjectId));
      return updated;
    } on ApiError catch (error) {
      state = state.copyWith(isUpdating: false, errorMessage: error.message);
      return null;
    } catch (_) {
      state = state.copyWith(
        isUpdating: false,
        errorMessage: 'Perubahan pertanyaan belum berhasil disimpan.',
      );
      return null;
    }
  }

  Future<bool> delete({
    required String subjectId,
    required String questionId,
  }) async {
    state = state.copyWith(isDeleting: true, clearError: true);
    try {
      final service = ref.read(examServiceProvider);
      await service.deleteQuestion(questionId);
      state = state.copyWith(isDeleting: false, clearError: true);
      ref.invalidate(questionListBySubjectProvider(subjectId));
      return true;
    } on ApiError catch (error) {
      state = state.copyWith(isDeleting: false, errorMessage: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isDeleting: false,
        errorMessage: 'Pertanyaan belum berhasil dihapus.',
      );
      return false;
    }
  }

  Future<List<AdminQuestion>?> reorder({
    required String subjectId,
    required List<String> orderedQuestionIds,
  }) async {
    state = state.copyWith(isReordering: true, clearError: true);
    try {
      final service = ref.read(examServiceProvider);
      final reordered = await service.reorderQuestions(
        subjectId: subjectId,
        orderedQuestionIds: orderedQuestionIds,
      );
      state = state.copyWith(isReordering: false, clearError: true);
      ref.invalidate(questionListBySubjectProvider(subjectId));
      return reordered;
    } on ApiError catch (error) {
      state = state.copyWith(isReordering: false, errorMessage: error.message);
      return null;
    } catch (_) {
      state = state.copyWith(
        isReordering: false,
        errorMessage: 'Urutan pertanyaan belum berhasil disimpan.',
      );
      return null;
    }
  }
}
