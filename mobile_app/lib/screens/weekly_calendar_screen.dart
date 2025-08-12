// screens/weekly_calendar_screen.dart - 支持双重批准系统
import 'package:flutter/material.dart';
import 'appointment_schedule_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WeeklyCalendarScreen extends StatefulWidget {
  const WeeklyCalendarScreen({super.key});

  @override
  State<WeeklyCalendarScreen> createState() => _WeeklyCalendarScreenState();
}

class _WeeklyCalendarScreenState extends State<WeeklyCalendarScreen> {
  int _selectedIndex = 1;
  DateTime selectedDate = DateTime.now();
  String selectedCoachId = 'coach1';
  String selectedGymId = 'gym1';
  Map<String, dynamic>? latestAppointment;

  @override
  void initState() {
    super.initState();
    _loadLatestAppointment();
  }

  void _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AppointmentScheduleScreen(
            preselectedDate: selectedDate,
            preselectedCoachId: selectedCoachId,
            preselectedGymId: selectedGymId,
          ),
        ),
      );

      if (result != null && result is Map<String, dynamic>) {
        setState(() {
          selectedDate = result['date'] ?? selectedDate;
          selectedCoachId = result['coachId'] ?? selectedCoachId;
          selectedGymId = result['gymId'] ?? selectedGymId;
        });
        _loadLatestAppointment();
      }
    } else {
      Navigator.pushReplacementNamed(context, '/main', arguments: {'initialIndex': index});
    }
  }

  // 更新的预约加载方法 - 支持双重批准系统
  Future<void> _loadLatestAppointment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      print('🔍 周历页面加载预约，用户ID: ${user.uid}');

      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: user.uid)
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final appointmentData = snapshot.docs.first.data();
        print('📋 周历页面找到预约: ${appointmentData['overallStatus']}');

        // 确保获取正确的健身房和教练名称
        String? coachName = appointmentData['coachName'];
        String? gymName = appointmentData['gymName'];

        // 如果显示为 Unknown，尝试从数据库重新获取
        if (coachName == null || coachName == 'Unknown Coach') {
          if (appointmentData['coachId'] != null) {
            try {
              final coachDoc = await FirebaseFirestore.instance.collection('users').doc(appointmentData['coachId']).get();
              if (coachDoc.exists) {
                coachName = coachDoc.data()?['name'] ?? 'Unknown Coach';
                print('📝 周历页面从用户集合获取教练名称: $coachName');
              }
            } catch (e) {
              print('❌ 周历页面获取教练名称失败: $e');
              coachName = 'Unknown Coach';
            }
          }
        }

        if (gymName == null || gymName == 'Unknown Gym') {
          if (appointmentData['gymId'] != null) {
            try {
              final gymDoc = await FirebaseFirestore.instance.collection('gyms').doc(appointmentData['gymId']).get();
              if (gymDoc.exists) {
                gymName = gymDoc.data()?['name'] ?? 'Unknown Gym';
                print('📝 周历页面从健身房集合获取健身房名称: $gymName');
              }
            } catch (e) {
              print('❌ 周历页面获取健身房名称失败: $e');
              gymName = 'Unknown Gym';
            }
          }
        }

        setState(() {
          latestAppointment = {
            ...appointmentData,
            'coachName': coachName,
            'gymName': gymName,
            'date': appointmentData['date'] is Timestamp
                ? appointmentData['date']
                : Timestamp.fromDate(DateTime.parse(appointmentData['date'])),
            // 双重批准系统字段
            'coachApproval': appointmentData['coachApproval'] ?? 'pending',
            'adminApproval': appointmentData['adminApproval'] ?? 'pending',
            'overallStatus': appointmentData['overallStatus'] ?? appointmentData['status'] ?? 'pending',
          };
        });
        print('✅ 周历页面预约数据加载完成');
      } else {
        setState(() {
          latestAppointment = null;
        });
        print('📭 周历页面没有找到预约');
      }
    } catch (e) {
      print('❌ 周历页面预约加载错误: $e');
      setState(() {
        latestAppointment = null;
      });
    }
  }

  // 更新的状态颜色方法 - 支持双重批准
  Color _getStatusColor(String? overallStatus, String? coachApproval, String? adminApproval) {
    switch (overallStatus) {
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
      // 对于pending状态，根据批准情况显示不同颜色
        if (coachApproval == 'approved' && adminApproval == 'approved') {
          return Colors.green; // 双重批准但尚未确认
        } else if (coachApproval == 'approved' || adminApproval == 'approved') {
          return Colors.blue; // 部分批准
        } else if (coachApproval == 'rejected' || adminApproval == 'rejected') {
          return Colors.red; // 被拒绝
        } else {
          return Colors.orange; // 等待批准
        }
    }
  }

  // 更新的状态文本方法 - 支持双重批准
  String _getStatusText(String? overallStatus, String? coachApproval, String? adminApproval) {
    switch (overallStatus) {
      case 'confirmed':
        return '✅ Confirmed';
      case 'completed':
        return '🎉 Completed';
      case 'cancelled':
        return '❌ Cancelled';
      default:
      // 对于pending状态，显示详细进度
        if (coachApproval == 'approved' && adminApproval == 'approved') {
          return '🔄 Ready to Confirm';
        } else if (coachApproval == 'approved' && adminApproval == 'pending') {
          return '⏳ Coach ✓, Waiting Admin';
        } else if (coachApproval == 'pending' && adminApproval == 'approved') {
          return '⏳ Admin ✓, Waiting Coach';
        } else if (coachApproval == 'rejected' || adminApproval == 'rejected') {
          return '❌ Rejected';
        } else {
          return '⏳ Waiting for Dual Approval';
        }
    }
  }

  // 获取当前预约的状态颜色
  Color _getCurrentStatusColor() {
    if (latestAppointment == null) return Colors.grey;

    return _getStatusColor(
      latestAppointment!['overallStatus'],
      latestAppointment!['coachApproval'],
      latestAppointment!['adminApproval'],
    );
  }

  // 获取当前预约的状态文本
  String _getCurrentStatusText() {
    if (latestAppointment == null) return '❓ No Appointment';

    return _getStatusText(
      latestAppointment!['overallStatus'],
      latestAppointment!['coachApproval'],
      latestAppointment!['adminApproval'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Weekly Calendar',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: _getCurrentStatusColor(),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _getCurrentStatusColor().withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (latestAppointment != null && latestAppointment!['date'] != null && latestAppointment!['date'] is Timestamp) ...[
                    // Status header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Latest Appointment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getCurrentStatusText(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Appointment details
                    _buildDetailRow('📅 Date', (latestAppointment!['date'] as Timestamp).toDate().toLocal().toString().split(" ")[0]),
                    const SizedBox(height: 8),
                    _buildDetailRow('👨‍🏫 Coach', latestAppointment!['coachName'] ?? 'Unknown Coach'),
                    const SizedBox(height: 8),
                    _buildDetailRow('🏋️ Gym', latestAppointment!['gymName'] ?? 'Unknown Gym'),
                    const SizedBox(height: 8),
                    _buildDetailRow('⏰ Time', latestAppointment!['timeSlot'] ?? ''),

                    // 添加批准状态显示（仅在pending状态时显示）
                    if (latestAppointment!['overallStatus'] == 'pending') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Approval Progress:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildApprovalBadge(
                                    'Coach',
                                    latestAppointment!['coachApproval'] ?? 'pending',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildApprovalBadge(
                                    'Admin',
                                    latestAppointment!['adminApproval'] ?? 'pending',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 进度条
                            _buildApprovalProgressBar(),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    const Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 48,
                            color: Colors.white,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No appointment scheduled.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Book your first session with dual approval!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppointmentScheduleScreen(
                      preselectedDate: selectedDate,
                      preselectedCoachId: selectedCoachId,
                      preselectedGymId: selectedGymId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline),
              label: Text(
                latestAppointment != null
                    ? 'Make New Appointment'
                    : 'Make Appointment',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            // Show appointment history button if there are appointments
            if (latestAppointment != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  // Navigate to appointment history
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Appointment history feature coming soon!')),
                  );
                },
                icon: const Icon(Icons.history),
                label: const Text('View Appointment History'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  side: const BorderSide(color: Colors.deepPurple),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],

            // 添加双重批准系统说明
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Dual Approval System',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All appointments require approval from both your coach and our admin team to ensure the best training experience.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildSystemStepBadge('1', 'Submit', Colors.orange),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      _buildSystemStepBadge('2', 'Dual Approval', Colors.blue),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      _buildSystemStepBadge('3', 'Confirmed', Colors.green),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  // 新增：批准状态徽章
  Widget _buildApprovalBadge(String title, String status) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$title: ${status.toUpperCase()}',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 新增：批准进度条
  Widget _buildApprovalProgressBar() {
    if (latestAppointment == null) return const SizedBox.shrink();

    final coachApproval = latestAppointment!['coachApproval'] ?? 'pending';
    final adminApproval = latestAppointment!['adminApproval'] ?? 'pending';

    int approvedCount = 0;
    if (coachApproval == 'approved') approvedCount++;
    if (adminApproval == 'approved') approvedCount++;

    double progress = approvedCount / 2.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress: $approvedCount/2 approvals',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white.withOpacity(0.3),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          minHeight: 4,
        ),
      ],
    );
  }

  // 新增：系统步骤徽章
  Widget _buildSystemStepBadge(String step, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}