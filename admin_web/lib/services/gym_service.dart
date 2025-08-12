// lib/services/gym_service.dart
// 用途：健身房信息管理服务

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/gym_info.dart';

class GymService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'gym_info';

  // 获取当前用户ID
  static String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // 获取用户专属的文档ID
  static String get _userDocId {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');
    return userId;
  }

  /// 获取健身房信息
  static Future<GymInfo?> getGymInfo() async {
    try {
      final doc = await _firestore.collection(_collection).doc(_userDocId).get();

      if (doc.exists && doc.data() != null) {
        return GymInfo.fromMap(doc.data()!);
      }

      // 如果文档不存在，返回默认信息
      return GymInfo.defaultInfo();
    } catch (e) {
      print('❌ Error getting gym info: $e');
      return GymInfo.defaultInfo();
    }
  }

  /// 保存健身房信息
  static Future<bool> saveGymInfo(GymInfo gymInfo) async {
    try {
      print('💾 Saving gym info: ${gymInfo.name}');

      await _firestore.collection(_collection).doc(_userDocId).set(
        gymInfo.toMap(),
        SetOptions(merge: true),
      );

      print('✅ Gym info saved successfully');
      return true;
    } catch (e) {
      print('❌ Error saving gym info: $e');
      return false;
    }
  }

  /// 实时监听健身房信息变化
  static Stream<GymInfo> gymInfoStream() {
    try {
      return _firestore.collection(_collection).doc(_userDocId).snapshots().map((doc) {
        if (doc.exists && doc.data() != null) {
          return GymInfo.fromMap(doc.data()!);
        }
        return GymInfo.defaultInfo();
      });
    } catch (e) {
      print('❌ Error creating gym info stream: $e');
      return Stream.value(GymInfo.defaultInfo());
    }
  }

  /// 更新特定字段
  static Future<bool> updateField(String field, dynamic value) async {
    try {
      print('📝 Updating field: $field = $value');

      await _firestore.collection(_collection).doc(_userDocId).update({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Field updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating field $field: $e');
      return false;
    }
  }

  /// 批量更新多个字段
  static Future<bool> updateFields(Map<String, dynamic> fields) async {
    try {
      print('📝 Updating multiple fields: ${fields.keys.join(', ')}');

      final updateData = Map<String, dynamic>.from(fields);
      updateData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection(_collection).doc(_userDocId).update(updateData);

      print('✅ Fields updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating fields: $e');
      return false;
    }
  }

  /// 检查是否已设置健身房信息
  static Future<bool> isGymInfoConfigured() async {
    try {
      final doc = await _firestore.collection(_collection).doc(_userDocId).get();
      if (doc.exists && doc.data() != null) {
        final gymInfo = GymInfo.fromMap(doc.data()!);
        return !gymInfo.isDefault;
      }
      return false;
    } catch (e) {
      print('❌ Error checking gym info configuration: $e');
      return false;
    }
  }

  /// 删除健身房信息（重置为默认状态）
  static Future<bool> resetGymInfo() async {
    try {
      print('🔄 Resetting gym info to default');

      await _firestore.collection(_collection).doc(_userDocId).delete();

      print('✅ Gym info reset successfully');
      return true;
    } catch (e) {
      print('❌ Error resetting gym info: $e');
      return false;
    }
  }

  /// 检查用户是否已认证
  static bool isUserAuthenticated() {
    return _currentUserId != null;
  }

  /// 获取健身房信息统计
  static Future<Map<String, dynamic>> getGymInfoStatistics() async {
    try {
      final gymInfo = await getGymInfo();
      if (gymInfo == null) return {};

      return {
        'isConfigured': !gymInfo.isDefault,
        'hasLogo': gymInfo.hasLogo,
        'amenitiesCount': gymInfo.amenities.length,
        'socialMediaCount': gymInfo.socialMediaCount,
        'lastUpdated': gymInfo.updatedAt?.toIso8601String(),
        'isValid': gymInfo.isValid,
        'operatingDays': gymInfo.operatingHours.length,
      };
    } catch (e) {
      print('❌ Error getting gym info statistics: $e');
      return {};
    }
  }

  /// 验证健身房信息
  static Future<List<String>> validateGymInfo(GymInfo gymInfo) async {
    final errors = <String>[];

    if (gymInfo.name.isEmpty || gymInfo.name == 'Your Gym Name') {
      errors.add('Gym name is required');
    }

    if (gymInfo.email.isEmpty || gymInfo.email == 'contact@yourgym.com') {
      errors.add('Valid email is required');
    }

    if (gymInfo.phone.isEmpty || gymInfo.phone == '+60 XX-XXX XXXX') {
      errors.add('Valid phone number is required');
    }

    if (gymInfo.address.isEmpty || gymInfo.address.contains('Your gym address')) {
      errors.add('Valid address is required');
    }

    if (gymInfo.operatingHours.isEmpty) {
      errors.add('Operating hours are required');
    }

    return errors;
  }

  /// 创建健身房信息备份
  static Future<bool> createBackup() async {
    try {
      final gymInfo = await getGymInfo();
      if (gymInfo == null) return false;

      final backupData = gymInfo.toMap();
      backupData['backupCreatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('gym_info_backups')
          .doc(_userDocId)
          .collection('backups')
          .add(backupData);

      print('✅ Gym info backup created successfully');
      return true;
    } catch (e) {
      print('❌ Error creating backup: $e');
      return false;
    }
  }

  /// 恢复健身房信息从备份
  static Future<bool> restoreFromBackup(String backupId) async {
    try {
      final backupDoc = await _firestore
          .collection('gym_info_backups')
          .doc(_userDocId)
          .collection('backups')
          .doc(backupId)
          .get();

      if (!backupDoc.exists) {
        print('❌ Backup not found');
        return false;
      }

      final backupData = backupDoc.data()!;
      backupData.remove('backupCreatedAt');
      backupData['restoredAt'] = FieldValue.serverTimestamp();

      await _firestore.collection(_collection).doc(_userDocId).set(
        backupData,
        SetOptions(merge: true),
      );

      print('✅ Gym info restored from backup successfully');
      return true;
    } catch (e) {
      print('❌ Error restoring from backup: $e');
      return false;
    }
  }

  /// 获取备份列表
  static Future<List<Map<String, dynamic>>> getBackupList() async {
    try {
      final backupsSnapshot = await _firestore
          .collection('gym_info_backups')
          .doc(_userDocId)
          .collection('backups')
          .orderBy('backupCreatedAt', descending: true)
          .limit(10)
          .get();

      return backupsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'createdAt': data['backupCreatedAt'],
          'size': data.toString().length,
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting backup list: $e');
      return [];
    }
  }
}