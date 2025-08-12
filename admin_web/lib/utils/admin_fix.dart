import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDocumentFix {
  static Future<void> fixMyAdminDocument() async {
    final String uid = 'EvqszC5cz3Njw6j0w3QDZ8dJVfL2';

    try {
      final docRef = FirebaseFirestore.instance.collection('admins').doc(uid);

      await docRef.set({
        'uid': uid,
        'email': 'weiliqi0502@gmail.com',
        'name': 'Tan Li Wei',
        'role': 'admin',
        'isActive': true,
        'platform': 'web',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // 保留其他已有字段

      print('✅ Admin document fixed successfully!');
    } catch (e) {
      print('❌ Failed to fix admin document: $e');
    }
  }
}
