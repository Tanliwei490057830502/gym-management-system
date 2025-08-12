// lib/services/notification_trigger_service.dart
// 用途：通知触发核心服务 - 监听App端事件并发送通知给Web端管理员

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_models.dart';
import '../models/models.dart';
import '../utils/utils.dart';
import 'dart:async';

class NotificationTriggerService {
  static final NotificationTriggerService _instance = NotificationTriggerService._internal();
  factory NotificationTriggerService() => _instance;
  NotificationTriggerService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 流订阅管理
  final List<StreamSubscription> _subscriptions = [];

  // 是否已初始化
  bool _isInitialized = false;

  /// 初始化通知触发服务
  Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('⚠️ NotificationTriggerService already initialized');
      }
      return;
    }

    try {
      // 1. 监听新预约请求
      _listenToNewAppointments();

      // 2. 监听预约状态变化
      _listenToAppointmentUpdates();

      // 3. 监听新绑定请求
      _listenToNewBindingRequests();

      // 4. 监听绑定请求状态变化
      _listenToBindingRequestUpdates();

      // 5. 监听教练状态变化
      _listenToCoachStatusChanges();

      _isInitialized = true;

      if (kDebugMode) {
        print('✅ NotificationTriggerService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize NotificationTriggerService: $e');
      }
      throw e;
    }
  }

  /// 监听新预约请求（来自App端用户）
  void _listenToNewAppointments() {
    final subscription = _firestore
        .collection('appointments')
        .where('overallStatus', isEqualTo: 'pending')
        .where('adminApproval', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _handleNewAppointment(change.doc);
        }
      }
    });

    _subscriptions.add(subscription);
  }

  /// 监听预约状态变化
  void _listenToAppointmentUpdates() {
    final subscription = _firestore
        .collection('appointments')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          _handleAppointmentUpdate(change.doc);
        }
      }
    });

    _subscriptions.add(subscription);
  }

  /// 监听新绑定请求（来自App端教练）
  void _listenToNewBindingRequests() {
    final subscription = _firestore
        .collection('binding_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _handleNewBindingRequest(change.doc);
        }
      }
    });

    _subscriptions.add(subscription);
  }

  /// 监听绑定请求状态变化
  void _listenToBindingRequestUpdates() {
    final subscription = _firestore
        .collection('binding_requests')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          _handleBindingRequestUpdate(change.doc);
        }
      }
    });

    _subscriptions.add(subscription);
  }

  /// 监听教练状态变化
  void _listenToCoachStatusChanges() {
    final subscription = _firestore
        .collection('coaches')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          _handleCoachStatusChange(change.doc);
        }
      }
    });

    _subscriptions.add(subscription);
  }

  /// 处理新预约请求
  Future<void> _handleNewAppointment(DocumentSnapshot doc) async {
    try {
      final appointment = Appointment.fromFirestore(doc);

      if (kDebugMode) {
        print('📱 New appointment detected: ${appointment.userName} -> ${appointment.coachName}');
      }

      // 查找目标管理员（健身房管理员）
      final targetAdminUid = await _findGymAdmin(appointment.gymId);
      if (targetAdminUid == null) {
        if (kDebugMode) {
          print('⚠️ No admin found for gym: ${appointment.gymName}');
        }
        return;
      }

      // 创建通知数据
      final notification = AppNotificationData(
        id: '${appointment.id}_new',
        type: NotificationType.newAppointment,
        title: 'New Appointment Request',
        message: '${appointment.userName} requested appointment with ${appointment.coachName} at ${appointment.gymName}',
        data: {
          'appointmentId': appointment.id,
          'userId': appointment.userId,
          'userName': appointment.userName,
          'userEmail': appointment.userEmail,
          'coachId': appointment.coachId,
          'coachName': appointment.coachName,
          'gymId': appointment.gymId,
          'gymName': appointment.gymName,
          'date': appointment.date.toIso8601String(),
          'timeSlot': appointment.timeSlot,
          'status': appointment.overallStatus,
          'adminApproval': appointment.adminApproval,
          'coachApproval': appointment.coachApproval,
        },
        timestamp: DateTime.now(),
        source: NotificationSource.userApp,
        priority: NotificationPriority.high,
        relatedId: appointment.id,
        actionUrl: '/appointments/${appointment.id}',
        metadata: {
          'triggerType': 'new_appointment',
          'sourceCollection': 'appointments',
          'sourceDocument': appointment.id,
        },
      );

      // 发送通知给管理员
      await _sendNotificationToAdmin(targetAdminUid, notification);

      // 如果配置了FCM，发送推送通知
      await _sendPushNotification(targetAdminUid, notification);

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling new appointment: $e');
      }
    }
  }

  /// 处理预约状态更新
  Future<void> _handleAppointmentUpdate(DocumentSnapshot doc) async {
    try {
      final appointment = Appointment.fromFirestore(doc);

      // 只处理状态从pending变为其他状态的情况
      if (appointment.overallStatus == 'pending') return;

      if (kDebugMode) {
        print('📊 Appointment updated: ${appointment.id} -> ${appointment.overallStatus}');
      }

      // 查找目标管理员
      final targetAdminUid = await _findGymAdmin(appointment.gymId);
      if (targetAdminUid == null) return;

      // 根据状态创建不同类型的通知
      NotificationType notificationType;
      String title;
      String message;
      NotificationPriority priority = NotificationPriority.normal;

      switch (appointment.overallStatus) {
        case 'confirmed':
          notificationType = NotificationType.appointmentApproved;
          title = 'Appointment Confirmed';
          message = 'Appointment with ${appointment.coachName} has been confirmed';
          priority = NotificationPriority.normal;
          break;
        case 'cancelled':
          notificationType = NotificationType.appointmentCancelled;
          title = 'Appointment Cancelled';
          message = 'Appointment with ${appointment.coachName} has been cancelled';
          priority = NotificationPriority.normal;
          break;
        case 'completed':
          notificationType = NotificationType.appointmentCompleted;
          title = 'Appointment Completed';
          message = 'Appointment with ${appointment.coachName} has been completed';
          priority = NotificationPriority.low;
          break;
        default:
          notificationType = NotificationType.appointmentUpdate;
          title = 'Appointment Updated';
          message = 'Appointment status changed to ${appointment.statusDisplayText}';
          priority = NotificationPriority.normal;
      }

      final notification = AppNotificationData(
        id: '${appointment.id}_update_${DateTime.now().millisecondsSinceEpoch}',
        type: notificationType,
        title: title,
        message: message,
        data: {
          'appointmentId': appointment.id,
          'userName': appointment.userName,
          'coachName': appointment.coachName,
          'gymName': appointment.gymName,
          'oldStatus': 'pending', // 可以从历史记录获取
          'newStatus': appointment.overallStatus,
          'adminApproval': appointment.adminApproval,
          'coachApproval': appointment.coachApproval,
        },
        timestamp: DateTime.now(),
        source: NotificationSource.system,
        priority: priority,
        relatedId: appointment.id,
        metadata: {
          'triggerType': 'appointment_update',
          'statusChange': appointment.overallStatus,
        },
      );

      await _sendNotificationToAdmin(targetAdminUid, notification);

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling appointment update: $e');
      }
    }
  }

  /// 处理新绑定请求
  Future<void> _handleNewBindingRequest(DocumentSnapshot doc) async {
    try {
      final request = BindingRequest.fromFirestore(doc);

      if (kDebugMode) {
        print('🏃‍♂️ New binding request detected: ${request.coachName} -> ${request.gymName}');
      }

      // 获取目标管理员UID（通常在请求中已指定）
      final targetAdminUid = request.targetAdminUid ?? await _findGymAdmin(request.gymId);
      if (targetAdminUid == null) {
        if (kDebugMode) {
          print('⚠️ No admin found for gym: ${request.gymName}');
        }
        return;
      }

      // 根据请求类型创建通知
      final notificationType = request.isBindRequest
          ? NotificationType.newBindingRequest
          : NotificationType.newUnbindingRequest;

      final notification = AppNotificationData(
        id: '${request.id}_new',
        type: notificationType,
        title: '${request.typeDisplayText} Request',
        message: 'Coach ${request.coachName} wants to ${request.type} ${request.gymName}',
        data: {
          'requestId': request.id,
          'coachId': request.coachId,
          'coachName': request.coachName,
          'coachEmail': request.coachEmail,
          'gymId': request.gymId,
          'gymName': request.gymName,
          'type': request.type,
          'message': request.message,
          'status': request.status,
        },
        timestamp: DateTime.now(),
        source: NotificationSource.coachApp,
        priority: NotificationPriority.high,
        relatedId: request.id,
        actionUrl: '/coaches/requests/${request.id}',
        metadata: {
          'triggerType': 'new_binding_request',
          'requestType': request.type,
          'sourceCollection': 'binding_requests',
          'sourceDocument': request.id,
        },
      );

      await _sendNotificationToAdmin(targetAdminUid, notification);
      await _sendPushNotification(targetAdminUid, notification);

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling new binding request: $e');
      }
    }
  }

  /// 处理绑定请求状态更新
  Future<void> _handleBindingRequestUpdate(DocumentSnapshot doc) async {
    try {
      final request = BindingRequest.fromFirestore(doc);

      // 只处理状态从pending变为其他状态的情况
      if (request.status == 'pending') return;

      if (kDebugMode) {
        print('📊 Binding request updated: ${request.id} -> ${request.status}');
      }

      final targetAdminUid = request.targetAdminUid ?? await _findGymAdmin(request.gymId);
      if (targetAdminUid == null) return;

      // 根据状态创建通知
      NotificationType notificationType;
      String title;
      String message;
      NotificationPriority priority = NotificationPriority.normal;

      switch (request.status) {
        case 'approved':
          notificationType = NotificationType.bindingRequestApproved;
          title = '${request.typeDisplayText} Request Approved';
          message = '${request.coachName}\'s ${request.type} request has been approved';
          priority = NotificationPriority.normal;
          break;
        case 'rejected':
          notificationType = NotificationType.bindingRequestRejected;
          title = '${request.typeDisplayText} Request Rejected';
          message = '${request.coachName}\'s ${request.type} request has been rejected';
          priority = NotificationPriority.normal;
          break;
        default:
          notificationType = NotificationType.bindingRequestUpdate;
          title = 'Binding Request Updated';
          message = '${request.coachName}\'s request status changed to ${request.statusDisplayText}';
          priority = NotificationPriority.low;
      }

      final notification = AppNotificationData(
        id: '${request.id}_update_${DateTime.now().millisecondsSinceEpoch}',
        type: notificationType,
        title: title,
        message: message,
        data: {
          'requestId': request.id,
          'coachName': request.coachName,
          'gymName': request.gymName,
          'type': request.type,
          'oldStatus': 'pending',
          'newStatus': request.status,
          'rejectReason': request.rejectReason,
        },
        timestamp: DateTime.now(),
        source: NotificationSource.system,
        priority: priority,
        relatedId: request.id,
        metadata: {
          'triggerType': 'binding_request_update',
          'statusChange': request.status,
          'requestType': request.type,
        },
      );

      await _sendNotificationToAdmin(targetAdminUid, notification);

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling binding request update: $e');
      }
    }
  }

  /// 处理教练状态变化
  Future<void> _handleCoachStatusChange(DocumentSnapshot doc) async {
    try {
      final coach = Coach.fromFirestore(doc);

      if (kDebugMode) {
        print('👨‍🏫 Coach status changed: ${coach.name} -> ${coach.status}');
      }

      // 获取教练绑定的所有健身房的管理员
      final adminUids = await _findAllAdminsForCoach(coach);

      if (adminUids.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No admins found for coach: ${coach.name}');
        }
        return;
      }

      final notification = AppNotificationData(
        id: '${coach.id}_status_${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.coachStatusChanged,
        title: 'Coach Status Changed',
        message: 'Coach ${coach.name} status changed to ${coach.status}',
        data: {
          'coachId': coach.id,
          'coachName': coach.name,
          'coachEmail': coach.email,
          'oldStatus': 'unknown', // 可以从历史记录获取
          'newStatus': coach.status,
          'assignedGymId': coach.assignedGymId,
          'assignedGymName': coach.assignedGymName,
        },
        timestamp: DateTime.now(),
        source: NotificationSource.system,
        priority: NotificationPriority.normal,
        relatedId: coach.id,
        metadata: {
          'triggerType': 'coach_status_change',
          'statusChange': coach.status,
        },
      );

      // 发送给所有相关管理员
      for (final adminUid in adminUids) {
        await _sendNotificationToAdmin(adminUid, notification);
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error handling coach status change: $e');
      }
    }
  }

  /// 查找健身房管理员
  Future<String?> _findGymAdmin(String gymId) async {
    try {
      // 方法1: 从gym_info集合查找（推荐）
      final gymDoc = await _firestore.collection('gym_info').doc(gymId).get();
      if (gymDoc.exists) {
        final data = gymDoc.data()!;
        final adminUid = data['adminUid'] ?? data['ownerId'] ?? gymId;
        return adminUid;
      }

      // 方法2: 从gyms集合查找（备用）
      final gymDocAlt = await _firestore.collection('gyms').doc(gymId).get();
      if (gymDocAlt.exists) {
        final data = gymDocAlt.data()!;
        return data['adminUid'] ?? data['ownerId'] ?? gymId;
      }

      // 方法3: 使用gymId作为adminUid（最后备用）
      return gymId;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error finding gym admin: $e');
      }
      return null;
    }
  }

  /// 查找教练相关的所有管理员
  Future<List<String>> _findAllAdminsForCoach(Coach coach) async {
    final adminUids = <String>[];

    try {
      // 从教练的assignedGymId获取管理员
      if (coach.assignedGymId != null) {
        final adminUid = await _findGymAdmin(coach.assignedGymId!);
        if (adminUid != null) {
          adminUids.add(adminUid);
        }
      }

      // 从教练的boundGyms获取所有管理员（如果支持多健身房绑定）
      if (coach.boundGyms != null) {
        for (final gymId in coach.boundGyms!) {
          final adminUid = await _findGymAdmin(gymId);
          if (adminUid != null && !adminUids.contains(adminUid)) {
            adminUids.add(adminUid);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error finding admins for coach: $e');
      }
    }

    return adminUids;
  }

  /// 发送通知给管理员
  Future<void> _sendNotificationToAdmin(String adminUid, AppNotificationData notification) async {
    try {
      // 保存通知到管理员的通知集合
      await _firestore
          .collection('admins')
          .doc(adminUid)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap());

      // 更新管理员的通知计数
      await _updateAdminNotificationCount(adminUid);

      if (kDebugMode) {
        print('✅ Notification sent to admin: $adminUid - ${notification.title}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending notification to admin: $e');
      }
    }
  }

  /// 更新管理员的通知计数
  Future<void> _updateAdminNotificationCount(String adminUid) async {
    try {
      final unreadCount = await _firestore
          .collection('admins')
          .doc(adminUid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get()
          .then((snapshot) => snapshot.docs.length);

      await _firestore.collection('admins').doc(adminUid).update({
        'unreadNotificationCount': unreadCount,
        'lastNotificationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating notification count: $e');
      }
    }
  }

  /// 发送推送通知（调用Firebase Cloud Functions）
  Future<void> _sendPushNotification(String adminUid, AppNotificationData notification) async {
    try {
      // 调用Firebase Cloud Functions发送FCM推送
      await _firestore.collection('fcm_notifications').add({
        'targetUid': adminUid,
        'title': notification.title,
        'body': notification.message,
        'data': notification.data,
        'type': notification.type.toString().split('.').last,
        'priority': notification.priority.toString().split('.').last,
        'platform': 'web',
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });

      if (kDebugMode) {
        print('📤 Push notification queued for admin: $adminUid');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error queueing push notification: $e');
      }
    }
  }

  /// 手动触发预约通知（用于测试或重新发送）
  Future<void> triggerAppointmentNotification(String appointmentId) async {
    try {
      final doc = await _firestore.collection('appointments').doc(appointmentId).get();
      if (doc.exists) {
        await _handleNewAppointment(doc);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error triggering appointment notification: $e');
      }
    }
  }

  /// 手动触发绑定请求通知（用于测试或重新发送）
  Future<void> triggerBindingRequestNotification(String requestId) async {
    try {
      final doc = await _firestore.collection('binding_requests').doc(requestId).get();
      if (doc.exists) {
        await _handleNewBindingRequest(doc);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error triggering binding request notification: $e');
      }
    }
  }

  /// 发送系统通知给所有管理员
  Future<void> sendSystemNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.systemUpdate,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 获取所有管理员
      final admins = await _firestore.collection('admins').get();

      final notification = AppNotificationData(
        id: 'system_${DateTime.now().millisecondsSinceEpoch}',
        type: type,
        title: title,
        message: message,
        data: data ?? {},
        timestamp: DateTime.now(),
        source: NotificationSource.system,
        priority: priority,
        metadata: {
          'triggerType': 'system_notification',
          'broadcast': true,
        },
      );

      // 发送给所有管理员
      for (final adminDoc in admins.docs) {
        await _sendNotificationToAdmin(adminDoc.id, notification);
      }

      if (kDebugMode) {
        print('✅ System notification sent to ${admins.docs.length} admins');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending system notification: $e');
      }
    }
  }

  /// 清理资源
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _isInitialized = false;

    if (kDebugMode) {
      print('✅ NotificationTriggerService disposed');
    }
  }

  /// 获取初始化状态
  bool get isInitialized => _isInitialized;
}