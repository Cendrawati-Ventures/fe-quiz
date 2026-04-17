import 'package:flutter/material.dart';

class ConnectionChip extends StatelessWidget {
  const ConnectionChip({
    super.key,
    required this.isOnline,
    required this.syncStatus,
  });

  final bool isOnline;
  final String syncStatus;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? Colors.green : Colors.orange;
    final statusText = isOnline ? 'Online' : 'Offline';
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 5),
      label: Text('$statusText • $syncStatus'),
    );
  }
}
