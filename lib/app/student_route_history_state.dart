import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/app_preferences.dart';

final studentRouteHistoryProvider =
    NotifierProvider<StudentRouteHistoryNotifier, List<String>>(
  StudentRouteHistoryNotifier.new,
);

class StudentRouteHistoryNotifier extends Notifier<List<String>> {
  static const String _preferenceKey = 'student_route_history_v1';
  static const int _maxHistorySize = 40;

  late final AppPreferences _preferences;

  @override
  List<String> build() {
    _preferences = ref.read(appPreferencesProvider);
    unawaited(_restore());
    return const <String>[];
  }

  Future<void> recordVisit(String routePath) async {
    final normalized = _normalizeRoute(routePath);
    if (normalized == null) {
      return;
    }

    final next = List<String>.from(state);
    if (next.isNotEmpty && next.last == normalized) {
      return;
    }

    next.add(normalized);
    if (next.length > _maxHistorySize) {
      next.removeRange(0, next.length - _maxHistorySize);
    }
    state = next;
    await _persist();
  }

  Future<String?> popPreviousRoute({required String currentRoute}) async {
    final normalizedCurrent = _normalizeRoute(currentRoute);
    if (normalizedCurrent == null) {
      return null;
    }

    final next = List<String>.from(state);
    if (next.isEmpty) {
      return null;
    }

    if (next.last != normalizedCurrent) {
      next.add(normalizedCurrent);
    }

    while (next.isNotEmpty && next.last == normalizedCurrent) {
      next.removeLast();
    }

    if (next.isEmpty) {
      state = <String>[normalizedCurrent];
      await _persist();
      return null;
    }

    state = next;
    await _persist();
    return next.last;
  }

  Future<void> clear() async {
    state = const <String>[];
    await _preferences.remove(_preferenceKey);
  }

  String? _normalizeRoute(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (!trimmed.startsWith('/')) {
      return null;
    }
    if (trimmed.startsWith('/admin') || trimmed == '/login') {
      return null;
    }
    return trimmed;
  }

  Future<void> _restore() async {
    final raw = await _preferences.getString(_preferenceKey);
    if (raw == null || raw.trim().isEmpty || !ref.mounted) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        final restored = decoded
            .map((item) => item.toString().trim())
            .where((item) => _normalizeRoute(item) != null)
            .toList();
        if (!ref.mounted) {
          return;
        }
        state = restored;
      }
    } catch (_) {
      if (!ref.mounted) {
        return;
      }
      await _preferences.remove(_preferenceKey);
      state = const <String>[];
    }
  }

  Future<void> _persist() {
    return _preferences.setString(_preferenceKey, jsonEncode(state));
  }
}
