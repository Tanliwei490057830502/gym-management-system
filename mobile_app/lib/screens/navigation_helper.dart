// lib/utils/navigation_helper.dart
import 'package:flutter/material.dart';
import 'main_navigation_screen.dart';

void goToTab(BuildContext context, int tabIndex) {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (context) => MainNavigationScreen(initialIndex: tabIndex),
    ),
        (route) => false, // 移除所有之前的页面，避免返回按钮跳回旧页
  );
}
