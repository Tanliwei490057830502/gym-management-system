// lib/widgets/coaches_tab.dart
// 用途：管理员教练管理标签页（支持状态过滤）

import 'package:flutter/material.dart';
import '../services/coach_service.dart';
import '../models/models.dart';
import '../utils/snackbar_utils.dart';

class CoachesTab extends StatefulWidget {
  final VoidCallback onRefreshStatistics;

  const CoachesTab({
    Key? key,
    required this.onRefreshStatistics,
  }) : super(key: key);

  @override
  State<CoachesTab> createState() => _CoachesTabState();
}

class _CoachesTabState extends State<CoachesTab> {
  String _selectedStatusFilter = 'active'; // 默认只显示活跃教练

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: StreamBuilder<List<Coach>>(
            stream: _getFilteredCoachesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading coaches...'),
                    ],
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        'Error loading coaches:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: widget.onRefreshStatistics,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final coaches = snapshot.data ?? [];

              if (coaches.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: coaches.length,
                itemBuilder: (context, index) {
                  return _buildCoachCard(coaches[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          const Text('Filter:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Active Only', 'active'),
                  const SizedBox(width: 8),
                  _buildFilterChip('On Break', 'break'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Inactive', 'inactive'),
                  const SizedBox(width: 8),
                  _buildFilterChip('All Coaches', 'all'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedStatusFilter == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatusFilter = value;
        });
      },
      selectedColor: Colors.purple.shade100,
      checkmarkColor: Colors.purple.shade700,
      labelStyle: TextStyle(
        color: isSelected ? Colors.purple.shade700 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Stream<List<Coach>> _getFilteredCoachesStream() {
    if (_selectedStatusFilter == 'all') {
      return CoachService.getAllCoachesStream();
    } else {
      return CoachService.getAllCoachesStream().map((coaches) {
        return coaches.where((coach) => coach.status == _selectedStatusFilter).toList();
      });
    }
  }

  Widget _buildEmptyState() {
    String message;
    String subtitle;

    switch (_selectedStatusFilter) {
      case 'active':
        message = 'No Active Coaches';
        subtitle = 'No coaches are currently active.\nApprove binding requests to activate coaches.';
        break;
      case 'break':
        message = 'No Coaches on Break';
        subtitle = 'No coaches are currently on break.';
        break;
      case 'inactive':
        message = 'No Inactive Coaches';
        subtitle = 'No inactive coaches found.\nCoaches become inactive when they unbind from all gyms.';
        break;
      default:
        message = 'No Coaches Found';
        subtitle = 'No coaches have been registered yet.';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachCard(Coach coach) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // 状态指示器
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                color: _getStatusColor(coach.status),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            // 教练头像
            CircleAvatar(
              radius: 30,
              backgroundColor: _getStatusColor(coach.status).withOpacity(0.1),
              child: Icon(
                Icons.person,
                size: 30,
                color: _getStatusColor(coach.status),
              ),
            ),
            const SizedBox(width: 16),
            // 教练信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          coach.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusBadge(coach.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    coach.email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 绑定健身房信息
                  _buildGymInfo(coach),
                  const SizedBox(height: 8),
                  // 加入时间
                  if (coach.joinedAt != null) ...[
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          'Joined: ${coach.joinedAt!.day}/${coach.joinedAt!.month}/${coach.joinedAt!.year}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // 操作按钮
            _buildActionButtons(coach),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    Color borderColor;
    String text;

    switch (status) {
      case 'active':
        backgroundColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        borderColor = Colors.green.shade200;
        text = 'Active';
        break;
      case 'break':
        backgroundColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        borderColor = Colors.orange.shade200;
        text = 'On Break';
        break;
      case 'inactive':
        backgroundColor = Colors.grey.shade50;
        textColor = Colors.grey.shade700;
        borderColor = Colors.grey.shade200;
        text = 'Inactive';
        break;
      default:
        backgroundColor = Colors.grey.shade50;
        textColor = Colors.grey.shade700;
        borderColor = Colors.grey.shade200;
        text = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildGymInfo(Coach coach) {
    if (coach.boundGyms.isEmpty) {
      return Row(
        children: [
          Icon(Icons.warning, size: 16, color: Colors.orange.shade600),
          const SizedBox(width: 4),
          Text(
            'No gym bindings',
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.fitness_center, size: 16, color: Colors.green.shade600),
        const SizedBox(width: 4),
        Text(
          'Bound to ${coach.boundGyms.length} gym${coach.boundGyms.length != 1 ? 's' : ''}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.green.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Coach coach) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
      onSelected: (value) => _handleAction(coach, value),
      itemBuilder: (context) => [
        if (coach.status == 'active')
          const PopupMenuItem(
            value: 'set_break',
            child: ListTile(
              leading: Icon(Icons.pause, color: Colors.orange),
              title: Text('Set on Break'),
              dense: true,
            ),
          ),
        if (coach.status == 'break')
          const PopupMenuItem(
            value: 'activate',
            child: ListTile(
              leading: Icon(Icons.play_arrow, color: Colors.green),
              title: Text('Activate'),
              dense: true,
            ),
          ),
        if (coach.status == 'inactive')
          const PopupMenuItem(
            value: 'activate',
            child: ListTile(
              leading: Icon(Icons.play_arrow, color: Colors.green),
              title: Text('Reactivate'),
              dense: true,
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'remove',
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Remove Coach'),
            dense: true,
          ),
        ),
      ],
    );
  }

  Future<void> _handleAction(Coach coach, String action) async {
    switch (action) {
      case 'activate':
        await _updateCoachStatus(coach, 'active');
        break;
      case 'set_break':
        await _updateCoachStatus(coach, 'break');
        break;
      case 'remove':
        await _removeCoach(coach);
        break;
    }
  }

  Future<void> _updateCoachStatus(Coach coach, String newStatus) async {
    final success = await CoachService.updateCoachStatus(coach.id, newStatus);

    if (success) {
      widget.onRefreshStatistics();
      if (mounted) {
        SnackbarUtils.showSuccess(
          context,
          'Coach status updated to ${newStatus == 'active' ? 'Active' : 'On Break'}',
        );
      }
    } else {
      if (mounted) {
        SnackbarUtils.showError(
          context,
          'Failed to update coach status',
        );
      }
    }
  }

  Future<void> _removeCoach(Coach coach) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Coach'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to remove ${coach.name}?'),
            const SizedBox(height: 8),
            const Text(
              'This action will:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text('• Delete the coach record'),
            const Text('• Cancel related binding requests'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await CoachService.removeCoach(coach.id);

      if (success) {
        widget.onRefreshStatistics();
        if (mounted) {
          SnackbarUtils.showSuccess(
            context,
            'Coach removed successfully',
          );
        }
      } else {
        if (mounted) {
          SnackbarUtils.showError(
            context,
            'Failed to remove coach',
          );
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'break':
        return Colors.orange;
      case 'inactive':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}