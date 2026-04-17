import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_db.dart';

final outboxQueueProvider = Provider<OutboxQueue>((ref) {
  final localDb = ref.watch(localDbProvider);
  return OutboxQueue(localDb: localDb);
});

enum OutboxItemType { answer, proctoring, submit }

OutboxItemType outboxTypeFromString(String value) {
  switch (value) {
    case 'answer':
      return OutboxItemType.answer;
    case 'proctoring':
      return OutboxItemType.proctoring;
    case 'submit':
      return OutboxItemType.submit;
    default:
      return OutboxItemType.answer;
  }
}

String outboxTypeToString(OutboxItemType value) {
  switch (value) {
    case OutboxItemType.answer:
      return 'answer';
    case OutboxItemType.proctoring:
      return 'proctoring';
    case OutboxItemType.submit:
      return 'submit';
  }
}

class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.type,
    required this.payload,
    required this.retryCount,
    required this.nextRetryAtEpochMs,
    required this.createdAtEpochMs,
  });

  final String id;
  final OutboxItemType type;
  final Map<String, dynamic> payload;
  final int retryCount;
  final int nextRetryAtEpochMs;
  final int createdAtEpochMs;

  factory OutboxItem.fromJson(Map<String, dynamic> json) {
    return OutboxItem(
      id: json['id'] as String,
      type: outboxTypeFromString(json['type'] as String),
      payload:
          (json['payload'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      retryCount: json['retryCount'] as int? ?? 0,
      nextRetryAtEpochMs: json['nextRetryAtEpochMs'] as int? ?? 0,
      createdAtEpochMs: json['createdAtEpochMs'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': outboxTypeToString(type),
      'payload': payload,
      'retryCount': retryCount,
      'nextRetryAtEpochMs': nextRetryAtEpochMs,
      'createdAtEpochMs': createdAtEpochMs,
    };
  }

  OutboxItem copyWith({
    String? id,
    OutboxItemType? type,
    Map<String, dynamic>? payload,
    int? retryCount,
    int? nextRetryAtEpochMs,
    int? createdAtEpochMs,
  }) {
    return OutboxItem(
      id: id ?? this.id,
      type: type ?? this.type,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAtEpochMs: nextRetryAtEpochMs ?? this.nextRetryAtEpochMs,
      createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    );
  }
}

class OutboxQueue {
  OutboxQueue({required AppLocalDb localDb}) : _localDb = localDb;

  static const int _maxBackoffMs = 60000;
  final AppLocalDb _localDb;
  final Random _random = Random();

  Future<List<OutboxItem>> getItems() async {
    final rows = await _localDb.listOutboxRows();
    final items = rows.map(_rowToItem).toList();
    return _sortByPriority(items);
  }

  Future<List<OutboxItem>> getDueItems({DateTime? now}) async {
    final current = now ?? DateTime.now().toUtc();
    final items = await getItems();
    return _sortByPriority(
      items
          .where((item) =>
              item.nextRetryAtEpochMs <= current.millisecondsSinceEpoch)
          .toList(),
    );
  }

  Future<void> enqueueAnswer({
    required String attemptId,
    required String questionId,
    required Object? answer,
  }) async {
    final dedupKey = '$attemptId::$questionId';
    await _upsert(
      type: OutboxItemType.answer,
      payload: <String, dynamic>{
        'attemptId': attemptId,
        'questionId': questionId,
        'answer': answer,
      },
      dedupKey: dedupKey,
    );
  }

  Future<void> enqueueProctoring({
    required String attemptId,
    required String type,
    required int value,
    required String timestamp,
  }) async {
    await _upsert(
      type: OutboxItemType.proctoring,
      payload: <String, dynamic>{
        'attemptId': attemptId,
        'type': type,
        'value': value,
        'timestamp': timestamp,
      },
      dedupKey: null,
    );
  }

  Future<void> enqueueSubmit({required String attemptId}) async {
    await _upsert(
      type: OutboxItemType.submit,
      payload: <String, dynamic>{'attemptId': attemptId},
      dedupKey: attemptId,
    );
  }

  Future<void> markSuccess(String itemId) async {
    await _localDb.deleteOutboxRowById(itemId);
  }

  Future<void> markFailure(String itemId) async {
    OutboxItem? currentItem;
    final current = await getItems();
    for (final item in current) {
      if (item.id == itemId) {
        currentItem = item;
        break;
      }
    }
    if (currentItem == null) {
      return;
    }

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final retryCount = currentItem.retryCount + 1;
    final backoffMs = _computeBackoffMs(retryCount);
    await _localDb.updateOutboxRetry(
      id: itemId,
      retryCount: retryCount,
      nextRetryAtEpochMs: nowMs + backoffMs,
    );
  }

  Future<void> clearByAttempt(String attemptId) async {
    final current = await getItems();
    for (final item in current) {
      if (item.payload['attemptId'] == attemptId) {
        await _localDb.deleteOutboxRowById(item.id);
      }
    }
  }

  Future<void> clear() async {
    await _localDb.clearOutbox();
  }

  Future<void> _upsert({
    required OutboxItemType type,
    required Map<String, dynamic> payload,
    required String? dedupKey,
  }) async {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final id = '$nowMs-${_random.nextInt(1 << 20)}';
    final dedupField = _dedupField(type);
    final typeString = outboxTypeToString(type);
    String? storedDedupKey = dedupKey;
    var payloadToStore = payload;

    if (dedupKey != null && dedupField != null) {
      final row = await _localDb.findOutboxRowByTypeAndDedup(
        type: typeString,
        dedupKey: dedupKey,
      );
      if (row != null) {
        final nextPayload = dedupField == 'attemptQuestionKey'
            ? <String, dynamic>{...payloadToStore, dedupField: dedupKey}
            : payloadToStore;
        await _localDb.updateOutboxRowById(
          id: row['id'] as String,
          payloadJson: jsonEncode(nextPayload),
          retryCount: 0,
          nextRetryAtEpochMs: nowMs,
        );
        return;
      }

      if (dedupField == 'attemptQuestionKey') {
        payloadToStore = <String, dynamic>{
          ...payloadToStore,
          dedupField: dedupKey
        };
      }
      storedDedupKey = dedupKey;
    }

    await _localDb.insertOutboxRow(
      id: id,
      type: typeString,
      dedupKey: storedDedupKey,
      payloadJson: jsonEncode(payloadToStore),
      retryCount: 0,
      nextRetryAtEpochMs: nowMs,
      createdAtEpochMs: nowMs,
    );
  }

  OutboxItem _rowToItem(Map<String, Object?> row) {
    final payloadRaw = row['payload_json'] as String? ?? '{}';
    final payloadDecoded = jsonDecode(payloadRaw);
    final payload = payloadDecoded is Map<String, dynamic>
        ? payloadDecoded
        : <String, dynamic>{};

    return OutboxItem(
      id: row['id'] as String,
      type: outboxTypeFromString(row['type'] as String),
      payload: payload,
      retryCount: (row['retry_count'] as int?) ?? 0,
      nextRetryAtEpochMs: (row['next_retry_at_epoch_ms'] as int?) ?? 0,
      createdAtEpochMs: (row['created_at_epoch_ms'] as int?) ?? 0,
    );
  }

  int _computeBackoffMs(int retryCount) {
    final base = 600;
    final exponent = retryCount.clamp(1, 10);
    final raw = base * (1 << (exponent - 1));
    final jitter = _random.nextInt(300);
    return min(_maxBackoffMs, raw + jitter);
  }

  String? _dedupField(OutboxItemType type) {
    switch (type) {
      case OutboxItemType.answer:
        return 'attemptQuestionKey';
      case OutboxItemType.proctoring:
        return null;
      case OutboxItemType.submit:
        return 'attemptId';
    }
  }

  List<OutboxItem> _sortByPriority(List<OutboxItem> items) {
    final sorted = List<OutboxItem>.from(items);
    sorted.sort((a, b) {
      final typeOrder = _priority(a.type).compareTo(_priority(b.type));
      if (typeOrder != 0) {
        return typeOrder;
      }
      return a.createdAtEpochMs.compareTo(b.createdAtEpochMs);
    });
    return sorted;
  }

  int _priority(OutboxItemType type) {
    switch (type) {
      case OutboxItemType.answer:
        return 0;
      case OutboxItemType.proctoring:
        return 1;
      case OutboxItemType.submit:
        return 2;
    }
  }
}
