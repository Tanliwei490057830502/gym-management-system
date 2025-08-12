// screens/analytics_tab_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class AnalyticsTabScreen extends StatefulWidget {
  const AnalyticsTabScreen({super.key});

  @override
  State<AnalyticsTabScreen> createState() => _AnalyticsTabScreenState();
}

class _AnalyticsTabScreenState extends State<AnalyticsTabScreen> {
  double? userWeight;
  double? userHeight;
  double? bmi;
  String? mainCourseTitle;
  List<int> weeklyIntensity = [1, 1, 1, 1, 1]; // 默认训练强度改为11111
  List<double> weightData = []; // 体重数据（5周）
  List<MapEntry<DateTime, double>> dailyWeights = []; // 实际体重数据
  Map<String, dynamic>? userData; // 用户数据
  bool isLoading = true;

  // 添加Firestore监听器
  Stream<DocumentSnapshot>? userDataStream;

  @override
  void initState() {
    super.initState();
    fetchUserData();
    _setupUserDataListener();
    _loadActualWeightData();
  }

  // 设置实时监听用户数据变化
  void _setupUserDataListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userDataStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();

      userDataStream!.listen((snapshot) {
        if (snapshot.exists && mounted) {
          final data = snapshot.data() as Map<String, dynamic>;
          setState(() {
            userData = data;
            userWeight = data['weight']?.toDouble() ?? 70.0;
            userHeight = data['height']?.toDouble() ?? 170.0;

            // 实时更新BMI
            if (userHeight != null && userHeight! > 0) {
              bmi = userWeight! / ((userHeight! / 100) * (userHeight! / 100));
            }

            // 根据新体重更新体重数据
            _updateWeightData();
          });
        }
      });
    }
  }

  // 🔥 修复：加载实际体重数据，兼容不同字段名
  Future<void> _loadActualWeightData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('weight_records')
          .where('userId', isEqualTo: user.uid)
          .orderBy('recordDate', descending: true)
          .limit(7)
          .get();

      final List<MapEntry<DateTime, double>> list = snapshot.docs.map((doc) {
        final data = doc.data();

        // 🔥 修复：优先使用 weight，然后 actualWeight
        double weight = 0.0;
        if (data.containsKey('weight') && data['weight'] != null) {
          final rawWeight = data['weight'];
          weight = (rawWeight is num) ? rawWeight.toDouble() : 0.0;
        } else if (data.containsKey('actualWeight') && data['actualWeight'] != null) {
          final rawWeight = data['actualWeight'];
          weight = (rawWeight is num) ? rawWeight.toDouble() : 0.0;
        } else {
          // 如果两个字段都不存在，尝试其他可能的字段名
          for (String fieldName in ['currentWeight', 'userWeight', 'bodyWeight']) {
            if (data.containsKey(fieldName) && data[fieldName] != null) {
              final rawWeight = data[fieldName];
              weight = (rawWeight is num) ? rawWeight.toDouble() : 0.0;
              break;
            }
          }
        }

        final date = (data['recordDate'] as Timestamp).toDate();
        return MapEntry(date, weight);
      }).where((entry) => entry.value > 0).toList(); // 过滤掉无效的体重数据

      list.sort((a, b) => a.key.compareTo(b.key)); // 升序排列

      setState(() {
        dailyWeights = list;
      });

      print('✅ 成功加载 ${list.length} 条体重记录');
    } catch (e) {
      print('Error loading weight data: $e');
      setState(() {
        dailyWeights = [];
      });
    }
  }

  // 更新体重数据
  void _updateWeightData() {
    switch (mainCourseTitle) {
      case 'Muscle Building Plan':
        weightData = _generateWeightData(userWeight!, [0.0, 0.2, 0.5, 0.8, 1.2]); // 增重
        break;
      case 'Core & Posture Training':
        weightData = _generateWeightData(userWeight!, [0.0, -0.2, -0.6, -1.1, -1.8]); // 减重
        break;
      case 'Fat Burning Program':
        weightData = _generateWeightData(userWeight!, [0.0, -0.3, -1.0, -1.8, -2.9]); // 减重
        break;
      default:
        weightData = _generateWeightData(userWeight ?? 70, [0.0, 0.0, 0.0, 0.0, 0.0]); // 默认保持体重不变
    }
  }

  Future<void> fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final courseSnapshot = await FirebaseFirestore.instance
          .collection('user_courses')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .where('isMainCourse', isEqualTo: true)
          .limit(1)
          .get();

      if (userDoc.exists) {
        userData = userDoc.data() as Map<String, dynamic>?;
        userWeight = userDoc['weight']?.toDouble() ?? 70.0; // 默认值
        userHeight = userDoc['height']?.toDouble() ?? 170.0; // 默认值
        if (userHeight != null && userHeight! > 0) {
          bmi = userWeight! / ((userHeight! / 100) * (userHeight! / 100));
        }
      }

      if (courseSnapshot.docs.isNotEmpty) {
        final course = courseSnapshot.docs.first.data();
        mainCourseTitle = course['title'];
      }

      setState(() {
        switch (mainCourseTitle) {
          case 'Muscle Building Plan': // 力量训练
            weeklyIntensity = [5, 4, 5, 5, 4];
            weightData = _generateWeightData(userWeight!, [0.0, -0.1, -0.3, -0.6, -1.0]);
            break;
          case 'Core & Posture Training': // 核心训练
            weeklyIntensity = [4, 3, 4, 3, 3];
            weightData = _generateWeightData(userWeight!, [0.0, -0.2, -0.6, -1.1, -1.8]);
            break;
          case 'Fat Burning Program': // 瘦身计划
            weeklyIntensity = [3, 3, 3, 3, 3];
            weightData = _generateWeightData(userWeight!, [0.0, -0.3, -1.0, -1.8, -2.9]);
            break;
          default:
            weeklyIntensity = [1, 1, 1, 1, 1]; // 改为默认11111
            weightData = _generateWeightData(userWeight ?? 70, [0.0, -0.2, -0.6, -1.1, -1.8]);
        }
        isLoading = false;
      });

      // 加载实际体重数据
      await _loadActualWeightData();
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      // 设置默认值防止崩溃
      setState(() {
        userWeight = 70.0;
        userHeight = 170.0;
        weeklyIntensity = [1, 1, 1, 1, 1]; // 改为默认11111
        weightData = _generateWeightData(70.0, [0.0, 0.0, 0.0, 0.0, 0.0]); // 默认保持体重不变
        isLoading = false;
      });
    }
  }

  List<double> _generateWeightData(double baseWeight, List<double> changes) {
    // 确保生成5个数据点，改为保留两位小数
    return List.generate(5, (index) {
      if (index < changes.length) {
        return double.parse((baseWeight + changes[index]).toStringAsFixed(2));
      } else {
        return baseWeight; // 如果变化数组不够长，使用基础体重
      }
    });
  }

  @override
  void dispose() {
    // 清理监听器
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white, // 白色背景
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your training intensity',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 强度标签
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.only(left: 8),
                          child: const Text(
                            'Strength',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 条形图
                    SizedBox(
                      height: 200,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(5, (index) =>
                            _buildBarChart('W${index + 1}', weeklyIntensity.isNotEmpty ? weeklyIntensity[index] : 1, Colors.blue)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 时间轴标签
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Time',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 用户个人资料卡片
              if (userData != null) buildUserProfileCard(),

              const SizedBox(height: 32),
              const Text(
                'Weight Progress',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // 改进的体重记录图表
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                height: 350,
                width: double.infinity,
                child: Column(
                  children: [
                    // 图表标题和状态提示
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Weight Records',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (dailyWeights.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              '${dailyWeights.length} records',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 改进的图表
                    Expanded(
                      child: CustomPaint(
                        painter: ImprovedWeightChartPainter(
                          data: dailyWeights,
                          baseWeight: userWeight,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(String label, int value, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 30,
          height: value * 30.0, // 根据强度值调整高度
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget buildUserProfileCard() {
    final bmi = calculateBMI();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                userData!['gender'] == 'Male' ? Icons.male : Icons.female,
                color: Colors.blue,
                size: 30,
              ),
              const SizedBox(width: 12),
              Text(
                'Your Profile',
                style: TextStyle(
                  color: Colors.blue.shade800,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              buildProfileItem(
                'Age',
                '${userData!['age'] ?? 'N/A'}',
                Icons.cake,
              ),
              buildProfileItem(
                'Weight',
                '${userData!['weight']?.toStringAsFixed(2) ?? 'N/A'}kg', // 改为显示两位小数
                Icons.monitor_weight,
              ),
              buildProfileItem(
                'Height',
                '${userData!['height'] ?? 'N/A'}cm',
                Icons.height,
              ),
            ],
          ),
          if (bmi != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: getBMIColor(bmi).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: getBMIColor(bmi)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'BMI: ${bmi.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: getBMIColor(bmi),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    getBMIStatus(bmi),
                    style: TextStyle(
                      color: getBMIColor(bmi),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildProfileItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(1, 1),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.blue,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  double? calculateBMI() {
    if (userData != null &&
        userData!['weight'] != null &&
        userData!['height'] != null) {
      final weight = userData!['weight'].toDouble();
      final height = userData!['height'].toDouble();
      if (height > 0) {
        return weight / ((height / 100) * (height / 100));
      }
    }
    return null;
  }

  Color getBMIColor(double bmi) {
    if (bmi < 18.5) {
      return Colors.blue; // 偏瘦
    } else if (bmi < 25) {
      return Colors.green; // 正常
    } else if (bmi < 30) {
      return Colors.orange; // 超重
    } else {
      return Colors.red; // 肥胖
    }
  }

  String getBMIStatus(double bmi) {
    if (bmi < 18.5) {
      return 'Underweight';
    } else if (bmi < 25) {
      return 'Normal';
    } else if (bmi < 30) {
      return 'Overweight';
    } else {
      return 'Obese';
    }
  }
}

// 改进的体重图表绘制器
class ImprovedWeightChartPainter extends CustomPainter {
  final List<MapEntry<DateTime, double>> data;
  final double? baseWeight; // 用户当前体重

  ImprovedWeightChartPainter({required this.data, this.baseWeight});

  @override
  void paint(Canvas canvas, Size size) {
    final margin = 50.0;
    final chartWidth = size.width - margin * 2;
    final chartHeight = size.height - margin * 2;

    // 过滤有效数据（排除0或无效值）
    final validData = data.where((entry) => entry.value > 0).toList();

    // 如果没有有效数据，显示提示信息
    if (validData.isEmpty) {
      _drawNoDataMessage(canvas, size);
      return;
    }

    // 设置Y轴范围（基于用户体重）
    final currentWeight = baseWeight ?? 70.0;
    final minY = currentWeight - 5; // 当前体重-5kg
    final maxY = currentWeight + 5; // 当前体重+5kg

    // 绘制坐标轴
    _drawAxes(canvas, size, margin, chartWidth, chartHeight);

    // 绘制Y轴刻度和标签
    _drawYAxisLabels(canvas, margin, chartWidth, chartHeight, minY, maxY);

    // 绘制数据点和连线
    _drawDataPoints(canvas, validData, margin, chartWidth, chartHeight, minY, maxY);

    // 绘制X轴日期标签
    _drawXAxisLabels(canvas, validData, margin, chartWidth, chartHeight);
  }

  void _drawNoDataMessage(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'No weight records yet\nComplete workouts to track progress',
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey,
          height: 1.5,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final centerX = size.width / 2 - textPainter.width / 2;
    final centerY = size.height / 2 - textPainter.height / 2;
    textPainter.paint(canvas, Offset(centerX, centerY));
  }

  void _drawAxes(Canvas canvas, Size size, double margin, double chartWidth, double chartHeight) {
    final axisPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.5;

    // Y轴
    canvas.drawLine(
      Offset(margin, margin),
      Offset(margin, margin + chartHeight),
      axisPaint,
    );

    // X轴
    canvas.drawLine(
      Offset(margin, margin + chartHeight),
      Offset(margin + chartWidth, margin + chartHeight),
      axisPaint,
    );
  }

  void _drawYAxisLabels(Canvas canvas, double margin, double chartWidth, double chartHeight, double minY, double maxY) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 绘制5个Y轴刻度
    for (int i = 0; i <= 4; i++) {
      final weight = maxY - (i * 2.5); // 每隔2.5kg一个刻度
      final y = margin + (chartHeight / 4) * i;

      // 刻度线
      final tickPaint = Paint()
        ..color = Colors.grey.shade300
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(margin - 5, y),
        Offset(margin + 5, y),
        tickPaint,
      );

      // 网格线
      final gridPaint = Paint()
        ..color = Colors.grey.shade100
        ..strokeWidth = 0.5;
      canvas.drawLine(
        Offset(margin, y),
        Offset(margin + chartWidth, y),
        gridPaint,
      );

      // 标签 - 改为显示两位小数
      textPainter.text = TextSpan(
        text: '${weight.toStringAsFixed(2)}kg',
        style: const TextStyle(
          fontSize: 12,
          color: Colors.black54,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(margin - textPainter.width - 10, y - textPainter.height / 2),
      );
    }
  }

  void _drawDataPoints(Canvas canvas, List<MapEntry<DateTime, double>> validData,
      double margin, double chartWidth, double chartHeight,
      double minY, double maxY) {
    final pointPaint = Paint()..color = Colors.green;
    final linePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final count = validData.length;
    final stepX = count > 1 ? chartWidth / (count - 1) : 0;
    final yRange = maxY - minY;

    Path path = Path();
    List<Offset> points = [];

    for (int i = 0; i < validData.length; i++) {
      final x = margin + (count > 1 ? stepX * i : chartWidth / 2);
      final y = margin + chartHeight - ((validData[i].value - minY) / yRange * chartHeight);

      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // 绘制连线（只有多个点时才绘制）
    if (validData.length > 1) {
      canvas.drawPath(path, linePaint);
    }

    // 绘制数据点和数值标签
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < points.length; i++) {
      final point = points[i];

      // 绘制点
      canvas.drawCircle(point, 6, pointPaint);
      canvas.drawCircle(point, 6, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);

      // 绘制数值标签 - 改为显示两位小数
      textPainter.text = TextSpan(
        text: '${validData[i].value.toStringAsFixed(2)}',
        style: const TextStyle(
          fontSize: 12,
          color: Colors.green,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();

      // 确保标签不会超出边界
      double labelX = point.dx - textPainter.width / 2;
      double labelY = point.dy - 25;

      // 防止标签超出左右边界
      if (labelX < 0) labelX = 5;
      if (labelX + textPainter.width > margin + chartWidth + margin) {
        labelX = margin + chartWidth + margin - textPainter.width - 5;
      }

      textPainter.paint(canvas, Offset(labelX, labelY));
    }
  }

  void _drawXAxisLabels(Canvas canvas, List<MapEntry<DateTime, double>> validData,
      double margin, double chartWidth, double chartHeight) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final count = validData.length;
    final stepX = count > 1 ? chartWidth / (count - 1) : 0;

    for (int i = 0; i < validData.length; i++) {
      final x = margin + (count > 1 ? stepX * i : chartWidth / 2);
      final date = validData[i].key;

      // 刻度线
      final tickPaint = Paint()
        ..color = Colors.grey.shade300
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(x, margin + chartHeight - 5),
        Offset(x, margin + chartHeight + 5),
        tickPaint,
      );

      // 日期标签
      textPainter.text = TextSpan(
        text: '${date.month}/${date.day}',
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black54,
        ),
      );
      textPainter.layout();

      // 旋转文字以避免重叠
      canvas.save();
      canvas.translate(x, margin + chartHeight + 15);
      canvas.rotate(-0.5); // 轻微倾斜
      textPainter.paint(canvas, Offset(-textPainter.width / 2, 0));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}