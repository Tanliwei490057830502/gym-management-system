// services/displayname_service.dart
// 修复版：解决类型安全问题

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DisplayNameService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 初始化服务 - 在应用启动时调用
  static void initialize() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        print('🔐 用户登录: ${user.uid}');
        autoFixDisplayName(user);
      }
    });
  }

  /// 自动修复当前用户的 displayName
  static Future<bool> autoFixDisplayName(User user) async {
    try {
      // 如果已经有 displayName，跳过
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        print('✅ 用户已有 displayName: ${user.displayName}');
        return true;
      }

      print('🔧 开始修复 displayName for: ${user.uid}');

      // 获取正确的用户名
      final correctName = await _getCorrectUserName(user.uid, user.email ?? '');

      if (correctName.isNotEmpty && correctName != 'Unknown') {
        await user.updateDisplayName(correctName);
        await user.reload();
        print('✅ 成功设置 displayName: $correctName');
        return true;
      } else {
        print('⚠️ 无法获取用户名，跳过修复');
        return false;
      }
    } catch (e) {
      print('❌ 修复 displayName 失败: $e');
      return false;
    }
  }

  /// 智能获取用户正确名称
  static Future<String> _getCorrectUserName(String userId, String email) async {
    // 1. 首先从 coaches 集合查找
    try {
      final coachDoc = await _firestore.collection('coaches').doc(userId).get();
      if (coachDoc.exists) {
        final data = coachDoc.data();
        if (data != null) {
          final name = data['name'] as String?;
          if (name != null && name.isNotEmpty && name != 'Unknown Coach') {
            print('📝 从教练记录获取名称: $name');
            return name;
          }
        }
      }
    } catch (e) {
      print('查询教练记录出错: $e');
    }

    // 2. 从 users 集合查找
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          final name = data['name'] as String?;
          if (name != null && name.isNotEmpty) {
            print('📝 从用户记录获取名称: $name');
            return name;
          }
        }
      }
    } catch (e) {
      print('查询用户记录出错: $e');
    }

    // 3. 从邮箱地址推测
    if (email.isNotEmpty) {
      final extractedName = _extractNameFromEmail(email);
      if (extractedName.isNotEmpty) {
        print('📝 从邮箱提取名称: $extractedName');
        return extractedName;
      }
    }

    return 'Unknown';
  }

  /// 从邮箱地址提取用户名
  static String _extractNameFromEmail(String email) {
    try {
      final parts = email.split('@');
      if (parts.isNotEmpty && parts[0].isNotEmpty) {
        String username = parts[0];

        // 移除数字和特殊字符，保留字母
        username = username.replaceAll(RegExp(r'[0-9._-]'), '');

        if (username.isNotEmpty) {
          // 首字母大写
          return username[0].toUpperCase() + username.substring(1).toLowerCase();
        }
      }
    } catch (e) {
      print('提取邮箱用户名出错: $e');
    }
    return '';
  }

  /// 手动设置当前用户的 displayName
  static Future<bool> setDisplayName(String name) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await user.updateDisplayName(name);
      await user.reload();

      // 同时更新 Firestore 中的记录
      await _updateFirestoreName(user.uid, name);

      print('✅ 手动设置 displayName: $name');
      return true;
    } catch (e) {
      print('❌ 设置 displayName 失败: $e');
      return false;
    }
  }

  /// 更新 Firestore 中的用户名
  static Future<void> _updateFirestoreName(String userId, String name) async {
    try {
      // 检查是否是教练
      final coachDoc = await _firestore.collection('coaches').doc(userId).get();
      if (coachDoc.exists) {
        await _firestore.collection('coaches').doc(userId).update({
          'name': name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('📝 更新教练记录中的名称');
        return;
      }

      // 检查是否是普通用户
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        await _firestore.collection('users').doc(userId).update({
          'name': name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('📝 更新用户记录中的名称');
      }
    } catch (e) {
      print('更新 Firestore 名称时出错: $e');
    }
  }

  /// 检查并修复所有绑定请求中的 Unknown Coach
  static Future<int> fixUnknownCoachRequests() async {
    try {
      print('🔧 开始修复 Unknown Coach 绑定请求...');

      final querySnapshot = await _firestore
          .collection('binding_requests')
          .where('coachName', isEqualTo: 'Unknown Coach')
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('✅ 没有发现 Unknown Coach 的绑定请求');
        return 0;
      }

      int fixedCount = 0;
      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final coachId = data['coachId'] as String? ?? '';
        final coachEmail = data['coachEmail'] as String? ?? '';

        // 获取正确的教练名称
        final correctName = await _getCorrectUserName(coachId, coachEmail);

        if (correctName.isNotEmpty && correctName != 'Unknown') {
          batch.update(doc.reference, {
            'coachName': correctName,
            'fixedAt': FieldValue.serverTimestamp(),
          });
          print('📝 修复绑定请求 ${doc.id}: $correctName');
          fixedCount++;
        }
      }

      if (fixedCount > 0) {
        await batch.commit();
        print('🎉 成功修复 $fixedCount 个绑定请求');
      }

      return fixedCount;
    } catch (e) {
      print('❌ 修复绑定请求失败: $e');
      return 0;
    }
  }

  /// 生成简化的修复报告
  static Future<ReportData> generateReport() async {
    try {
      print('📊 生成 DisplayName 修复报告...');

      // 统计绑定请求
      final allRequests = await _firestore.collection('binding_requests').get();
      final unknownRequests = allRequests.docs.where((doc) {
        final data = doc.data();
        final coachName = data['coachName'] as String?;
        return coachName == 'Unknown Coach';
      }).toList();

      // 统计教练记录
      final allCoaches = await _firestore.collection('coaches').get();
      final unknownCoaches = allCoaches.docs.where((doc) {
        final data = doc.data();
        final name = data['name'] as String?;
        return name == null || name.isEmpty || name == 'Unknown Coach';
      }).toList();

      // 统计用户记录
      final allUsers = await _firestore.collection('users').get();
      final unnamedUsers = allUsers.docs.where((doc) {
        final data = doc.data();
        final name = data['name'] as String?;
        return name == null || name.isEmpty;
      }).toList();

      final report = ReportData(
        bindingRequestsTotal: allRequests.docs.length,
        bindingRequestsUnknown: unknownRequests.length,
        coachesTotal: allCoaches.docs.length,
        coachesWithoutName: unknownCoaches.length,
        usersTotal: allUsers.docs.length,
        usersWithoutName: unnamedUsers.length,
      );

      print('📋 修复报告摘要:');
      print('  绑定请求: ${report.bindingRequestsTotal} 个，Unknown Coach: ${report.bindingRequestsUnknown} 个');
      print('  教练记录: ${report.coachesTotal} 个，无名称: ${report.coachesWithoutName} 个');
      print('  用户记录: ${report.usersTotal} 个，无名称: ${report.usersWithoutName} 个');
      print('  发现问题总数: ${report.totalIssues}');

      return report;
    } catch (e) {
      print('❌ 生成报告失败: $e');
      return ReportData.empty();
    }
  }

  /// 一键修复所有问题
  static Future<FixResults> fixAllIssues() async {
    print('🚀 开始一键修复所有 DisplayName 问题...');

    final results = FixResults();

    try {
      // 1. 修复绑定请求
      results.bindingRequestsFixed = await fixUnknownCoachRequests();

      // 2. 如果当前用户需要修复，则修复
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final fixed = await autoFixDisplayName(currentUser);
        if (fixed) {
          results.authUsersFixed = 1;
        }
      }

      print('🎉 一键修复完成！');
      print('  修复绑定请求: ${results.bindingRequestsFixed} 个');
      print('  修复认证用户: ${results.authUsersFixed} 个');

    } catch (e) {
      print('❌ 一键修复过程中出错: $e');
      results.errors = 1;
    }

    return results;
  }

  /// 验证修复结果
  static Future<bool> validateFixes() async {
    try {
      print('🔍 验证修复结果...');

      // 检查还有没有 Unknown Coach 的绑定请求
      final unknownRequests = await _firestore
          .collection('binding_requests')
          .where('coachName', isEqualTo: 'Unknown Coach')
          .get();

      final isValid = unknownRequests.docs.isEmpty;

      if (isValid) {
        print('✅ 验证通过：没有发现 Unknown Coach 的绑定请求');
      } else {
        print('⚠️ 验证失败：仍有 ${unknownRequests.docs.length} 个 Unknown Coach 请求');
      }

      return isValid;
    } catch (e) {
      print('❌ 验证过程出错: $e');
      return false;
    }
  }
}

/// ✅ 类型安全的报告数据类
class ReportData {
  final int bindingRequestsTotal;
  final int bindingRequestsUnknown;
  final int coachesTotal;
  final int coachesWithoutName;
  final int usersTotal;
  final int usersWithoutName;

  ReportData({
    required this.bindingRequestsTotal,
    required this.bindingRequestsUnknown,
    required this.coachesTotal,
    required this.coachesWithoutName,
    required this.usersTotal,
    required this.usersWithoutName,
  });

  factory ReportData.empty() {
    return ReportData(
      bindingRequestsTotal: 0,
      bindingRequestsUnknown: 0,
      coachesTotal: 0,
      coachesWithoutName: 0,
      usersTotal: 0,
      usersWithoutName: 0,
    );
  }

  int get totalIssues => bindingRequestsUnknown + coachesWithoutName + usersWithoutName;

  double get bindingRequestsPercentage =>
      bindingRequestsTotal > 0 ? (bindingRequestsUnknown / bindingRequestsTotal * 100) : 0.0;

  double get coachesPercentage =>
      coachesTotal > 0 ? (coachesWithoutName / coachesTotal * 100) : 0.0;

  double get usersPercentage =>
      usersTotal > 0 ? (usersWithoutName / usersTotal * 100) : 0.0;
}

/// ✅ 修复结果数据类
class FixResults {
  int bindingRequestsFixed = 0;
  int authUsersFixed = 0;
  int errors = 0;

  bool get hasErrors => errors > 0;
  bool get hasFixedItems => bindingRequestsFixed > 0 || authUsersFixed > 0;
}