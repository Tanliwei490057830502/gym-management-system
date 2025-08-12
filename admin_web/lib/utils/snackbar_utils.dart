// lib/utils/snackbar_utils.dart
// 用途：通知消息工具类

import 'package:flutter/material.dart';

class SnackbarUtils {
  /// 显示成功消息
  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.green, Icons.check_circle);
  }

  /// 显示错误消息
  static void showError(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.red, Icons.error);
  }

  /// 显示信息消息
  static void showInfo(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.blue, Icons.info);
  }

  /// 显示警告消息
  static void showWarning(BuildContext context, String message) {
    _showSnackBar(context, message, Colors.orange, Icons.warning);
  }

  /// 显示自定义消息
  static void showCustom(
      BuildContext context,
      String message,
      Color color,
      IconData icon, {
        Duration duration = const Duration(seconds: 3),
      }) {
    _showSnackBar(context, message, color, icon, duration: duration);
  }

  /// 显示加载消息
  static void showLoading(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(minutes: 1), // 长时间显示
      ),
    );
  }

  /// 关闭当前显示的SnackBar
  static void dismiss(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// 私有方法：显示SnackBar
  static void _showSnackBar(
      BuildContext context,
      String message,
      Color color,
      IconData icon, {
        Duration duration = const Duration(seconds: 3),
      }) {
    // 先关闭当前显示的SnackBar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: duration,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// 显示确认消息（带有操作按钮）
  static void showConfirmation(
      BuildContext context,
      String message,
      VoidCallback onConfirm, {
        String confirmText = 'Confirm',
        String cancelText = 'Cancel',
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: confirmText,
          textColor: Colors.white,
          onPressed: onConfirm,
        ),
      ),
    );
  }

  /// 显示可撤销的操作消息
  static void showUndoable(
      BuildContext context,
      String message,
      VoidCallback onUndo, {
        String undoText = 'Undo',
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey.shade800,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: undoText,
          textColor: Colors.blue.shade300,
          onPressed: onUndo,
        ),
      ),
    );
  }
}