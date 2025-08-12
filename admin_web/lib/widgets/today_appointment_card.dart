// lib/widgets/today_appointment_card.dart
// 用途：今日预约卡片组件 - 支持双重批准系统

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../utils/utils.dart';

class TodayAppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback? onTap;
  final Function(String, String, String)? onApprovalUpdate; // 改为支持批准类型
  final bool showActions;
  final bool compact;
  final String userRole; // 'coach' 或 'admin'

  const TodayAppointmentCard({
    Key? key,
    required this.appointment,
    this.onTap,
    this.onApprovalUpdate,
    this.showActions = true,
    this.compact = false,
    this.userRole = 'admin', // 默认为管理员
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: compact ? 8 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: compact ? 3 : 5,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: appointment.statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: compact ? _buildCompactLayout() : _buildFullLayout(),
          ),
        ),
      ),
    );
  }

  Widget _buildFullLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildApprovalStatus(), // 新增批准状态显示
        const SizedBox(height: 12),
        _buildAppointmentInfo(),
        if (showActions && _canUserApprove()) ...[
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ],
    );
  }

  Widget _buildCompactLayout() {
    return Row(
      children: [
        _buildTimeSlot(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _buildCompactInfo(),
              const SizedBox(height: 4),
              _buildCompactApprovalStatus(),
            ],
          ),
        ),
        if (showActions && _canUserApprove()) ...[
          const SizedBox(width: 12),
          _buildCompactActions(),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _buildTimeSlot(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.userName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                appointment.userEmail,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildTimeSlot() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: appointment.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: appointment.statusColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.access_time,
            color: appointment.statusColor,
            size: 16,
          ),
          const SizedBox(height: 4),
          Text(
            appointment.timeSlot,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: appointment.statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: appointment.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: appointment.statusColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            appointment.statusIcon,
            color: appointment.statusColor,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            appointment.overallStatus.toUpperCase(),
            style: TextStyle(
              color: appointment.statusColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // 新增：批准状态显示
  Widget _buildApprovalStatus() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Approval Status',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildApprovalItem(
                  'Coach',
                  appointment.coachApproval,
                  Icons.person,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildApprovalItem(
                  'Admin',
                  appointment.adminApproval,
                  Icons.admin_panel_settings,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: appointment.approvalProgress,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              appointment.approvalProgress == 1.0 ? Colors.green : Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            appointment.detailedStatusText,
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalItem(String title, String status, IconData icon) {
    Color statusColor = _getApprovalColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: statusColor),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactApprovalStatus() {
    return Row(
      children: [
        _buildCompactApprovalBadge('C', appointment.coachApproval),
        const SizedBox(width: 4),
        _buildCompactApprovalBadge('A', appointment.adminApproval),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            appointment.detailedStatusText,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactApprovalBadge(String letter, String status) {
    Color statusColor = _getApprovalColor(status);

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getApprovalColor(String approval) {
    switch (approval) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _buildAppointmentInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.fitness_center,
            label: 'Coach',
            value: appointment.coachName,
            color: Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.location_on,
            label: 'Gym',
            value: appointment.gymName,
            color: Colors.green,
          ),
          if (appointment.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.note,
              label: 'Notes',
              value: appointment.notes!,
              color: Colors.orange,
            ),
          ],
          if (appointment.coachRejectReason?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.warning,
              label: 'Coach Reject Reason',
              value: appointment.coachRejectReason!,
              color: Colors.red,
            ),
          ],
          if (appointment.adminRejectReason?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.warning,
              label: 'Admin Reject Reason',
              value: appointment.adminRejectReason!,
              color: Colors.red,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appointment.userName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Coach: ${appointment.coachName}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          'Gym: ${appointment.gymName}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
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
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _canUserApprove() {
    if (userRole == 'coach') {
      return appointment.canCoachApprove;
    } else if (userRole == 'admin') {
      return appointment.canAdminApprove;
    }
    return false;
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _handleApprovalUpdate('approved'),
            icon: const Icon(Icons.check, size: 18),
            label: Text('Approve as ${userRole.toUpperCase()}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _handleApprovalUpdate('rejected'),
            icon: const Icon(Icons.close, size: 18),
            label: Text('Reject as ${userRole.toUpperCase()}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              side: BorderSide(color: Colors.red.shade400),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _handleApprovalUpdate('approved'),
          icon: const Icon(Icons.check),
          style: IconButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            minimumSize: const Size(32, 32),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () => _handleApprovalUpdate('rejected'),
          icon: const Icon(Icons.close),
          style: IconButton.styleFrom(
            backgroundColor: Colors.red.shade100,
            foregroundColor: Colors.red.shade600,
            minimumSize: const Size(32, 32),
          ),
        ),
      ],
    );
  }

  void _handleApprovalUpdate(String approval) {
    if (onApprovalUpdate != null) {
      onApprovalUpdate!(appointment.id, userRole, approval);
    }
  }
}

/// 待审批专用的紧凑卡片 - 更新为双重批准
class PendingApprovalCard extends StatelessWidget {
  final Appointment appointment;
  final int index;
  final Function(String, String, String)? onApprovalUpdate; // appointmentId, userRole, approval
  final String userRole; // 'coach' 或 'admin'

  const PendingApprovalCard({
    Key? key,
    required this.appointment,
    required this.index,
    this.onApprovalUpdate,
    this.userRole = 'admin',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade100,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    index.toString(),
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  appointment.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              // 批准状态指示器
              Row(
                children: [
                  _buildStatusDot('C', appointment.coachApproval),
                  const SizedBox(width: 2),
                  _buildStatusDot('A', appointment.adminApproval),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Coach: ${appointment.coachName}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            'Time: ${appointment.timeSlot}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            appointment.detailedStatusText,
            style: TextStyle(
              fontSize: 10,
              color: Colors.blue.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // 只显示当前用户可以操作的按钮
          if (_canUserApprove()) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleApprovalUpdate('approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      '✓ ${userRole.toUpperCase()}',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleApprovalUpdate('rejected'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      '✗ ${userRole.toUpperCase()}',
                      style: TextStyle(color: Colors.red.shade600, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _getWaitingMessage(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusDot(String letter, String status) {
    Color color;
    switch (status) {
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 6,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  bool _canUserApprove() {
    if (userRole == 'coach') {
      return appointment.canCoachApprove;
    } else if (userRole == 'admin') {
      return appointment.canAdminApprove;
    }
    return false;
  }

  String _getWaitingMessage() {
    if (userRole == 'coach' && !appointment.canCoachApprove) {
      return 'Already processed by coach';
    } else if (userRole == 'admin' && !appointment.canAdminApprove) {
      return 'Already processed by admin';
    }
    return 'Waiting for action';
  }

  void _handleApprovalUpdate(String approval) {
    if (onApprovalUpdate != null) {
      onApprovalUpdate!(appointment.id, userRole, approval);
    }
  }
}

/// 预约状态更新工具类 - 更新为双重批准
class AppointmentCardUtils {
  static Future<void> updateCoachApproval(
      BuildContext context,
      String appointmentId,
      String approval,
      ) async {
    try {
      final updateData = {
        'coachApproval': approval,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (approval == 'approved') {
        updateData['coachApprovedAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update(updateData);

      // 检查是否需要自动确认
      await _checkAndAutoConfirm(appointmentId);

      if (context.mounted) {
        SnackbarUtils.showSuccess(
          context,
          'Coach ${approval == 'approved' ? 'approved' : 'rejected'} appointment successfully!',
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showError(context, 'Failed to update coach approval: $e');
      }
    }
  }

  static Future<void> updateAdminApproval(
      BuildContext context,
      String appointmentId,
      String approval,
      ) async {
    try {
      final updateData = {
        'adminApproval': approval,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (approval == 'approved') {
        updateData['adminApprovedAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update(updateData);

      // 检查是否需要自动确认
      await _checkAndAutoConfirm(appointmentId);

      if (context.mounted) {
        SnackbarUtils.showSuccess(
          context,
          'Admin ${approval == 'approved' ? 'approved' : 'rejected'} appointment successfully!',
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showError(context, 'Failed to update admin approval: $e');
      }
    }
  }

  static Future<void> _checkAndAutoConfirm(String appointmentId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .get();

      if (doc.exists) {
        final appointment = Appointment.fromFirestore(doc);

        if (appointment.shouldAutoConfirm) {
          // 双重批准完成，自动确认预约
          await FirebaseFirestore.instance
              .collection('appointments')
              .doc(appointmentId)
              .update({
            'overallStatus': 'confirmed',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (appointment.shouldAutoCancel) {
          // 任一方拒绝，自动取消预约
          await FirebaseFirestore.instance
              .collection('appointments')
              .doc(appointmentId)
              .update({
            'overallStatus': 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error checking auto-confirm: $e');
    }
  }

  static void showAppointmentDetails(BuildContext context, Appointment appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Appointment Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('User:', appointment.userName),
              _buildDetailRow('Email:', appointment.userEmail),
              _buildDetailRow('Coach:', appointment.coachName),
              _buildDetailRow('Gym:', appointment.gymName),
              _buildDetailRow('Date:', AppDateUtils.formatDate(appointment.date)),
              _buildDetailRow('Time:', appointment.timeSlot),
              const SizedBox(height: 12),
              const Text('Approval Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildDetailRow('Coach Approval:', appointment.coachApproval.toUpperCase()),
              _buildDetailRow('Admin Approval:', appointment.adminApproval.toUpperCase()),
              _buildDetailRow('Overall Status:', appointment.overallStatus.toUpperCase()),
              if (appointment.notes?.isNotEmpty == true)
                _buildDetailRow('Notes:', appointment.notes!),
              if (appointment.coachRejectReason?.isNotEmpty == true)
                _buildDetailRow('Coach Reject Reason:', appointment.coachRejectReason!),
              if (appointment.adminRejectReason?.isNotEmpty == true)
                _buildDetailRow('Admin Reject Reason:', appointment.adminRejectReason!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}