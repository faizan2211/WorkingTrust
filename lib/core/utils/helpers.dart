import 'package:flutter/material.dart';

class Helpers {
  Helpers._();

  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<bool> confirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = 'OK',
    String cancelText = 'Cancel',
    bool showCancel = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          if (showCancel)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelText),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static void hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
}
