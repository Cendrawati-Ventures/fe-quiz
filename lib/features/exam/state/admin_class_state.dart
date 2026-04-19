import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../model/classroom_models.dart';
import '../service/classroom_service.dart';
import '../service/student_account_service.dart';

class AdminClassActionState {
  const AdminClassActionState({
    this.isCreating = false,
    this.isUpdating = false,
    this.isDeleting = false,
    this.isSavingAssignments = false,
    this.errorMessage,
  });

  final bool isCreating;
  final bool isUpdating;
  final bool isDeleting;
  final bool isSavingAssignments;
  final String? errorMessage;

  AdminClassActionState copyWith({
    bool? isCreating,
    bool? isUpdating,
    bool? isDeleting,
    bool? isSavingAssignments,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminClassActionState(
      isCreating: isCreating ?? this.isCreating,
      isUpdating: isUpdating ?? this.isUpdating,
      isDeleting: isDeleting ?? this.isDeleting,
      isSavingAssignments: isSavingAssignments ?? this.isSavingAssignments,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final adminClassActionProvider =
    NotifierProvider<AdminClassActionNotifier, AdminClassActionState>(
  AdminClassActionNotifier.new,
);

class AdminClassActionNotifier extends Notifier<AdminClassActionState> {
  @override
  AdminClassActionState build() {
    return const AdminClassActionState();
  }

  Future<AdminClassSummary?> createClass(String name) async {
    state = state.copyWith(isCreating: true, clearError: true);
    try {
      final service = ref.read(classroomServiceProvider);
      final created = await service.createClass(name: name);
      state = state.copyWith(isCreating: false, clearError: true);
      ref.invalidate(classListProvider);
      return created;
    } on ApiError catch (error) {
      state = state.copyWith(isCreating: false, errorMessage: error.message);
      return null;
    } catch (_) {
      state = state.copyWith(
        isCreating: false,
        errorMessage: 'Kelas belum berhasil dibuat.',
      );
      return null;
    }
  }

  Future<AdminClassSummary?> updateClass({
    required String classId,
    required String name,
  }) async {
    state = state.copyWith(isUpdating: true, clearError: true);
    try {
      final service = ref.read(classroomServiceProvider);
      final updated = await service.updateClass(classId: classId, name: name);
      state = state.copyWith(isUpdating: false, clearError: true);
      ref.invalidate(classListProvider);
      ref.invalidate(classDetailProvider(classId));
      return updated;
    } on ApiError catch (error) {
      state = state.copyWith(isUpdating: false, errorMessage: error.message);
      return null;
    } catch (_) {
      state = state.copyWith(
        isUpdating: false,
        errorMessage: 'Kelas belum berhasil diperbarui.',
      );
      return null;
    }
  }

  Future<bool> deleteClass(String classId) async {
    state = state.copyWith(isDeleting: true, clearError: true);
    try {
      final service = ref.read(classroomServiceProvider);
      await service.deleteClass(classId);
      state = state.copyWith(isDeleting: false, clearError: true);
      ref.invalidate(classListProvider);
      ref.invalidate(studentAccountsProvider);
      return true;
    } on ApiError catch (error) {
      state = state.copyWith(isDeleting: false, errorMessage: error.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isDeleting: false,
        errorMessage: 'Kelas belum berhasil dihapus.',
      );
      return false;
    }
  }

  Future<AdminClassDetail?> saveAssignments({
    required String classId,
    required List<String> studentIds,
    required List<String> subjectIds,
  }) async {
    state = state.copyWith(isSavingAssignments: true, clearError: true);
    try {
      final service = ref.read(classroomServiceProvider);
      await service.replaceClassStudents(
        classId: classId,
        studentIds: studentIds,
      );
      final detail = await service.replaceClassSubjects(
        classId: classId,
        subjectIds: subjectIds,
      );
      state = state.copyWith(isSavingAssignments: false, clearError: true);
      ref.invalidate(classListProvider);
      ref.invalidate(classDetailProvider(classId));
      ref.invalidate(studentAccountsProvider);
      return detail;
    } on ApiError catch (error) {
      state = state.copyWith(
        isSavingAssignments: false,
        errorMessage: error.message,
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        isSavingAssignments: false,
        errorMessage: 'Pengaturan kelas belum berhasil disimpan.',
      );
      return null;
    }
  }
}
