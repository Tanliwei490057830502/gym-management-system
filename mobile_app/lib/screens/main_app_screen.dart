import 'package:flutter/material.dart';
import 'main_navigation_screen.dart';

class MainAppScreen extends StatelessWidget {
  final int initialIndex;

  const MainAppScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return MainNavigationScreen(initialIndex: initialIndex);
  }
}
