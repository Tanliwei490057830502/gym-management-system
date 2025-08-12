// lib/services/coach_service.dart
// 用途：支持绑定/解绑请求的教练管理服务（集成通知触发）

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/coach.dart';
import '../models/binding_request.dart';
import '../models/course.dart';
import '../models/notification_models.dart';
import '../services/notification_trigger_service.dart';
import 'services.dart';

class CoachService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final NotificationTriggerService _notificationService = NotificationTriggerService();

  /// 初始化服务（新增 - 确保通知服务已启动）
  static Future<void> initialize() async {
    try {
      // 确保通知触发服务已初始化
      if (!_notificationService.isInitialized) {
        await _notificationService.initialize();
      }

      if (kDebugMode) {
        print('✅ CoachService initialized with notification support');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize CoachService: $e');
      }
    }
  }

  /// 获取已批准的教练（仅显示活跃和休息状态的教练）
  static Stream<List<Coach>> getCoachesStream() {
    return _firestore
        .collection('coaches')
        .where('status', whereIn: ['active', 'break']) // 移除 'inactive'
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Coach.fromFirestore(doc)).toList();
    });
  }

  /// 获取所有教练（包括未激活的）- 新增方法
  static Stream<List<Coach>> getAllCoachesStream() {
    return _firestore
        .collection('coaches')
        .where('status', whereIn: ['active', 'inactive', 'break'])
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Coach.fromFirestore(doc)).toList();
    });
  }

  /// 获取待审核的绑定/解绑请求
  static Stream<List<BindingRequest>> getBindingRequestsStream() {
    try {
      return _firestore
          .collection('binding_requests')
          .where('status', isEqualTo: 'pending')
          .where('targetAdminUid', isEqualTo: AuthService.currentUserUid)
          .snapshots()
          .map((snapshot) {
        final requests = snapshot.docs.map((doc) {
          return BindingRequest.fromFirestore(doc);
        }).toList();

        // 在内存中排序，避免 Firestore 复合索引要求
        requests.sort((a, b) {
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        });

        return requests;
      }).handleError((error) {
        if (kDebugMode) {
          print('❌ 获取绑定/解绑请求流失败: $error');
        }
        return <BindingRequest>[];
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ 创建绑定/解绑请求流失败: $e');
      }
      return Stream.value(<BindingRequest>[]);
    }
  }

  /// 获取特定教练的绑定请求流（用于移动端）
  static Stream<List<BindingRequest>> getCoachBindingRequestsStream(String coachId) {
    return _firestore
        .collection('binding_requests')
        .where('coachId', isEqualTo: coachId)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs.map((doc) => BindingRequest.fromFirestore(doc)).toList();

      // 在内存中排序
      requests.sort((a, b) {
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });

      return requests;
    });
  }

  /// 获取课程
  static Stream<List<Course>> getCoursesStream() {
    return _firestore.collection('courses').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Course.fromFirestore(doc)).toList();
    });
  }

  /// 发送绑定/解绑请求（移动端调用）- 集成通知触发
  static Future<bool> sendBindingRequest({
    required String coachId,
    required String coachName,
    required String coachEmail,
    required String gymId,
    required String gymName,
    required String message,
    required String targetAdminUid,  // 新增参数
    String type = 'bind', // 'bind' 或 'unbind'
  }) async {
    try {
      if (kDebugMode) {
        print('📤 发送${type == 'unbind' ? '解绑' : '绑定'}请求...');
        print('教练: $coachName ($coachEmail)');
        print('健身房: $gymName');
        print('类型: $type');
        print('目标管理员: $targetAdminUid');
      }

      // 检查是否已存在相同类型的待处理请求
      final existingRequests = await _firestore
          .collection('binding_requests')
          .where('coachId', isEqualTo: coachId)
          .where('gymId', isEqualTo: gymId)
          .where('type', isEqualTo: type)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequests.docs.isNotEmpty) {
        if (kDebugMode) {
          print('⚠️ 已存在待处理的${type == 'unbind' ? '解绑' : '绑定'}请求');
        }
        return false;
      }

      // 创建新的请求
      final docRef = await _firestore.collection('binding_requests').add({
        'coachId': coachId,
        'coachName': coachName.isNotEmpty ? coachName : 'Unknown Coach',
        'coachEmail': coachEmail,
        'gymId': gymId,
        'gymName': gymName,
        'message': message,
        'type': type, // 添加请求类型
        'status': 'pending',
        'targetAdminUid': targetAdminUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ ${type == 'unbind' ? '解绑' : '绑定'}请求发送成功，文档ID: ${docRef.id}');
      }

      // 🔔 触发通知 - 通知系统会自动监听并发送通知给管理员
      // NotificationTriggerService 已经在监听 binding_requests 集合的变化
      // 当新文档添加时会自动触发通知

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 发送${type == 'unbind' ? '解绑' : '绑定'}请求失败: $e');
      }
      return false;
    }
  }

  /// 处理绑定/解绑请求 - 增强版（集成通知触发）
  static Future<bool> handleBindingRequest({
    required String requestId,
    required String action, // 'approve' or 'reject'
    String? rejectReason,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 处理请求: $requestId, 操作: $action');
      }

      final batch = _firestore.batch();

      // 获取请求数据
      final requestRef = _firestore.collection('binding_requests').doc(requestId);
      final requestDoc = await requestRef.get();

      if (!requestDoc.exists) {
        if (kDebugMode) {
          print('❌ 请求不存在: $requestId');
        }
        return false;
      }

      final requestData = requestDoc.data()!;
      final coachId = requestData['coachId'] as String;
      final coachName = requestData['coachName'] as String;
      final coachEmail = requestData['coachEmail'] as String;
      final gymId = requestData['gymId'] as String;
      final gymName = requestData['gymName'] as String;
      final requestType = requestData['type'] as String? ?? 'bind';
      final targetAdminUid = requestData['targetAdminUid'] as String?;

      if (action == 'approve') {
        if (kDebugMode) {
          print('✅ 批准${requestType == 'unbind' ? '解绑' : '绑定'}请求');
        }

        // 1. 更新请求状态为approved
        batch.update(requestRef, {
          'status': 'approved',
          'processedAt': FieldValue.serverTimestamp(),
          'processedBy': AuthService.currentUserUid,
        });

        // 2. 根据请求类型处理教练记录
        final coachRef = _firestore.collection('coaches').doc(coachId);
        final existingCoach = await coachRef.get();

        if (requestType == 'bind') {
          // 绑定处理
          if (existingCoach.exists) {
            // 更新现有教练记录，支持多健身房绑定
            final currentData = existingCoach.data()!;
            List<String> boundGyms = [];

            // 获取当前绑定的健身房列表
            if (currentData['boundGyms'] != null) {
              boundGyms = List<String>.from(currentData['boundGyms']);
            } else if (currentData['assignedGymId'] != null) {
              boundGyms.add(currentData['assignedGymId']);
            }

            // 添加新的健身房
            if (!boundGyms.contains(gymId)) {
              boundGyms.add(gymId);
            }

            batch.update(coachRef, {
              'boundGyms': boundGyms,
              'assignedGymId': gymId, // 保持兼容性
              'assignedGymName': gymName, // 保持兼容性
              'status': 'active',
              'updatedAt': FieldValue.serverTimestamp(),
            });

            if (kDebugMode) {
              print('📝 更新教练记录，添加健身房绑定: $gymName');
            }
          } else {
            // 创建新的教练记录
            batch.set(coachRef, {
              'id': coachId,
              'name': coachName,
              'email': coachEmail,
              'boundGyms': [gymId],
              'assignedGymId': gymId, // 保持兼容性
              'assignedGymName': gymName, // 保持兼容性
              'status': 'active',
              'role': 'coach',
              'joinedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });

            if (kDebugMode) {
              print('🆕 创建新教练记录');
            }
          }
        } else if (requestType == 'unbind') {
          // 解绑处理
          if (existingCoach.exists) {
            final currentData = existingCoach.data()!;
            List<String> boundGyms = [];

            // 获取当前绑定的健身房列表
            if (currentData['boundGyms'] != null) {
              boundGyms = List<String>.from(currentData['boundGyms']);
            } else if (currentData['assignedGymId'] != null) {
              boundGyms.add(currentData['assignedGymId']);
            }

            // 移除指定的健身房
            boundGyms.remove(gymId);

            if (boundGyms.isEmpty) {
              // 如果没有绑定的健身房了，设为inactive
              batch.update(coachRef, {
                'boundGyms': [],
                'assignedGymId': null,
                'assignedGymName': null,
                'status': 'inactive',
                'updatedAt': FieldValue.serverTimestamp(),
              });

              if (kDebugMode) {
                print('📝 教练已解绑所有健身房，设为inactive');
              }
            } else {
              // 更新绑定列表
              final newPrimaryGym = boundGyms.first;
              batch.update(coachRef, {
                'boundGyms': boundGyms,
                'assignedGymId': newPrimaryGym, // 保持兼容性，设为第一个
                'updatedAt': FieldValue.serverTimestamp(),
              });

              if (kDebugMode) {
                print('📝 更新教练记录，移除健身房绑定: $gymName');
              }
            }
          }
        }

        if (kDebugMode) {
          print('✅ 批准${requestType == 'unbind' ? '解绑' : '绑定'}请求: $coachName');
        }
      } else if (action == 'reject') {
        if (kDebugMode) {
          print('❌ 拒绝${requestType == 'unbind' ? '解绑' : '绑定'}请求');
        }

        // 拒绝请求
        batch.update(requestRef, {
          'status': 'rejected',
          'processedAt': FieldValue.serverTimestamp(),
          'processedBy': AuthService.currentUserUid,
          if (rejectReason != null && rejectReason.isNotEmpty) 'rejectReason': rejectReason,
        });

        if (kDebugMode) {
          print('❌ 拒绝${requestType == 'unbind' ? '解绑' : '绑定'}请求: $coachName, 原因: ${rejectReason ?? '无'}');
        }
      }

      // 提交批量操作
      await batch.commit();

      // 🔔 发送处理结果通知给教练（可选）
      if (targetAdminUid != null) {
        await _sendProcessingNotificationToCoach(
          coachId: coachId,
          coachName: coachName,
          action: action,
          requestType: requestType,
          gymName: gymName,
          rejectReason: rejectReason,
        );
      }

      if (kDebugMode) {
        print('✅ 请求处理完成');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 处理请求失败: $e');
      }
      return false;
    }
  }

  /// 发送处理结果通知给教练（新增）
  static Future<void> _sendProcessingNotificationToCoach({
    required String coachId,
    required String coachName,
    required String action,
    required String requestType,
    required String gymName,
    String? rejectReason,
  }) async {
    try {
      final notificationType = action == 'approve'
          ? (requestType == 'bind' ? 'binding_approved' : 'unbinding_approved')
          : (requestType == 'bind' ? 'binding_rejected' : 'unbinding_rejected');

      final title = action == 'approve'
          ? '${requestType == 'bind' ? 'Binding' : 'Unbinding'} Request Approved'
          : '${requestType == 'bind' ? 'Binding' : 'Unbinding'} Request Rejected';

      final message = action == 'approve'
          ? 'Your ${requestType} request for $gymName has been approved'
          : 'Your ${requestType} request for $gymName has been rejected${rejectReason != null ? ': $rejectReason' : ''}';

      // 发送给教练的通知（可以保存到教练的通知集合）
      await _firestore
          .collection('coaches')
          .doc(coachId)
          .collection('notifications')
          .add({
        'type': notificationType,
        'title': title,
        'message': message,
        'gymName': gymName,
        'requestType': requestType,
        'action': action,
        'rejectReason': rejectReason,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) {
        print('✅ 处理结果通知已发送给教练: $coachName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 发送教练通知失败: $e');
      }
    }
  }

  /// 更新教练状态 - 集成通知触发
  static Future<bool> updateCoachStatus(String coachId, String status, {String? reason}) async {
    try {
      if (kDebugMode) {
        print('📝 更新教练状态: $coachId -> $status');
      }

      // 获取教练信息用于通知
      final coachDoc = await _firestore.collection('coaches').doc(coachId).get();
      final oldStatus = coachDoc.exists ? (coachDoc.data()?['status'] ?? 'unknown') : 'unknown';

      await _firestore.collection('coaches').doc(coachId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusUpdatedBy': AuthService.currentUserUid,
        if (reason != null) 'statusChangeReason': reason,
      });

      // 🔔 发送状态变更通知（可选 - 仅在重要状态变更时）
      if (_shouldNotifyStatusChange(oldStatus, status)) {
        await _sendStatusChangeNotification(coachId, oldStatus, status, reason);
      }

      if (kDebugMode) {
        print('✅ 教练状态更新成功');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 更新教练状态失败: $e');
      }
      return false;
    }
  }

  /// 判断是否需要发送状态变更通知
  static bool _shouldNotifyStatusChange(String? oldStatus, String newStatus) {
    // 重要的状态变更才发送通知
    const importantChanges = [
      'active', 'inactive', 'suspended'
    ];

    return oldStatus != newStatus &&
        (importantChanges.contains(oldStatus) || importantChanges.contains(newStatus));
  }

  /// 发送状态变更通知
  static Future<void> _sendStatusChangeNotification(
      String coachId,
      String? oldStatus,
      String newStatus,
      String? reason
      ) async {
    try {
      final coachDoc = await _firestore.collection('coaches').doc(coachId).get();
      if (!coachDoc.exists) return;

      final coachData = coachDoc.data()!;
      final coachName = coachData['name'] ?? 'Unknown Coach';

      // 通过NotificationTriggerService发送系统通知
      await _notificationService.sendSystemNotification(
        title: 'Coach Status Changed',
        message: 'Coach $coachName status changed from ${oldStatus ?? 'unknown'} to $newStatus${reason != null ? ' ($reason)' : ''}',
        type: NotificationType.coachStatusChanged,
        priority: NotificationPriority.normal,
        data: {
          'coachId': coachId,
          'coachName': coachName,
          'oldStatus': oldStatus,
          'newStatus': newStatus,
          'reason': reason,
          'updatedBy': AuthService.currentUserUid,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 发送状态变更通知失败: $e');
      }
    }
  }

  /// 移除教练 - 集成通知触发
  static Future<bool> removeCoach(String coachId, {String? reason}) async {
    try {
      if (kDebugMode) {
        print('🗑️ 移除教练: $coachId');
      }

      final batch = _firestore.batch();

      // 获取教练信息用于通知
      final coachDoc = await _firestore.collection('coaches').doc(coachId).get();
      final coachName = coachDoc.exists ? (coachDoc.data()?['name'] ?? 'Unknown Coach') : 'Unknown Coach';

      // 删除教练记录
      final coachRef = _firestore.collection('coaches').doc(coachId);
      batch.delete(coachRef);

      // 将相关的绑定请求标记为已取消
      final relatedRequests = await _firestore
          .collection('binding_requests')
          .where('coachId', isEqualTo: coachId)
          .where('status', isEqualTo: 'approved')
          .get();

      for (final requestDoc in relatedRequests.docs) {
        batch.update(requestDoc.reference, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelReason': 'Coach removed from system',
        });
      }

      await batch.commit();

      // 🔔 发送教练移除通知
      await _notificationService.sendSystemNotification(
        title: 'Coach Removed',
        message: 'Coach $coachName has been removed from the system${reason != null ? ' ($reason)' : ''}',
        type: NotificationType.coachStatusChanged,
        priority: NotificationPriority.high,
        data: {
          'coachId': coachId,
          'coachName': coachName,
          'action': 'removed',
          'reason': reason,
          'removedBy': AuthService.currentUserUid,
        },
      );

      if (kDebugMode) {
        print('✅ 教练移除成功');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 移除教练失败: $e');
      }
      return false;
    }
  }

  /// 添加课程 - 集成通知触发
  static Future<bool> addCourse({
    required String title,
    required String description,
    required String coachId,
    required String duration,
    required int maxParticipants,
  }) async {
    try {
      if (kDebugMode) {
        print('➕ 添加课程: $title');
      }

      final docRef = await _firestore.collection('courses').add({
        'title': title,
        'description': description,
        'coachId': coachId,
        'duration': duration,
        'maxParticipants': maxParticipants,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': AuthService.currentUserUid,
      });

      // 🔔 发送课程创建通知（可选 - 仅当需要时）
      final coachDoc = await _firestore.collection('coaches').doc(coachId).get();
      final coachName = coachDoc.exists ? (coachDoc.data()?['name'] ?? 'Unknown Coach') : 'Unknown Coach';

      await _notificationService.sendSystemNotification(
        title: 'New Course Added',
        message: 'Course "$title" has been added for coach $coachName',
        type: NotificationType.general,
        priority: NotificationPriority.low,
        data: {
          'courseId': docRef.id,
          'courseTitle': title,
          'coachId': coachId,
          'coachName': coachName,
          'action': 'course_added',
        },
      );

      if (kDebugMode) {
        print('✅ 课程添加成功');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 添加课程失败: $e');
      }
      return false;
    }
  }

  /// 删除课程 - 集成通知触发
  static Future<bool> deleteCourse(String courseId, {String? reason}) async {
    try {
      if (kDebugMode) {
        print('🗑️ 删除课程: $courseId');
      }

      // 获取课程信息用于通知
      final courseDoc = await _firestore.collection('courses').doc(courseId).get();
      if (!courseDoc.exists) {
        if (kDebugMode) {
          print('❌ 课程不存在: $courseId');
        }
        return false;
      }

      final courseData = courseDoc.data()!;
      final courseTitle = courseData['title'] ?? 'Unknown Course';
      final coachId = courseData['coachId'];

      await _firestore.collection('courses').doc(courseId).delete();

      // 🔔 发送课程删除通知
      String coachName = 'Unknown Coach';
      if (coachId != null) {
        final coachDoc = await _firestore.collection('coaches').doc(coachId).get();
        coachName = coachDoc.exists ? (coachDoc.data()?['name'] ?? 'Unknown Coach') : 'Unknown Coach';
      }

      await _notificationService.sendSystemNotification(
        title: 'Course Deleted',
        message: 'Course "$courseTitle" has been deleted${reason != null ? ' ($reason)' : ''}',
        type: NotificationType.general,
        priority: NotificationPriority.normal,
        data: {
          'courseId': courseId,
          'courseTitle': courseTitle,
          'coachId': coachId,
          'coachName': coachName,
          'action': 'course_deleted',
          'reason': reason,
        },
      );

      if (kDebugMode) {
        print('✅ 课程删除成功');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 删除课程失败: $e');
      }
      return false;
    }
  }

  /// 获取统计信息
  static Future<Map<String, int>> getStatistics() async {
    try {
      final stats = <String, int>{};

      // 统计教练数量
      final coaches = await _firestore.collection('coaches').get();
      stats['total_coaches'] = coaches.docs.length;
      stats['active_coaches'] = coaches.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'active';
      }).length;
      stats['inactive_coaches'] = coaches.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'inactive';
      }).length;
      stats['break_coaches'] = coaches.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'break';
      }).length;

      // 统计请求（包括绑定和解绑）
      final requests = await _firestore.collection('binding_requests').get();
      stats['total_requests'] = requests.docs.length;
      stats['pending_requests'] = requests.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'pending';
      }).length;
      stats['approved_requests'] = requests.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'approved';
      }).length;
      stats['rejected_requests'] = requests.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'rejected';
      }).length;

      // 统计绑定和解绑请求
      stats['bind_requests'] = requests.docs.where((doc) {
        final data = doc.data();
        return (data['type'] ?? 'bind') == 'bind';
      }).length;
      stats['unbind_requests'] = requests.docs.where((doc) {
        final data = doc.data();
        return data['type'] == 'unbind';
      }).length;

      // 统计课程
      final courses = await _firestore.collection('courses').get();
      stats['total_courses'] = courses.docs.length;

      return stats;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取统计信息失败: $e');
      }
      return {};
    }
  }

  /// 批量操作 - 批量更新教练状态（新增）
  static Future<bool> batchUpdateCoachStatus(
      List<String> coachIds,
      String status,
      {String? reason}
      ) async {
    try {
      if (kDebugMode) {
        print('📝 批量更新教练状态: ${coachIds.length} 个教练 -> $status');
      }

      final batch = _firestore.batch();
      final List<String> coachNames = [];

      // 获取教练信息
      for (final coachId in coachIds) {
        final coachRef = _firestore.collection('coaches').doc(coachId);
        batch.update(coachRef, {
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
          'statusUpdatedBy': AuthService.currentUserUid,
          if (reason != null) 'statusChangeReason': reason,
        });

        // 获取教练名称用于通知
        try {
          final coachDoc = await coachRef.get();
          if (coachDoc.exists) {
            coachNames.add(coachDoc.data()?['name'] ?? 'Unknown Coach');
          }
        } catch (e) {
          coachNames.add('Unknown Coach');
        }
      }

      await batch.commit();

      // 🔔 发送批量状态变更通知
      await _notificationService.sendSystemNotification(
        title: 'Batch Coach Status Update',
        message: '${coachIds.length} coaches status changed to $status${reason != null ? ' ($reason)' : ''}',
        type: NotificationType.coachStatusChanged,
        priority: NotificationPriority.normal,
        data: {
          'coachIds': coachIds,
          'coachNames': coachNames,
          'newStatus': status,
          'reason': reason,
          'updatedBy': AuthService.currentUserUid,
          'batchOperation': true,
        },
      );

      if (kDebugMode) {
        print('✅ 批量教练状态更新成功');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 批量更新教练状态失败: $e');
      }
      return false;
    }
  }

  /// 获取通知触发服务实例（用于外部调用）
  static NotificationTriggerService get notificationService => _notificationService;

  /// 清理资源
  static Future<void> dispose() async {
    await _notificationService.dispose();
    if (kDebugMode) {
      print('✅ CoachService disposed');
    }
  }

  // =============== 原有的辅助方法保持不变 ===============

  /// 获取教练数据（静态方法，用于预约系统）
  static Future<List<Map<String, dynamic>>> getCoaches() async {
    try {
      final snapshot = await _firestore
          .collection('coaches')
          .where('status', whereIn: ['active', 'break'])
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Coach',
          'email': data['email'] ?? '',
          'assignedGymId': data['assignedGymId'],
          'assignedGymName': data['assignedGymName'] ?? 'Unknown Gym',
          'status': data['status'] ?? 'inactive',
          'boundGyms': data['boundGyms'] ?? [],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取教练数据失败: $e');
      }
      return [];
    }
  }

  /// 获取教练分配的健身房
  static Future<List<Map<String, dynamic>>> getCoachAssignedGyms(String coachId) async {
    try {
      final coachDoc = await _firestore.collection('coaches').doc(coachId).get();
      if (!coachDoc.exists) return [];

      final coachData = coachDoc.data()!;
      final boundGyms = coachData['boundGyms'] as List<dynamic>? ?? [];

      if (boundGyms.isEmpty && coachData['assignedGymId'] != null) {
        boundGyms.add(coachData['assignedGymId']);
      }

      final gyms = <Map<String, dynamic>>[];

      for (final gymId in boundGyms) {
        try {
          final gymDoc = await _firestore.collection('gyms').doc(gymId).get();
          if (gymDoc.exists) {
            final gymData = gymDoc.data()!;
            gyms.add({
              'id': gymDoc.id,
              'name': gymData['name'] ?? 'Unknown Gym',
              'address': gymData['address'] ?? '',
            });
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ 获取健身房信息失败: $gymId - $e');
          }
        }
      }

      return gyms;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取教练健身房失败: $e');
      }
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
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('appointments')
          .where('coachId', isEqualTo: coachId)
          .where('gymId', isEqualTo: gymId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .where('overallStatus', whereIn: ['pending', 'confirmed'])
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['timeSlot'] as String? ?? '')
          .where((slot) => slot.isNotEmpty)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取已预订时间段失败: $e');
      }
      return [];
    }
  }
}