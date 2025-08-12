// lib/screens/coaches_screen.dart
// 用途：管理员教练管理页面 - 主文件（集成实时通知响应）

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/coach_service.dart';
import '../services/admin_notification_service.dart';

import '../widgets/coaches_tab.dart';
import '../widgets/binding_requests_tab.dart';
import '../widgets/courses_tab.dart';
import '../widgets/statistics_tab.dart';
import '../widgets/coaches_header.dart';
import '../utils/utils.dart';

class CoachesScreen extends StatefulWidget {
  final int? initialTabIndex; // 新增：支持从外部指定初始标签页

  const CoachesScreen({Key? key, this.initialTabIndex}) : super(key: key);

  @override
  State<CoachesScreen> createState() => _CoachesScreenState();
}

class _CoachesScreenState extends State<CoachesScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  late TabController _tabController;
  late AnimationController _notificationAnimationController;
  late Animation<double> _notificationAnimation;

  bool _isLoading = false;
  Map<String, int> _statistics = {};

  // 通知相关
  final AdminNotificationService _notificationService = AdminNotificationService();
  int _pendingRequestsCount = 0;
  bool _hasNewNotifications = false;
  DateTime? _lastNotificationTime;

  // 标签页索引映射
  static const int _coachesTabIndex = 0;
  static const int _requestsTabIndex = 1;
  static const int _coursesTabIndex = 2;
  static const int _statisticsTabIndex = 3;

  @override
  bool get wantKeepAlive => true; // 保持页面状态

  @override
  void initState() {
    super.initState();

    // 初始化TabController，支持外部指定初始索引
    final initialIndex = widget.initialTabIndex ?? 0;
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialIndex.clamp(0, 3),
    );

    // 初始化通知动画
    _notificationAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _notificationAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _notificationAnimationController,
      curve: Curves.elasticOut,
    ));

    // 初始化数据和通知监听
    _initializeScreen();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notificationAnimationController.dispose();
    super.dispose();
  }

  /// 初始化屏幕数据和通知监听
  Future<void> _initializeScreen() async {
    await _loadStatistics();
    _setupNotificationListeners();
    _startPeriodicRefresh();
  }

  /// 设置通知监听器
  void _setupNotificationListeners() {
    // 监听新绑定请求通知
    _notificationService.setNewBindingRequestCallback(_handleNewBindingRequestNotification);

    // 监听绑定请求更新通知
    _notificationService.setBindingRequestUpdateCallback(_handleBindingRequestUpdateNotification);

    if (kDebugMode) {
      print('✅ CoachesScreen notification listeners setup');
    }
  }

  /// 处理新绑定请求通知
  void _handleNewBindingRequestNotification(AppNotificationData notification) {
    if (!mounted) return;

    setState(() {
      _hasNewNotifications = true;
      _lastNotificationTime = DateTime.now();
    });

    // 播放通知动画
    _playNotificationAnimation();

    // 如果当前不在请求标签页，显示导航提示
    if (_tabController.index != _requestsTabIndex) {
      _showNotificationSnackBar(notification);
    }

    // 刷新统计数据
    _loadStatistics();

    if (kDebugMode) {
      print('📱 New binding request notification handled in CoachesScreen');
    }
  }

  /// 处理绑定请求更新通知
  void _handleBindingRequestUpdateNotification(AppNotificationData notification) {
    if (!mounted) return;

    // 刷新统计数据
    _loadStatistics();

    // 如果在请求标签页，显示更新提示
    if (_tabController.index == _requestsTabIndex) {
      _showUpdateSnackBar(notification);
    }

    if (kDebugMode) {
      print('📊 Binding request update notification handled in CoachesScreen');
    }
  }

  /// 播放通知动画
  void _playNotificationAnimation() {
    _notificationAnimationController.forward().then((_) {
      _notificationAnimationController.reverse();
    });
  }

  /// 显示通知提示条
  void _showNotificationSnackBar(AppNotificationData notification) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              notification.type.icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    notification.message,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _navigateToRequestsTab();
              },
              child: const Text(
                'View',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: notification.type.color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white70,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// 显示更新提示条
  void _showUpdateSnackBar(AppNotificationData notification) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.refresh,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Request updated: ${notification.message}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      ),
    );
  }

  /// 导航到请求标签页
  void _navigateToRequestsTab() {
    if (!mounted) return;

    setState(() {
      _hasNewNotifications = false;
    });

    _tabController.animateTo(_requestsTabIndex);

    // 标记通知为已读
    if (_lastNotificationTime != null) {
      _markNotificationsAsRead();
    }
  }

  /// 标记通知为已读
  void _markNotificationsAsRead() {
    // 这里可以调用通知服务标记已读
    // _notificationService.markAllAsRead();
  }

  /// 开始定期刷新
  void _startPeriodicRefresh() {
    // 每30秒刷新一次统计数据
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadStatistics();
        _startPeriodicRefresh();
      }
    });
  }

  /// 加载统计信息
  Future<void> _loadStatistics() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final stats = await CoachService.getStatistics();
      if (mounted) {
        setState(() {
          _statistics = stats;
          _pendingRequestsCount = stats['pending_requests'] ?? 0;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 加载统计信息失败: $e');
      }
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to load statistics');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 刷新统计信息（供子组件调用）
  void _refreshStatistics() {
    _loadStatistics();
  }

  /// 处理标签页变化
  void _handleTabChange() {
    if (!mounted) return;

    // 如果切换到请求标签页，清除新通知标记
    if (_tabController.index == _requestsTabIndex) {
      setState(() {
        _hasNewNotifications = false;
      });
      _markNotificationsAsRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 为了AutomaticKeepAliveClientMixin

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // 头部区域
          CoachesHeader(
            onRefreshStatistics: _refreshStatistics,
            pendingRequestsCount: _pendingRequestsCount,
            hasNewNotifications: _hasNewNotifications,
          ),

          // 标签栏
          _buildTabBar(),

          // 标签页内容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                CoachesTab(onRefreshStatistics: _refreshStatistics),
                BindingRequestsTab(
                  onRefreshStatistics: _refreshStatistics,
                  highlightNew: _hasNewNotifications,
                ),
                CoursesTab(onRefreshStatistics: _refreshStatistics),
                StatisticsTab(
                  statistics: _statistics,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ],
      ),

      // 浮动刷新按钮
      floatingActionButton: _buildRefreshFAB(),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.purple.shade600,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.purple.shade600,
        indicatorWeight: 3,
        onTap: (_) => _handleTabChange(),
        tabs: [
          // Coaches标签
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people, size: 20),
                const SizedBox(width: 8),
                const Text('Coaches'),
                if (_statistics['total_coaches'] != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_statistics['total_coaches']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Requests标签（带通知指示器）
          Tab(
            child: AnimatedBuilder(
              animation: _notificationAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _hasNewNotifications ? _notificationAnimation.value : 1.0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          const Icon(Icons.pending_actions, size: 20),
                          if (_hasNewNotifications)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      const Text('Requests'),
                      if (_pendingRequestsCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _hasNewNotifications
                                ? Colors.red.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _hasNewNotifications
                                  ? Colors.red.shade300
                                  : Colors.orange.shade300,
                            ),
                          ),
                          child: Text(
                            '$_pendingRequestsCount',
                            style: TextStyle(
                              fontSize: 12,
                              color: _hasNewNotifications
                                  ? Colors.red.shade700
                                  : Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          // Courses标签
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.class_, size: 20),
                const SizedBox(width: 8),
                const Text('Courses'),
                if (_statistics['total_courses'] != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_statistics['total_courses']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Statistics标签
          const Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.analytics, size: 20),
                SizedBox(width: 8),
                Text('Statistics'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshFAB() {
    return FloatingActionButton(
      onPressed: _isLoading ? null : _refreshStatistics,
      backgroundColor: Colors.purple.shade600,
      child: _isLoading
          ? SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      )
          : const Icon(
        Icons.refresh,
        color: Colors.white,
      ),
      tooltip: 'Refresh Data',
    );
  }
}

/// 扩展的CoachesHeader组件，支持通知状态显示
class EnhancedCoachesHeader extends StatelessWidget {
  final VoidCallback onRefreshStatistics;
  final int pendingRequestsCount;
  final bool hasNewNotifications;

  const EnhancedCoachesHeader({
    Key? key,
    required this.onRefreshStatistics,
    required this.pendingRequestsCount,
    required this.hasNewNotifications,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.admin_panel_settings,
            color: Colors.blue.shade600,
            size: 28,
          ),
          const SizedBox(width: 15),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coach & Course Management',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Manage coaches, binding requests, and courses',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const Spacer(),

          // 通知状态指示器
          if (hasNewNotifications || pendingRequestsCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: hasNewNotifications
                    ? Colors.red.shade100
                    : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasNewNotifications
                      ? Colors.red.shade300
                      : Colors.orange.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasNewNotifications
                        ? Icons.notifications_active
                        : Icons.pending_actions,
                    color: hasNewNotifications
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasNewNotifications
                        ? 'New Requests!'
                        : '$pendingRequestsCount Pending',
                    style: TextStyle(
                      color: hasNewNotifications
                          ? Colors.red.shade700
                          : Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],

          // 刷新按钮
          IconButton(
            onPressed: onRefreshStatistics,
            icon: Icon(
              Icons.refresh,
              color: Colors.grey.shade600,
            ),
            tooltip: 'Refresh Statistics',
          ),
        ],
      ),
    );
  }
}