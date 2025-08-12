// lib/screens/appointment_screen.dart
// 用途：管理员预约管理页面 - 支持双重批准机制

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../utils/utils.dart';

class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({Key? key}) : super(key: key);

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAppointmentsList('all'),
                _buildAppointmentsList('pending'),
                _buildAppointmentsList('waiting_admin'),
                _buildAppointmentsList('partially_approved'),
                _buildAppointmentsList('confirmed'),
                _buildAppointmentsList('completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
                'Admin Appointment Management',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Manage admin approval for appointments',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const Spacer(),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('adminApproval', isEqualTo: 'pending')
                .where('overallStatus', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              final pendingCount = snapshot.data?.docs.length ?? 0;
              return Row(
                children: [
                  if (pendingCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$pendingCount Pending Admin Approval${pendingCount > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info,
                          color: Colors.blue.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Dual Approval System',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.blue.shade600,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.blue.shade600,
        isScrollable: true,
        tabs: const [
          Tab(text: 'All', icon: Icon(Icons.list)),
          Tab(text: 'Pending', icon: Icon(Icons.pending_actions)),
          Tab(text: 'Need Admin', icon: Icon(Icons.admin_panel_settings)),
          Tab(text: 'Partial', icon: Icon(Icons.pending)),
          Tab(text: 'Confirmed', icon: Icon(Icons.check_circle)),
          Tab(text: 'Completed', icon: Icon(Icons.done_all)),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList(String statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getAppointmentsStream(statusFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text('Error loading appointments: ${snapshot.error}'),
              ],
            ),
          );
        }

        final appointmentDocs = snapshot.data?.docs ?? [];
        final appointments = appointmentDocs.map((doc) => Appointment.fromFirestore(doc)).toList();

        if (appointments.isEmpty) {
          return _buildEmptyState(statusFilter);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (statusFilter == 'all') _buildStatsCards(appointments),
              if (statusFilter == 'all') const SizedBox(height: 30),
              _buildAppointmentsGrid(appointments),
            ],
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot> _getAppointmentsStream(String statusFilter) {
    var query = FirebaseFirestore.instance
        .collection('appointments')
        .orderBy('date', descending: false);

    switch (statusFilter) {
      case 'pending':
        query = query.where('overallStatus', isEqualTo: 'pending') as Query<Map<String, dynamic>>;
        break;
      case 'waiting_admin':
        query = query.where('adminApproval', isEqualTo: 'pending') as Query<Map<String, dynamic>>;
        query = query.where('overallStatus', isEqualTo: 'pending') as Query<Map<String, dynamic>>;
        break;
      case 'partially_approved':
      // 需要客户端过滤，因为Firestore不支持复杂的OR查询
        query = query.where('overallStatus', isEqualTo: 'pending') as Query<Map<String, dynamic>>;
        break;
      case 'confirmed':
        query = query.where('overallStatus', isEqualTo: 'confirmed') as Query<Map<String, dynamic>>;
        break;
      case 'completed':
        query = query.where('overallStatus', isEqualTo: 'completed') as Query<Map<String, dynamic>>;
        break;
    // 'all' case - no additional filtering
    }

    return query.snapshots();
  }

  Widget _buildEmptyState(String statusFilter) {
    String title;
    String subtitle;
    IconData icon;

    switch (statusFilter) {
      case 'pending':
        title = 'No Pending Appointments';
        subtitle = 'Appointments waiting for approval will appear here';
        icon = Icons.pending_actions;
        break;
      case 'waiting_admin':
        title = 'No Appointments Waiting Admin Approval';
        subtitle = 'Appointments needing your approval will appear here';
        icon = Icons.admin_panel_settings;
        break;
      case 'partially_approved':
        title = 'No Partially Approved Appointments';
        subtitle = 'Appointments with partial approval will appear here';
        icon = Icons.pending;
        break;
      case 'confirmed':
        title = 'No Confirmed Appointments';
        subtitle = 'Fully approved appointments will appear here';
        icon = Icons.check_circle_outline;
        break;
      case 'completed':
        title = 'No Completed Appointments';
        subtitle = 'Completed appointments will appear here';
        icon = Icons.done_all;
        break;
      default:
        title = 'No Appointments Yet';
        subtitle = 'User appointments will appear here';
        icon = Icons.calendar_today;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(List<Appointment> appointments) {
    final stats = AppointmentStats.fromAppointments(appointments);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard('Total', stats.total.toString(), Icons.calendar_today, Colors.blue),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildStatCard('Pending', stats.pending.toString(), Icons.pending_actions, Colors.orange),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildStatCard('Confirmed', stats.confirmed.toString(), Icons.check_circle, Colors.green),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildStatCard('Completed', stats.completed.toString(), Icons.done_all, Colors.purple),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildStatCard('Need Admin', stats.waitingAdminApproval.toString(), Icons.admin_panel_settings, Colors.red),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildStatCard('Need Coach', stats.waitingCoachApproval.toString(), Icons.person, Colors.teal),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildStatCard('Partial', stats.partiallyApproved.toString(), Icons.pending, Colors.amber),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildStatCard('Cancelled', stats.cancelled.toString(), Icons.cancel, Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsGrid(List<Appointment> appointments) {
    // 客户端过滤 partially_approved
    if (_selectedFilter == 'partially_approved') {
      appointments = appointments.where((a) =>
      (a.coachApproval == 'approved' || a.adminApproval == 'approved') &&
          a.overallStatus == 'pending').toList();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.3,
      ),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        return _buildAppointmentCard(appointments[index]);
      },
    );
  }

  Widget _buildAppointmentCard(Appointment appointment) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: appointment.statusColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAppointmentDetails(appointment),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        appointment.userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: appointment.statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(appointment.statusIcon, color: appointment.statusColor, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 批准状态指示器
                _buildApprovalIndicator(appointment),
                const SizedBox(height: 8),

                Text(
                  '👨‍🏫 ${appointment.coachName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '🏢 ${appointment.gymName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '📅 ${AppDateUtils.formatDate(appointment.date)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '🕐 ${appointment.timeSlot}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),

                const Spacer(),

                // 管理员操作按钮
                if (appointment.canAdminApprove || appointment.canAdminReject) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: appointment.canAdminApprove
                              ? () => _updateAdminApproval(appointment.id, 'approved')
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                          child: const Text(
                            'Approve',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: appointment.canAdminReject
                              ? () => _showRejectDialog(appointment.id)
                              : null,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade400),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                          child: Text(
                            'Reject',
                            style: TextStyle(color: Colors.red.shade600, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    appointment.detailedStatusText,
                    style: TextStyle(
                      fontSize: 11,
                      color: appointment.statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalIndicator(Appointment appointment) {
    return Row(
      children: [
        // 教练批准状态
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: _getApprovalColor(appointment.coachApproval).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getApprovalIcon(appointment.coachApproval),
                size: 10,
                color: _getApprovalColor(appointment.coachApproval),
              ),
              const SizedBox(width: 2),
              Text(
                'Coach',
                style: TextStyle(
                  fontSize: 8,
                  color: _getApprovalColor(appointment.coachApproval),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        // 管理员批准状态
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: _getApprovalColor(appointment.adminApproval).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getApprovalIcon(appointment.adminApproval),
                size: 10,
                color: _getApprovalColor(appointment.adminApproval),
              ),
              const SizedBox(width: 2),
              Text(
                'Admin',
                style: TextStyle(
                  fontSize: 8,
                  color: _getApprovalColor(appointment.adminApproval),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
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

  IconData _getApprovalIcon(String approval) {
    switch (approval) {
      case 'approved':
        return Icons.check;
      case 'rejected':
        return Icons.close;
      default:
        return Icons.schedule;
    }
  }

  void _showAppointmentDetails(Appointment appointment) {
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
              const SizedBox(height: 16),
              const Text('Approval Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
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
          if (appointment.canAdminApprove) ...[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateAdminApproval(appointment.id, 'approved');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Approve as Admin', style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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

  Future<void> _updateAdminApproval(String appointmentId, String approval) async {
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

      // 检查是否需要自动确认预约
      await _checkAndAutoConfirm(appointmentId);

      if (mounted) {
        SnackbarUtils.showSuccess(
          context,
          'Admin ${approval == 'approved' ? 'approved' : 'rejected'} appointment successfully!',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Failed to update appointment: $e');
      }
    }
  }

  Future<void> _checkAndAutoConfirm(String appointmentId) async {
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

  Future<void> _showRejectDialog(String appointmentId) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to reject this appointment as admin?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Why are you rejecting this appointment?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointmentId)
            .update({
          'adminApproval': 'rejected',
          'adminRejectReason': reasonController.text.trim(),
          'overallStatus': 'cancelled', // 任一方拒绝就取消整个预约
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          SnackbarUtils.showSuccess(
            context,
            'Appointment rejected by admin successfully!',
          );
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showError(context, 'Failed to reject appointment: $e');
        }
      }
    }
  }
}