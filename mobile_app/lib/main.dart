import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/displayname_service.dart'; // ✅ 添加新的服务
import 'screens/auth_gate.dart';
import 'screens/welcome_screen.dart';
import 'screens/main_app_screen.dart';
import 'screens/schedule_tab_screen.dart';
import 'screens/analytics_tab_screen.dart';
import 'screens/chat_tab_screen.dart';
import 'screens/purchase_plan_screen.dart';
import 'screens/my_courses.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('🔥 处理后台消息: ${message.messageId}');
  print('📢 标题: ${message.notification?.title}');
  print('💬 内容: ${message.notification?.body}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await MobileAds.instance.initialize();
  await NotificationService().initialize();

  // ✅ 初始化 DisplayName 自动修复服务
  DisplayNameService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget { // ✅ 改回 StatelessWidget，因为服务自己处理
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'LTC Fitness',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,

        // ✅ 全局文字黑色
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Colors.black),
          displayMedium: TextStyle(color: Colors.black),
          headlineLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: Colors.black),
          titleMedium: TextStyle(color: Colors.black),
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black54),
          labelLarge: TextStyle(color: Colors.black),
        ),

        // ✅ 输入框统一风格
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.deepPurple),
            borderRadius: BorderRadius.circular(8),
          ),
          labelStyle: const TextStyle(color: Colors.black),
        ),

        // ✅ 按钮风格
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

        // ✅ AppBar 黑色字体 + 白色背景
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 1,
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      routes: {
        '/purchase_plan': (context) => const PurchasePlanScreen(),
        '/my_courses': (context) => const MyCoursesScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/main') {
          final args = settings.arguments as Map<String, dynamic>?;
          final int initialIndex = args?['initialIndex'] ?? 0;
          return MaterialPageRoute(
            builder: (context) => MainAppScreen(initialIndex: initialIndex),
          );
        }
        return null;
      },
    );
  }
}