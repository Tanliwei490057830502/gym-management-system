// screens/coach_home_page.dart - 修复头像显示问题 + 显示学生预约卡片
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String name = '';
  String title = '';
  String? profileImageUrl; // 添加头像URL变量
  bool isLoading = true;

  // 学生相关数据
  int totalStudents = 0;
  int checkedInStudents = 0;
  List<Map<String, dynamic>> studentsList = [];
  List<Map<String, dynamic>> todayCheckIns = [];
  List<Map<String, dynamic>> todayAppointments = []; // 改为显示预约信息

  @override
  void initState() {
    super.initState();
    _loadCoachData();
  }

  Future<void> _loadCoachData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _loadCoachInfo(user.uid);
      await _loadStudentsData(user.uid);
      await _loadTodayCheckIns(user.uid);
      await _loadTodayAppointments(user.uid); // 加载今日预约
    }
  }

  Future<void> _loadCoachInfo(String coachId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('coaches').doc(coachId).get();
      if (doc.exists) {
        setState(() {
          name = doc['name'] ?? 'Coach';
          title = doc['certification'] ?? 'Fitness Coach';
          profileImageUrl = doc['profileImageUrl']; // 加载头像URL
        });
      }
    } catch (e) {
      print('Error loading coach info: $e');
    }
  }

  Future<void> _loadStudentsData(String coachId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('coaches')
          .doc(coachId)
          .collection('students')
          .get();

      final List<Map<String, dynamic>> loadedStudents = [];
      for (var doc in snapshot.docs) {
        final studentId = doc.id;
        final studentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentId)
            .get();

        if (studentDoc.exists) {
          final studentData = studentDoc.data()!;
          loadedStudents.add({
            'uid': studentId,
            'name': studentData['name'] ?? studentData['username'] ?? 'Unknown Student',
            'email': studentData['email'] ?? '',
            'addedAt': doc.data()['addedAt'],
            'courseTitle': doc.data()['courseTitle'] ?? '',
          });
        }
      }

      setState(() {
        studentsList = loadedStudents;
        totalStudents = loadedStudents.length;
      });
    } catch (e) {
      print('Error loading students: $e');
    }
  }

  // 修改：使用现有的 check_ins 集合
  Future<void> _loadTodayCheckIns(String coachId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      print('🔍 查询今日签到数据...');

      // 查询今日所有签到记录
      final snapshot = await FirebaseFirestore.instance
          .collection('check_ins')
          .where('checkInDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('checkInDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .get();

      print('📊 找到 ${snapshot.docs.length} 条今日签到记录');

      final List<Map<String, dynamic>> todayCheckins = [];
      int checkedInCount = 0;
      Set<String> checkedInUserIds = {}; // 避免重复计算同一用户

      for (var doc in snapshot.docs) {
        final checkInData = doc.data();
        final userId = checkInData['userId'];

        // 检查这个用户是否是这个教练的学生
        final isStudent = studentsList.any((student) => student['uid'] == userId);

        if (isStudent) {
          print('✅ 学生 $userId 今日已签到');

          // 获取用户信息
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data()!;

            // 构建签到记录
            final checkInRecord = {
              'userId': userId,
              'userName': userData['name'] ?? userData['username'] ?? 'Unknown',
              'checkInTime': checkInData['checkInDate'],
              'checkInType': checkInData['checkInType'] ?? 'general',
              'itemType': checkInData['itemType'] ?? '',
              'itemTitle': checkInData['itemTitle'] ?? 'General Check-in',
            };

            // 添加额外信息（如果有的话）
            if (checkInData['totalDuration'] != null) {
              checkInRecord['duration'] = checkInData['totalDuration'];
            }

            todayCheckins.add(checkInRecord);

            // 计算签到学生数（去重）
            if (!checkedInUserIds.contains(userId)) {
              checkedInUserIds.add(userId);
              checkedInCount++;
            }
          }
        }
      }

      setState(() {
        todayCheckIns = todayCheckins;
        checkedInStudents = checkedInCount;
        isLoading = false;
      });

      print('✅ 今日签到数据加载完成: $checkedInCount/$totalStudents 学生已签到');
    } catch (e) {
      print('❌ Error loading check-ins: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // 🔄 修改为显示今日预约的方法
  Future<void> _loadTodayAppointments(String coachId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      print('🔍 查询今日预约数据...');

      final snapshot = await FirebaseFirestore.instance
          .collection('appointments')
          .where('coachId', isEqualTo: coachId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('date')
          .get();

      print('📊 找到 ${snapshot.docs.length} 条今日预约记录');

      final List<Map<String, dynamic>> appointments = [];
      for (var doc in snapshot.docs) {
        final appointmentData = doc.data();
        final userId = appointmentData['userId'];

        // 获取用户信息
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          appointments.add({
            'appointmentId': doc.id,
            'userId': userId,
            'userName': appointmentData['userName'] ?? userData['name'] ?? 'Unknown',
            'userEmail': appointmentData['userEmail'] ?? userData['email'] ?? '',
            'appointmentDate': appointmentData['date'],
            'timeSlot': appointmentData['timeSlot'] ?? '',
            'gymName': appointmentData['gymName'] ?? 'General Training',
            'coachApproval': appointmentData['coachApproval'] ?? 'pending',
            'adminApproval': appointmentData['adminApproval'] ?? 'pending',
            'overallStatus': appointmentData['overallStatus'] ?? 'pending',
            'createdAt': appointmentData['createdAt'],
          });
        }
      }

      setState(() {
        todayAppointments = appointments;
      });

      print('✅ 今日预约数据加载完成: ${appointments.length} 个预约');
    } catch (e) {
      print('❌ Error loading appointments: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 教练信息卡片
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange[100]!, Colors.orange[50]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                // 修复后的头像显示
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: profileImageUrl != null && profileImageUrl!.isNotEmpty
                      ? NetworkImage(profileImageUrl!)
                      : null,
                  child: profileImageUrl == null || profileImageUrl!.isEmpty
                      ? const Icon(
                    Icons.fitness_center,
                    size: 40,
                    color: Colors.orange,
                  )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name : 'Coach',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$totalStudents Students',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 今日学生签到进度
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bookmark, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'Today\'s student check-in progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$checkedInStudents/$totalStudents',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 动态进度条
                if (totalStudents > 0) ...[
                  Row(
                    children: List.generate(totalStudents > 8 ? 8 : totalStudents, (index) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 4),
                          height: 30,
                          decoration: BoxDecoration(
                            color: index < checkedInStudents ? Colors.orange : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      );
                    }),
                  ),
                  if (totalStudents > 8)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Showing first 8 of $totalStudents students',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ] else
                  const Text(
                    'No students yet',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),

                // 显示已签到的学生
                if (todayCheckIns.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Checked in today:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...todayCheckIns.map((checkIn) => Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            checkIn['userName'],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // 显示签到类型
                        if (checkIn['itemTitle'] != null && checkIn['itemTitle'].isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              checkIn['itemTitle'],
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        Text(
                          _formatTime(checkIn['checkInTime']),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 今日预约概览
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text(
                      'Today\'s appointment overview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${todayAppointments.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (todayAppointments.isEmpty)
                  const Text(
                    'No appointments today',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: todayAppointments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final appointment = entry.value;
                      return _buildAppointmentItem(
                        (index + 1).toString(),
                        '${appointment['userName']} has training session at ${appointment['timeSlot']}',
                        appointment['overallStatus'],
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 🔄 修改为今日学生预约 - 显示预约卡片
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text(
                      'Today\'s Student Appointments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    // 添加管理按钮，点击跳转到专门的预约管理页面
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/coach_reservations');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.settings,
                              size: 14,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Manage',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (todayAppointments.isEmpty)
                  const Text(
                    'No student appointments today',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  )
                else
                  Column(
                    children: todayAppointments.map((appointment) {
                      return _buildAppointmentCard(appointment);
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 新增：构建预约卡片
  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final coachApproval = appointment['coachApproval'] ?? 'pending';
    final adminApproval = appointment['adminApproval'] ?? 'pending';
    final overallStatus = appointment['overallStatus'] ?? 'pending';
    final userName = appointment['userName'] ?? 'Unknown User';
    final userEmail = appointment['userEmail'] ?? '';
    final timeSlot = appointment['timeSlot'] ?? 'TBD';
    final gymName = appointment['gymName'] ?? 'General Training';

    // 根据状态确定卡片颜色
    Color cardColor;
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (overallStatus) {
      case 'confirmed':
        cardColor = Colors.green.shade50;
        statusColor = Colors.green;
        statusText = 'Confirmed';
        statusIcon = Icons.check_circle;
        break;
      case 'completed':
        cardColor = Colors.purple.shade50;
        statusColor = Colors.purple;
        statusText = 'Completed';
        statusIcon = Icons.done_all;
        break;
      case 'cancelled':
        cardColor = Colors.red.shade50;
        statusColor = Colors.red;
        statusText = 'Cancelled';
        statusIcon = Icons.cancel;
        break;
      default:
        if (coachApproval == 'approved' && adminApproval == 'approved') {
          cardColor = Colors.blue.shade50;
          statusColor = Colors.blue;
          statusText = 'Ready to Confirm';
          statusIcon = Icons.pending_actions;
        } else if (coachApproval == 'approved') {
          cardColor = Colors.blue.shade50;
          statusColor = Colors.blue;
          statusText = 'Coach Approved';
          statusIcon = Icons.schedule;
        } else if (coachApproval == 'rejected') {
          cardColor = Colors.red.shade50;
          statusColor = Colors.red;
          statusText = 'Rejected by Coach';
          statusIcon = Icons.cancel;
        } else {
          cardColor = Colors.orange.shade50;
          statusColor = Colors.orange;
          statusText = 'Pending Coach Approval';
          statusIcon = Icons.schedule;
        }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 上半部分：用户信息和状态
          Row(
            children: [
              // 用户头像
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.purple[100],
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: Colors.purple[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 用户信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    if (userEmail.isNotEmpty)
                      Text(
                        userEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              // 状态徽章
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 下半部分：预约详情
          Row(
            children: [
              // 时间信息
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Time:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      timeSlot,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // 健身房信息
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Gym:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      gymName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 双重批准状态显示（如果是pending状态）
          if (overallStatus == 'pending') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildApprovalBadge('Coach', coachApproval),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.add, color: Colors.blue.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildApprovalBadge('Admin', adminApproval),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 🆕 新增：构建批准徽章
  Widget _buildApprovalBadge(String title, String approval) {
    Color badgeColor;
    IconData badgeIcon;

    switch (approval) {
      case 'approved':
        badgeColor = Colors.green;
        badgeIcon = Icons.check_circle;
        break;
      case 'rejected':
        badgeColor = Colors.red;
        badgeIcon = Icons.cancel;
        break;
      default:
        badgeColor = Colors.orange;
        badgeIcon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$title: ${approval.toUpperCase()}',
              style: TextStyle(
                fontSize: 9,
                color: badgeColor,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentItem(String number, String text, String status) {
    Color statusColor;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      case 'confirmed':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getColorWithOpacity(statusColor, 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _getColorWithOpacity(statusColor, 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getColorWithOpacity(statusColor, 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return '';
    }

    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 辅助方法：获取带透明度的颜色
  Color _getColorWithOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
}