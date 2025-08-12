// gym_app_system/lib/screens/coach_reservation_status_screen.dart
// 用途：教练管理学员预约请求 - 支持双重批准机制
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/coach_service.dart';

class CoachReservationStatusScreen extends StatefulWidget {
  const CoachReservationStatusScreen({super.key});

  @override
  State<CoachReservationStatusScreen> createState() => _CoachReservationStatusScreenState();
}

class _CoachReservationStatusScreenState extends State<CoachReservationStatusScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedFilter = 'pending'; // pending, approved, rejected, confirmed, completed, all

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to continue')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Manage Appointments',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[800],
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header with gradient background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue[800]!, Colors.blue[600]!],
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Coach Approval System',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Appointments need both coach and admin approval',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('appointments')
                      .where('coachId', isEqualTo: currentUser.uid)
                      .where('coachApproval', isEqualTo: 'pending')
                      .where('overallStatus', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final pendingCount = snapshot.data?.docs.length ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$pendingCount Pending Coach Approval${pendingCount != 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Filter tabs
          Container(
            color: Colors.grey[100],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterTab('Pending', 'pending', Icons.schedule, Colors.orange),
                  _buildFilterTab('Approved', 'approved', Icons.check_circle, Colors.green),
                  _buildFilterTab('Rejected', 'rejected', Icons.cancel, Colors.red),
                  _buildFilterTab('Confirmed', 'confirmed', Icons.verified, Colors.blue),
                  _buildFilterTab('Completed', 'completed', Icons.done_all, Colors.purple),
                  _buildFilterTab('All', 'all', Icons.list, Colors.grey),
                ],
              ),
            ),
          ),

          // Table header
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: const Row(
              children: [
                Expanded(flex: 1, child: Text('User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 2, child: Text('Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 2, child: Text('Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 2, child: Text('Approval Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                Expanded(flex: 1, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
              ],
            ),
          ),

          // Appointments list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getAppointmentsStream(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final appointments = snapshot.data?.docs ?? [];

                if (appointments.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final appointment = appointments[index];
                    final data = appointment.data() as Map<String, dynamic>;

                    return _buildAppointmentRow(
                      appointment.id,
                      data,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, String value, IconData icon, Color color) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? color : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? color : Colors.grey[600],
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Stream<QuerySnapshot> _getAppointmentsStream(String coachId) {
    Query query = FirebaseFirestore.instance
        .collection('appointments')
        .where('coachId', isEqualTo: coachId)
        .orderBy('date', descending: false);

    switch (_selectedFilter) {
      case 'pending':
        query = query.where('coachApproval', isEqualTo: 'pending');
        query = query.where('overallStatus', isEqualTo: 'pending');
        break;
      case 'approved':
        query = query.where('coachApproval', isEqualTo: 'approved');
        break;
      case 'rejected':
        query = query.where('coachApproval', isEqualTo: 'rejected');
        break;
      case 'confirmed':
        query = query.where('overallStatus', isEqualTo: 'confirmed');
        break;
      case 'completed':
        query = query.where('overallStatus', isEqualTo: 'completed');
        break;
    // 'all' case - no additional filtering
    }

    return query.snapshots();
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_selectedFilter) {
      case 'pending':
        message = 'No pending coach approvals';
        icon = Icons.schedule;
        break;
      case 'approved':
        message = 'No approved appointments';
        icon = Icons.check_circle_outline;
        break;
      case 'rejected':
        message = 'No rejected appointments';
        icon = Icons.cancel_outlined;
        break;
      case 'confirmed':
        message = 'No confirmed appointments';
        icon = Icons.verified_outlined;
        break;
      case 'completed':
        message = 'No completed appointments';
        icon = Icons.done_all;
        break;
      default:
        message = 'No appointments found';
        icon = Icons.event_busy;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Student appointment requests will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentRow(String appointmentId, Map<String, dynamic> data) {
    final coachApproval = data['coachApproval'] ?? 'pending';
    final adminApproval = data['adminApproval'] ?? 'pending';
    final overallStatus = data['overallStatus'] ?? 'pending';
    final date = (data['date'] as Timestamp?)?.toDate();
    final timeSlot = data['timeSlot'] ?? '';
    final userName = data['userName'] ?? 'Unknown User';
    final userEmail = data['userEmail'] ?? '';
    final gymName = data['gymName'] ?? 'General Training';

    // Format date and time
    final dateStr = date != null
        ? '${date.day}/${date.month}/${date.year}'
        : 'TBD';
    final timeStr = timeSlot.isNotEmpty ? timeSlot : 'TBD';

    // Status colors and icons based on overall status
    Color statusColor;
    IconData statusIcon;

    switch (overallStatus) {
      case 'confirmed':
        statusColor = Colors.green;
        statusIcon = Icons.verified;
        break;
      case 'completed':
        statusColor = Colors.purple;
        statusIcon = Icons.done_all;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        if (coachApproval == 'approved' && adminApproval == 'approved') {
          statusColor = Colors.green;
          statusIcon = Icons.verified;
        } else if (coachApproval == 'approved' || adminApproval == 'approved') {
          statusColor = Colors.blue;
          statusIcon = Icons.pending_actions;
        } else if (coachApproval == 'rejected' || adminApproval == 'rejected') {
          statusColor = Colors.red;
          statusIcon = Icons.cancel;
        } else {
          statusColor = Colors.orange;
          statusIcon = Icons.schedule;
        }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
        color: coachApproval == 'rejected'
            ? Colors.red.shade50
            : coachApproval == 'approved'
            ? Colors.green.shade50
            : Colors.white,
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Row(
        children: [
          // User avatar and info
          Expanded(
            flex: 1,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.purple[100],
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: TextStyle(
                      color: Colors.purple[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 14,
                ),
              ],
            ),
          ),

          // Name and details
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (userEmail.isNotEmpty)
                    Text(
                      userEmail.length > 15 ? '${userEmail.substring(0, 15)}...' : userEmail,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    gymName.length > 15 ? '${gymName.substring(0, 15)}...' : gymName,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Schedule
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    timeStr.length > 12 ? '${timeStr.substring(0, 12)}...' : timeStr,
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Approval Status
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  // Coach approval
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getApprovalColor(coachApproval).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: _getApprovalColor(coachApproval).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getApprovalIcon(coachApproval),
                          size: 8,
                          color: _getApprovalColor(coachApproval),
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            'C:${coachApproval.substring(0, 3).toUpperCase()}',
                            style: TextStyle(
                              color: _getApprovalColor(coachApproval),
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 1),
                  // Admin approval
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getApprovalColor(adminApproval).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: _getApprovalColor(adminApproval).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getApprovalIcon(adminApproval),
                          size: 8,
                          color: _getApprovalColor(adminApproval),
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            'A:${adminApproval.substring(0, 3).toUpperCase()}',
                            style: TextStyle(
                              color: _getApprovalColor(adminApproval),
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Actions
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Accept button
                    if (coachApproval == 'pending' && overallStatus == 'pending')
                      GestureDetector(
                        onTap: () => _updateCoachApproval(appointmentId, 'approved'),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      )
                    else if (coachApproval == 'approved')
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),

                    const SizedBox(width: 2),

                    // Reject button
                    if (coachApproval == 'pending' && overallStatus == 'pending')
                      GestureDetector(
                        onTap: () => _showRejectDialog(appointmentId),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      )
                    else if (coachApproval == 'rejected')
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                  ],
                ),
                // Complete button for confirmed appointments (separate row)
                if (overallStatus == 'confirmed' && date != null && date.isBefore(DateTime.now())) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () => _updateAppointmentStatus(appointmentId, 'completed'),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Icon(
                        Icons.done,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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

  Future<void> _updateCoachApproval(String appointmentId, String approval) async {
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

      // 检查是否需要自动确认预约
      await _checkAndAutoConfirm(appointmentId);

      if (mounted) {
        String message;
        Color backgroundColor;

        switch (approval) {
          case 'approved':
            message = '✅ Coach approval granted!';
            backgroundColor = Colors.green;
            break;
          case 'rejected':
            message = '❌ Coach rejected appointment!';
            backgroundColor = Colors.red;
            break;
          default:
            message = 'Coach approval updated!';
            backgroundColor = Colors.blue;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating coach approval: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
        final data = doc.data() as Map<String, dynamic>;
        final coachApproval = data['coachApproval'] ?? 'pending';
        final adminApproval = data['adminApproval'] ?? 'pending';
        final overallStatus = data['overallStatus'] ?? 'pending';

        if (coachApproval == 'approved' && adminApproval == 'approved' && overallStatus == 'pending') {
          // 双重批准完成，自动确认预约
          await FirebaseFirestore.instance
              .collection('appointments')
              .doc(appointmentId)
              .update({
            'overallStatus': 'confirmed',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎉 Appointment fully confirmed!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else if (coachApproval == 'rejected' && overallStatus == 'pending') {
          // 教练拒绝，自动取消预约
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

  Future<void> _updateAppointmentStatus(String appointmentId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
        'overallStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (newStatus == 'completed') 'completedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Appointment marked as $newStatus!'),
            backgroundColor: Colors.purple,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating appointment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            const Text('Are you sure you want to reject this appointment as coach?'),
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
          'coachApproval': 'rejected',
          'coachRejectReason': reasonController.text.trim(),
          'overallStatus': 'cancelled', // 任一方拒绝就取消整个预约
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Appointment rejected by coach!'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error rejecting appointment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}