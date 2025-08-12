// screens/home_tab_screen.dart - 支持双重批准系统
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeTabScreen extends StatefulWidget {
  const HomeTabScreen({super.key});

  @override
  State<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen> with AutomaticKeepAliveClientMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _purchasedCourses = [];
  List<Map<String, dynamic>> _aiPlans = [];
  Map<String, dynamic>? _latestAppointment;
  bool _isLoading = true;
  bool _hasCheckedInToday = false;
  Map<String, dynamic>? _todayCheckInData;
  Set<String> _todayCheckedInItems = {}; // Track what items were checked in today

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupCheckInListener();
    _setupAIPlansListener(); // 添加AI计划实时监听

    // 添加调试调用
    Future.delayed(const Duration(seconds: 2), () {
      _debugCheckAppointments();
    });
  }

  // 📊 调试方法：检查用户所有预约
  Future<void> _debugCheckAppointments() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('🔍 调试：检查用户所有预约，用户ID: ${user.uid}');

      final allAppointments = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      print('📊 总预约数量: ${allAppointments.docs.length}');

      if (allAppointments.docs.isEmpty) {
        print('❌ 没有找到任何预约数据');
        return;
      }

      for (var doc in allAppointments.docs) {
        final data = doc.data();
        final appointmentDate = (data['date'] as Timestamp).toDate();
        final now = DateTime.now();
        final isUpcoming = appointmentDate.isAfter(DateTime(now.year, now.month, now.day));

        print('📋 预约详情:');
        print('   - ID: ${doc.id}');
        print('   - 日期: $appointmentDate');
        print('   - 时间: ${data['timeSlot']}');
        print('   - 状态: ${data['overallStatus']}');
        print('   - 是否未来: $isUpcoming');
        print('   - 教练: ${data['coachName']}');
        print('   - 健身房: ${data['gymName']}');
        print('   - 创建时间: ${data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : 'null'}');
        print('   ---');
      }
    } catch (e) {
      print('❌ 调试检查失败: $e');
    }
  }

  // 添加AI计划实时监听
  void _setupAIPlansListener() {
    final user = _auth.currentUser;
    if (user != null) {
      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('ai_plans')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          _loadAIPlansFromSnapshot(snapshot, user.uid);
        }
      });
    }
  }

  // 从快照加载AI计划数据
  Future<void> _loadAIPlansFromSnapshot(QuerySnapshot snapshot, String userId) async {
    try {
      List<Map<String, dynamic>> plans = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        // 计算基于实际训练签到的进度
        await _calculateActualTrainingProgress(data, userId);
        plans.add(data);
      }

      if (mounted) {
        setState(() {
          _aiPlans = plans;
        });
        print('🔄 AI计划数据已更新，共${plans.length}个计划');
      }
    } catch (e) {
      print('Error loading AI plans from snapshot: $e');
    }
  }

  void _setupCheckInListener() {
    final user = _auth.currentUser;
    if (user != null) {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      _firestore
          .collection('check_ins')
          .where('userId', isEqualTo: user.uid)
          .where('checkInDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('checkInDate', isLessThan: Timestamp.fromDate(endOfDay))
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          setState(() {
            _hasCheckedInToday = snapshot.docs.isNotEmpty;
            _todayCheckedInItems.clear();

            for (var doc in snapshot.docs) {
              final data = doc.data();
              // Track which specific items were checked in today
              if (data['itemType'] != null && data['itemId'] != null) {
                _todayCheckedInItems.add('${data['itemType']}_${data['itemId']}');
              }
              // 添加AI计划训练签到跟踪
              if (data['aiPlanId'] != null) {
                _todayCheckedInItems.add('ai_plan_${data['aiPlanId']}');
              }
            }

            if (snapshot.docs.isNotEmpty) {
              _todayCheckInData = snapshot.docs.first.data();
            } else {
              _todayCheckInData = null;
            }
          });

          // 当签到状态变化时，重新加载AI计划进度
          if (snapshot.docs.isNotEmpty) {
            final hasAITraining = snapshot.docs.any((doc) =>
            doc.data()['aiPlanId'] != null &&
                doc.data()['checkInType'] == 'training_completed'
            );
            if (hasAITraining) {
              print('🔥 检测到AI训练完成，重新加载AI计划进度');
              _loadAIPlans(user.uid);
            }
          }
        }
      });
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _loadBasicUserData(user.uid);
        await _loadPurchasedCourses(user.uid);
        await _loadAIPlans(user.uid);
        await _loadLatestAppointment(user.uid);
        await _checkTodayCheckIn(user.uid);
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBasicUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        setState(() {
          _userData = doc.data();
        });
      }
    } catch (e) {
      print('Error loading basic user data: $e');
    }
  }

  // 修复：更准确的AI计划进度计算
  Future<void> _loadAIPlans(String uid) async {
    try {
      print('🔍 开始加载AI计划数据...');

      final querySnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('ai_plans')
          .orderBy('createdAt', descending: true)
          .limit(5) // 显示最近5个计划
          .get();

      List<Map<String, dynamic>> plans = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        // 计算基于实际训练签到的进度
        await _calculateActualTrainingProgress(data, uid);
        plans.add(data);

        print('📋 计划 ${data['title']}: ${data['actualTrainingDays']}/${data['durationDays']} 天 (${data['progressPercentage'].toInt()}%)');
      }

      if (mounted) {
        setState(() {
          _aiPlans = plans;
        });
        print('✅ AI计划数据加载完成，共${plans.length}个计划');
      }
    } catch (e) {
      print('❌ Error loading AI plans: $e');
      if (mounted) {
        setState(() {
          _aiPlans = [];
        });
      }
    }
  }

  // 在 home_tab_screen.dart 中替换这两个方法：

// 1. 替换 _calculateActualTrainingProgress 方法
  Future<void> _calculateActualTrainingProgress(Map<String, dynamic> planData, String userId) async {
    try {
      final planId = planData['id'];
      final totalDays = (planData['durationDays'] as num?)?.toInt() ?? 0;
      final createdAt = planData['createdAt'] as Timestamp?;

      if (createdAt == null || totalDays == 0) {
        planData['actualTrainingDays'] = 0;
        planData['progressPercentage'] = 0.0;
        planData['isCompleted'] = planData['isCompleted'] ?? false;
        return;
      }

      final planStartDate = createdAt.toDate();

      print('🔍 首页计算AI计划进度，计划ID: $planId');

      final checkInQuery = await _firestore
          .collection('check_ins')
          .where('userId', isEqualTo: userId)
          .where('aiPlanId', isEqualTo: planId)
          .where('checkInType', isEqualTo: 'training_completed')
          .where('checkInDate', isGreaterThanOrEqualTo: Timestamp.fromDate(planStartDate))
          .get();

      print('📊 首页找到 ${checkInQuery.docs.length} 条训练记录');

      final actualTrainingDays = checkInQuery.docs.length;
      final progressPercentage = totalDays > 0
          ? ((actualTrainingDays / totalDays) * 100).clamp(0.0, 100.0)
          : 0.0;

      final wasManuallyCompleted = planData['isCompleted'] == true;
      final shouldAutoComplete = actualTrainingDays >= totalDays;
      final isCompleted = wasManuallyCompleted || shouldAutoComplete;

      if (shouldAutoComplete && !wasManuallyCompleted) {
        try {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('ai_plans')
              .doc(planId)
              .update({
            'isCompleted': true,
            'completedAt': FieldValue.serverTimestamp(),
            'progressPercentage': 100.0,
            'autoCompletedByTraining': true,
          });
          print('✅ 首页：AI计划 $planId 已自动完成');
        } catch (e) {
          print('❌ 首页：自动完成AI计划失败: $e');
        }
      }

      planData['actualTrainingDays'] = actualTrainingDays;
      planData['progressPercentage'] = double.parse(progressPercentage.toStringAsFixed(1));
      planData['isCompleted'] = isCompleted;
      planData['remainingDays'] = (totalDays - actualTrainingDays).clamp(0, totalDays);

      print('📈 首页计划$planId进度: $actualTrainingDays/$totalDays 天 (${progressPercentage.toStringAsFixed(1)}%)');

    } catch (e) {
      print('❌ 首页计算进度错误 ${planData['id']}: $e');
      planData['actualTrainingDays'] = 0;
      planData['progressPercentage'] = 0.0;
      planData['isCompleted'] = planData['isCompleted'] ?? false;
    }
  }

  // 修复后的课程加载方法 - 直接使用 user_courses 数据
  Future<void> _loadPurchasedCourses(String uid) async {
    try {
      print('🔍 开始加载用户课程，用户ID: $uid');

      final querySnapshot = await _firestore
          .collection('user_courses')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .orderBy('purchaseDate', descending: true)
          .get();

      print('📊 查询到的课程数量: ${querySnapshot.docs.length}');

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _purchasedCourses = [];
        });
        return;
      }

      // 直接使用 user_courses 数据，不依赖 courses 集合
      List<Map<String, dynamic>> courses = [];

      for (var doc in querySnapshot.docs) {
        final courseData = doc.data();
        print('📄 处理课程: ${courseData['title']}');

        // 直接构建课程数据
        final course = _buildCourseDataFromUserCourse(doc.id, courseData);
        courses.add(course);
      }

      print('📋 最终处理的课程数量: ${courses.length}');

      if (mounted) {
        setState(() {
          _purchasedCourses = courses;
        });
        print('✅ 课程数据已更新到UI');
      }
    } catch (e) {
      print('❌ Error loading purchased courses: $e');
      if (mounted) {
        setState(() {
          _purchasedCourses = [];
        });
      }
      _showErrorSnackBar('Failed to load courses. Please try again.');
    }
  }

  // 新方法：直接从 user_courses 数据构建课程信息
  Map<String, dynamic> _buildCourseDataFromUserCourse(String docId, Map<String, dynamic> courseData) {
    // Safe extraction with default values
    final totalSessions = (courseData['totalSessions'] as num?)?.toInt() ?? 8;
    final remainingSessions = (courseData['remainingSessions'] as num?)?.toInt() ?? 8;
    final completedSessions = (totalSessions - remainingSessions).clamp(0, totalSessions);

    // Calculate progress percentage with division by zero protection
    final progressPercentage = totalSessions > 0
        ? ((completedSessions / totalSessions) * 100).clamp(0.0, 100.0)
        : 0.0;

    // Safe date handling
    bool isExpired = false;
    Timestamp? expiryTimestamp;

    if (courseData['expiryDate'] != null) {
      try {
        expiryTimestamp = courseData['expiryDate'] as Timestamp;
        final expiryDate = expiryTimestamp.toDate();
        isExpired = DateTime.now().isAfter(expiryDate);
      } catch (e) {
        print('Error parsing expiry date for course $docId: $e');
      }
    }

    // 使用 user_courses 中的数据，或提供默认值
    return {
      // Course info from user_courses collection
      'title': courseData['title'] as String? ?? 'Untitled Course',
      'category': courseData['category'] as String? ?? 'Fitness',
      'description': _getDefaultDescription(courseData['title'] as String? ?? ''),
      'imageUrl': _getDefaultImageUrl(courseData['title'] as String? ?? ''),

      // User course data
      'userCourseId': docId,
      'courseId': courseData['courseId'] as String?,
      'purchaseDate': courseData['purchaseDate'] as Timestamp?,
      'expiryDate': expiryTimestamp,
      'paymentAmount': (courseData['paymentAmount'] as num?)?.toDouble() ?? 99.0,
      'status': courseData['status'] as String? ?? 'active',

      // Calculated fields
      'totalSessions': totalSessions,
      'remainingSessions': remainingSessions,
      'completedSessions': completedSessions,
      'progressPercentage': progressPercentage,
      'isExpired': isExpired,

      // Additional computed properties
      'isCompleted': completedSessions >= totalSessions,
      'canAttendSession': !isExpired && remainingSessions > 0,
    };
  }

  // 获取默认描述的辅助方法
  String _getDefaultDescription(String title) {
    switch (title) {
      case 'Muscle Building Plan':
        return 'Build lean muscle and increase strength with our comprehensive muscle building program.';
      case 'Fat Burning Program':
        return 'Burn calories and lose fat with high-intensity interval training and cardio workouts.';
      case 'Core & Posture Training':
        return 'Strengthen your core and improve posture with targeted exercises and techniques.';
      default:
        return 'Comprehensive fitness program designed to meet your specific goals.';
    }
  }

  // 获取默认图片URL的辅助方法
  String? _getDefaultImageUrl(String title) {
    switch (title) {
      case 'Muscle Building Plan':
        return 'assets/images/muscle_building.jpg';
      case 'Fat Burning Program':
        return 'assets/images/fat_burning.jpg';
      case 'Core & Posture Training':
        return 'assets/images/core_training.jpg';
      default:
        return null;
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _loadUserData(),
          ),
        ),
      );
    }
  }

  // 🔧 修复后的预约加载方法 - 支持双重批准系统
  Future<void> _loadLatestAppointment(String uid) async {
    try {
      print('🔍 加载最新预约，用户ID: $uid');

      // 修复：使用今天的开始时间而不是当前时间
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      print('📅 查询条件 - 今天开始时间: $startOfToday');
      print('📅 当前时间: $now');

      final snapshot = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday)) // 使用今天开始时间
          .orderBy('date', descending: false)
          .limit(1)
          .get();

      print('📊 查询结果数量: ${snapshot.docs.length}');

      if (snapshot.docs.isNotEmpty) {
        final appointmentData = snapshot.docs.first.data();
        final appointmentDate = (appointmentData['date'] as Timestamp).toDate();

        print('📋 找到预约数据:');
        print('   - 预约日期: $appointmentDate');
        print('   - 总体状态: ${appointmentData['overallStatus']}');
        print('   - 教练批准: ${appointmentData['coachApproval']}');
        print('   - 管理员批准: ${appointmentData['adminApproval']}');

        // 确保获取正确的健身房和教练名称
        String? coachName = appointmentData['coachName'];
        String? gymName = appointmentData['gymName'];

        // 如果显示为 Unknown，尝试从数据库重新获取
        if (coachName == null || coachName == 'Unknown Coach') {
          if (appointmentData['coachId'] != null) {
            try {
              final coachDoc = await _firestore.collection('users').doc(appointmentData['coachId']).get();
              if (coachDoc.exists) {
                coachName = coachDoc.data()?['name'] ?? 'Unknown Coach';
                print('📝 从用户集合获取教练名称: $coachName');
              }
            } catch (e) {
              print('❌ 获取教练名称失败: $e');
              coachName = 'Unknown Coach';
            }
          }
        }

        if (gymName == null || gymName == 'Unknown Gym') {
          if (appointmentData['gymId'] != null) {
            try {
              final gymDoc = await _firestore.collection('gyms').doc(appointmentData['gymId']).get();
              if (gymDoc.exists) {
                gymName = gymDoc.data()?['name'] ?? 'Unknown Gym';
                print('📝 从健身房集合获取健身房名称: $gymName');
              }
            } catch (e) {
              print('❌ 获取健身房名称失败: $e');
              gymName = 'Unknown Gym';
            }
          }
        }

        setState(() {
          _latestAppointment = {
            ...appointmentData,
            'coachName': coachName,
            'gymName': gymName,
            'date': appointmentData['date'] is Timestamp
                ? appointmentData['date']
                : Timestamp.fromDate(DateTime.parse(appointmentData['date'])),
            // 双重批准系统字段
            'coachApproval': appointmentData['coachApproval'] ?? 'pending',
            'adminApproval': appointmentData['adminApproval'] ?? 'pending',
            'overallStatus': appointmentData['overallStatus'] ?? 'pending',
          };
        });
        print('✅ 预约数据加载完成');
      } else {
        // 如果没有找到未来预约，检查是否有任何预约（用于调试）
        print('📭 没有找到未来的预约，检查是否有任何预约...');

        final allAppointments = await _firestore
            .collection('appointments')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();

        print('📊 用户总预约数量: ${allAppointments.docs.length}');

        for (var doc in allAppointments.docs) {
          final data = doc.data();
          final appointmentDate = (data['date'] as Timestamp).toDate();
          print('   - 预约: $appointmentDate, 状态: ${data['overallStatus']}');
        }

        setState(() {
          _latestAppointment = null;
        });
        print('📭 设置为无预约状态');
      }
    } catch (e) {
      print('❌ Error loading appointment: $e');
      print('❌ 错误详情: ${e.toString()}');

      // 在出错时也设置为 null
      setState(() {
        _latestAppointment = null;
      });
    }
  }

  Future<void> _checkTodayCheckIn(String uid) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final querySnapshot = await _firestore
          .collection('check_ins')
          .where('userId', isEqualTo: uid)
          .where('checkInDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('checkInDate', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      setState(() {
        _hasCheckedInToday = querySnapshot.docs.isNotEmpty;
        _todayCheckedInItems.clear();

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          if (data['itemType'] != null && data['itemId'] != null) {
            _todayCheckedInItems.add('${data['itemType']}_${data['itemId']}');
          }
          // 添加AI计划训练签到跟踪
          if (data['aiPlanId'] != null) {
            _todayCheckedInItems.add('ai_plan_${data['aiPlanId']}');
          }
        }

        if (querySnapshot.docs.isNotEmpty) {
          _todayCheckInData = querySnapshot.docs.first.data();
        }
      });
    } catch (e) {
      print('Error checking today check-in: $e');
    }
  }

  // Check in for course or AI plan
  Future<void> _checkInItem(String itemType, String itemId, String itemTitle) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final itemKey = '${itemType}_$itemId';
    if (_todayCheckedInItems.contains(itemKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have already checked in for this item today!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _firestore.collection('check_ins').add({
        'userId': user.uid,
        'itemType': itemType, // 'course' or 'ai_plan'
        'itemId': itemId,
        'itemTitle': itemTitle,
        'checkInDate': FieldValue.serverTimestamp(),
        'checkInType': 'item_completed',
      });

      setState(() {
        _todayCheckedInItems.add(itemKey);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Checked in for $itemTitle!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Check-in failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 获取双重批准状态的颜色
  Color _getAppointmentStatusColor() {
    if (_latestAppointment == null) return Colors.grey;

    final overallStatus = _latestAppointment!['overallStatus'] ?? 'pending';
    final coachApproval = _latestAppointment!['coachApproval'] ?? 'pending';
    final adminApproval = _latestAppointment!['adminApproval'] ?? 'pending';

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

  // 获取双重批准状态的文本
  String _getAppointmentStatusText() {
    if (_latestAppointment == null) return '❓ No Appointment';

    final overallStatus = _latestAppointment!['overallStatus'] ?? 'pending';
    final coachApproval = _latestAppointment!['coachApproval'] ?? 'pending';
    final adminApproval = _latestAppointment!['adminApproval'] ?? 'pending';

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
          return '⏳ Coach Approved, Waiting Admin';
        } else if (coachApproval == 'pending' && adminApproval == 'approved') {
          return '⏳ Admin Approved, Waiting Coach';
        } else if (coachApproval == 'rejected' || adminApproval == 'rejected') {
          return '❌ Rejected';
        } else {
          return '⏳ Waiting for Dual Approval';
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.deepPurple),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUserData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildBannerSection(),
            if (_userData != null) _buildUserProfileCard(),
            _buildCheckInSection(),
            _buildCoursesSection(),
            _buildAIPlansSection(),
            _buildAppointmentSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple, Colors.purple],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Back${_userData?['name'] != null ? ', ${_userData!['name'].split(' ')[0]}!' : '!'}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ready to continue your fitness journey?',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey[200],
            child: _userData?['profileImageUrl'] != null
                ? ClipOval(
              child: Image.network(
                _userData!['profileImageUrl'],
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.deepPurple,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            )
                : const Icon(
              Icons.person,
              size: 30,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userData?['name'] ?? 'User',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userData?['email'] ?? '',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInSection() {
    String checkInMessage;
    String checkInDetail = '';

    if (_hasCheckedInToday) {
      if (_todayCheckInData?['checkInType'] == 'training_completed') {
        checkInMessage = '🎉 Training completed and checked in!';
        checkInDetail = 'Total training time: ${_todayCheckInData?['totalDuration'] ?? 0} minutes';
      } else {
        checkInMessage = '✅ You have checked in today!';
      }
    } else {
      checkInMessage = '⏰ Don\'t forget to check in!';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _hasCheckedInToday ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hasCheckedInToday ? Colors.green : Colors.orange,
          width: 2,
        ),
        boxShadow: _hasCheckedInToday ? [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _hasCheckedInToday ? Icons.check_circle : Icons.schedule,
                color: _hasCheckedInToday ? Colors.green : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  checkInMessage,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              if (_hasCheckedInToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'DONE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (checkInDetail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              checkInDetail,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
          if (_hasCheckedInToday && _todayCheckInData?['checkInDate'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Check-in time: ${(_todayCheckInData!['checkInDate'] as Timestamp).toDate().toLocal().toString().split('.')[0]}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoursesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Courses',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_purchasedCourses.isNotEmpty)
                TextButton(
                  onPressed: () {
                    // Navigate to view all courses
                    Navigator.pushNamed(context, '/my_courses');
                  },
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_purchasedCourses.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No courses purchased yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Explore our fitness plans to get started!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/purchase_plan');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Browse Plans',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _purchasedCourses.take(3).map((course) => _buildCourseCard(course)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    bool isExpired = course['isExpired'] ?? false;
    double progressPercentage = course['progressPercentage']?.toDouble() ?? 0.0;
    bool isCompleted = course['isCompleted'] ?? false;
    String courseKey = 'course_${course['userCourseId']}';
    bool hasCheckedInToday = _todayCheckedInItems.contains(courseKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpired ? Colors.red.shade200 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['title'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course['category'] ?? 'Fitness',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isExpired ? Colors.red[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isExpired ? Colors.red.shade200 : Colors.green.shade200,
                  ),
                ),
                child: Text(
                  isExpired ? 'EXPIRED' : 'ACTIVE',
                  style: TextStyle(
                    color: isExpired ? Colors.red : Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progressPercentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isExpired ? Colors.red : Colors.deepPurple,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${progressPercentage.toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isExpired ? Colors.red : Colors.deepPurple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Course details and check-in button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sessions: ${course['completedSessions'] ?? 0}/${course['totalSessions'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (course['expiryDate'] != null)
                      Text(
                        'Expires: ${(course['expiryDate'] as Timestamp).toDate().toLocal().toString().split(' ')[0]}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isExpired ? Colors.red : Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\$${(course['paymentAmount'] ?? 0).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(width: 8),
              // Check-in button
              if (isCompleted && !isExpired)
                ElevatedButton(
                  onPressed: hasCheckedInToday
                      ? null
                      : () => _checkInItem('course', course['userCourseId'], course['title']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasCheckedInToday ? Colors.grey : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: const Size(60, 30),
                  ),
                  child: Text(
                    hasCheckedInToday ? '✓' : 'Check In',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIPlansSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My AI Plans',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_aiPlans.isNotEmpty)
                TextButton(
                  onPressed: () {
                    // Show AI Plans modal
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => Container(
                        height: MediaQuery.of(context).size.height * 0.8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text(
                                'All AI Plans',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            // Add AI Plans modal content here
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_aiPlans.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No AI plans yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your first AI-powered fitness plan!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Show AI Plan creation modal
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => Container(
                          height: MediaQuery.of(context).size.height * 0.8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: const Center(
                            child: Text('AI Plan Creation Modal'),
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Create AI Plan',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: _aiPlans.take(3).map((plan) => _buildAIPlanCard(plan)).toList(),
            ),
        ],
      ),
    );
  }

  // 2. 替换 _buildAIPlanCard 方法
  Widget _buildAIPlanCard(Map<String, dynamic> plan) {
    double progressPercentage = (plan['progressPercentage'] as num?)?.toDouble() ?? 0.0;
    bool isCompleted = plan['isCompleted'] ?? false;
    int actualTrainingDays = (plan['actualTrainingDays'] as num?)?.toInt() ?? 0;
    int totalDays = (plan['durationDays'] as num?)?.toInt() ?? 0;

    if (isCompleted) {
      progressPercentage = 100.0;
    }

    double progressBarFactor = (progressPercentage / 100.0).clamp(0.0, 1.0);

    String planKey = 'ai_plan_${plan['id']}';
    bool hasTrainedToday = _todayCheckedInItems.contains(planKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.green.shade200 : Colors.purple.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCompleted ? Colors.green : Colors.purple).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green[50] : Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle : Icons.auto_awesome,
                  color: isCompleted ? Colors.green[600] : Colors.purple[600],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan['title'] ?? 'AI Fitness Plan',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan['goalType'] ?? 'Fitness Goal',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasTrainedToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.green[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green[50] : Colors.purple[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCompleted ? Colors.green.shade200 : Colors.purple.shade200,
                  ),
                ),
                child: Text(
                  isCompleted ? 'COMPLETED' : (actualTrainingDays >= totalDays ? 'READY' : 'ACTIVE'),
                  style: TextStyle(
                    color: isCompleted ? Colors.green : Colors.purple,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progressBarFactor,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.green : Colors.purple,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${progressPercentage.round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isCompleted ? Colors.green : Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Training: $actualTrainingDays/$totalDays days',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (plan['weightChange'] != null)
                      Text(
                        'Target: ${plan['weightChange']}kg ${plan['goalType'] == 'Muscle Gain' ? 'gain' : 'loss'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Text(
                    'Finished',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (actualTrainingDays < totalDays)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    '${totalDays - actualTrainingDays} days left',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upcoming Appointment',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          if (_latestAppointment == null)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No upcoming appointments',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Book a session to start your training!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/main',
                            (route) => false,
                        arguments: {'initialIndex': 1}, // Schedule tab
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Book Session',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_getAppointmentStatusColor().withOpacity(0.1), _getAppointmentStatusColor().withOpacity(0.05)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getAppointmentStatusColor().withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getAppointmentStatusColor(),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Next Session",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _getAppointmentStatusColor(),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getAppointmentStatusColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getAppointmentStatusColor().withOpacity(0.3)),
                        ),
                        child: Text(
                          _getAppointmentStatusText(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getAppointmentStatusColor(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildAppointmentDetail(
                    Icons.today,
                    "Date",
                    _latestAppointment?['date'] != null
                        ? (_latestAppointment!['date'] as Timestamp).toDate().toLocal().toString().split(' ')[0]
                        : '',
                  ),
                  _buildAppointmentDetail(
                    Icons.access_time,
                    "Time",
                    _latestAppointment?['timeSlot'] ?? '',
                  ),
                  _buildAppointmentDetail(
                    Icons.person,
                    "Coach",
                    _latestAppointment?['coachName'] ?? '',
                  ),
                  _buildAppointmentDetail(
                    Icons.location_on,
                    "Gym",
                    _latestAppointment?['gymName'] ?? '',
                  ),
                  // 添加批准状态显示
                  if (_latestAppointment!['overallStatus'] == 'pending') ...[
                    const SizedBox(height: 8),
                    _buildApprovalStatusRow(),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApprovalStatusRow() {
    final coachApproval = _latestAppointment!['coachApproval'] ?? 'pending';
    final adminApproval = _latestAppointment!['adminApproval'] ?? 'pending';

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
            'Approval Progress:',
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
                child: _buildApprovalBadge('Coach', coachApproval),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildApprovalBadge('Admin', adminApproval),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 12, color: statusColor),
          const SizedBox(width: 4),
          Text(
            '$title: ${status.toUpperCase()}',
            style: TextStyle(
              fontSize: 10,
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentDetail(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: _getAppointmentStatusColor(),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              "$label:",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}