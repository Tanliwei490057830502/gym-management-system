// screens/card_payment_screen.dart
import 'package:flutter/material.dart';
import 'thank_you_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CardPaymentScreen extends StatefulWidget {
  final String title;
  final String planId;
  final double price;
  final String category;
  final String? coachId; // 添加教练ID参数

  const CardPaymentScreen({
    super.key,
    required this.title,
    required this.planId,
    required this.price,
    required this.category,
    this.coachId,
  });

  @override
  State<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cvcController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();

  double _additionalFee = 0.0;
  double _totalPrice = 0.0;
  String _gymAdminId = '';
  bool _isLoadingFees = true;

  @override
  void initState() {
    super.initState();
    _loadAdditionalFees();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cardNumberController.dispose();
    _cvcController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  // 加载健身房额外费用设置
  Future<void> _loadAdditionalFees() async {
    try {
      String? coachId = widget.coachId;

      // 如果没有传入coachId，尝试从课程数据获取
      if (coachId == null || coachId.isEmpty) {
        final courseDoc = await FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.planId)
            .get();

        if (courseDoc.exists) {
          coachId = courseDoc.data()?['coachId'];
        }
      }

      if (coachId != null && coachId.isNotEmpty) {
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
              _totalPrice = widget.price + additionalFee;
              _gymAdminId = gymAdminId!;
              _isLoadingFees = false;
            });
            return;
          }
        }
      }

      // 如果没有找到额外费用，使用原价
      setState(() {
        _additionalFee = 0.0;
        _totalPrice = widget.price;
        _isLoadingFees = false;
      });
    } catch (e) {
      print('Error loading additional fees: $e');
      setState(() {
        _additionalFee = 0.0;
        _totalPrice = widget.price;
        _isLoadingFees = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Card Payment',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 价格明细显示
                          _buildPriceBreakdown(),

                          const SizedBox(height: 30),

                          // Form fields
                          _buildInputField(
                            'Name of Card:',
                            _nameController,
                            TextInputType.text,
                          ),
                          _buildInputField(
                            'Card Number:',
                            _cardNumberController,
                            TextInputType.number,
                          ),
                          _buildInputField(
                            'CVC:',
                            _cvcController,
                            TextInputType.number,
                          ),
                          _buildInputField(
                            'Expiration Month:',
                            _monthController,
                            TextInputType.number,
                          ),
                          _buildInputField(
                            'Expiration Year:',
                            _yearController,
                            TextInputType.number,
                          ),

                          // 使用Expanded而不是Spacer来避免overflow
                          const Expanded(
                            child: SizedBox(height: 20),
                          ),

                          // Pay Now button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoadingFees ? null : () => _navigateToThankYou(context),
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
                                'Pay RM ${_totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20), // 底部安全间距
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    if (_isLoadingFees) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading price information...'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Price Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Course Price:',
                style: TextStyle(color: Colors.black87),
              ),
              Text(
                'RM ${widget.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (_additionalFee > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Service Fee:',
                  style: TextStyle(color: Colors.black87),
                ),
                Text(
                  'RM ${_additionalFee.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                'RM ${_totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, TextInputType keyboardType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              fillColor: Colors.white,
              filled: true,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter ${label.toLowerCase()}';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // 修改后的支付处理方法 - 添加收入记录功能
  void _navigateToThankYou(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not logged in')),
          );
          return;
        }

        final firestore = FirebaseFirestore.instance;

        print('🔄 开始处理支付...');

        // 1. 首先确保courses集合中有对应的课程文档
        final courseRef = firestore.collection('courses').doc(widget.planId);
        final courseDoc = await courseRef.get();

        String? coachId;

        if (!courseDoc.exists) {
          // 如果课程文档不存在，创建它
          await courseRef.set({
            'title': widget.title,
            'category': widget.category,
            'description': _getCourseDescription(widget.title),
            'price': widget.price,
            'imageUrl': _getCourseImageUrl(widget.title),
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('✅ 创建了课程文档: ${widget.planId}');
        } else {
          print('✅ 课程文档已存在: ${widget.planId}');
          // 获取教练ID
          coachId = courseDoc.data()?['coachId'];
        }

        // 2. 写入 user_courses 集合
        await firestore.collection('user_courses').add({
          'userId': user.uid,
          'courseId': widget.planId,
          'title': widget.title,
          'category': widget.category,
          'status': 'active',
          'purchaseDate': Timestamp.now(),
          'remainingSessions': 8,
          'totalSessions': 8,
          'paymentAmount': _totalPrice, // 使用总价格
          'coursePrice': widget.price, // 原课程价格
          'additionalFee': _additionalFee, // 额外费用
          'expiryDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
          'isMainCourse': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        print('✅ 用户课程记录已保存');

        // 3. 记录健身房收入数据（如果有额外费用）
        if (_additionalFee > 0 && _gymAdminId.isNotEmpty) {
          await _recordGymRevenue(firestore, user.uid);
        }

        // 4. 自动加好友功能
        if (coachId != null && coachId.isNotEmpty) {
          await _autoAddFriend(user.uid, coachId, firestore);
        } else {
          print('⚠️ 未找到教练ID，跳过自动加好友');
        }

        // 显示成功消息
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Payment successful! Course added and coach connected!'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // 跳转到 Thank You 页面
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ThankYouScreen(),
          ),
        );
      } catch (e) {
        print('❌ 支付处理失败: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    }
  }

  // 记录健身房收入数据的方法
  Future<void> _recordGymRevenue(FirebaseFirestore firestore, String userId) async {
    try {
      print('💰 记录健身房收入: RM ${_additionalFee.toStringAsFixed(2)}');

      final now = DateTime.now();

      await firestore.collection('gym_revenues').add({
        'gymAdminId': _gymAdminId,
        'amount': _additionalFee,
        'source': 'course_purchase',
        'courseTitle': widget.title,
        'coursePlanId': widget.planId,
        'userId': userId,
        'date': Timestamp.now(),
        'year': now.year,
        'month': now.month,
        'day': now.day,
        'dayOfWeek': now.weekday, // 1=Monday, 7=Sunday
        'description': 'Service fee from course purchase: ${widget.title}',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ 健身房收入记录已保存');
    } catch (e) {
      print('❌ 记录健身房收入失败: $e');
      // 不要因为收入记录失败而影响购买流程，只记录错误
    }
  }

  // 自动加好友的方法
  Future<void> _autoAddFriend(String userId, String coachId, FirebaseFirestore firestore) async {
    try {
      print('🤝 开始自动加好友: 用户 $userId 和教练 $coachId');

      // 检查用户和教练是否存在
      final userDoc = await firestore.collection('users').doc(userId).get();
      final coachDoc = await firestore.collection('coaches').doc(coachId).get();

      if (!userDoc.exists) {
        print('❌ 用户文档不存在');
        return;
      }

      if (!coachDoc.exists) {
        print('❌ 教练文档不存在');
        return;
      }

      // 使用批量写入确保原子性
      final batch = firestore.batch();

      // 1. 将用户添加到教练的学生列表
      final studentRef = firestore
          .collection('coaches')
          .doc(coachId)
          .collection('students')
          .doc(userId);

      batch.set(studentRef, {
        'addedAt': FieldValue.serverTimestamp(),
        'addedBy': 'auto_purchase',
        'courseTitle': widget.title,
        'coursePurchaseDate': Timestamp.now(),
      });

      // 2. 将教练添加到用户的教练列表
      final coachRefForUser = firestore
          .collection('users')
          .doc(userId)
          .collection('coaches')
          .doc(coachId);

      batch.set(coachRefForUser, {
        'addedAt': FieldValue.serverTimestamp(),
        'addedBy': 'auto_purchase',
        'courseTitle': widget.title,
        'coursePurchaseDate': Timestamp.now(),
      });

      // 3. 将教练添加到用户的好友列表（用于聊天）
      final friendRefForUser = firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc(coachId);

      batch.set(friendRefForUser, {
        'addedAt': FieldValue.serverTimestamp(),
        'addedBy': 'auto_purchase',
        'relationship': 'coach',
        'courseTitle': widget.title,
      });

      // 4. 检查教练是否有 users 文档，如果有则互加好友
      final coachUserDoc = await firestore.collection('users').doc(coachId).get();
      if (coachUserDoc.exists) {
        final friendRefForCoach = firestore
            .collection('users')
            .doc(coachId)
            .collection('friends')
            .doc(userId);

        batch.set(friendRefForCoach, {
          'addedAt': FieldValue.serverTimestamp(),
          'addedBy': 'auto_purchase',
          'relationship': 'student',
          'courseTitle': widget.title,
        });
      }

      // 执行批量写入
      await batch.commit();

      print('✅ 自动加好友成功完成');

    } catch (e) {
      print('❌ 自动加好友失败: $e');
      // 不要因为加好友失败而影响购买流程，只记录错误
    }
  }

  // 获取课程描述的辅助方法
  String _getCourseDescription(String title) {
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

  // 获取课程图片URL的辅助方法（可选）
  String? _getCourseImageUrl(String title) {
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
}