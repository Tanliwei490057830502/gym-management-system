// screens/main_app_screen.dart
import 'package:flutter/material.dart';
import 'coach_main_navigation_screen.dart';

class CoachMainScreen extends StatelessWidget {
  const CoachMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 直接返回导航界面
    return const CoachMainNavigationScreen();
  }
}