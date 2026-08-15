import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> confirmExitApp(BuildContext context) async {
  final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Keluar Aplikasi'),
          content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Tidak'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Ya, Keluar'),
            ),
          ],
        ),
      ) ??
      false;

  if (shouldExit) {
    await SystemNavigator.pop();
  }
}
