// lib/screens/main_screen.dart
// 用途：主界面布局（集成实时通知系统）

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../widgets/sidebar.dart';
import '../widgets/admin_notification_widget.dart';
import '../services/auth_service.dart';
import '../services/admin_notification_service.dart';
import '../models/admin_info.dart';
import '../models/models.dart';
import 'home_screen.dart';
import 'monthly_schedule_screen.dart';
import 'appointment_screen.dart';
import 'coaches_screen.dart';
import 'charts_screen.dart';

class MainScreen extends StatefulWidget {
  final int? initialIndex;

  const MainScreen({Key? key, this.initialIndex}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final AdminNotificationService _notificationService = AdminNotificationService();

  // 添加缓存机制避免重复调用
  Future<AdminInfo?>? _adminInfoFuture;
  AdminInfo? _cachedAdminInfo;
  bool _isLoadingAdminInfo = false;

  // 精简后的页面列表（移除今日行程）
  List<Widget> get _pages => [
    HomeScreen(
      onNavigateToPage: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
    ),
    const MonthlyScheduleScreen(),        // 月行程 - 索引调整为1
    const AppointmentScreen(),
    const CoachesScreen(),
    const ChartsScreen(),
  ];

  // 精简后的页面标题
  final List<String> _pageTitles = [
    'Dashboard',
    'Monthly Schedule',                   // 月行程标题
    'Appointment Management',
    'Coaches & Courses',
    'Analytics & Reports',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex ?? 0;

    // 初始化时获取管理员信息（只调用一次）
    _loadAdminInfo();
    _initializeNotificationService();
  }

  /// 只在初始化时调用一次，避免重复获取
  Future<void> _loadAdminInfo() async {
    if (_isLoadingAdminInfo || _cachedAdminInfo != null) {
      if (kDebugMode) {
        print('🚫 Skipping admin info load - already loaded or loading');
      }
      return;
    }

    setState(() {
      _isLoadingAdminInfo = true;
    });

    try {
      if (kDebugMode) {
        print('👤 Loading admin info...');
      }

      final adminInfo = await AuthService.getAdminInfo();

      if (mounted) {
        setState(() {
          _cachedAdminInfo = adminInfo;
          _isLoadingAdminInfo = false;
        });

        if (kDebugMode) {
          print('✅ Admin info loaded successfully');
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to load admin info: $e');
      }

      if (mounted) {
        setState(() {
          _isLoadingAdminInfo = false;
        });
      }
    }
  }

  Future<void> _initializeNotificationService() async {
    try {
      // 初始化管理员通知服务
      await _notificationService.initializeAdminNotifications();

      if (kDebugMode) {
        print('✅ Notification service initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize notification service: $e');
      }
    }
  }

  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 使用精简版侧边栏组件
          Sidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),

          // 主内容区域
          Expanded(
            child: Container(
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: _pages[_selectedIndex],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 30),
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
          // 页面标题
          Text(
            _pageTitles[_selectedIndex],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),

          const Spacer(),

          // 实时状态指示器
          _buildLiveIndicator(),

          const SizedBox(width: 20),

          // 集成新的通知组件
          AdminNotificationWidget(
            onNavigateToPage: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),

          const SizedBox(width: 15),

          // 用户信息（使用缓存数据）
          _buildUserInfo(),
        ],
      ),
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.green.shade500,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Live',
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// 修复后的用户信息组件 - 使用缓存数据，避免重复调用
  Widget _buildUserInfo() {
    // 如果正在加载，显示加载状态
    if (_isLoadingAdminInfo) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.purple.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.purple.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade600),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Loading...',
              style: TextStyle(
                color: Colors.purple.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // 使用缓存的管理员信息
    final adminInfo = _cachedAdminInfo;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.purple.shade600,
            child: Text(
              (adminInfo?.name.isNotEmpty == true)
                  ? adminInfo!.name[0].toUpperCase()
                  : 'A',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                adminInfo?.name ?? 'Admin',
                style: TextStyle(
                  color: Colors.purple.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              Text(
                adminInfo?.roleDisplayText ?? 'Administrator',
                style: TextStyle(
                  color: Colors.purple.shade500,
                  fontSize: 10,
                ),
              ),
            ],
          ),

          // 添加刷新按钮（可选）
          const SizedBox(width: 8),
          InkWell(
            onTap: _refreshAdminInfo,
            child: Icon(
              Icons.refresh,
              size: 16,
              color: Colors.purple.shade400,
            ),
          ),
        ],
      ),
    );
  }

  /// 手动刷新管理员信息
  Future<void> _refreshAdminInfo() async {
    if (_isLoadingAdminInfo) return;

    setState(() {
      _cachedAdminInfo = null;
      _isLoadingAdminInfo = true;
    });

    try {
      if (kDebugMode) {
        print('🔄 Refreshing admin info...');
      }

      final adminInfo = await AuthService.getAdminInfo();

      if (mounted) {
        setState(() {
          _cachedAdminInfo = adminInfo;
          _isLoadingAdminInfo = false;
        });

        if (kDebugMode) {
          print('✅ Admin info refreshed successfully');
        }
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to refresh admin info: $e');
      }

      if (mounted) {
        setState(() {
          _isLoadingAdminInfo = false;
        });

        // 显示错误消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh user info: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}