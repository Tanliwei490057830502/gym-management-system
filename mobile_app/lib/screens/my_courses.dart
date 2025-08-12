import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'today_training_screen.dart';
import 'ai_plan_modal.dart';

class MyCoursesScreen extends StatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _purchasedCourses = [];
  List<Map<String, dynamic>> _aiPlans = [];
  bool _isLoading = true;
  bool _loadingAIPlans = true;
  String? _mainCourseId;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _loadAIPlans();
  }

  Future<void> _loadCourses() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final snapshot = await _firestore
          .collection('user_courses')
          .where('userId', isEqualTo: user.uid)
          .get();

      final courses = snapshot.docs.map((doc) => {
        ...doc.data(),
        'userCourseId': doc.id,
      }).toList();

      final mainCourse = courses.firstWhere(
            (c) => c['isMainCourse'] == true,
        orElse: () => {},
      );

      if (mounted) {
        setState(() {
          _purchasedCourses = courses;
          _mainCourseId = mainCourse['userCourseId'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading courses: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Load AI plans from Firestore with progress calculation
  Future<void> _loadAIPlans() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _loadingAIPlans = false);
      return;
    }

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('ai_plans')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> plans = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        await _calculateActualProgress(data, user.uid);
        plans.add(data);
      }

      setState(() {
        _aiPlans = plans;
        _loadingAIPlans = false;
      });
    } catch (e) {
      debugPrint('Failed to load AI plans: $e');
      setState(() => _loadingAIPlans = false);
    }
  }

  Future<void> _calculateActualProgress(Map<String, dynamic> planData, String userId) async {
    try {
      final planId = planData['id'];
      final totalDays = planData['durationDays'] as int? ?? 0;
      final createdAt = planData['createdAt'] as Timestamp?;

      if (createdAt == null || totalDays == 0) {
        planData['actualTrainingDays'] = 0;
        planData['progressPercentage'] = 0.0;
        planData['isCompleted'] = false;
        return;
      }

      final planStartDate = createdAt.toDate();

      final checkInQuery = await _firestore
          .collection('check_ins')
          .where('userId', isEqualTo: userId)
          .where('aiPlanId', isEqualTo: planId)
          .where('checkInType', isEqualTo: 'training_completed')
          .where('checkInDate', isGreaterThanOrEqualTo: Timestamp.fromDate(planStartDate))
          .get();

      final actualTrainingDays = checkInQuery.docs.length;
      final progressPercentage = totalDays > 0
          ? (actualTrainingDays / totalDays * 100).clamp(0.0, 100.0)
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
        } catch (e) {
          debugPrint('Auto complete failed: $e');
        }
      }

      planData['actualTrainingDays'] = actualTrainingDays;
      planData['progressPercentage'] = progressPercentage;
      planData['isCompleted'] = isCompleted;
      planData['remainingDays'] = (totalDays - actualTrainingDays).clamp(0, totalDays);

    } catch (e) {
      debugPrint('Error calculating progress: $e');
      planData['actualTrainingDays'] = 0;
      planData['progressPercentage'] = 0.0;
      planData['isCompleted'] = false;
    }
  }

  Future<void> _setAsMainCourse(String userCourseId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    final batch = _firestore.batch();
    final allCourses = await _firestore
        .collection('user_courses')
        .where('userId', isEqualTo: user.uid)
        .get();

    for (final doc in allCourses.docs) {
      batch.update(doc.reference, {'isMainCourse': false});
    }
    batch.update(
      _firestore.collection('user_courses').doc(userCourseId),
      {'isMainCourse': true},
    );

    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已设置为主课程')),
      );
      await _loadCourses();
    }
  }

  // 简化版训练项目（作为后备方案）
  List<TrainingItem> _buildTrainingItems(String courseId, String title, String category) {
    return [
      // 热身
      TrainingItem(
        name: 'Warm-up',
        durationMinutes: 10,
        color: Colors.redAccent,
        icon: Icons.directions_run,
        courseId: courseId,
        title: title,
        category: category,
      ),

      // 主要训练
      TrainingItem(
        name: 'Main Workout',
        durationMinutes: 40,
        color: Colors.deepPurple,
        icon: Icons.fitness_center,
        courseId: courseId,
        title: title,
        category: category,
      ),

      // 冷却
      TrainingItem(
        name: 'Cool-down',
        durationMinutes: 10,
        color: Colors.cyanAccent,
        icon: Icons.spa,
        courseId: courseId,
        title: title,
        category: category,
      ),
    ];
  }

  // 使用教练制作的真实训练内容
  Future<List<TrainingItem>> _buildTrainingItemsFromCoach(String courseId, String title, String category) async {
    try {
      print('🔍 获取教练课程数据，courseId: $courseId');

      // 获取教练课程数据
      final courseDoc = await _firestore.collection('courses').doc(courseId).get();

      if (!courseDoc.exists) {
        print('❌ 课程文档不存在');
        return _buildTrainingItems(courseId, title, category); // 返回默认版本
      }

      final courseData = courseDoc.data()!;
      final days = courseData['days'] as Map<String, dynamic>? ?? {};

      // 获取今天是星期几 (1=周一, 7=周日)
      final today = DateTime.now();
      final dayOfWeek = today.weekday; // 1-7
      final dayKey = 'day$dayOfWeek';

      print('📅 今天是: $dayKey');

      final todayPlan = days[dayKey] as Map<String, dynamic>?;

      if (todayPlan == null || todayPlan['hasCourse'] != true) {
        print('📋 今天没有训练安排');
        return [
          TrainingItem(
            name: 'Rest Day',
            durationMinutes: 0,
            color: Colors.grey,
            icon: Icons.hotel,
            courseId: courseId,
            title: title,
            category: category,
          ),
        ];
      }

      final exercises = todayPlan['exercises'] as List<dynamic>? ?? [];
      final warmUpDuration = (todayPlan['warmUp'] as num?)?.toInt() ?? 10;
      final coolDownDuration = (todayPlan['coolDown'] as num?)?.toInt() ?? 10;

      print('🏋️ 找到 ${exercises.length} 个训练动作');

      List<TrainingItem> trainingItems = [];

      // 热身
      trainingItems.add(TrainingItem(
        name: 'Warm-up',
        durationMinutes: warmUpDuration,
        color: Colors.redAccent,
        icon: Icons.directions_run,
        courseId: courseId,
        title: title,
        category: category,
      ));

      // 教练设计的训练动作
      for (int i = 0; i < exercises.length; i++) {
        final exercise = exercises[i] as Map<String, dynamic>;
        final exerciseName = exercise['name'] as String? ?? 'Exercise ${i + 1}';
        final duration = _parseDuration(exercise['duration'] as String? ?? '');

        // 构建详细的动作名称，包含组数和休息时间
        final reps = exercise['reps'] as String? ?? '';
        final rest = exercise['rest'] as String? ?? '';
        final detailedName = reps.isNotEmpty || rest.isNotEmpty
            ? '$exerciseName (${reps.isNotEmpty ? reps : ''} ${rest.isNotEmpty ? '• $rest' : ''})'
            : exerciseName;

        trainingItems.add(TrainingItem(
          name: detailedName,
          durationMinutes: duration,
          color: _getExerciseColor(i), // 动态分配颜色
          icon: Icons.fitness_center,
          courseId: courseId,
          title: title,
          category: category,
        ));
      }

      // 冷却
      trainingItems.add(TrainingItem(
        name: 'Cool-down',
        durationMinutes: coolDownDuration,
        color: Colors.cyanAccent,
        icon: Icons.spa,
        courseId: courseId,
        title: title,
        category: category,
      ));

      print('✅ 构建完成，总共 ${trainingItems.length} 个训练项目');
      return trainingItems;

    } catch (e) {
      print('❌ 获取教练训练数据失败: $e');
      return _buildTrainingItems(courseId, title, category); // 返回默认版本
    }
  }

  // 辅助方法：解析时长
  int _parseDuration(String duration) {
    // 尝试从字符串中提取数字，如 "45 seconds" -> 1分钟
    final numbers = RegExp(r'\d+').allMatches(duration);
    if (numbers.isNotEmpty) {
      final value = int.tryParse(numbers.first.group(0)!) ?? 0;
      if (duration.toLowerCase().contains('min')) {
        return value;
      } else if (duration.toLowerCase().contains('sec')) {
        return (value / 60).ceil(); // 秒转分钟
      } else {
        return value; // 假设是分钟
      }
    }
    return 5; // 默认5分钟
  }

  // 辅助方法：为不同练习分配颜色
  Color _getExerciseColor(int index) {
    final colors = [
      Colors.deepPurple,
      Colors.orange,
      Colors.blue,
      Colors.green,
      Colors.pink,
      Colors.teal,
      Colors.indigo,
      Colors.amber,
    ];
    return colors[index % colors.length];
  }

  void onNewPlanSaved(String newPlanTitle) {
    // Reload AI plans when a new plan is saved
    _loadAIPlans();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('AI 计划 "$newPlanTitle" 已添加')),
    );
  }

  void showAIPlanOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: AIPlanModal(
          onNewPlanSaved: onNewPlanSaved,
          aiPlans: const [], // Pass empty list since we're loading from Firestore
        ),
      ),
    );
  }

  // Check if user has trained today for specific AI plan
  Future<bool> _hasTrainedToday(String planId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final querySnapshot = await _firestore
          .collection('check_ins')
          .where('userId', isEqualTo: user.uid)
          .where('aiPlanId', isEqualTo: planId)
          .where('checkInType', isEqualTo: 'training_completed')
          .where('checkInDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('checkInDate', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking today training: $e');
      return false;
    }
  }

  // Start today's training for AI plan
  void _startTodayTraining(Map<String, dynamic> plan) async {
    final hasTrainedToday = await _hasTrainedToday(plan['id']);

    if (hasTrainedToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('您今天已经完成训练了！'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final trainingItems = _createSimpleTrainingItemForAI(plan);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TodayTrainingScreen(
          trainingItems: trainingItems,
          courseId: plan['id'],
          aiPlanId: plan['id'],
          fullTrainingPlan: plan['trainingPlan'],
        ),
      ),
    );

    if (result == 'completed' && mounted) {
      _loadAIPlans();
    }
  }

  // Create training item for AI plan
  List<TrainingItem> _createSimpleTrainingItemForAI(Map<String, dynamic> plan) {
    return [
      TrainingItem(
        name: plan['trainingPlan'] ?? '',
        durationMinutes: 30,
        color: Colors.purple,
        icon: Icons.auto_awesome,
        courseId: plan['id'],
        title: plan['title'] ?? 'AI Training',
        category: plan['goalType'] ?? 'Fitness',
      ),
    ];
  }

  // Delete AI plan
  Future<void> _deleteAIPlan(Map<String, dynamic> plan) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Plan',
          style: TextStyle(color: Colors.black), // 改为黑色
        ),
        content: Text(
          'Are you sure you want to delete the plan? "${plan['title'] ?? 'AI Plan'}" ? This action cannot be undone。',
          style: const TextStyle(color: Colors.black), // 改为黑色
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'cancel',
              style: TextStyle(color: Colors.black), // 改为黑色
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete the AI plan document
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('ai_plans')
          .doc(plan['id'])
          .delete();

      // Also delete related check-ins
      final checkInsQuery = await _firestore
          .collection('check_ins')
          .where('userId', isEqualTo: user.uid)
          .where('aiPlanId', isEqualTo: plan['id'])
          .get();

      final batch = _firestore.batch();
      for (final doc in checkInsQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('计划已删除'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Close details page
        _loadAIPlans(); // Reload AI plans
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show AI plan details
  void _showAIPlanDetails(Map<String, dynamic> plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag indicator
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title, status and delete button
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                plan['title'] ?? 'AI PLan',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black, // 改为黑色
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (plan['isCompleted'] ?? false)
                                    ? Colors.green
                                    : Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                (plan['isCompleted'] ?? false) ? '已完成' : '进行中',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _deleteAIPlan(plan),
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red,
                              tooltip: 'Delete Plan',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Progress section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Training progress',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black, // 改为黑色
                                    ),
                                  ),
                                  Text(
                                    '${(plan['progressPercentage'] ?? 0).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: (plan['isCompleted'] ?? false) ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: (plan['progressPercentage'] ?? 0) / 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: (plan['isCompleted'] ?? false) ? Colors.green : Colors.orange,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Training days: ${plan['actualTrainingDays'] ?? 0}/${plan['durationDays'] ?? 0}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black, // 改为黑色
                                ),
                              ),
                              if (!(plan['isCompleted'] ?? false))
                                Text(
                                  'Remaining: ${plan['remainingDays'] ?? 0} day',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black, // 改为黑色
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Goal information
                        _buildDetailCard(
                          'Target Information',
                          Icons.track_changes,
                          Colors.purple,
                          [
                            _buildDetailRow('Target type', plan['goalType'] ?? ''),
                            _buildDetailRow('Current weight', '${plan['currentWeight'] ?? 0}kg'),
                            _buildDetailRow('Expect changes', '${plan['weightChange'] ?? 0}kg'),
                            _buildDetailRow('Planned duration', '${plan['durationDays'] ?? 0}天'),
                            _buildDetailRow('Daily food budget', 'RM ${plan['dailyFoodBudget']?.toStringAsFixed(0) ?? '20'}'), // 新增预算显示
                          ],
                        ),

                        // Training plan
                        _buildDetailCard(
                          '训练计划',
                          Icons.fitness_center,
                          Colors.blue,
                          [
                            Text(
                              plan['trainingPlan'] ?? '无训练计划',
                              style: const TextStyle(
                                height: 1.5,
                                color: Colors.black, // 改为黑色
                              ),
                            ),
                          ],
                        ),

                        // Diet plan with pricing
                        _buildDetailCard(
                          '饮食计划 (含价格)', // 更新标题提及价格
                          Icons.restaurant,
                          Colors.orange,
                          [
                            Text(
                              plan['dietPlan'] ?? '无饮食计划',
                              style: const TextStyle(
                                height: 1.5,
                                color: Colors.black, // 改为黑色
                              ),
                            ),
                          ],
                        ),

                        // Advice (if available)
                        if (plan['advice'] != null && plan['advice'].isNotEmpty)
                          _buildDetailCard(
                            '专家建议',
                            Icons.lightbulb_outline,
                            Colors.amber,
                            [
                              Text(
                                plan['advice'],
                                style: const TextStyle(
                                  height: 1.5,
                                  color: Colors.black, // 改为黑色
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 20),

                        // Action buttons
                        Column(
                          children: [
                            // Start training button (if plan not completed)
                            if (!(plan['isCompleted'] ?? false))
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _startTodayTraining(plan);
                                  },
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Start Training Today'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 12),

                            // Delete button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _deleteAIPlan(plan),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('删除计划'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailCard(String title, IconData icon, Color color, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color, // 保持图标的颜色一致性
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black), // 改为黑色
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black, // 改为黑色
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'My Courses',
            style: TextStyle(color: Colors.black) // 改为黑色
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Courses section
          Expanded(
            child: ListView.builder(
              itemCount: _purchasedCourses.length,
              itemBuilder: (context, index) {
                final course = _purchasedCourses[index];
                final isMain = course['isMainCourse'] == true;
                final title = course['title'] ?? 'Untitled';
                final category = course['category'] ?? 'Fitness';
                final userCourseId = course['userCourseId'];

                return GestureDetector(
                  onTap: isMain
                      ? () async {
                    // 显示加载状态
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );

                    try {
                      // 获取教练制作的真实训练内容
                      final trainingItems = await _buildTrainingItemsFromCoach(
                        course['courseId'],
                        title,
                        category,
                      );

                      // 关闭加载对话框
                      if (mounted) Navigator.pop(context);

                      // 跳转到训练页面
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TodayTrainingScreen(
                              trainingItems: trainingItems,
                              courseId: course['courseId'],
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      // 关闭加载对话框
                      if (mounted) Navigator.pop(context);

                      // 显示错误消息
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('加载训练内容失败: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                      : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isMain ? const Color(0xFFFF9D00) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    title,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black
                                    )
                                ),
                                const SizedBox(height: 4),
                                Text(
                                    category,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black // 改为黑色
                                    )
                                ),
                              ],
                            ),
                            if (!isMain)
                              TextButton.icon(
                                onPressed: () => _setAsMainCourse(userCourseId),
                                icon: Icon(Icons.star_border, color: Colors.deepPurple.shade600),
                                label: Text(
                                    '设为主课程',
                                    style: TextStyle(color: Colors.deepPurple.shade600)
                                ),
                              )
                            else
                              Icon(Icons.star, color: Colors.deepPurple.shade600),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                            'Sessions: ${course['completedSessions'] ?? 0}/${course['totalSessions'] ?? 0}',
                            style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black // 改为黑色
                            )
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // AI Plans section
          if (!_loadingAIPlans && _aiPlans.isNotEmpty) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade50, Colors.blue.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'AI Fitness Plan (with Budget)', // 更新标题提及预算
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black, // 改为黑色
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: showAIPlanOptions,
                        child: const Text(
                          'Check All',
                          style: TextStyle(color: Colors.purple),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Show recent AI plans with progress
                  ...(_aiPlans.take(3).map((plan) => GestureDetector(
                    onTap: () => _showAIPlanDetails(plan),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: (plan['isCompleted'] ?? false)
                                    ? Colors.green
                                    : Colors.purple,
                                radius: 16,
                                child: Icon(
                                  (plan['isCompleted'] ?? false)
                                      ? Icons.check
                                      : Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plan['title'] ?? 'AI 计划',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black, // 改为黑色
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${plan['goalType'] ?? ''} • ${plan['durationDays'] ?? 0}天 • RM${plan['dailyFoodBudget']?.toStringAsFixed(0) ?? '20'}/日', // 添加预算信息
                                      style: const TextStyle(
                                        color: Colors.black, // 改为黑色
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: (plan['isCompleted'] ?? false)
                                      ? Colors.green.shade100
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  (plan['isCompleted'] ?? false) ? '已完成' : '进行中',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: (plan['isCompleted'] ?? false)
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Quick delete button
                              InkWell(
                                onTap: () => _deleteAIPlan(plan),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Progress bar
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (plan['progressPercentage'] ?? 0) / 100,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: (plan['isCompleted'] ?? false) ? Colors.green : Colors.purple,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(plan['progressPercentage'] ?? 0).toInt()}% 完成',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black, // 改为黑色
                                ),
                              ),
                              Text(
                                '训练: ${plan['actualTrainingDays'] ?? 0}/${plan['durationDays'] ?? 0}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black, // 改为黑色
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ))),
                ],
              ),
            ),
          ],

          // AI Generation button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: showAIPlanOptions,
              icon: const Icon(Icons.bolt),
              label: const Text('Generate AI smart training (watch ads)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}