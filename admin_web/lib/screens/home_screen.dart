// lib/screens/home_screen.dart
// 用途：主页仪表板界面（调整导航索引）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/gym_service.dart';
import '../services/schedule_service.dart';
import '../models/gym_info.dart';
import '../models/models.dart';
import '../widgets/schedule_dashboard_widget.dart';
import 'package:gym_admin_web/screens/gym_settings_screen.dart';




class HomeScreen extends StatelessWidget {
  final Function(int)? onNavigateToPage;

  const HomeScreen({
    super.key,
    this.onNavigateToPage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[50],
        child: StreamBuilder<GymInfo>(
          stream: GymService.gymInfoStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildErrorState(context);
            }

            final gymInfo = snapshot.data ?? GymInfo.defaultInfo();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部操作栏
                  _buildTopBar(context, gymInfo),

                  const SizedBox(height: 30),

                  // 主要内容
                  if (gymInfo.isDefault)
                    _buildSetupPrompt(context)
                  else ...[
                    // 健身房信息和行程仪表盘
                    _buildMainContent(context, gymInfo),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, GymInfo gymInfo) {
    return Column(
      children: [
        // 快速统计概览
        _buildQuickStatsOverview(),

        const SizedBox(height: 30),

        // 健身房信息和月度概览并排显示
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧：健身房信息
            Expanded(
              flex: 2,
              child: _buildGymInfoCard(context, gymInfo),
            ),

            const SizedBox(width: 30),

            // 右侧：月度概览（替换今日概览）
            Expanded(
              flex: 3,
              child: _buildMonthlyOverview(context),
            ),
          ],
        ),

        const SizedBox(height: 30),

        // 行程仪表盘
        ScheduleDashboardWidget(
          onNavigateToPage: onNavigateToPage,
        ),
      ],
    );
  }

  Widget _buildQuickStatsOverview() {
    return StreamBuilder<List<Appointment>>(
      stream: ScheduleService.getCurrentMonthAppointments(),
      builder: (context, monthSnapshot) {
        final monthAppointments = monthSnapshot.data ?? [];
        final monthStats = AppointmentStats.fromAppointments(monthAppointments);

        return StreamBuilder<int>(
          stream: ScheduleService.getPendingAppointmentsCount(),
          builder: (context, pendingSnapshot) {
            final pendingCount = pendingSnapshot.data ?? 0;

            return Row(
              children: [
                Expanded(
                  child: _buildQuickStatCard(
                    title: 'This Month',
                    value: monthStats.total.toString(),
                    icon: Icons.calendar_month,
                    color: Colors.purple,
                    subtitle: 'Total bookings',
                    onTap: () => onNavigateToPage?.call(1), // 调整为月行程索引1
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildQuickStatCard(
                    title: 'Pending Approvals',
                    value: pendingCount.toString(),
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                    subtitle: 'Need attention',
                    onTap: () => onNavigateToPage?.call(2), // 调整为appointments索引2
                    hasNotification: pendingCount > 0,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildQuickStatCard(
                    title: 'Confirmed',
                    value: monthStats.confirmed.toString(),
                    icon: Icons.check_circle,
                    color: Colors.green,
                    subtitle: 'This month',
                    onTap: () => onNavigateToPage?.call(1), // 跳转到月行程
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildQuickStatCard(
                    title: 'Completion Rate',
                    value: _calculateCompletionRate(monthStats),
                    icon: Icons.trending_up,
                    color: Colors.blue,
                    subtitle: 'This month',
                    onTap: () => onNavigateToPage?.call(4), // 调整为analytics索引4
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildQuickStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    VoidCallback? onTap,
    bool hasNotification = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey[200]!,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: hasNotification
              ? Border.all(color: Colors.orange[300]!, width: 2)
              : Border.all(color: color.withValues(alpha: 0.1), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Row(
                  children: [
                    if (hasNotification)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (onTap != null) ...[
                      if (hasNotification) const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey[400],
                        size: 14,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGymInfoCard(BuildContext context, GymInfo gymInfo) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[200]!,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 卡片头部
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[600]!, Colors.purple[400]!],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gym Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        gymInfo.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 卡片内容
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildCompactInfoRow(Icons.phone, 'Phone', gymInfo.phone, Colors.green),
                const SizedBox(height: 12),
                _buildCompactInfoRow(Icons.email, 'Email', gymInfo.email, Colors.blue),
                const SizedBox(height: 12),
                _buildCompactInfoRow(Icons.location_on, 'Address', gymInfo.address, Colors.red),
                if (gymInfo.website.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildCompactInfoRow(Icons.language, 'Website', gymInfo.website, Colors.orange),
                ],

                if (gymInfo.operatingHours.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildCompactOperatingHours(gymInfo),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToSettings(context),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Information'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[50],
                      foregroundColor: Colors.purple[600],
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.purple[200]!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactOperatingHours(GymInfo gymInfo) {
    final limitedHours = gymInfo.operatingHours.entries.take(3).toList();
    final hasMore = gymInfo.operatingHours.length > 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.access_time, color: Colors.purple[600], size: 16),
            const SizedBox(width: 8),
            const Text(
              'Operating Hours',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              ...limitedHours.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              )),
              if (hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${gymInfo.operatingHours.length - 3} more',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // 新增：月度概览替换今日概览
  Widget _buildMonthlyOverview(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[200]!,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 卡片头部
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[600]!, Colors.purple[400]!],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_month,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'This month\'s statistics',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => onNavigateToPage?.call(1), // 跳转到月行程
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 月度统计
          StreamBuilder<List<Appointment>>(
            stream: ScheduleService.getCurrentMonthAppointments(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final appointments = snapshot.data ?? [];

              if (appointments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No appointments this month',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Start scheduling!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final stats = AppointmentStats.fromAppointments(appointments);

              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildMonthlyStatRow('Total', stats.total, Icons.calendar_today, Colors.blue),
                    const SizedBox(height: 12),
                    _buildMonthlyStatRow('Pending', stats.pending, Icons.pending_actions, Colors.orange),
                    const SizedBox(height: 12),
                    _buildMonthlyStatRow('Confirmed', stats.confirmed, Icons.check_circle, Colors.green),
                    const SizedBox(height: 12),
                    _buildMonthlyStatRow('Completed', stats.completed, Icons.done_all, Colors.purple),
                    const SizedBox(height: 20),
                    _buildCompletionRateCard(stats),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStatRow(String label, int value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionRateCard(AppointmentStats stats) {
    final rate = _calculateCompletionRate(stats);
    final rateValue = int.parse(rate.replaceAll('%', ''));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: rateValue >= 80 ? Colors.green : rateValue >= 60 ? Colors.orange : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'Completion Rate',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            rate,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: rateValue >= 80 ? Colors.green : rateValue >= 60 ? Colors.orange : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateCompletionRate(AppointmentStats stats) {
    if (stats.total == 0) return '0%';
    final rate = (stats.completed / stats.total * 100).round();
    return '$rate%';
  }

  Widget _buildTopBar(BuildContext context, GymInfo gymInfo) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              gymInfo.isDefault
                  ? 'Configure your gym information to get started'
                  : 'Welcome to ${gymInfo.name}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            if (!gymInfo.isDefault) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green[500],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Configured',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
            ElevatedButton.icon(
              onPressed: () => _navigateToSettings(context),
              icon: const Icon(Icons.settings, size: 18),
              label: Text(gymInfo.isDefault ? 'Setup Gym Info' : 'Edit Info'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSetupPrompt(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[200]!,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.settings,
              size: 80,
              color: Colors.purple[400],
            ),
          ),

          const SizedBox(height: 30),

          const Text(
            'Welcome to LTC Gym Admin!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Get started by configuring your gym information.\nThis will personalize your admin dashboard.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),

          const SizedBox(height: 40),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFeatureItem(Icons.business, 'Gym Details'),
              const SizedBox(width: 40),
              _buildFeatureItem(Icons.access_time, 'Operating Hours'),
              const SizedBox(width: 40),
              _buildFeatureItem(Icons.fitness_center, 'Amenities'),
            ],
          ),

          const SizedBox(height: 50),

          ElevatedButton.icon(
            onPressed: () => _navigateToSettings(context),
            icon: const Icon(Icons.arrow_forward, size: 20),
            label: const Text('Configure Gym Information'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.purple[600],
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 20),
          const Text(
            'Failed to load gym information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Please check your connection and try again',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => _navigateToSettings(context),
            icon: const Icon(Icons.settings),
            label: const Text('Go to Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const GymSettingsScreen(),
      ),
    );
  }
}