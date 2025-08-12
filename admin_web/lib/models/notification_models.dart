// lib/models/notification_models.dart
// 用途：通知系统相关数据模型

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 主要通知数据模型
class AppNotificationData {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool isRead;
  final NotificationSource source;
  final NotificationStatus status;
  final NotificationPriority priority;
  final String? actionUrl; // 可选的操作链接
  final DateTime? expiresAt; // 可选的过期时间
  final String? relatedId; // 关联的业务数据ID（如appointmentId, requestId）
  final Map<String, dynamic>? metadata; // 额外的元数据

  AppNotificationData({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    required this.timestamp,
    this.isRead = false,
    required this.source,
    this.status = NotificationStatus.active,
    this.priority = NotificationPriority.normal,
    this.actionUrl,
    this.expiresAt,
    this.relatedId,
    this.metadata,
  });

  /// 从 Firestore 数据创建对象
  factory AppNotificationData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotificationData(
      id: doc.id,
      type: NotificationType.values.firstWhere(
            (e) => e.toString().split('.').last == (data['type'] ?? 'general'),
        orElse: () => NotificationType.general,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      source: NotificationSource.values.firstWhere(
            (e) => e.toString().split('.').last == (data['source'] ?? 'system'),
        orElse: () => NotificationSource.system,
      ),
      status: NotificationStatus.values.firstWhere(
            (e) => e.toString().split('.').last == (data['status'] ?? 'active'),
        orElse: () => NotificationStatus.active,
      ),
      priority: NotificationPriority.values.firstWhere(
            (e) => e.toString().split('.').last == (data['priority'] ?? 'normal'),
        orElse: () => NotificationPriority.normal,
      ),
      actionUrl: data['actionUrl'],
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      relatedId: data['relatedId'],
      metadata: data['metadata'] != null
          ? Map<String, dynamic>.from(data['metadata'])
          : null,
    );
  }

  /// 转换为 Firestore 数据
  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'title': title,
      'message': message,
      'data': data,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'source': source.toString().split('.').last,
      'status': status.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      if (actionUrl != null) 'actionUrl': actionUrl,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
      if (relatedId != null) 'relatedId': relatedId,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// 创建副本
  AppNotificationData copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool? isRead,
    NotificationSource? source,
    NotificationStatus? status,
    NotificationPriority? priority,
    String? actionUrl,
    DateTime? expiresAt,
    String? relatedId,
    Map<String, dynamic>? metadata,
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
      status: status ?? this.status,
      priority: priority ?? this.priority,
      actionUrl: actionUrl ?? this.actionUrl,
      expiresAt: expiresAt ?? this.expiresAt,
      relatedId: relatedId ?? this.relatedId,
      metadata: metadata ?? this.metadata,
    );
  }

  /// 检查通知是否已过期
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// 检查通知是否需要立即处理
  bool get isUrgent => priority == NotificationPriority.urgent;

  /// 检查通知是否是高优先级
  bool get isHighPriority =>
      priority == NotificationPriority.high || priority == NotificationPriority.urgent;

  @override
  String toString() {
    return 'AppNotificationData(id: $id, type: $type, title: $title, isRead: $isRead)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppNotificationData &&
        other.id == id &&
        other.type == type &&
        other.title == title &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return id.hashCode ^ type.hashCode ^ title.hashCode ^ timestamp.hashCode;
  }
}

/// 通知类型枚举
enum NotificationType {
  newAppointment,           // 新预约请求
  newBindingRequest,        // 新绑定请求
  newUnbindingRequest,      // 新解绑请求
  appointmentUpdate,        // 预约状态更新
  bindingRequestUpdate,     // 绑定请求状态更新
  appointmentApproved,      // 预约已批准
  appointmentRejected,      // 预约已拒绝
  appointmentCancelled,     // 预约已取消
  appointmentCompleted,     // 预约已完成
  bindingRequestApproved,   // 绑定请求已批准
  bindingRequestRejected,   // 绑定请求已拒绝
  coachStatusChanged,       // 教练状态变更
  systemMaintenance,        // 系统维护
  systemUpdate,             // 系统更新
  general,                  // 一般通知
}

/// 通知来源枚举
enum NotificationSource {
  userApp,      // 来自用户App
  coachApp,     // 来自教练App
  webAdmin,     // 来自Web管理端
  system,       // 系统自动
  scheduler,    // 定时任务
  external,     // 外部系统
}

/// 通知状态枚举
enum NotificationStatus {
  active,       // 活跃状态
  archived,     // 已归档
  deleted,      // 已删除
  expired,      // 已过期
}

/// 通知优先级枚举
enum NotificationPriority {
  low,          // 低优先级
  normal,       // 普通优先级
  high,         // 高优先级
  urgent,       // 紧急优先级
}

/// 通知操作类型枚举
enum NotificationAction {
  view,         // 查看
  approve,      // 批准
  reject,       // 拒绝
  navigate,     // 导航
  dismiss,      // 忽略
  archive,      // 归档
}

/// 通知统计数据模型
class NotificationStats {
  final int total;
  final int unread;
  final int today;
  final int thisWeek;
  final Map<NotificationType, int> byType;
  final Map<NotificationSource, int> bySource;
  final Map<NotificationPriority, int> byPriority;

  NotificationStats({
    required this.total,
    required this.unread,
    required this.today,
    required this.thisWeek,
    required this.byType,
    required this.bySource,
    required this.byPriority,
  });

  factory NotificationStats.empty() {
    return NotificationStats(
      total: 0,
      unread: 0,
      today: 0,
      thisWeek: 0,
      byType: {},
      bySource: {},
      byPriority: {},
    );
  }

  factory NotificationStats.fromNotifications(List<AppNotificationData> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    final byType = <NotificationType, int>{};
    final bySource = <NotificationSource, int>{};
    final byPriority = <NotificationPriority, int>{};

    int unreadCount = 0;
    int todayCount = 0;
    int thisWeekCount = 0;

    for (final notification in notifications) {
      // 统计未读
      if (!notification.isRead) unreadCount++;

      // 统计今日
      if (notification.timestamp.isAfter(today)) todayCount++;

      // 统计本周
      if (notification.timestamp.isAfter(weekStart)) thisWeekCount++;

      // 按类型统计
      byType[notification.type] = (byType[notification.type] ?? 0) + 1;

      // 按来源统计
      bySource[notification.source] = (bySource[notification.source] ?? 0) + 1;

      // 按优先级统计
      byPriority[notification.priority] = (byPriority[notification.priority] ?? 0) + 1;
    }

    return NotificationStats(
      total: notifications.length,
      unread: unreadCount,
      today: todayCount,
      thisWeek: thisWeekCount,
      byType: byType,
      bySource: bySource,
      byPriority: byPriority,
    );
  }
}

/// 通知设置模型
class NotificationSettings {
  final bool enableAppointmentNotifications;
  final bool enableBindingRequestNotifications;
  final bool enableSystemNotifications;
  final bool enableSoundNotifications;
  final bool enableEmailNotifications;
  final NotificationPriority minimumPriority;
  final List<NotificationType> mutedTypes;
  final Map<String, dynamic> customSettings;

  NotificationSettings({
    this.enableAppointmentNotifications = true,
    this.enableBindingRequestNotifications = true,
    this.enableSystemNotifications = true,
    this.enableSoundNotifications = true,
    this.enableEmailNotifications = false,
    this.minimumPriority = NotificationPriority.low,
    this.mutedTypes = const [],
    this.customSettings = const {},
  });

  factory NotificationSettings.fromMap(Map<String, dynamic> data) {
    return NotificationSettings(
      enableAppointmentNotifications: data['enableAppointmentNotifications'] ?? true,
      enableBindingRequestNotifications: data['enableBindingRequestNotifications'] ?? true,
      enableSystemNotifications: data['enableSystemNotifications'] ?? true,
      enableSoundNotifications: data['enableSoundNotifications'] ?? true,
      enableEmailNotifications: data['enableEmailNotifications'] ?? false,
      minimumPriority: NotificationPriority.values.firstWhere(
            (e) => e.toString().split('.').last == (data['minimumPriority'] ?? 'low'),
        orElse: () => NotificationPriority.low,
      ),
      mutedTypes: (data['mutedTypes'] as List<dynamic>?)
          ?.map((e) => NotificationType.values.firstWhere(
            (type) => type.toString().split('.').last == e,
        orElse: () => NotificationType.general,
      ))
          .toList() ?? [],
      customSettings: Map<String, dynamic>.from(data['customSettings'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enableAppointmentNotifications': enableAppointmentNotifications,
      'enableBindingRequestNotifications': enableBindingRequestNotifications,
      'enableSystemNotifications': enableSystemNotifications,
      'enableSoundNotifications': enableSoundNotifications,
      'enableEmailNotifications': enableEmailNotifications,
      'minimumPriority': minimumPriority.toString().split('.').last,
      'mutedTypes': mutedTypes.map((e) => e.toString().split('.').last).toList(),
      'customSettings': customSettings,
    };
  }

  /// 检查是否应该显示某个通知
  bool shouldShowNotification(AppNotificationData notification) {
    // 检查类型是否被静音
    if (mutedTypes.contains(notification.type)) return false;

    // 检查优先级是否满足要求
    if (notification.priority.index < minimumPriority.index) return false;

    // 检查特定类型的开关
    switch (notification.type) {
      case NotificationType.newAppointment:
      case NotificationType.appointmentUpdate:
      case NotificationType.appointmentApproved:
      case NotificationType.appointmentRejected:
      case NotificationType.appointmentCancelled:
      case NotificationType.appointmentCompleted:
        return enableAppointmentNotifications;

      case NotificationType.newBindingRequest:
      case NotificationType.newUnbindingRequest:
      case NotificationType.bindingRequestUpdate:
      case NotificationType.bindingRequestApproved:
      case NotificationType.bindingRequestRejected:
        return enableBindingRequestNotifications;

      case NotificationType.systemMaintenance:
      case NotificationType.systemUpdate:
        return enableSystemNotifications;

      default:
        return true;
    }
  }

  NotificationSettings copyWith({
    bool? enableAppointmentNotifications,
    bool? enableBindingRequestNotifications,
    bool? enableSystemNotifications,
    bool? enableSoundNotifications,
    bool? enableEmailNotifications,
    NotificationPriority? minimumPriority,
    List<NotificationType>? mutedTypes,
    Map<String, dynamic>? customSettings,
  }) {
    return NotificationSettings(
      enableAppointmentNotifications: enableAppointmentNotifications ?? this.enableAppointmentNotifications,
      enableBindingRequestNotifications: enableBindingRequestNotifications ?? this.enableBindingRequestNotifications,
      enableSystemNotifications: enableSystemNotifications ?? this.enableSystemNotifications,
      enableSoundNotifications: enableSoundNotifications ?? this.enableSoundNotifications,
      enableEmailNotifications: enableEmailNotifications ?? this.enableEmailNotifications,
      minimumPriority: minimumPriority ?? this.minimumPriority,
      mutedTypes: mutedTypes ?? this.mutedTypes,
      customSettings: customSettings ?? this.customSettings,
    );
  }
}

/// 通知类型扩展方法
extension NotificationTypeExtension on NotificationType {
  /// 获取显示名称
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
      case NotificationType.appointmentApproved:
        return 'Appointment Approved';
      case NotificationType.appointmentRejected:
        return 'Appointment Rejected';
      case NotificationType.appointmentCancelled:
        return 'Appointment Cancelled';
      case NotificationType.appointmentCompleted:
        return 'Appointment Completed';
      case NotificationType.bindingRequestApproved:
        return 'Binding Approved';
      case NotificationType.bindingRequestRejected:
        return 'Binding Rejected';
      case NotificationType.coachStatusChanged:
        return 'Coach Status Changed';
      case NotificationType.systemMaintenance:
        return 'System Maintenance';
      case NotificationType.systemUpdate:
        return 'System Update';
      case NotificationType.general:
        return 'General';
    }
  }

  /// 获取图标
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
      case NotificationType.appointmentApproved:
        return Icons.check_circle;
      case NotificationType.appointmentRejected:
        return Icons.cancel;
      case NotificationType.appointmentCancelled:
        return Icons.event_busy;
      case NotificationType.appointmentCompleted:
        return Icons.done_all;
      case NotificationType.bindingRequestApproved:
        return Icons.check_circle_outline;
      case NotificationType.bindingRequestRejected:
        return Icons.highlight_off;
      case NotificationType.coachStatusChanged:
        return Icons.person;
      case NotificationType.systemMaintenance:
        return Icons.build;
      case NotificationType.systemUpdate:
        return Icons.system_update;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  /// 获取颜色
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
      case NotificationType.appointmentApproved:
      case NotificationType.bindingRequestApproved:
        return Colors.green;
      case NotificationType.appointmentRejected:
      case NotificationType.bindingRequestRejected:
        return Colors.red;
      case NotificationType.appointmentCancelled:
        return Colors.orange;
      case NotificationType.appointmentCompleted:
        return Colors.purple;
      case NotificationType.coachStatusChanged:
        return Colors.indigo;
      case NotificationType.systemMaintenance:
        return Colors.amber;
      case NotificationType.systemUpdate:
        return Colors.cyan;
      case NotificationType.general:
        return Colors.grey;
    }
  }

  /// 检查是否需要立即处理
  bool get requiresImmediateAction {
    switch (this) {
      case NotificationType.newAppointment:
      case NotificationType.newBindingRequest:
      case NotificationType.newUnbindingRequest:
        return true;
      default:
        return false;
    }
  }
}

/// 通知优先级扩展方法
extension NotificationPriorityExtension on NotificationPriority {
  String get displayName {
    switch (this) {
      case NotificationPriority.low:
        return 'Low';
      case NotificationPriority.normal:
        return 'Normal';
      case NotificationPriority.high:
        return 'High';
      case NotificationPriority.urgent:
        return 'Urgent';
    }
  }

  Color get color {
    switch (this) {
      case NotificationPriority.low:
        return Colors.grey;
      case NotificationPriority.normal:
        return Colors.blue;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.urgent:
        return Colors.red;
    }
  }
}

/// 通知来源扩展方法
extension NotificationSourceExtension on NotificationSource {
  String get displayName {
    switch (this) {
      case NotificationSource.userApp:
        return 'User App';
      case NotificationSource.coachApp:
        return 'Coach App';
      case NotificationSource.webAdmin:
        return 'Web Admin';
      case NotificationSource.system:
        return 'System';
      case NotificationSource.scheduler:
        return 'Scheduler';
      case NotificationSource.external:
        return 'External';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationSource.userApp:
        return Icons.smartphone;
      case NotificationSource.coachApp:
        return Icons.sports;
      case NotificationSource.webAdmin:
        return Icons.web;
      case NotificationSource.system:
        return Icons.computer;
      case NotificationSource.scheduler:
        return Icons.schedule;
      case NotificationSource.external:
        return Icons.cloud;
    }
  }
}