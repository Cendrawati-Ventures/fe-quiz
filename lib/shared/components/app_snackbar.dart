import 'package:flutter/material.dart';

enum AppSnackBarType { info, success, error }

class AppSnackBar {
  const AppSnackBar._();

  static void show(
    BuildContext context, {
    required String message,
    AppSnackBarType type = AppSnackBarType.info,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }

    final scheme = Theme.of(context).colorScheme;
    Color backgroundColor;
    Color foregroundColor;
    IconData icon;

    switch (type) {
      case AppSnackBarType.info:
        backgroundColor = scheme.inverseSurface;
        foregroundColor = scheme.onInverseSurface;
        icon = Icons.info_outline;
        break;
      case AppSnackBarType.success:
        backgroundColor = Colors.green.shade700;
        foregroundColor = Colors.white;
        icon = Icons.check_circle_outline;
        break;
      case AppSnackBarType.error:
        backgroundColor = scheme.error;
        foregroundColor = scheme.onError;
        icon = Icons.error_outline;
        break;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: backgroundColor,
          content: Row(
            children: <Widget>[
              Icon(icon, color: foregroundColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: foregroundColor),
                ),
              ),
            ],
          ),
        ),
      );
  }

  static void info(BuildContext context, String message) {
    show(context, message: message, type: AppSnackBarType.info);
  }

  static void success(BuildContext context, String message) {
    show(context, message: message, type: AppSnackBarType.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, type: AppSnackBarType.error);
  }
}
