// lib/services/admin_notification_service.dart
// 用途：管理员Web端专用通知服务 - 接收来自App端的请求

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import 'dart:async';
export '../models/notification_models.dart';

class AdminNotificationService {
  static final AdminNotificationService _instance = AdminNotificationService._internal();
  factory AdminNotificationService() => _instance;
  AdminNotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 通知回调函数
  Function(AppNotificationData)? _onNewAppointment;
  Function(AppNotificationData)? _onNewBindingRequest;
  Function(AppNotificationData)? _onAppointmentUpdate;
  Function(AppNotificationData)? _onBindingRequestUpdate;

  // 流订阅
  List<StreamSubscription> _subscriptions = [];

  // 通知计数器
  int _pendingAppointments = 0;
  int _pendingBindingRequests = 0;

  // 获取管理员UID
  String? get adminUid => _auth.currentUser?.uid;

  // 初始化管理员通知服务
  Future<void> initializeAdminNotifications() async {
    if (adminUid == null) {
      if (kDebugMode) {
        print('❌ 管理员未登录，无法初始化通知服务');
      }
      return;
    }

    try {
      // 1. 设置管理员在线状态
      await _setAdminOnlineStatus(true);

      // 2. 监听新预约请求
      _listenToNewAppointments();

      // 3. 监听新绑定请求
      _listenToNewBindingRequests();

      // 4. 监听预约状态变化
      _listenToAppointmentUpdates();

      // 5. 监听绑定请求状态变化
      _listenToBindingRequestUpdates();

      // 6. 初始化未读计数
      await _updateNotificationCounts();

      if (kDebugMode) {
        print('✅ 管理员通知服务初始化完成');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 管理员通知服务初始化失败: $e');
      }
    }
  }

  // 设置管理员在线状态
  Future<void> _setAdminOnlineStatus(bool isOnline) async {
    if (adminUid == null) return;

    try {
      await _firestore.collection('admins').doc(adminUid).set({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : 'app',
      }, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        print('❌ 设置在线状态失败: $e');
      }
    }
  }

  // 监听新预约请求（来自App端用户）
  void _listenToNewAppointments() {
    final subscription = _firestore
        .collection('appointments')
        .where('overallStatus', isEqualTo: 'pending')
        .where('adminApproval', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final appointment = Appointment.fromFirestore(change.doc);

          final notificationData = AppNotificationData(
            id: appointment.id,
            type: NotificationType.newAppointment,
            title: 'New Appointment Request',
            message: '${appointment.userName} requested appointment with ${appointment.coachName}',
            data: {
              'appointmentId': appointment.id,
              'userId': appointment.userId,
              'userName': appointment.userName,
              'coachName': appointment.coachName,
              'gymName': appointment.gymName,
              'date': appointment.date.toIso8601String(),
              'timeSlot': appointment.timeSlot,
            },
            timestamp: DateTime.now(),
            isRead: false,
            source: NotificationSource.userApp,
          );

          _onNewAppointment?.call(notificationData);
          _saveNotificationToHistory(notificationData);
          _updateNotificationCounts();

          if (kDebugMode) {
            print('📱 新预约请求: ${appointment.userName} -> ${appointment.coachName}');
          }
        }
      }
    });

    _subscriptions.add(subscription);
  }

  // 监听新绑定请求（来自App端教练）
  void _listenToNewBindingRequests() {
    final subscription = _firestore
        .collection('binding_requests')
        .where('status', isEqualTo: 'pending')
        .where('targetAdminUid', isEqualTo: adminUid)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final request = BindingRequest.fromFirestore(change.doc);

          final notificationData = AppNotificationData(
            id: request.id,
            type: request.isBindRequest
                ? NotificationType.newBindingRequest
                : NotificationType.newUnbindingRequest,
            title: '${request.typeDisplayText} Request',
            message: '${request.coachName} wants to ${request.type} ${request.gymName}',
            data: {
              'requestId': request.id,
              'coachId': request.coachId,
              'coachName': request.coachName,
              'coachEmail': request.coachEmail,
              'gymId': request.gymId,
              'gymName': request.gymName,
              'type': request.type,
              'message': request.message,
            },
            timestamp: DateTime.now(),
            isRead: false,
            source: NotificationSource.coachApp,
          );

          _onNewBindingRequest?.call(notificationData);
          _saveNotificationToHistory(notificationData);
          _updateNotificationCounts();

          if (kDebugMode) {
            print('🏃‍♂️ 新绑定请求: ${request.coachName} -> ${request.gymName}');
          }
        }
      }
    });

    _subscriptions.add(subscription);
  }

  // 监听预约状态变化
  void _listenToAppointmentUpdates() {
    final subscription = _firestore
        .collection('appointments')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final appointment = Appointment.fromFirestore(change.doc);

          // 只处理涉及管理员的状态变化
          if (appointment.adminApproval != 'pending') {
            final notificationData = AppNotificationData(
              id: '${appointment.id}_update',
              type: NotificationType.appointmentUpdate,
              title: 'Appointment Status Updated',
              message: 'Appointment with ${appointment.coachName} is now ${appointment.statusDisplayText}',
              data: {
                'appointmentId': appointment.id,
                'status': appointment.overallStatus,
                'adminApproval': appointment.adminApproval,
                'coachApproval': appointment.coachApproval,
              },
              timestamp: DateTime.now(),
              isRead: false,
              source: NotificationSource.system,
            );

            _onAppointmentUpdate?.call(notificationData);
            _updateNotificationCounts();
          }
        }
      }
    });

    _subscriptions.add(subscription);
  }

  // 监听绑定请求状态变化
  void _listenToBindingRequestUpdates() {
    final subscription = _firestore
        .collection('binding_requests')
        .where('targetAdminUid', isEqualTo: adminUid)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final request = BindingRequest.fromFirestore(change.doc);

          if (request.status != 'pending') {
            final notificationData = AppNotificationData(
              id: '${request.id}_update',
              type: NotificationType.bindingRequestUpdate,
              title: 'Binding Request ${request.statusDisplayText}',
              message: '${request.coachName}\'s ${request.type} request has been ${request.status}',
              data: {
                'requestId': request.id,
                'status': request.status,
                'coachName': request.coachName,
                'gymName': request.gymName,
                'type': request.type,
              },
              timestamp: DateTime.now(),
              isRead: false,
              source: NotificationSource.system,
            );

            _onBindingRequestUpdate?.call(notificationData);
            _updateNotificationCounts();
          }
        }
      }
    });

    _subscriptions.add(subscription);
  }

  // 保存通知到历史记录
  Future<void> _saveNotificationToHistory(AppNotificationData notification) async {
    if (adminUid == null) return;

    try {
      await _firestore
          .collection('admins')
          .doc(adminUid)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap());
    } catch (e) {
      if (kDebugMode) {
        print('❌ 保存通知历史失败: $e');
      }
    }
  }

  // 更新通知计数
  Future<void> _updateNotificationCounts() async {
    try {
      // 统计待处理的预约
      final appointmentsSnapshot = await _firestore
          .collection('appointments')
          .where('overallStatus', isEqualTo: 'pending')
          .where('adminApproval', isEqualTo: 'pending')
          .get();

      // 统计待处理的绑定请求
      final requestsSnapshot = await _firestore
          .collection('binding_requests')
          .where('status', isEqualTo: 'pending')
          .where('targetAdminUid', isEqualTo: adminUid)
          .get();

      _pendingAppointments = appointmentsSnapshot.docs.length;
      _pendingBindingRequests = requestsSnapshot.docs.length;

      if (kDebugMode) {
        print('📊 通知计数更新 - 预约: $_pendingAppointments, 绑定: $_pendingBindingRequests');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 更新通知计数失败: $e');
      }
    }
  }

  // 设置回调函数
  void setNewAppointmentCallback(Function(AppNotificationData) callback) {
    _onNewAppointment = callback;
  }

  void setNewBindingRequestCallback(Function(AppNotificationData) callback) {
    _onNewBindingRequest = callback;
  }

  void setAppointmentUpdateCallback(Function(AppNotificationData) callback) {
    _onAppointmentUpdate = callback;
  }

  void setBindingRequestUpdateCallback(Function(AppNotificationData) callback) {
    _onBindingRequestUpdate = callback;
  }

  // 标记通知为已读
  Future<void> markNotificationAsRead(String notificationId) async {
    if (adminUid == null) return;

    try {
      await _firestore
          .collection('admins')
          .doc(adminUid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
    } catch (e) {
      if (kDebugMode) {
        print('❌ 标记通知已读失败: $e');
      }
    }
  }

  // 获取通知历史
  Stream<List<AppNotificationData>> getNotificationHistory() {
    if (adminUid == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('admins')
        .doc(adminUid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => AppNotificationData.fromFirestore(doc))
        .toList());
  }

  // 获取未读通知数量
  int get pendingAppointmentsCount => _pendingAppointments;
  int get pendingBindingRequestsCount => _pendingBindingRequests;
  int get totalPendingCount => _pendingAppointments + _pendingBindingRequests;

  // 清除所有通知
  Future<void> clearAllNotifications() async {
    if (adminUid == null) return;

    try {
      final batch = _firestore.batch();
      final notifications = await _firestore
          .collection('admins')
          .doc(adminUid)
          .collection('notifications')
          .get();

      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 清除通知失败: $e');
      }
    }
  }

  // 停止监听并清理资源
  Future<void> dispose() async {
    // 设置管理员离线状态
    await _setAdminOnlineStatus(false);

    // 取消所有订阅
    for (var subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    // 清空回调
    _onNewAppointment = null;
    _onNewBindingRequest = null;
    _onAppointmentUpdate = null;
    _onBindingRequestUpdate = null;

    if (kDebugMode) {
      print('✅ 管理员通知服务已清理');
    }
  }
}

// 通知数据模型
class AppNotificationData {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool isRead;
  final NotificationSource source;

  AppNotificationData({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    required this.timestamp,
    required this.isRead,
    required this.source,
  });

  factory AppNotificationData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotificationData(
      id: doc.id,
      type: NotificationType.values.firstWhere(
            (e) => e.toString().split('.').last == data['type'],
        orElse: () => NotificationType.general,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      source: NotificationSource.values.firstWhere(
            (e) => e.toString().split('.').last == data['source'],
        orElse: () => NotificationSource.system,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'title': title,
      'message': message,
      'data': data,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'source': source.toString().split('.').last,
    };
  }

  AppNotificationData copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool? isRead,
    NotificationSource? source,
  }) {
    return AppNotificationData(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      source: source ?? this.source,
    );
  }
}

// 通知类型枚举
enum NotificationType {
  newAppointment,
  newBindingRequest,
  newUnbindingRequest,
  appointmentUpdate,
  bindingRequestUpdate,
  general,
}

// 通知来源枚举
enum NotificationSource {
  userApp,    // 来自用户App
  coachApp,   // 来自教练App
  system,     // 系统通知
  admin,      // 管理员操作
}

// 通知类型扩展
extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.newAppointment:
        return 'New Appointment';
      case NotificationType.newBindingRequest:
        return 'Binding Request';
      case NotificationType.newUnbindingRequest:
        return 'Unbinding Request';
      case NotificationType.appointmentUpdate:
        return 'Appointment Update';
      case NotificationType.bindingRequestUpdate:
        return 'Request Update';
      case NotificationType.general:
        return 'General';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.newAppointment:
        return Icons.event_note;
      case NotificationType.newBindingRequest:
        return Icons.link;
      case NotificationType.newUnbindingRequest:
        return Icons.link_off;
      case NotificationType.appointmentUpdate:
        return Icons.update;
      case NotificationType.bindingRequestUpdate:
        return Icons.notifications_active;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.newAppointment:
        return Colors.blue;
      case NotificationType.newBindingRequest:
        return Colors.green;
      case NotificationType.newUnbindingRequest:
        return Colors.orange;
      case NotificationType.appointmentUpdate:
        return Colors.purple;
      case NotificationType.bindingRequestUpdate:
        return Colors.teal;
      case NotificationType.general:
        return Colors.grey;
    }
  }
}