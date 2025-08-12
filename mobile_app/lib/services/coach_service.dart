// gym_app_system/lib/services/coach_service.dart
// 用途：教练管理服务（教练端使用）
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CoachService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 发送绑定请求
  static Future<bool> sendBindingRequest({
    required String coachId,
    required String coachName,
    required String coachEmail,
    required String gymId,
    required String gymName,
    required String message,
    required String targetAdminUid,
    String type = 'bind', // 新增：支持绑定/解绑类型
  }) async {
    try {
      // 检查是否已有待处理的相同类型请求
      final existingRequest = await _firestore
          .collection('binding_requests')
          .where('coachId', isEqualTo: coachId)
          .where('gymId', isEqualTo: gymId)
          .where('type', isEqualTo: type) // 新增：检查请求类型
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        print('Already have a pending ${type} request for this gym');
        return false;
      }

      await _firestore.collection('binding_requests').add({
        'coachId': coachId,
        'coachName': coachName,
        'coachEmail': coachEmail,
        'gymId': gymId,
        'gymName': gymName,
        'message': message,
        'targetAdminUid': targetAdminUid,
        'type': type, // 新增：保存请求类型
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error sending ${type} request: $e');
      return false;
    }
  }

  /// 发送解绑请求（便利方法）
  static Future<bool> sendUnbindRequest({
    required String coachId,
    required String coachName,
    required String coachEmail,
    required String gymId,
    required String gymName,
    required String message,
    required String targetAdminUid,
  }) async {
    return sendBindingRequest(
      coachId: coachId,
      coachName: coachName,
      coachEmail: coachEmail,
      gymId: gymId,
      gymName: gymName,
      message: message,
      targetAdminUid: targetAdminUid,
      type: 'unbind',
    );
  }

  /// 获取教练的绑定请求历史
  static Stream<List<BindingRequest>> getCoachBindingRequestsStream(String coachId) {
    return _firestore
        .collection('binding_requests')
        .where('coachId', isEqualTo: coachId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => BindingRequest.fromFirestore(doc)).toList();
    });
  }

  /// 获取所有教练（用于预约选择）
  static Future<List<Map<String, dynamic>>> getCoaches() async {
    try {
      final snapshot = await _firestore
          .collection('coaches')
          .where('status', isEqualTo: 'active')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'assignedGymId': data['assignedGymId'],
          'assignedGymName': data['assignedGymName'],
          'status': data['status'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error getting coaches: $e');
      return [];
    }
  }

  /// 获取教练分配的健身房
  static Future<List<Map<String, dynamic>>> getCoachAssignedGyms(String coachId) async {
    try {
      // 获取教练信息
      final coachDoc = await _firestore.collection('coaches').doc(coachId).get();
      if (!coachDoc.exists) return [];

      final coachData = coachDoc.data()!;
      final assignedGymId = coachData['assignedGymId'];

      if (assignedGymId == null) return [];

      // 获取健身房信息
      final gymDoc = await _firestore.collection('gym_info').doc(assignedGymId).get();
      if (!gymDoc.exists) return [];

      final gymData = gymDoc.data()!;
      return [{
        'id': gymDoc.id,
        'name': gymData['name'] ?? 'Unknown Gym',
        'address': gymData['address'] ?? '',
        'phone': gymData['phone'] ?? '',
      }];
    } catch (e) {
      print('Error getting coach assigned gyms: $e');
      return [];
    }
  }

  /// 获取已预订的时间段
  static Future<List<String>> getBookedTimeSlots({
    required DateTime date,
    required String coachId,
    required String gymId,
  }) async {
    try {
      // 设置日期范围（当天的开始和结束）
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await _firestore
          .collection('appointments')
          .where('coachId', isEqualTo: coachId)
          .where('gymId', isEqualTo: gymId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .where('status', whereIn: ['pending', 'confirmed'])
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return data['timeSlot'] as String;
      }).toList();
    } catch (e) {
      print('Error getting booked time slots: $e');
      return [];
    }
  }

  /// 创建预约
  static Future<bool> createAppointment({
    required String coachId,
    required String gymId,
    required DateTime date,
    required String timeSlot,
    required String userId,
    String? notes,
  }) async {
    try {
      // 获取用户信息
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.exists ? userDoc.data()! : {};

      // 获取教练信息
      final coachDoc = await _firestore.collection('coaches').doc(coachId).get();
      final coachData = coachDoc.exists ? coachDoc.data()! : {};

      // 获取健身房信息
      final gymDoc = await _firestore.collection('gym_info').doc(gymId).get();
      final gymData = gymDoc.exists ? gymDoc.data()! : {};

      await _firestore.collection('appointments').add({
        'userId': userId,
        'userName': userData['name'] ?? 'Unknown User',
        'userEmail': userData['email'] ?? '',
        'coachId': coachId,
        'coachName': coachData['name'] ?? 'Unknown Coach',
        'gymId': gymId,
        'gymName': gymData['name'] ?? 'Unknown Gym',
        'date': Timestamp.fromDate(date),
        'timeSlot': timeSlot,
        'status': 'pending',
        'notes': notes ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error creating appointment: $e');
      return false;
    }
  }
}

/// 绑定请求数据模型
class BindingRequest {
  final String id;
  final String coachId;
  final String coachName;
  final String coachEmail;
  final String gymId;
  final String gymName;
  final String message;
  final String type; // 新增：请求类型 'bind' 或 'unbind'
  final String status;
  final DateTime? createdAt;
  final DateTime? processedAt;
  final String? rejectReason;

  BindingRequest({
    required this.id,
    required this.coachId,
    required this.coachName,
    required this.coachEmail,
    required this.gymId,
    required this.gymName,
    required this.message,
    this.type = 'bind', // 默认为绑定类型
    required this.status,
    this.createdAt,
    this.processedAt,
    this.rejectReason,
  });

  factory BindingRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BindingRequest(
      id: doc.id,
      coachId: data['coachId'] ?? '',
      coachName: data['coachName'] ?? '',
      coachEmail: data['coachEmail'] ?? '',
      gymId: data['gymId'] ?? '',
      gymName: data['gymName'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'bind', // 新增：读取请求类型
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      processedAt: (data['processedAt'] as Timestamp?)?.toDate(),
      rejectReason: data['rejectReason'],
    );
  }

  /// 获取状态显示文本
  String get statusDisplayText {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  /// 获取请求类型显示文本
  String get typeDisplayText {
    return type == 'unbind' ? 'Unbind' : 'Bind';
  }

  /// 格式化创建时间
  String get formattedCreatedAt {
    if (createdAt == null) return 'Unknown';
    return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
  }
}