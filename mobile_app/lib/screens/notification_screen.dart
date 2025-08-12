import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _isMounted = true; // ← 添加

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  List<Map<String, dynamic>> _notifications_list = [];
  bool _isDailyReminderEnabled = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadNotifications();
    _loadDailyReminderSetting();
    _setupMessageListener();
  }

  @override
  void dispose() {
    _isMounted = false; // ← 设置已销毁标志
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    await Permission.notification.request();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 🔔 注册 Android 通知频道（杀死 App 后才能显示）
    const androidChannel = AndroidNotificationChannel(
      'messages', // 👈 必须和服务器端一样
      '消息通知',
      description: '推送消息使用的频道',
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }


  void _setupMessageListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    _firestore.collectionGroup('messages')
        .where('timestamp', isGreaterThan: Timestamp.now())
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          if (data['senderId'] != user.uid) {
            _showMessageNotification(data);
            _addNotificationToList('新消息', data['text'] ?? '收到一条新消息');
          }
        }
      }
    });
  }

  Future<void> _showMessageNotification(Map<String, dynamic> messageData) async {
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

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '新消息',
      messageData['text'] ?? '收到一条新消息',
      details,
    );
  }

  void _addNotificationToList(String title, String content) {
    if (!_isMounted) return;
    setState(() {
      _notifications_list.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': title,
        'content': content,
        'time': DateTime.now(),
        'isRead': false,
      });
    });
    _saveNotifications();
  }

  Future<void> _loadNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc('list')
          .get();

      if (doc.exists && _isMounted) {
        final data = doc.data()!;
        setState(() {
          _notifications_list = List<Map<String, dynamic>>.from(
            data['notifications']?.map((item) => {
              ...Map<String, dynamic>.from(item),
              'time': (item['time'] as Timestamp).toDate(),
            }) ?? [],
          );
        });
      }
    } catch (e) {
      print('加载通知失败: $e');
    }
  }

  Future<void> _saveNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc('list')
          .set({
        'notifications': _notifications_list.map((item) => {
          ...item,
          'time': Timestamp.fromDate(item['time']),
        }).toList(),
      });
    } catch (e) {
      print('保存通知失败: $e');
    }
  }

  Future<void> _loadDailyReminderSetting() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .get();

      if (doc.exists && _isMounted) {
        setState(() {
          _isDailyReminderEnabled = doc.data()?['dailyReminder'] ?? false;
        });
      }
    } catch (e) {
      print('加载设置失败: $e');
    }
  }

  Future<void> _saveDailyReminderSetting() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .set({'dailyReminder': _isDailyReminderEnabled});
      await _scheduleDailyReminder();
    } catch (e) {
      print('保存设置失败: $e');
    }
  }

  Future<void> _scheduleDailyReminder() async {
    if (_isDailyReminderEnabled) {
      await Workmanager().cancelByUniqueName('daily_reminder');
      await Workmanager().registerPeriodicTask(
        'daily_reminder',
        'dailyReminderTask',
        frequency: const Duration(days: 1),
        initialDelay: _getInitialDelay(),
        constraints: Constraints(networkType: NetworkType.not_required),
      );
    } else {
      await Workmanager().cancelByUniqueName('daily_reminder');
    }
  }

  Duration _getInitialDelay() {
    final now = DateTime.now();
    var next8AM = DateTime(now.year, now.month, now.day, 8, 0);
    if (now.isAfter(next8AM)) {
      next8AM = next8AM.add(const Duration(days: 1));
    }
    return next8AM.difference(now);
  }

  void _markAsRead(String id) {
    if (!_isMounted) return;
    setState(() {
      final index = _notifications_list.indexWhere((item) => item['id'] == id);
      if (index != -1) {
        _notifications_list[index]['isRead'] = true;
      }
    });
    _saveNotifications();
  }

  void _clearAllNotifications() {
    if (!_isMounted) return;
    setState(() {
      _notifications_list.clear();
    });
    _saveNotifications();
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('通知点击: ${response.payload}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知中心', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all, color: Colors.black),
            onPressed: _clearAllNotifications,
          ),
        ],
      ),
      body: Column(
        children: [
          // 设置开关区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: Colors.deepPurple),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('每日8点提醒',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('开启后每天8点会收到计划提醒',
                          style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                Switch(
                  value: _isDailyReminderEnabled,
                  onChanged: (value) {
                    if (!_isMounted) return;
                    setState(() {
                      _isDailyReminderEnabled = value;
                    });
                    _saveDailyReminderSetting();
                  },
                  activeColor: Colors.deepPurple,
                ),
              ],
            ),
          ),

          // 通知列表
          Expanded(
            child: _notifications_list.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无通知', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _notifications_list.length,
              itemBuilder: (context, index) {
                final notification = _notifications_list[index];
                final isRead = notification['isRead'] ?? false;
                final time = notification['time'] as DateTime;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isRead ? Colors.grey : Colors.deepPurple,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(notification['title'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        )),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notification['content'] ?? ''),
                        const SizedBox(height: 4),
                        Text(_formatTime(time), style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    onTap: () {
                      if (!isRead) {
                        _markAsRead(notification['id']);
                      }
                    },
                    trailing: !isRead
                        ? const Icon(Icons.circle, color: Colors.deepPurple, size: 8)
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}月${time.day}日';
  }
}

// 顶层函数：WorkManager 回调
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'dailyReminderTask') {
      final notifications = FlutterLocalNotificationsPlugin();
      const androidDetails = AndroidNotificationDetails(
        'daily_reminder',
        '每日提醒',
        channelDescription: '每天8点的计划提醒',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      await notifications.show(
        999,
        '计划提醒',
        '新的一天开始了！快来查看今天的计划吧 ✨',
        details,
      );
    }
    return Future.value(true);
  });
}
