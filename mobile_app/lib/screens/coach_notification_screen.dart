// screens/coach_notification_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';

class CoachNotificationScreen extends StatefulWidget {
  const CoachNotificationScreen({super.key});

  @override
  State<CoachNotificationScreen> createState() => _CoachNotificationScreenState();
}

class _CoachNotificationScreenState extends State<CoachNotificationScreen> {
  bool _isMounted = true;

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
    _isMounted = false;
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

    const androidChannel = AndroidNotificationChannel(
      'coach_messages',
      'Coach Messages',
      description: 'Notifications for coach messages',
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    Workmanager().initialize(coachCallbackDispatcher, isInDebugMode: false);
  }

  void _setupMessageListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    // Listen for new messages in coach chats
    _firestore.collectionGroup('messages')
        .where('timestamp', isGreaterThan: Timestamp.now())
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          // Check if message is for this coach
          if (data['senderId'] != user.uid &&
              change.doc.reference.parent.parent?.id?.contains('coach_${user.uid}') == true) {
            _showMessageNotification(data);
            _addNotificationToList('New Student Message', data['text'] ?? 'You have a new message');
          }
        }
      }
    });

    // Listen for coach-specific notifications
    _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: user.uid)
        .where('recipientType', isEqualTo: 'coach')
        .where('createdAt', isGreaterThan: Timestamp.now())
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          _showNotification(data);
          _addNotificationToList(
              data['title'] ?? 'Notification',
              data['message'] ?? 'You have a new notification'
          );
        }
      }
    });
  }

  Future<void> _showMessageNotification(Map<String, dynamic> messageData) async {
    const androidDetails = AndroidNotificationDetails(
      'coach_messages',
      'Coach Messages',
      channelDescription: 'New messages from students',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'New Student Message',
      messageData['text'] ?? 'You have a new message',
      details,
    );
  }

  Future<void> _showNotification(Map<String, dynamic> notificationData) async {
    const androidDetails = AndroidNotificationDetails(
      'coach_notifications',
      'Coach Notifications',
      channelDescription: 'General notifications for coaches',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notificationData['title'] ?? 'Notification',
      notificationData['message'] ?? 'You have a new notification',
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
          .collection('coaches')
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
      print('Error loading notifications: $e');
    }
  }

  Future<void> _saveNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore
          .collection('coaches')
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
      print('Error saving notifications: $e');
    }
  }

  Future<void> _loadDailyReminderSetting() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore
          .collection('coaches')
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
      print('Error loading settings: $e');
    }
  }

  Future<void> _saveDailyReminderSetting() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('coaches')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .set({'dailyReminder': _isDailyReminderEnabled});
      await _scheduleDailyReminder();
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  Future<void> _scheduleDailyReminder() async {
    if (_isDailyReminderEnabled) {
      await Workmanager().cancelByUniqueName('coach_daily_reminder');
      await Workmanager().registerPeriodicTask(
        'coach_daily_reminder',
        'coachDailyReminderTask',
        frequency: const Duration(days: 1),
        initialDelay: _getInitialDelay(),
        constraints: Constraints(networkType: NetworkType.not_required),
      );
    } else {
      await Workmanager().cancelByUniqueName('coach_daily_reminder');
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
    print('Notification tapped: ${response.payload}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _clearAllNotifications,
            child: const Text(
              'Clear All',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Daily Reminder Settings
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border(bottom: BorderSide(color: Colors.orange.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: Colors.orange),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily 8AM Reminder',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'Get daily reminders to check on your students',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
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
                  activeColor: Colors.orange,
                ),
              ],
            ),
          ),

          // Notifications List
          Expanded(
            child: _notifications_list.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You\'ll see notifications about appointments,\nstudent activities, and system updates here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications_list.length,
              itemBuilder: (context, index) {
                final notification = _notifications_list[index];
                final isRead = notification['isRead'] ?? false;
                final time = notification['time'] as DateTime;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRead ? Colors.grey.shade200 : Colors.orange.shade200,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getNotificationIcon(notification['type']),
                        color: Colors.orange[700],
                        size: 20,
                      ),
                    ),
                    title: Text(
                      notification['title'] ?? 'Notification',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          notification['content'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatTime(time),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: !isRead
                        ? Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    )
                        : null,
                    onTap: () {
                      if (!isRead) {
                        _markAsRead(notification['id']);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'appointment':
        return Icons.calendar_today;
      case 'student_activity':
        return Icons.person;
      case 'system':
        return Icons.settings;
      case 'message':
        return Icons.message;
      default:
        return Icons.notifications;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} minutes ago';
    if (diff.inDays < 1) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${time.month}/${time.day}';
  }
}

// WorkManager callback for coach notifications
@pragma('vm:entry-point')
void coachCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'coachDailyReminderTask') {
      final notifications = FlutterLocalNotificationsPlugin();
      const androidDetails = AndroidNotificationDetails(
        'coach_daily_reminder',
        'Coach Daily Reminder',
        channelDescription: 'Daily reminders for coaches',
        importance: Importance.high,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
      await notifications.show(
        999,
        'Daily Coach Reminder',
        'Good morning! Check on your students and review today\'s schedule 💪',
        details,
      );
    }
    return Future.value(true);
  });
}