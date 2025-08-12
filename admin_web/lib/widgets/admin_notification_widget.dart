// lib/widgets/admin_notification_widget.dart
// 用途：Web端管理员通知显示组件

import 'package:flutter/material.dart';
import '../services/admin_notification_service.dart';
import '../utils/utils.dart';

class AdminNotificationWidget extends StatefulWidget {
  final Function(int)? onNavigateToPage; // 导航回调

  const AdminNotificationWidget({
    Key? key,
    this.onNavigateToPage,
  }) : super(key: key);

  @override
  State<AdminNotificationWidget> createState() => _AdminNotificationWidgetState();
}

class _AdminNotificationWidgetState extends State<AdminNotificationWidget> {
  final AdminNotificationService _notificationService = AdminNotificationService();
  final List<AppNotificationData> _recentNotifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    // 初始化通知服务
    await _notificationService.initializeAdminNotifications();

    // 设置各种通知回调
    _notificationService.setNewAppointmentCallback(_handleNewAppointment);
    _notificationService.setNewBindingRequestCallback(_handleNewBindingRequest);
    _notificationService.setAppointmentUpdateCallback(_handleAppointmentUpdate);
    _notificationService.setBindingRequestUpdateCallback(_handleBindingRequestUpdate);

    // 更新计数
    _updateUnreadCount();
  }

  void _handleNewAppointment(AppNotificationData notification) {
    if (!mounted) return;

    setState(() {
      _recentNotifications.insert(0, notification);
      if (_recentNotifications.length > 10) {
        _recentNotifications.removeLast();
      }
    });

    _updateUnreadCount();
    _showInAppNotification(notification);
  }

  void _handleNewBindingRequest(AppNotificationData notification) {
    if (!mounted) return;

    setState(() {
      _recentNotifications.insert(0, notification);
      if (_recentNotifications.length > 10) {
        _recentNotifications.removeLast();
      }
    });

    _updateUnreadCount();
    _showInAppNotification(notification);
  }

  void _handleAppointmentUpdate(AppNotificationData notification) {
    if (!mounted) return;

    setState(() {
      _recentNotifications.insert(0, notification);
      if (_recentNotifications.length > 10) {
        _recentNotifications.removeLast();
      }
    });

    _updateUnreadCount();
  }

  void _handleBindingRequestUpdate(AppNotificationData notification) {
    if (!mounted) return;

    setState(() {
      _recentNotifications.insert(0, notification);
      if (_recentNotifications.length > 10) {
        _recentNotifications.removeLast();
      }
    });

    _updateUnreadCount();
  }

  void _updateUnreadCount() {
    if (!mounted) return;

    setState(() {
      _unreadCount = _notificationService.totalPendingCount;
    });
  }

  void _showInAppNotification(AppNotificationData notification) {
    if (!mounted) return;

    // 显示顶部通知横幅
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ListTile(
          leading: Icon(
            notification.type.icon,
            color: Colors.white,
            size: 20,
          ),
          title: Text(
            notification.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            notification.message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          trailing: notification.type == NotificationType.newAppointment ||
              notification.type == NotificationType.newBindingRequest
              ? TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              _handleNotificationTap(notification);
            },
            child: const Text(
              'View',
              style: TextStyle(color: Colors.white),
            ),
          )
              : null,
        ),
        backgroundColor: notification.type.color,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _handleNotificationTap(AppNotificationData notification) {
    // 根据通知类型导航到相应页面
    switch (notification.type) {
      case NotificationType.newAppointment:
      case NotificationType.appointmentUpdate:
      // 导航到预约管理页面 (索引 2)
        widget.onNavigateToPage?.call(2);
        break;
      case NotificationType.newBindingRequest:
      case NotificationType.newUnbindingRequest:
      case NotificationType.bindingRequestUpdate:
      // 导航到教练管理页面 (索引 3)
        widget.onNavigateToPage?.call(3);
        break;
      default:
        break;
    }

    // 标记为已读
    _notificationService.markNotificationAsRead(notification.id);
    _updateUnreadCount();
  }

  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildNotificationBell();
  }

  Widget _buildNotificationBell() {
    return Stack(
      children: [
        IconButton(
          onPressed: () => _showNotificationDropdown(context),
          icon: Icon(
            Icons.notifications_outlined,
            color: Colors.grey.shade600,
            size: 24,
          ),
          tooltip: 'Notifications',
        ),

        // 未读数量徽章
        if (_unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationDropdown(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _NotificationDropdownDialog(
        notifications: _recentNotifications,
        onNotificationTap: _handleNotificationTap,
        onClearAll: () {
          setState(() {
            _recentNotifications.clear();
            _unreadCount = 0;
          });
          _notificationService.clearAllNotifications();
        },
        pendingAppointments: _notificationService.pendingAppointmentsCount,
        pendingBindingRequests: _notificationService.pendingBindingRequestsCount,
        onViewAppointments: () {
          Navigator.of(context).pop();
          widget.onNavigateToPage?.call(2);
        },
        onViewBindingRequests: () {
          Navigator.of(context).pop();
          widget.onNavigateToPage?.call(3);
        },
      ),
    );
  }
}

class _NotificationDropdownDialog extends StatelessWidget {
  final List<AppNotificationData> notifications;
  final Function(AppNotificationData) onNotificationTap;
  final VoidCallback onClearAll;
  final int pendingAppointments;
  final int pendingBindingRequests;
  final VoidCallback onViewAppointments;
  final VoidCallback onViewBindingRequests;

  const _NotificationDropdownDialog({
    Key? key,
    required this.notifications,
    required this.onNotificationTap,
    required this.onClearAll,
    required this.pendingAppointments,
    required this.pendingBindingRequests,
    required this.onViewAppointments,
    required this.onViewBindingRequests,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.shade600,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      onClearAll();
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Clear All',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),

            // 快速操作区域
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  // 待处理预约
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.event_note,
                      title: 'Appointments',
                      count: pendingAppointments,
                      color: Colors.blue,
                      onTap: onViewAppointments,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 待处理绑定请求
                  Expanded(
                    child: _QuickActionCard(
                      icon: Icons.link,
                      title: 'Binding Requests',
                      count: pendingBindingRequests,
                      color: Colors.green,
                      onTap: onViewBindingRequests,
                    ),
                  ),
                ],
              ),
            ),

            // 通知列表
            Flexible(
              child: notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _NotificationItem(
                    notification: notification,
                    onTap: () {
                      onNotificationTap(notification);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Recent Notifications',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New appointment and binding requests will appear here',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final AppNotificationData notification;
  final VoidCallback onTap;

  const _NotificationItem({
    Key? key,
    required this.notification,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
            color: notification.isRead ? Colors.transparent : Colors.blue.shade50,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 通知图标
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: notification.type.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  notification.type.icon,
                  color: notification.type.color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),

              // 通知内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: notification.type.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppDateUtils.formatTimeAgo(notification.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}