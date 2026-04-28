import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_preferences.dart';
import '../service/classroom_service.dart';

final studentSelectedClassIdProvider =
    NotifierProvider<StudentSelectedClassIdNotifier, String?>(
  StudentSelectedClassIdNotifier.new,
);

final effectiveStudentClassIdProvider = Provider<String?>((ref) {
  final selectedClassId = ref.watch(studentSelectedClassIdProvider);
  final classOptions = ref.watch(myClassOptionsProvider).maybeWhen(
        data: (items) => items,
        orElse: () => const [],
      );

  if (classOptions.isEmpty) {
    return null;
  }

  final normalizedSelected = selectedClassId?.trim();
  if (normalizedSelected != null &&
      normalizedSelected.isNotEmpty &&
      classOptions.any((item) => item.id == normalizedSelected)) {
    return normalizedSelected;
  }

  return classOptions.first.id;
});

class StudentSelectedClassIdNotifier extends Notifier<String?> {
  static const String _preferenceKey = 'student_selected_class_id_v1';

  late final AppPreferences _preferences;

  @override
  String? build() {
    _preferences = ref.read(appPreferencesProvider);
    unawaited(_restore());
    return null;
  }

  Future<void> setSelectedClassId(String? classId) async {
    final normalized = classId?.trim();
    if (normalized == null || normalized.isEmpty) {
      await clear();
      return;
    }

    state = normalized;
    await _preferences.setString(_preferenceKey, normalized);
  }

  Future<void> clear() async {
    state = null;
    await _preferences.remove(_preferenceKey);
  }

  Future<void> _restore() async {
    final stored = await _preferences.getString(_preferenceKey);
    if (!ref.mounted) {
      return;
    }
    final normalized = stored?.trim();
    state = (normalized == null || normalized.isEmpty) ? null : normalized;
  }
}
