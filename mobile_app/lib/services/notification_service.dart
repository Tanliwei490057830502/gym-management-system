// notification_service.dart - 新建这个文件
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

// ✅ 全局后台消息处理函数（必须在顶层）
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🔥 后台消息: ${message.notification?.title}");

  // 在这里可以显示本地通知
  final notifications = FlutterLocalNotificationsPlugin();

  const androidDetails = AndroidNotificationDetails(
    'messages',
    '消息通知',
    channelDescription: '新消息提醒',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  const iosDetails = DarwinNotificationDetails();
  const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

  await notifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    message.notification?.title ?? '新消息',
    message.notification?.body ?? '您有一条新消息',
    details,
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // 初始化通知服务
  Future<void> initialize() async {
    // 1. 设置后台消息处理器
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. 请求通知权限
    await _requestPermissions();

    // 3. 初始化本地通知
    await _initializeLocalNotifications();

    // 4. 获取并保存FCM Token
    await _handleTokenRefresh();

    // 5. 设置消息监听器
    _setupMessageListeners();
  }

  // 请求通知权限
  Future<void> _requestPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('✅ 通知权限状态: ${settings.authorizationStatus}');
  }

  // 初始化本地通知
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);

    // 创建Android通知渠道
    const androidChannel = AndroidNotificationChannel(
      'messages',
      '消息通知',
      description: '推送消息使用的频道',
      importance: Importance.high,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  // 处理Token刷新
  Future<void> _handleTokenRefresh() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 获取FCM Token
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      print('✅ FCM Token: $token');

      final userRef = _firestore.collection('users').doc(user.uid);
      final coachRef = _firestore.collection('coaches').doc(user.uid);

      final userDoc = await userRef.get();
      final coachDoc = await coachRef.get();

      final data = {
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      };

      if (userDoc.exists) {
        await userRef.set(data, SetOptions(merge: true));
        debugPrint('✅ Token saved to users');
      } else if (coachDoc.exists) {
        await coachRef.set(data, SetOptions(merge: true));
        debugPrint('✅ Token saved to coaches');
      } else {
        debugPrint('⚠️ 无法写入 Token：用户和教练文档都不存在');
      }
    }

    // 监听Token变化
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      print('🔄 Token刷新: $newToken');

      final user = _auth.currentUser;
      if (user == null) return;

      final userRef = _firestore.collection('users').doc(user.uid);
      final coachRef = _firestore.collection('coaches').doc(user.uid);

      final userDoc = await userRef.get();
      final coachDoc = await coachRef.get();

      final data = {
        'fcmToken': newToken,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      };

      if (userDoc.exists) {
        await userRef.set(data, SetOptions(merge: true));
      } else if (coachDoc.exists) {
        await coachRef.set(data, SetOptions(merge: true));
      } else {
        debugPrint('⚠️ Token 刷新时未找到用户或教练文档');
      }
    });
  }

  // 设置消息监听器
  void _setupMessageListeners() {
    // 前台消息
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 前台消息: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // 应用被点击打开时的消息
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 点击通知打开应用: ${message.notification?.title}');
      _handleNotificationClick(message);
    });

    // 检查应用启动时的消息
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print('🚀 应用启动消息: ${message.notification?.title}');
        _handleNotificationClick(message);
      }
    });
  }

  // 显示本地通知
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'messages',
      '消息通知',
      channelDescription: '新消息提醒',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Colors.deepPurple,
    );

    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? '新消息',
      message.notification?.body ?? '您有一条新消息',
      details,
      payload: message.data.toString(),
    );
  }

  // 处理通知点击
  void _handleNotificationClick(RemoteMessage message) {
    // 这里可以根据消息内容导航到相应页面
    print('处理通知点击: ${message.data}');
  }

  // 获取当前用户的FCM Token
  Future<String?> getCurrentToken() async {
    return await _firebaseMessaging.getToken();
  }

  // 订阅主题
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }

  // 取消订阅主题
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }
}