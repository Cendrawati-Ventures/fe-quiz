import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OutboxQueue {
  static const String _queueKey = 'outbox_queue_v1';

  Future<List<Map<String, dynamic>>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_queueKey) ?? <String>[];
    return rawList
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .toList();
  }

  Future<void> enqueue(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_queueKey) ?? <String>[];
    current.add(jsonEncode(item));
    await prefs.setStringList(_queueKey, current);
  }

  Future<void> removeAt(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_queueKey) ?? <String>[];
    if (index < 0 || index >= current.length) return;
    current.removeAt(index);
    await prefs.setStringList(_queueKey, current);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }
}
