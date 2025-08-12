import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'coach_course_detail_screen.dart';
import 'coach_create_course_screen.dart';

class CoachCourseFolderScreen extends StatefulWidget {
  const CoachCourseFolderScreen({super.key});

  @override
  State<CoachCourseFolderScreen> createState() => _CoachCourseFolderScreenState();
}

class _CoachCourseFolderScreenState extends State<CoachCourseFolderScreen> {
  final user = FirebaseAuth.instance.currentUser;
  late final CollectionReference courseRef;

  @override
  void initState() {
    super.initState();
    courseRef = FirebaseFirestore.instance.collection('courses');
  }

  Future<void> _saveCourseToFirestore(Map<String, dynamic> data) async {
    final docRef = courseRef.doc();
    await docRef.set({
      'title': data['title'],
      'description': data['description'] ?? '',
      'price': data['price'] ?? 99.0,
      'imageUrl': data['imageUrl'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'category': data['category'] ?? 'Fitness',
      'coachId': user!.uid, // 修正字段名为 coachId
      'days': data['days'] ?? {},
      'status': 'draft', // 新课程默认为草稿状态
      'isVisible': false, // 默认不可见
      'activities': [],
      'priceBreakdown': [],
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ 课程已成功创建')),
    );
  }

  Future<void> _createNewCourse() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CoachCreateCourseScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      await _saveCourseToFirestore(result);
      setState(() {}); // 刷新课程列表
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("❌ 未登录用户")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Folder'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNewCourse,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: courseRef
            .where('coachId', isEqualTo: user!.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('加载出错'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('暂无已创建课程'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final course = doc.data() as Map<String, dynamic>;
              final createdAt = course['createdAt'] as Timestamp?;
              final status = course['status'] ?? 'draft';
              final price = course['price'] ?? 0.0;

              return Card(
                color: Colors.orange[50],
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: Stack(
                    children: [
                      const Icon(Icons.school, color: Colors.orange, size: 40),
                      if (status == 'published')
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(course['title'] ?? '未命名课程'),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: status == 'published' ? Colors.green : Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status == 'published' ? 'LIVE' : 'DRAFT',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (price > 0)
                        Text(
                          'Price: RM ${price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      Text(
                        '创建时间: ${createdAt != null ? createdAt.toDate().toLocal().toString().substring(0, 16) : 'N/A'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CoachCourseDetailScreen(
                          courseData: {
                            ...course,
                            'id': doc.id,
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add),
        label: const Text('创建新课程'),
        onPressed: _createNewCourse,
      ),
    );
  }
}