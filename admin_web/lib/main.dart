import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

// 屏幕导入
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/charts_screen.dart';

// 服务导入
import 'services/notification_trigger_service.dart';
import 'services/admin_notification_service.dart';
import 'services/coach_service.dart';
import 'services/gym_revenue_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. 初始化Firebase
    await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: "AIzaSyBN48JPJ-NIuBxvc5IfMFZf9evMsYzIKEg",
          authDomain: "gym-app-firebase-79daf.firebaseapp.com",
          projectId: "gym-app-firebase-79daf",
          storageBucket: "gym-app-firebase-79daf.firebasestorage.app",
          messagingSenderId: "780860598498",
          appId: "1:780860598498:web:f955ea17e136375fd416bb",
          measurementId: "G-7H44MZY9CW"
      ),
    );

    if (kDebugMode) {
      print('✅ Firebase initialized successfully');
    }

    // 2. 初始化全局错误处理
    GlobalErrorHandler.setupGlobalErrorHandling();

    // 3. 恢复核心服务初始化（带错误处理）
    await _initializeCoreServices();

  } catch (e) {
    if (kDebugMode) {
      print('❌ Firebase initialization failed: $e');
    }
    // 即使Firebase初始化失败，也要启动应用（降级模式）
  }

  runApp(AppLifecycleManager(child: GymAdminApp()));
}

/// 初始化核心服务（恢复完整版本）
Future<void> _initializeCoreServices() async {
  try {
    if (kDebugMode) {
      print('🚀 Initializing core services...');
    }

    // 使用 Future.wait 但添加超时和错误处理
    await Future.wait([
      _initializeNotificationService(),
      _initializeCoachService(),
    ]).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        if (kDebugMode) {
          print('⚠️ Core services initialization timeout');
        }
        throw TimeoutException('Core services timeout', const Duration(seconds: 15));
      },
    );

    if (kDebugMode) {
      print('🎉 All core services initialized successfully');
    }

  } catch (e) {
    if (kDebugMode) {
      print('❌ Failed to initialize core services: $e');
      print('📱 App will continue with basic functionality');
    }
    // 不要抛出异常，让应用继续运行（降级模式）
  }
}

/// 初始化通知服务（带错误处理）
Future<void> _initializeNotificationService() async {
  try {
    final notificationTriggerService = NotificationTriggerService();
    await notificationTriggerService.initialize();

    if (kDebugMode) {
      print('✅ NotificationTriggerService initialized');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Failed to initialize NotificationTriggerService: $e');
    }
    // 不重新抛出异常，继续初始化其他服务
  }
}

/// 初始化教练服务（带错误处理）
Future<void> _initializeCoachService() async {
  try {
    await CoachService.initialize();

    if (kDebugMode) {
      print('✅ CoachService initialized');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Failed to initialize CoachService: $e');
    }
    // 不重新抛出异常，继续初始化其他服务
  }
}

class GymAdminApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LTC Gym Admin',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // 恢复通知相关的主题配置
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        // 为通知组件添加默认样式
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // 为费用相关页面添加主题配置
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.purple.shade600, width: 2),
          ),
        ),
      ),
      home: AuthWrapper(),
      debugShowCheckedModeBanner: false,
      // 恢复路由配置以支持通知和费用系统导航
      routes: {
        '/main': (context) => MainScreen(),
        '/login': (context) => LoginScreen(),
        '/analytics': (context) => const ChartsScreen(),
      },
      // 处理未知路由
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => AuthWrapper(),
        );
      },
    );
  }
}

/// 修复版 AuthWrapper - 恢复完整服务初始化但避免无限循环
class AuthWrapper extends StatefulWidget {
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitializingUserServices = false;
  bool _hasInitialized = false;
  String? _lastInitializedUserId;
  Future<void>? _initializationFuture; // 🔑 关键：缓存Future避免重复创建

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (kDebugMode) {
          print('🔍 AuthWrapper StreamBuilder triggered');
          print('🔍 Connection state: ${snapshot.connectionState}');
          print('🔍 Has data: ${snapshot.hasData}');
          print('🔍 User: ${snapshot.data?.uid ?? "null"}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing LTC Gym Admin...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;

          // 🔑 关键修复：检查是否需要重新初始化（用户变更或首次初始化）
          if (!_hasInitialized || _lastInitializedUserId != user.uid) {
            if (kDebugMode) {
              print('🔄 Need to initialize services for user: ${user.uid}');
            }

            _lastInitializedUserId = user.uid;
            _hasInitialized = false;

            // 🔑 重要：只创建一次Future，避免无限循环
            _initializationFuture = _initializeUserSpecificServices(user);
          }

          // 🔑 如果已经初始化过且是同一用户，直接返回MainScreen
          if (_hasInitialized && _lastInitializedUserId == user.uid) {
            if (kDebugMode) {
              print('✅ Already initialized, showing MainScreen');
            }
            return MainScreen();
          }

          // 显示初始化界面
          return FutureBuilder<void>(
            future: _initializationFuture, // 🔑 使用缓存的Future
            builder: (context, initSnapshot) {
              if (initSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Setting up admin workspace...'),
                        SizedBox(height: 8),
                        Text(
                          'Loading fee settings and revenue analytics...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // 初始化完成，标记状态并返回主界面
              if (initSnapshot.connectionState == ConnectionState.done) {
                // 使用 addPostFrameCallback 避免在构建过程中调用setState
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_hasInitialized) {
                    setState(() {
                      _hasInitialized = true;
                    });

                    if (kDebugMode) {
                      print('✅ User services initialization completed');
                    }
                  }
                });
              }

              return MainScreen();
            },
          );
        }

        // 用户未登录，重置状态并显示登录界面
        if (kDebugMode) {
          print('👤 No user found, resetting state and showing login');
        }

        _hasInitialized = false;
        _lastInitializedUserId = null;
        _initializationFuture = null;

        return LoginScreen();
      },
    );
  }

  /// 恢复完整的用户特定服务初始化
  Future<void> _initializeUserSpecificServices(User user) async {
    // 防止重复初始化
    if (_isInitializingUserServices) {
      if (kDebugMode) {
        print('⚠️ Initialization already in progress, skipping...');
      }
      return;
    }

    _isInitializingUserServices = true;

    try {
      if (kDebugMode) {
        print('👤 Initializing user-specific services for: ${user.uid}');
      }

      // 并行初始化所有服务以提高性能，但添加超时处理
      await Future.wait([
        _initializeAdminNotifications(user),
        _initializeGymRevenueSystem(user),
        _setUserOnlineStatus(user, true),
        _validateUserPermissions(user),
      ]).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (kDebugMode) {
            print('⚠️ User services initialization timeout, continuing with basic functionality');
          }
          throw TimeoutException('User services initialization timeout', const Duration(seconds: 30));
        },
      );

      if (kDebugMode) {
        print('🎉 All user-specific services initialized successfully');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize user-specific services: $e');
        print('📱 Continuing with basic functionality');
      }
      // 不抛出异常，让用户能够继续使用基本功能
    } finally {
      _isInitializingUserServices = false;
    }
  }

  /// 初始化管理员通知服务
  Future<void> _initializeAdminNotifications(User user) async {
    try {
      final adminNotificationService = AdminNotificationService();
      await adminNotificationService.initializeAdminNotifications();

      if (kDebugMode) {
        print('✅ AdminNotificationService initialized for: ${user.email}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize admin notifications: $e');
      }
      rethrow; // 重新抛出异常以便上层处理
    }
  }

  /// 恢复完整的健身房收入系统初始化
  Future<void> _initializeGymRevenueSystem(User user) async {
    try {
      if (kDebugMode) {
        print('💰 Initializing gym revenue system...');
      }

      // 添加超时控制
      await Future.wait([
        _ensureGymFeeSettings(user),
        _ensureGymInfoDocument(user),
      ]).timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('✅ Gym revenue system initialized');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize gym revenue system: $e');
      }
      rethrow;
    }
  }

  /// 确保费用设置存在
  Future<void> _ensureGymFeeSettings(User user) async {
    try {
      final existingSettings = await GymRevenueService.getGymFeeSettings(user.uid);

      if (existingSettings == null) {
        await GymRevenueService.updateGymFeeSettings(
          gymAdminId: user.uid,
          additionalFee: 0.0,
          feeDescription: 'Default service fee - not configured yet',
        );

        if (kDebugMode) {
          print('✅ Created default gym fee settings');
        }
      } else {
        if (kDebugMode) {
          print('✅ Gym fee settings already exist');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error ensuring gym fee settings: $e');
      }
      rethrow;
    }
  }

  /// 确保健身房信息文档存在
  Future<void> _ensureGymInfoDocument(User user) async {
    try {
      final gymInfoDoc = await FirebaseFirestore.instance
          .collection('gym_info')
          .doc(user.uid)
          .get();

      if (!gymInfoDoc.exists) {
        await FirebaseFirestore.instance
            .collection('gym_info')
            .doc(user.uid)
            .set({
          'name': user.displayName ?? 'My Fitness Center',
          'email': user.email ?? '',
          'phone': '',
          'address': '',
          'description': '',
          'website': '',
          'operatingHours': {},
          'amenities': [],
          'socialMedia': [],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (kDebugMode) {
          print('✅ Created default gym info document');
        }
      } else {
        if (kDebugMode) {
          print('✅ Gym info document already exists');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error ensuring gym info document: $e');
      }
      rethrow;
    }
  }

  /// 设置用户在线状态
  Future<void> _setUserOnlineStatus(User user, bool isOnline) async {
    try {
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .set({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
        'email': user.email,
        'displayName': user.displayName,
        'platform': kIsWeb ? 'web' : 'mobile',
        'userAgent': kIsWeb ? 'web-admin' : 'mobile-admin',
        'hasRevenueAccess': true, // 标记为有收入管理权限
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('✅ User online status set: $isOnline');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to set user online status: $e');
      }
      rethrow;
    }
  }

  /// 验证用户权限
  Future<void> _validateUserPermissions(User user) async {
    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();

      if (!adminDoc.exists) {
        await FirebaseFirestore.instance
            .collection('admins')
            .doc(user.uid)
            .set({
          'email': user.email,
          'displayName': user.displayName,
          'role': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'permissions': {
            'manageCoaches': true,
            'manageAppointments': true,
            'viewAnalytics': true,
            'systemSettings': true,
            'feeManagement': true, // 新增：费用管理权限
            'revenueAnalytics': true, // 新增：收入分析权限
          },
        }, SetOptions(merge: true));

        if (kDebugMode) {
          print('📝 Created new admin record with revenue permissions for: ${user.email}');
        }
      } else {
        // 更新权限（使用merge避免覆盖）
        await FirebaseFirestore.instance
            .collection('admins')
            .doc(user.uid)
            .set({
          'permissions': {
            'feeManagement': true,
            'revenueAnalytics': true,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (kDebugMode) {
          print('✅ User permissions validated with revenue access');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to validate user permissions: $e');
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _cleanupServices();
    super.dispose();
  }

  /// 清理服务资源
  Future<void> _cleanupServices() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // 设置用户离线状态
        await _setUserOnlineStatus(currentUser, false);
      }

      // 清理通知服务
      final adminNotificationService = AdminNotificationService();
      await adminNotificationService.dispose();

      // 清理教练服务
      await CoachService.dispose();

      if (kDebugMode) {
        print('✅ Services cleaned up successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to cleanup services: $e');
      }
    }
  }
}

/// 恢复应用生命周期管理
class AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const AppLifecycleManager({Key? key, required this.child}) : super(key: key);

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _handleAppResumed(currentUser);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _handleAppPaused(currentUser);
        break;
      case AppLifecycleState.detached:
        _handleAppDetached(currentUser);
        break;
      case AppLifecycleState.hidden:
        _handleAppHidden(currentUser);
        break;
    }
  }

  void _handleAppResumed(User user) async {
    try {
      // 应用恢复时，重新设置在线状态并刷新数据
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'lastResumed': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('📱 App resumed - user set online, data may refresh');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to handle app resume: $e');
      }
    }
  }

  void _handleAppPaused(User user) async {
    try {
      // 应用暂停时，保持在线但更新最后活跃时间
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .update({
        'lastSeen': FieldValue.serverTimestamp(),
        'lastPaused': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('📱 App paused - updated last seen');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to handle app pause: $e');
      }
    }
  }

  void _handleAppDetached(User user) async {
    try {
      // 应用完全关闭时，设置离线状态
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
        'lastDetached': FieldValue.serverTimestamp(),
      });

      // 清理通知服务资源
      final adminNotificationService = AdminNotificationService();
      await adminNotificationService.dispose();

      if (kDebugMode) {
        print('📱 App detached - user set offline, services cleaned up');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to handle app detach: $e');
      }
    }
  }

  void _handleAppHidden(User user) async {
    try {
      // 应用隐藏时，更新最后活跃时间
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .update({
        'lastSeen': FieldValue.serverTimestamp(),
        'lastHidden': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('📱 App hidden - updated last seen');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to handle app hidden: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// 全局错误处理
class GlobalErrorHandler {
  static void handleError(Object error, StackTrace? stackTrace) {
    if (kDebugMode) {
      print('🚨 Global Error: $error');
      if (stackTrace != null) {
        print('📍 Stack Trace: $stackTrace');
      }
    }

    // 特别处理费用系统相关的错误
    if (error.toString().contains('gym_revenues') ||
        error.toString().contains('gym_settings') ||
        error.toString().contains('fee')) {
      if (kDebugMode) {
        print('💰 Revenue System Error Detected: $error');
      }
    }

    // 这里可以添加错误报告服务，如Firebase Crashlytics
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }

  static void setupGlobalErrorHandling() {
    // 处理Flutter框架错误
    FlutterError.onError = (FlutterErrorDetails details) {
      handleError(details.exception, details.stack);
    };

    // 处理异步错误
    PlatformDispatcher.instance.onError = (error, stack) {
      handleError(error, stack);
      return true;
    };

    if (kDebugMode) {
      print('✅ Global error handling initialized with revenue system support');
    }
  }
}

/// 应用配置和常量
class AppConfig {
  static const String appName = 'LTC Gym Admin';
  static const String version = '2.0.0'; // 更新版本号以反映新功能

  // 费用系统相关配置
  static const double defaultAdditionalFee = 0.0;
  static const String defaultFeeDescription = 'Service fee';
  static const int maxRevenueHistoryItems = 100;

  // Firebase集合名称
  static const String gymSettingsCollection = 'gym_settings';
  static const String gymRevenuesCollection = 'gym_revenues';
  static const String gymInfoCollection = 'gym_info';
  static const String adminsCollection = 'admins';

  // 路由名称
  static const String mainRoute = '/main';
  static const String loginRoute = '/login';
  static const String adminDashboardRoute = '/admin-dashboard';
  static const String feeSettingsRoute = '/fee-settings';
  static const String analyticsRoute = '/analytics';

  static bool get isDebugMode => kDebugMode;

  /// 获取应用信息字符串
  static String getAppInfo() {
    return '$appName v$version${isDebugMode ? ' (Debug)' : ''}';
  }
}