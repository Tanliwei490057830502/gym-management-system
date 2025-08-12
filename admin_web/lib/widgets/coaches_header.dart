// lib/widgets/coaches_header.dart
// 用途：教练管理页面头部组件

import 'package:flutter/material.dart';
import '../services/coach_service.dart';
import '../models/models.dart';
import '../dialogs/add_course_dialog.dart';

class CoachesHeader extends StatelessWidget {
  final VoidCallback onRefreshStatistics;
  final int? pendingRequestsCount; // ← 添加
  final bool? hasNewNotifications; // ← 添加

  const CoachesHeader({
    Key? key,
    required this.onRefreshStatistics,
    this.pendingRequestsCount, // ← 添加
    this.hasNewNotifications,
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.fitness_center,
              color: Colors.purple.shade600,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coaches & Courses Management',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Manage your gym coaches, process binding requests and organize fitness courses',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          _buildNotificationAndActions(context),
        ],
      ),
    );
  }

  Widget _buildNotificationAndActions(BuildContext context) {
    return StreamBuilder<List<BindingRequest>>(
      stream: CoachService.getBindingRequestsStream(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data?.length ?? 0;

        return Row(
          children: [
            if (pendingCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_active,
                      color: Colors.orange.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$pendingCount Pending Request${pendingCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
            ],
            ElevatedButton.icon(
              onPressed: () => _showAddCourseDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Course'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddCourseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddCourseDialog(
        onCourseAdded: onRefreshStatistics,
      ),
    );
  }
}