import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditCourseDescriptionScreen extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;

  const EditCourseDescriptionScreen({
    super.key,
    required this.courseId,
    required this.courseData,
  });

  @override
  State<EditCourseDescriptionScreen> createState() => _EditCourseDescriptionScreenState();
}

class _EditCourseDescriptionScreenState extends State<EditCourseDescriptionScreen> {
  late TextEditingController _introController;
  late TextEditingController _priceController; // 新增价格控制器
  List<TextEditingController> _activityControllers = [];
  List<TextEditingController> _priceControllers = [];

  @override
  void initState() {
    super.initState();
    _introController = TextEditingController(
      text: widget.courseData['description'] ?? '',
    );

    // 初始化价格控制器
    _priceController = TextEditingController(
      text: widget.courseData['price']?.toString() ?? '99',
    );

    final activities = List<String>.from(widget.courseData['activities'] ?? []);
    final prices = List<String>.from(widget.courseData['priceBreakdown'] ?? []);

    _activityControllers = activities.map((e) => TextEditingController(text: e)).toList();
    _priceControllers = prices.map((e) => TextEditingController(text: e)).toList();

    if (_activityControllers.isEmpty) _activityControllers.add(TextEditingController());
    if (_priceControllers.isEmpty) _priceControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    _introController.dispose();
    _priceController.dispose(); // 释放价格控制器
    for (var c in _activityControllers) {
      c.dispose();
    }
    for (var c in _priceControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _saveChanges() async {
    try {
      // 显示加载状态
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在保存...'), duration: Duration(seconds: 1)),
      );

      final intro = _introController.text.trim();
      final price = double.tryParse(_priceController.text.trim()) ?? 99.0;
      final activities = _activityControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      final prices = _priceControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

      // 调试信息
      print('🔄 正在保存课程数据...');
      print('Course ID: ${widget.courseId}');
      print('Description: $intro');
      print('Price: $price');
      print('Activities: $activities');
      print('Price Breakdown: $prices');

      // 检查courseId是否有效
      if (widget.courseId.isEmpty) {
        throw Exception('Course ID is empty');
      }

      // 保存到Firestore
      await FirebaseFirestore.instance.collection('courses').doc(widget.courseId).update({
        'description': intro,
        'price': price,
        'activities': activities,
        'priceBreakdown': prices,
        'updatedAt': FieldValue.serverTimestamp(), // 添加更新时间
      });

      print('✅ 数据保存成功');

      if (!mounted) return;

      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Description updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // 返回并传递刷新信号
      Navigator.pop(context, true);

    } catch (e) {
      print('❌ 保存失败: $e');

      if (!mounted) return;

      // 显示错误消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to save: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildDynamicList(String title, List<TextEditingController> controllers, VoidCallback onAdd) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...controllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: '$title ${index + 1}',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() => controllers.removeAt(index));
                  },
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          );
        }),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text('Add $title'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Description', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 课程介绍
            const Text('Introduction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _introController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter course introduction',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // 新增：课程价格
            const Text('Course Price (RM)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Enter price (e.g., 99)',
                prefixText: 'RM ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // 活动列表
            _buildDynamicList('Activity', _activityControllers, () {
              setState(() => _activityControllers.add(TextEditingController()));
            }),

            // 价格明细
            _buildDynamicList('Price Item', _priceControllers, () {
              setState(() => _priceControllers.add(TextEditingController()));
            }),

            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}