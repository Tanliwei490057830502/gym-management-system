// 更新后的 chat_tab_screen.dart
// - 显示自己的 UID，有紫色长方形背景，带复制按钮
// - 搜索框灰色长方形包裹
// - 所有字体改为黑色
// - 删除返回键图标

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'chat_screen.dart';

class ChatTabScreen extends StatefulWidget {
  const ChatTabScreen({super.key});

  @override
  State<ChatTabScreen> createState() => _ChatTabScreenState();
}

class _ChatTabScreenState extends State<ChatTabScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _friendCodeController = TextEditingController();

  String? _userId;
  List<Map<String, dynamic>> _friends = [];

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() => _userId = user.uid);
      _loadFriends(user.uid);
    }
  }

  Future<void> _loadFriends(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .get();

    final List<Map<String, dynamic>> loadedFriends = [];
    for (var doc in snapshot.docs) {
      final friendId = doc.id;
      final friendDoc = await _firestore.collection('users').doc(friendId).get();
      if (friendDoc.exists) {
        loadedFriends.add({
          'uid': friendId,
          'name': friendDoc['username'] ?? 'Unknown',
        });
      }
    }

    setState(() => _friends = loadedFriends);
  }

  Future<void> _addFriend() async {
    final friendCode = _friendCodeController.text.trim();
    final user = _auth.currentUser;

    if (user == null || friendCode.isEmpty || friendCode == user.uid) return;

    final friendDoc = await _firestore.collection('users').doc(friendCode).get();
    if (friendDoc.exists) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('friends')
          .doc(friendCode)
          .set({});

      await _firestore
          .collection('users')
          .doc(friendCode)
          .collection('friends')
          .doc(user.uid)
          .set({});

      await _loadFriends(user.uid);
      _friendCodeController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('添加成功')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该用户不存在')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('我的好友', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_userId != null) ...[
              const Text('我的好友码：', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _userId!,
                        style: const TextStyle(color: Colors.deepPurple, fontSize: 14),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: Colors.deepPurple),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: _userId!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('好友码已复制')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _friendCodeController,
                    decoration: InputDecoration(
                      hintText: '输入好友码',
                      hintStyle: const TextStyle(color: Colors.black54),
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addFriend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                  ),
                  child: const Text('添加', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('好友列表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 8),
            Expanded(
              child: _friends.isEmpty
                  ? const Center(child: Text('暂无好友', style: TextStyle(color: Colors.black)))
                  : ListView.builder(
                itemCount: _friends.length,
                itemBuilder: (context, index) {
                  final friend = _friends[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.person, color: Colors.deepPurple),
                      title: Text(friend['name'] ?? 'Unknown', style: const TextStyle(color: Colors.black)),
                      subtitle: Text('UID: ${friend['uid']}', style: const TextStyle(color: Colors.black87)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              friendUid: friend['uid'],
                              friendName: friend['name'],
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
    _friendCodeController.dispose();
    super.dispose();
  }
}
