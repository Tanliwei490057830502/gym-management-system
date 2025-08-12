// lib/widgets/statistics_tab.dart
// 用途：统计信息标签页

import 'package:flutter/material.dart';
import '../widgets/stat_card.dart';

class StatisticsTab extends StatelessWidget {
  final Map<String, int> statistics;
  final bool isLoading;

  const StatisticsTab({
    Key? key,
    required this.statistics,
    required this.isLoading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Statistics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            _buildStatisticsCards(),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Column(
      children: [
        _buildFirstRow(),
        const SizedBox(height: 20),
        _buildSecondRow(),
        const SizedBox(height: 20),
        _buildThirdRow(),
      ],
    );
  }

  Widget _buildFirstRow() {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: 'Total Coaches',
            value: '${statistics['total_coaches'] ?? 0}',
            icon: Icons.people,
            color: Colors.blue,
            subtitle: 'All registered coaches',
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: StatCard(
            title: 'Active Coaches',
            value: '${statistics['active_coaches'] ?? 0}',
            icon: Icons.work,
            color: Colors.green,
            subtitle: 'Currently working',
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: StatCard(
            title: 'Total Requests',
            value: '${statistics['total_requests'] ?? 0}',
            icon: Icons.request_page,
            color: Colors.orange,
            subtitle: 'All binding requests',
          ),
        ),
      ],
    );
  }

  Widget _buildSecondRow() {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: 'Pending Requests',
            value: '${statistics['pending_requests'] ?? 0}',
            icon: Icons.pending,
            color: Colors.orange,
            subtitle: 'Awaiting approval',
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: StatCard(
            title: 'Approved Requests',
            value: '${statistics['approved_requests'] ?? 0}',
            icon: Icons.check_circle,
            color: Colors.green,
            subtitle: 'Successfully approved',
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: StatCard(
            title: 'Total Courses',
            value: '${statistics['total_courses'] ?? 0}',
            icon: Icons.class_,
            color: Colors.purple,
            subtitle: 'Available courses',
          ),
        ),
      ],
    );
  }

  Widget _buildThirdRow() {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: 'Bind Requests',
            value: '${statistics['bind_requests'] ?? 0}',
            icon: Icons.link,
            color: Colors.blue,
            subtitle: 'Coach binding requests',
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: StatCard(
            title: 'Unbind Requests',
            value: '${statistics['unbind_requests'] ?? 0}',
            icon: Icons.link_off,
            color: Colors.orange,
            subtitle: 'Coach unbinding requests',
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: StatCard(
            title: 'Rejected Requests',
            value: '${statistics['rejected_requests'] ?? 0}',
            icon: Icons.cancel,
            color: Colors.red,
            subtitle: 'Declined applications',
          ),
        ),
      ],
    );
  }
}