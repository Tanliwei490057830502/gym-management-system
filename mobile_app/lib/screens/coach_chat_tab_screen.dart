// screens/coach_chat_tab_screen.dart
// 教练版本的聊天标签页
// - 显示教练的 UID，有橙色长方形背景，带复制按钮
// - 搜索框灰色长方形包裹
// - 所有字体改为黑色
// - 使用橙色主题色

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'coach_chat_screen.dart';

class CoachChatTabScreen extends StatefulWidget {
  const CoachChatTabScreen({super.key});

  @override
  State<CoachChatTabScreen> createState() => _CoachChatTabScreenState();
}

class _CoachChatTabScreenState extends State<CoachChatTabScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _studentCodeController = TextEditingController();

  String? _coachId;
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadCoachId();
  }

  Future<void> _loadCoachId() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() => _coachId = user.uid);
      _loadStudents(user.uid);
    }
  }

  Future<void> _loadStudents(String uid) async {
    final snapshot = await _firestore
        .collection('coaches')
        .doc(uid)
        .collection('students')
        .get();

    final List<Map<String, dynamic>> loadedStudents = [];
    for (var doc in snapshot.docs) {
      final studentId = doc.id;
      final studentDoc = await _firestore.collection('users').doc(studentId).get();
      if (studentDoc.exists) {
        loadedStudents.add({
          'uid': studentId,
          'name': studentDoc['name'] ?? studentDoc['username'] ?? 'Unknown Student',
        });
      }
    }

    setState(() => _students = loadedStudents);
  }

  Future<void> _addStudent() async {
    final studentCode = _studentCodeController.text.trim();
    final user = _auth.currentUser;

    if (user == null || studentCode.isEmpty || studentCode == user.uid) return;

    final studentDoc = await _firestore.collection('users').doc(studentCode).get();
    if (studentDoc.exists) {
      // Add student to coach's student list
      await _firestore
          .collection('coaches')
          .doc(user.uid)
          .collection('students')
          .doc(studentCode)
          .set({
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Add coach to student's coach list
      await _firestore
          .collection('users')
          .doc(studentCode)
          .collection('coaches')
          .doc(user.uid)
          .set({
        'addedAt': FieldValue.serverTimestamp(),
      });

      await _loadStudents(user.uid);
      _studentCodeController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('学生添加成功'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('该学生不存在'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_coachId != null) ...[
              const Text(
                '我的教练码：',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _coachId!,
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.orange),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: _coachId!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('教练码已复制'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],

            // Add Student Section
            const Text(
              '添加学生：',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _studentCodeController,
                    decoration: InputDecoration(
                      hintText: '输入学生用户码',
                      hintStyle: const TextStyle(color: Colors.black54),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.person_add, color: Colors.orange),
                    ),
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addStudent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text(
                    '添加',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Students List
            Row(
              children: [
                const Text(
                  '我的学生',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_students.length}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _students.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '暂无学生',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '添加学生后可以开始聊天',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _students.length,
                itemBuilder: (context, index) {
                  final student = _students[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: const Icon(
                          Icons.person,
                          color: Colors.orange,
                        ),
                      ),
                      title: Text(
                        student['name'] ?? 'Unknown Student',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'UID: ${student['uid']}',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.chat,
                          color: Colors.orange,
                          size: 20,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CoachChatScreen(
                              studentUid: student['uid'],
                              studentName: student['name'],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _studentCodeController.dispose();
    super.dispose();
  }
}