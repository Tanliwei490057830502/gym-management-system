// screens/coach_auth_screen.dart
import 'package:flutter/material.dart';
import 'coach_login_tab.dart';
import 'coach_register_tab.dart';

class CoachAuthScreen extends StatefulWidget {
  const CoachAuthScreen({super.key});

  @override
  State<CoachAuthScreen> createState() => _CoachAuthScreenState();
}

class _CoachAuthScreenState extends State<CoachAuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange,
      body: Column(
        children: [
          // Tab bar
          Container(
            color: Colors.orange,
            child: SafeArea(
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Login'),
                  Tab(text: 'Register'),
                ],
              ),
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                CoachLoginTab(),
                CoachRegisterTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}