import 'package:flutter/material.dart';

class NotificationService {
  static NotificationService? _instance;
  NotificationService._internal();

  static NotificationService get instance {
    _instance ??= NotificationService._internal();
    return _instance!;
  }

  BuildContext? _context;

  void setContext(BuildContext context) {
    _context = context;
  }

  void showJobFileNotification(String message, Color color) {
    if (_context == null) return;

    // Only show job file notifications
    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}