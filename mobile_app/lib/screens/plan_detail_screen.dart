// screens/plan_detail_screen.dart
import 'package:flutter/material.dart';
import 'card_payment_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlanDetailScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String rating;
  final Color color1;
  final Color color2;
  final double? price;
  final String? courseId;
  final Map<String, dynamic>? courseData;

  const PlanDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.rating,
    required this.color1,
    required this.color2,
    this.price,
    this.courseId,
    this.courseData,
  });

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  double _additionalFee = 0.0;
  double _totalPrice = 0.0;
  String? _coachId;
  bool _isLoadingFees = true;

  @override
  void initState() {
    super.initState();
    _loadPriceInformation();
  }

  // 加载价格信息包括额外费用
  Future<void> _loadPriceInformation() async {
    try {
      final displayPrice = widget.price ?? 99.0;

      // 获取教练ID
      String? coachId;
      if (widget.courseData != null) {
        coachId = widget.courseData!['coachId'];
      } else if (widget.courseId != null) {
        final courseDoc = await FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.courseId!)
            .get();
        if (courseDoc.exists) {
          coachId = courseDoc.data()?['coachId'];
        }
      }

      if (coachId != null && coachId.isNotEmpty) {
        _coachId = coachId;

        // 查找教练绑定的健身房
        final coachDoc = await FirebaseFirestore.instance
            .collection('coaches')
            .doc(coachId)
            .get();

        String? gymAdminId;
        if (coachDoc.exists) {
          gymAdminId = coachDoc.data()?['assignedGymId'];
        }

        // 如果找到了健身房，获取费用设置
        if (gymAdminId != null && gymAdminId.isNotEmpty) {
          final gymSettingsDoc = await FirebaseFirestore.instance
              .collection('gym_settings')
              .doc(gymAdminId)
              .get();

          if (gymSettingsDoc.exists) {
            final additionalFee = (gymSettingsDoc.data()?['additionalFee'] ?? 0.0).toDouble();
            setState(() {
              _additionalFee = additionalFee;
              _totalPrice = displayPrice + additionalFee;
              _isLoadingFees = false;
            });
            return;
          }
        }
      }

      // 如果没有找到额外费用，使用原价
      setState(() {
        _additionalFee = 0.0;
        _totalPrice = displayPrice;
        _isLoadingFees = false;
      });
    } catch (e) {
      print('Error loading price information: $e');
      setState(() {
        _additionalFee = 0.0;
        _totalPrice = widget.price ?? 99.0;
        _isLoadingFees = false;
      });
    }
  }

  // 获取课程详细信息 - 现在支持动态数据和硬编码数据
  Map<String, dynamic> _getPlanDetails() {
    // 如果有来自Firestore的数据，优先使用
    if (widget.courseData != null) {
      return {
        'introduction': widget.courseData!['description'] ?? 'Comprehensive fitness program designed to meet your specific goals.',
        'activities': List<String>.from(widget.courseData!['activities'] ?? ['Custom Training', 'Nutrition Guidance', 'Progress Tracking']),
        'priceBreakdown': List<String>.from(widget.courseData!['priceBreakdown'] ?? ['Training Sessions', 'Meal Planning', 'Progress Reports'])
      };
    }

    // 否则使用硬编码数据（向后兼容）
    switch (widget.title) {
      case 'Muscle Building Plan':
        return {
          'introduction': 'This plan is designed for individuals who want to build lean muscle, increase strength, and improve overall physique. Whether you\'re a beginner or have gym experience, this structured program provides progressive resistance training and nutrition guidance to help you sculpt the body you want.',
          'activities': [
            '4-Day Strength Training',
            'Muscle Isolation Circuits',
            'Protein Meal Plan',
            'Monthly Progress Check'
          ],
          'priceBreakdown': [
            'Coach Supervision (RM 39)',
            'Protein Supplement Guide (RM 20)',
            'Gym Access / Equipment (RM 30)',
            'Progress Evaluation Report (RM 10)'
          ]
        };
      case 'Fat Burning Program':
        return {
          'introduction': 'Ideal for individuals focused on losing body fat, increasing stamina, and boosting metabolism. This plan combines cardio-intensive workouts and balanced meal guidance to help you achieve a fitter, leaner shape.',
          'activities': [
            'HIIT & Cardio Sessions',
            'Fat-Loss Meal Plan',
            'Group Coaching & Motivation',
            'Body Fat Tracking'
          ],
          'priceBreakdown': [
            'Cardio Coaching (RM 35)',
            'Meal Plan Guidance (RM 25)',
            'Gym / HIIT Zone Access (RM 30)',
            'Progress Tracker (RM 9)'
          ]
        };
      case 'Core & Posture Training':
        return {
          'introduction': 'Perfect for improving core strength, correcting posture, and enhancing body stability. This program includes targeted movements and flexibility work to support daily balance and long-term spine health.',
          'activities': [
            'Core Strength Workouts',
            'Posture Correction Exercises',
            'Breathing & Balance Drills',
            'Monthly Check-in Feedback'
          ],
          'priceBreakdown': [
            'Posture Training Guide (RM 29)',
            'Core Stability Sessions (RM 30)',
            'Equipment / Mat Use (RM 25)',
            'Monthly Feedback (RM 15)'
          ]
        };
      default:
        return {
          'introduction': 'Comprehensive fitness program designed to meet your specific goals.',
          'activities': ['Custom Training', 'Nutrition Guidance', 'Progress Tracking'],
          'priceBreakdown': ['Training Sessions', 'Meal Planning', 'Progress Reports']
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final planDetails = _getPlanDetails();
    final displayPrice = widget.price ?? 99.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'LTC',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),

            // 标题部分
            Center(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.color1, widget.color2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Introduction 部分
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Introduction :',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange[300]!, width: 1),
                    ),
                    child: Text(
                      planDetails['introduction'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Program Activities 部分
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Program Activities :',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ...planDetails['activities'].map<Widget>((activity) =>
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '• $activity',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                  ).toList(),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Price 部分 - 修改为显示详细价格分解
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pricing Details :',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // 价格明细卡片
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[300]!, width: 2),
                    ),
                    child: _isLoadingFees
                        ? const Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Loading pricing information...'),
                      ],
                    )
                        : Column(
                      children: [
                        // 课程价格
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Course Price:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'RM ${displayPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        // 如果有额外费用，显示服务费
                        if (_additionalFee > 0) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Service Fee:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'RM ${_additionalFee.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],

                        const Divider(height: 24, thickness: 2),

                        // 总价格
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Price:',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              'RM ${_totalPrice.toStringAsFixed(0)}/Month',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 原有的价格分解项目
                  ...planDetails['priceBreakdown'].map<Widget>((item) =>
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.orange[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '• $item',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                  ).toList(),
                ],
              ),
            ),

            const SizedBox(height: 100), // 给底部按钮留空间
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoadingFees ? null : () => _navigateToPayment(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: _isLoadingFees
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
              'Continue to Payment - RM ${_totalPrice.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToPayment(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CardPaymentScreen(
          title: widget.title,
          planId: widget.courseId ?? widget.title.replaceAll(' ', '_').toLowerCase(),
          price: widget.price ?? 99.0,
          category: 'Fitness',
          coachId: _coachId, // 传递教练ID
        ),
      ),
    );
  }
}