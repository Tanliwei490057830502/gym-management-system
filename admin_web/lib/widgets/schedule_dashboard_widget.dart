// lib/widgets/schedule_dashboard_widget.dart
// 用途：行程仪表盘组件（移除今日相关功能）

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/schedule_service.dart';
import '../utils/utils.dart';
import 'widgets.dart';

class ScheduleDashboardWidget extends StatelessWidget {
  final Function(int)? onNavigateToPage;

  const ScheduleDashboardWidget({
    super.key,
    this.onNavigateToPage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Monthly Overview', Icons.calendar_month),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: _buildMonthlyCalendarCard(),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 1,
              child: _buildMonthlyStatsCard(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.purple[600], size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyCalendarCard() {
    return Container(
      height: 320,
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
      ),
      child: Column(
        children: [
          _buildCardHeader(
            'Monthly Calendar',
            Icons.calendar_view_month,
            Colors.purple,
            onTap: () => onNavigateToPage?.call(1), // 跳转到月行程页面（索引1）
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CompactScheduleCalendar(
                month: DateTime.now(),
                onDateSelected: (date) => onNavigateToPage?.call(1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStatsCard() {
    return Container(
      height: 320,
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
      ),
      child: Column(
        children: [
          _buildCardHeader(
            'Monthly Statistics',
            Icons.bar_chart,
            Colors.green,
            onTap: () => onNavigateToPage?.call(4), // 跳转到分析页面（索引4）
          ),
          Expanded(
            child: StreamBuilder<List<Appointment>>(
              stream: ScheduleService.getCurrentMonthAppointments(),
              builder: (context, snapshot) {
                final appointments = snapshot.data ?? [];
                final stats = AppointmentStats.fromAppointments(appointments);

                return _buildMonthlyStatsContent(stats);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHeader(String title, IconData icon, MaterialColor color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color[100]!, color[50]!],
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
            Icon(icon, color: color[700]!, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color[700]!,
              ),
            ),
            const Spacer(),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                color: color[600]!,
                size: 14,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyStatsContent(AppointmentStats stats) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildMonthlyStatRow('Total Appointments', stats.total, Icons.calendar_today, Colors.blue),
          const SizedBox(height: 12),
          _buildMonthlyStatRow('Pending Approval', stats.pending, Icons.schedule, Colors.orange),
          const SizedBox(height: 12),
          _buildMonthlyStatRow('Confirmed', stats.confirmed, Icons.check_circle, Colors.green),
          const SizedBox(height: 12),
          _buildMonthlyStatRow('Completed', stats.completed, Icons.done_all, Colors.purple),
          const Spacer(),
          _buildCompletionRate(stats),
        ],
      ),
    );
  }

  Widget _buildMonthlyStatRow(String label, int value, IconData icon, MaterialColor color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
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

  Widget _buildCompletionRate(AppointmentStats stats) {
    final total = stats.total;
    final completed = stats.completed;
    final rate = total > 0 ? (completed / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Completion Rate',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '$rate%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: rate >= 80 ? Colors.green : rate >= 60 ? Colors.orange : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}