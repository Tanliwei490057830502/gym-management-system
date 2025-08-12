import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'coach_create_course_screen.dart';
import 'edit_course_description_screen.dart';

class CoachCourseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> courseData;

  const CoachCourseDetailScreen({super.key, required this.courseData});

  @override
  State<CoachCourseDetailScreen> createState() => _CoachCourseDetailScreenState();
}

class _CoachCourseDetailScreenState extends State<CoachCourseDetailScreen> {
  late Map<String, dynamic> _courseData;

  @override
  void initState() {
    super.initState();
    _courseData = Map<String, dynamic>.from(widget.courseData);
  }

  // 发布课程到用户购买界面
  Future<void> _publishCourse() async {
    try {
      final courseId = _courseData['id'];
      if (courseId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Course ID not found')),
        );
        return;
      }

      // 检查必要字段是否完整
      final title = _courseData['title'];
      final description = _courseData['description'];
      final price = _courseData['price'];
      final activities = _courseData['activities'];

      if (title == null || title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Please set course title first')),
        );
        return;
      }

      if (description == null || description.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Please add course description first')),
        );
        return;
      }

      if (price == null || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Please set a valid price first')),
        );
        return;
      }

      if (activities == null || activities.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Please add course activities first')),
        );
        return;
      }

      // 显示确认对话框
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Publish Course'),
          content: Text('Are you sure you want to publish "$title" to the user purchase page?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Publish', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // 更新课程状态为已发布
      await FirebaseFirestore.instance.collection('courses').doc(courseId).update({
        'status': 'published',
        'publishedAt': FieldValue.serverTimestamp(),
        'isVisible': true, // 用户可见
      });

      // 更新本地状态
      setState(() {
        _courseData['status'] = 'published';
        _courseData['isVisible'] = true;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Course published successfully! Users can now purchase it.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to publish: $e')),
      );
    }
  }

  // 取消发布课程
  Future<void> _unpublishCourse() async {
    try {
      final courseId = _courseData['id'];
      if (courseId == null) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unpublish Course'),
          content: const Text('This will remove the course from user purchase page. Are you sure?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Unpublish', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      await FirebaseFirestore.instance.collection('courses').doc(courseId).update({
        'status': 'draft',
        'isVisible': false,
      });

      setState(() {
        _courseData['status'] = 'draft';
        _courseData['isVisible'] = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📋 Course unpublished successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to unpublish: $e')),
      );
    }
  }

  // 刷新课程数据
  Future<void> _refreshCourseData() async {
    try {
      final courseId = _courseData['id'];
      if (courseId == null || courseId.isEmpty) {
        print('❌ Course ID is null or empty');
        return;
      }

      print('🔄 正在刷新课程数据...');
      final doc = await FirebaseFirestore.instance.collection('courses').doc(courseId).get();

      if (doc.exists) {
        setState(() {
          _courseData = {
            ...doc.data()!,
            'id': doc.id,
          };
        });
        print('✅ 课程数据已刷新');
      } else {
        print('❌ 课程文档不存在');
      }
    } catch (e) {
      print('❌ 刷新课程数据失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to refresh data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = _courseData['title'] ?? 'Untitled';
    final String courseId = _courseData['id'] ?? '';
    final days = _courseData['days'] ?? {};
    final isPublished = _courseData['status'] == 'published';
    final price = _courseData['price'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Course Details', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          // 刷新按钮
          IconButton(
            onPressed: _refreshCourseData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 标题和状态
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isPublished ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPublished ? 'PUBLISHED' : 'DRAFT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // 价格显示
          if (price > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Price: RM $price',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 功能按钮方块
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CoachCreateCourseScreen(
                          isEditMode: true,
                          courseId: courseId,
                          existingCourseData: _courseData,
                        ),
                      ),
                    );
                    if (result != null) {
                      _refreshCourseData();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange, width: 1),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.edit_calendar, color: Colors.orange, size: 28),
                        SizedBox(height: 8),
                        Text(
                          '编辑训练计划',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditCourseDescriptionScreen(
                          courseId: _courseData['id'],
                          courseData: _courseData,
                        ),
                      ),
                    );
                    if (result == true) {
                      print('🔄 刷新课程数据...');
                      await _refreshCourseData();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange, width: 1),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.article, color: Colors.orange, size: 28),
                        SizedBox(height: 8),
                        Text(
                          '编辑课程简介',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 发布/取消发布按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isPublished ? _unpublishCourse : _publishCourse,
              icon: Icon(isPublished ? Icons.visibility_off : Icons.publish),
              label: Text(isPublished ? 'Unpublish Course' : 'Publish Course'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPublished ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // 显示课程大纲标题
          const Text('课程训练安排（预览）',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // 显示 Day1~7 的简略概览
          ...List.generate(7, (i) {
            final dayKey = 'day${i + 1}';
            final config = days[dayKey];
            final hasCourse = config != null && config['hasCourse'] == true;
            final exercises = (config?['exercises'] as List?)?.length ?? 0;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasCourse ? Colors.orange[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: hasCourse ? Colors.orange : Colors.grey, width: 1),
              ),
              child: Row(
                children: [
                  Text('Day ${i + 1}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hasCourse ? Colors.orange : Colors.grey)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasCourse ? '$exercises 个动作' : '休息日',
                      style: TextStyle(
                          color: hasCourse ? Colors.orange[800] : Colors.grey,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            );
          }),
        ]),
      ),
    );
  }
}