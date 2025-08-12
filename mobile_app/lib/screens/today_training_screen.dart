import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrainingItem {
  final String name;
  final int durationMinutes;
  final Color color;
  final IconData icon;
  final String courseId;
  final String title;
  final String category;
  bool isCompleted;

  TrainingItem({
    required this.name,
    required this.durationMinutes,
    required this.color,
    required this.icon,
    required this.courseId,
    required this.title,
    required this.category,
    this.isCompleted = false,
  });
}

class TodayTrainingScreen extends StatefulWidget {
  final List<TrainingItem> trainingItems;
  final String courseId;
  final String? aiPlanId;
  final String? fullTrainingPlan;

  const TodayTrainingScreen({
    super.key,
    required this.trainingItems,
    required this.courseId,
    this.aiPlanId,
    this.fullTrainingPlan,
  });

  @override
  State<TodayTrainingScreen> createState() => _TodayTrainingScreenState();
}

class _TodayTrainingScreenState extends State<TodayTrainingScreen> with SingleTickerProviderStateMixin {
  int currentItemIndex = 0;
  Timer? timer;
  int remainingSeconds = 0;
  bool isRunning = false;
  bool isPaused = false;
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _todayTrainingText;

  @override
  void initState() {
    super.initState();

    if (widget.aiPlanId != null) {
      _extractTodayTrainingText();
    } else {
      _setupCurrentItem();
      _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
      _progressAnimation = Tween<double>(begin: 0, end: 1).animate(_animationController);
      _startTimer();
    }
  }

  void _extractTodayTrainingText() {
    if (widget.fullTrainingPlan == null || widget.fullTrainingPlan!.isEmpty) {
      _todayTrainingText = '未找到训练计划内容';
      return;
    }

    final fullPlan = widget.fullTrainingPlan!;
    final todayWeekday = DateTime.now().weekday;
    final dayNumber = todayWeekday;
    final dayPattern = 'Day $dayNumber:';

    try {
      final dayIndex = fullPlan.indexOf(dayPattern);
      if (dayIndex != -1) {
        final startIndex = dayIndex + dayPattern.length;
        final nextDayPattern = RegExp(r'Day \d+:');
        final remainingText = fullPlan.substring(startIndex);
        final nextDayMatch = nextDayPattern.firstMatch(remainingText);

        String todayContent;
        if (nextDayMatch != null) {
          todayContent = remainingText.substring(0, nextDayMatch.start).trim();
        } else {
          todayContent = remainingText.trim();
        }

        _todayTrainingText = todayContent.isNotEmpty ? todayContent : '今日无特定训练内容';
      } else {
        final cyclicDayNumber = ((todayWeekday - 1) % 7) + 1;
        final cyclicDayPattern = 'Day $cyclicDayNumber:';
        final cyclicDayIndex = fullPlan.indexOf(cyclicDayPattern);

        if (cyclicDayIndex != -1) {
          final startIndex = cyclicDayIndex + cyclicDayPattern.length;
          final nextDayPattern = RegExp(r'Day \d+:');
          final remainingText = fullPlan.substring(startIndex);
          final nextDayMatch = nextDayPattern.firstMatch(remainingText);

          String todayContent;
          if (nextDayMatch != null) {
            todayContent = remainingText.substring(0, nextDayMatch.start).trim();
          } else {
            todayContent = remainingText.trim();
          }

          _todayTrainingText = todayContent.isNotEmpty ? todayContent : '今日无特定训练内容';
        } else {
          final lines = fullPlan.split('\n');
          final nonEmptyLines = lines.where((line) => line.trim().isNotEmpty).toList();

          if (nonEmptyLines.isNotEmpty) {
            final todayLines = nonEmptyLines.take(10).toList();
            _todayTrainingText = todayLines.join('\n');
          } else {
            _todayTrainingText = '训练计划格式异常，请检查内容';
          }
        }
      }
    } catch (e) {
      print('Error extracting today training text: $e');
      _todayTrainingText = '提取今日训练内容时出错：${e.toString()}';
    }

    print('🗓️ 今日是周$todayWeekday，提取的训练内容：$_todayTrainingText');
  }

  void _setupCurrentItem() {
    if (widget.trainingItems.isNotEmpty) {
      remainingSeconds = widget.trainingItems[currentItemIndex].durationMinutes * 60;
    }
  }

  void _startTimer() {
    setState(() => isRunning = true);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!isPaused) {
        setState(() => remainingSeconds--);
        if (remainingSeconds <= 0) _completeCurrentItem();
      }
    });
  }

  void _pauseTimer() => setState(() => isPaused = true);
  void _resumeTimer() => setState(() => isPaused = false);
  void _skipToNext() => _completeCurrentItem();

  void _completeCurrentItem() {
    if (widget.trainingItems.isNotEmpty) {
      widget.trainingItems[currentItemIndex].isCompleted = true;
    }
    timer?.cancel();
    if (currentItemIndex < widget.trainingItems.length - 1) {
      setState(() => currentItemIndex++);
      _setupCurrentItem();
      _startTimer();
    } else {
      _finishTraining();
    }
  }

  void _finishEarly() {
    timer?.cancel();
    _finishTraining();
  }

  Future<void> _finishTraining() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      print('开始处理训练完成，AI计划ID: ${widget.aiPlanId}');

      if (widget.aiPlanId == null) {
        await _updateCourseProgress(user.uid);
      }

      await _createTrainingCheckIn(user.uid);

      if (mounted) {
        await _showWeightInputDialog();
      }
    } catch (e) {
      print('Error updating training progress: $e');
      if (mounted) {
        _showTrainingCompletedMessage();
      }
    }
  }

  Future<void> _showWeightInputDialog() async {
    final TextEditingController weightController = TextEditingController();

    final weight = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Record weight',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Training is complete! Please record your current weight:',
              style: TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'weight',
                labelStyle: TextStyle(color: Colors.black),
                border: OutlineInputBorder(),
                suffixText: '（kg）',
                suffixStyle: TextStyle(color: Colors.black),
              ),
              style: const TextStyle(color: Colors.black),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text(
              'skip',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final weightText = weightController.text.trim();
              if (weightText.isNotEmpty) {
                final weight = double.tryParse(weightText);
                if (weight != null && weight > 0 && weight < 1000) {
                  Navigator.of(context).pop(weight);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid weight'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('save'),
          ),
        ],
      ),
    );

    if (weight != null) {
      await _saveWeightRecord(weight);
    }

    if (mounted) {
      _showTrainingCompletedMessage();
    }
  }

  Future<void> _saveWeightRecord(double weight) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('weight_records').add({
        'userId': user.uid,
        'actualWeight': weight,
        'recordDate': Timestamp.now(),
        'recordType': 'post_training',
        'aiPlanId': widget.aiPlanId,
        'courseId': widget.courseId,
        'createdAt': Timestamp.now(),
      });

      if (widget.aiPlanId != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('ai_plans')
            .doc(widget.aiPlanId!)
            .update({
          'currentWeight': weight,
          'lastWeightUpdate': Timestamp.now(),
        });
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'weight': weight,
        'lastWeightUpdate': Timestamp.now(),
      });

      print('✅ 体重记录已保存: ${weight}kg');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('体重记录已保存: ${weight}kg'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving weight record: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存体重记录失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateCourseProgress(String userId) async {
    try {
      final query = await _firestore
          .collection('user_courses')
          .where('userId', isEqualTo: userId)
          .where('courseId', isEqualTo: widget.courseId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first.reference;
        final remaining = query.docs.first.data()['remainingSessions'] ?? 8;
        await doc.update({'remainingSessions': remaining > 0 ? remaining - 1 : 0});
        print('Course training completion recorded successfully');
      }
    } catch (e) {
      print('Error updating course progress: $e');
    }
  }

  Future<void> _createTrainingCheckIn(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      Query checkInQuery = _firestore
          .collection('check_ins')
          .where('userId', isEqualTo: userId)
          .where('checkInDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('checkInDate', isLessThan: Timestamp.fromDate(endOfDay))
          .where('checkInType', isEqualTo: 'training_completed');

      if (widget.aiPlanId != null) {
        checkInQuery = checkInQuery.where('aiPlanId', isEqualTo: widget.aiPlanId);
        print('检查AI计划今日签到状态');
      } else {
        checkInQuery = checkInQuery.where('courseId', isEqualTo: widget.courseId);
        print('检查课程今日签到状态');
      }

      final existing = await checkInQuery.limit(1).get();

      if (existing.docs.isEmpty) {
        final checkInData = {
          'userId': userId,
          'checkInDate': Timestamp.now(),
          'checkInType': 'training_completed',
          'createdAt': Timestamp.now(),
        };

        if (widget.aiPlanId != null) {
          checkInData['aiPlanId'] = widget.aiPlanId!;
          checkInData['courseId'] = widget.courseId;
          checkInData['trainingType'] = 'ai_plan';
          checkInData['todayTrainingContent'] = _todayTrainingText ?? '';
          checkInData['totalDuration'] = 30;

          await _updateAIPlanLastTraining(userId);
        } else {
          checkInData['courseId'] = widget.courseId;
          checkInData['trainingType'] = 'course';
          checkInData['trainingItems'] = widget.trainingItems.map((item) => {
            'name': item.name,
            'durationMinutes': item.durationMinutes,
            'isCompleted': item.isCompleted,
          }).toList();
          checkInData['totalDuration'] = widget.trainingItems.fold<int>(0, (sum, item) => sum + item.durationMinutes);
        }

        await _firestore.collection('check_ins').add(checkInData);
        print('✅ 签到记录已创建');
      } else {
        print('今日已签到');
      }
    } catch (e) {
      print('Error creating training check-in: $e');
    }
  }

  Future<void> _updateAIPlanLastTraining(String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('ai_plans')
          .doc(widget.aiPlanId!)
          .update({
        'lastTrainingDate': Timestamp.now(),
        'lastTrainingAt': FieldValue.serverTimestamp(),
      });
      print('✅ AI计划最后训练时间已更新');
    } catch (e) {
      print('Error updating AI plan last training: $e');
    }
  }

  void _showTrainingCompletedMessage() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              Text(
                widget.aiPlanId != null ? '🎉 AI训练完成！' : '🎉 训练完成！',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.aiPlanId != null
                    ? 'Todays progress of the AI training plan has been updated'
                    : 'Course training progress has been updated',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop('completed');
                  Navigator.pushReplacementNamed(
                    context,
                    '/main',
                    arguments: {'initialIndex': 0, 'refresh': true},
                  );
                },
                icon: const Icon(Icons.home),
                label: const Text('Return to homepage'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun'];
    return weekdays[weekday - 1];
  }

  @override
  void dispose() {
    timer?.cancel();
    if (widget.aiPlanId == null) {
      _animationController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.aiPlanId != null ? 'AI训练进行中' : '训练进行中',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: widget.aiPlanId != null ? Colors.purple : Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _finishEarly,
            child: const Text('end early', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: widget.aiPlanId != null ? _buildAITrainingView() : _buildCourseTimerView(),
    );
  }

  Widget _buildAITrainingView() {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: Stack(
        children: [
          // 主要内容区域 - 可滚动
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 100, // 为底部按钮留出空间
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 顶部信息卡片
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade100, Colors.purple.shade50],
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
                            Icon(Icons.auto_awesome, color: Colors.purple.shade600),
                            const SizedBox(width: 8),
                            const Text(
                              '📅 Today’s training plan',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${DateTime.now().year}年${DateTime.now().month}月${DateTime.now().day}日 - 周${_getWeekdayName(DateTime.now().weekday)}',
                          style: const TextStyle(fontSize: 14, color: Colors.black),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 训练内容展示卡片
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.fitness_center, color: Colors.orange.shade600, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Training content',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _todayTrainingText ?? 'Loading training content...',
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // 底部固定按钮
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _finishTraining,
                icon: const Icon(Icons.check_circle),
                label: const Text(
                  'Complete today training',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseTimerView() {
    if (widget.trainingItems.isEmpty) {
      return const Center(
        child: Text(
          'No training program',
          style: TextStyle(color: Colors.black),
        ),
      );
    }

    final currentItem = widget.trainingItems[currentItemIndex];
    final screenHeight = MediaQuery.of(context).size.height;
    final appBarHeight = AppBar().preferredSize.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final availableHeight = screenHeight - appBarHeight - statusBarHeight;

    return Container(
      height: availableHeight,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // 进度条
            LinearProgressIndicator(
              value: (currentItemIndex + 1) / widget.trainingItems.length,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
            const SizedBox(height: 8),
            Text(
              '${currentItemIndex + 1} / ${widget.trainingItems.length}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 32),

            // 当前训练项目
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: currentItem.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: currentItem.color.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    currentItem.icon,
                    size: 48,
                    color: currentItem.color,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currentItem.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _formatTime(remainingSeconds),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // 控制按钮
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _skipToNext,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isRunning ? _pauseTimer : (isPaused ? _resumeTimer : _startTimer),
                  icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(isRunning ? 'Stop' : (isPaused ? '继续' : '开始')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRunning ? Colors.orange : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _finishEarly,
                  icon: const Icon(Icons.stop),
                  label: const Text('Finish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // 训练项目列表
            Container(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.trainingItems.length,
                itemBuilder: (context, index) {
                  final item = widget.trainingItems[index];
                  final isActive = index == currentItemIndex;
                  final isCompleted = item.isCompleted;

                  return Container(
                    width: 100,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.shade50
                          : (isActive ? item.color.withOpacity(0.2) : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCompleted
                            ? Colors.green
                            : (isActive ? item.color : Colors.grey.shade300),
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle : item.icon,
                          color: isCompleted
                              ? Colors.green
                              : (isActive ? item.color : Colors.grey),
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            color: isCompleted
                                ? Colors.green
                                : (isActive ? Colors.black : Colors.grey),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.durationMinutes}min',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}