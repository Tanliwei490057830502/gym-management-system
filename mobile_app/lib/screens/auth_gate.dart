import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'welcome_screen.dart';
import 'package:gym_app_system/screens/main_navigation_screen.dart' as user_nav;
import 'package:gym_app_system/screens/coach_main_navigation_screen.dart' as coach_nav;

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with TickerProviderStateMixin {
  // 字母动画控制器
  late AnimationController _letterController;
  late AnimationController _bracketController;
  late AnimationController _fadeController;

  // 字母动画
  late Animation<Offset> _lAnimation;
  late Animation<Offset> _tAnimation;
  late Animation<Offset> _cAnimation;

  // 方括号动画
  late Animation<Offset> _leftBracketAnimation;
  late Animation<Offset> _rightBracketAnimation;

  // 整体淡入动画
  late Animation<double> _fadeAnimation;

  bool _showContent = false;

  @override
  void initState() {
    super.initState();

    // 字母动画控制器 (1.2秒)
    _letterController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // 方括号动画控制器 (0.8秒)
    _bracketController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // 淡入动画控制器
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // L字母：从上面到中间
    _lAnimation = Tween<Offset>(
      begin: const Offset(0, -3),  // 从上面3个屏幕高度
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _letterController,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    ));

    // T字母：从下面到中间
    _tAnimation = Tween<Offset>(
      begin: const Offset(0, 3),   // 从下面3个屏幕高度
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _letterController,
      curve: const Interval(0.2, 0.9, curve: Curves.elasticOut),
    ));

    // C字母：从上面到中间
    _cAnimation = Tween<Offset>(
      begin: const Offset(0, -3),  // 从上面3个屏幕高度
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _letterController,
      curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
    ));

    // 左方括号：从左边到中间
    _leftBracketAnimation = Tween<Offset>(
      begin: const Offset(-5, 0),  // 从左边5个屏幕宽度
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bracketController,
      curve: Curves.elasticOut,
    ));

    // 右方括号：从右边到中间
    _rightBracketAnimation = Tween<Offset>(
      begin: const Offset(5, 0),   // 从右边5个屏幕宽度
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bracketController,
      curve: Curves.elasticOut,
    ));

    // 淡入动画
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _startAnimations();
  }

  void _startAnimations() async {
    // 先启动字母动画
    _letterController.forward();

    // 0.5秒后启动方括号动画
    await Future.delayed(const Duration(milliseconds: 500));
    _bracketController.forward();

    // 等字母动画完成后开始淡入其他内容
    await Future.delayed(const Duration(milliseconds: 1000));
    _fadeController.forward();

    // 再等待一段时间后显示实际内容
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _showContent = true;
    });
  }

  @override
  void dispose() {
    _letterController.dispose();
    _bracketController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // 如果还在播放入场动画，显示启动画面
    if (!_showContent) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2C3E50),  // 深蓝灰
                Color(0xFF3498DB),  // 蓝色
                Color(0xFF9B59B6),  // 紫色
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LTC Logo动画
                SizedBox(
                  height: 120,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 左方括号【
                      AnimatedBuilder(
                        animation: _leftBracketAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              _leftBracketAnimation.value.dx * MediaQuery.of(context).size.width,
                              _leftBracketAnimation.value.dy * MediaQuery.of(context).size.height,
                            ),
                            child: Text(
                              '【',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // L字母
                      AnimatedBuilder(
                        animation: _lAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              _lAnimation.value.dx * MediaQuery.of(context).size.width,
                              _lAnimation.value.dy * MediaQuery.of(context).size.height,
                            ),
                            child: Text(
                              'L',
                              style: TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // T字母
                      AnimatedBuilder(
                        animation: _tAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              _tAnimation.value.dx * MediaQuery.of(context).size.width,
                              _tAnimation.value.dy * MediaQuery.of(context).size.height,
                            ),
                            child: Text(
                              'T',
                              style: TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // C字母
                      AnimatedBuilder(
                        animation: _cAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              _cAnimation.value.dx * MediaQuery.of(context).size.width,
                              _cAnimation.value.dy * MediaQuery.of(context).size.height,
                            ),
                            child: Text(
                              'C',
                              style: TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // 右方括号】
                      AnimatedBuilder(
                        animation: _rightBracketAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              _rightBracketAnimation.value.dx * MediaQuery.of(context).size.width,
                              _rightBracketAnimation.value.dy * MediaQuery.of(context).size.height,
                            ),
                            child: Text(
                              '】',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // 副标题淡入动画
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    'Fitness & Training',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                // 加载指示器淡入动画
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Column(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '正在加载...',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 动画播放完毕后，显示原有的认证逻辑
    if (user == null) {
      return const WelcomeScreen(); // 未登录
    }

    // 同时从两个集合取文档
    final usersRef = FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final coachesRef = FirebaseFirestore.instance.collection('coaches').doc(user.uid).get();

    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait([usersRef, coachesRef]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('正在验证用户信息...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('发生错误，请稍后重试')),
          );
        }

        final userDoc = snapshot.data![0];
        final coachDoc = snapshot.data![1];

        if (userDoc.exists) {
          return const user_nav.MainNavigationScreen();
        } else if (coachDoc.exists) {
          return const coach_nav.CoachMainNavigationScreen();
        } else {
          return const WelcomeScreen(); // 没有注册信息
        }
      },
    );
  }
}