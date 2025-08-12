// lib/services/gym_revenue_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class GymRevenueService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 记录健身房收入
  static Future<bool> recordRevenue({
    required String gymAdminId,
    required double amount,
    required String source,
    required String description,
    String? courseTitle,
    String? coursePlanId,
    String? userId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final now = DateTime.now();

      final revenueData = <String, dynamic>{
        'gymAdminId': gymAdminId,
        'amount': amount,
        'source': source,
        'description': description,
        'date': Timestamp.now(),
        'year': now.year,
        'month': now.month,
        'day': now.day,
        'dayOfWeek': now.weekday, // 1=Monday, 7=Sunday
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 添加可选字段
      if (courseTitle != null) revenueData['courseTitle'] = courseTitle;
      if (coursePlanId != null) revenueData['coursePlanId'] = coursePlanId;
      if (userId != null) revenueData['userId'] = userId;
      if (additionalData != null) {
        // 修复类型不匹配问题
        additionalData.forEach((key, value) {
          revenueData[key] = value;
        });
      }

      await _firestore.collection('gym_revenues').add(revenueData);

      print('✅ Revenue recorded: RM ${amount.toStringAsFixed(2)} for $gymAdminId');
      return true;
    } catch (e) {
      print('❌ Failed to record revenue: $e');
      return false;
    }
  }

  // 获取指定时间段的收入数据
  static Future<List<RevenueRecord>> getRevenuesByPeriod({
    required String gymAdminId,
    required DateTime startDate,
    required DateTime endDate,
    String? source,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore
          .collection('gym_revenues')
          .where('gymAdminId', isEqualTo: gymAdminId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThan: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true);

      if (source != null) {
        query = query.where('source', isEqualTo: source);
      }

      final snapshot = await query.limit(limit).get();

      return snapshot.docs.map((doc) {
        return RevenueRecord.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      print('❌ Failed to get revenues by period: $e');
      return [];
    }
  }

  // 获取每日收入统计
  static Future<Map<String, double>> getDailyRevenueStats({
    required String gymAdminId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('gym_revenues')
          .where('gymAdminId', isEqualTo: gymAdminId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThan: Timestamp.fromDate(endDate))
          .get();

      Map<String, double> dailyStats = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0.0).toDouble();
        final date = (data['date'] as Timestamp).toDate();
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        dailyStats[dateKey] = (dailyStats[dateKey] ?? 0.0) + amount;
      }

      return dailyStats;
    } catch (e) {
      print('❌ Failed to get daily revenue stats: $e');
      return {};
    }
  }

  // 获取周收入统计
  static Future<Map<String, double>> getWeeklyRevenueStats({
    required String gymAdminId,
    DateTime? weekStartDate,
  }) async {
    try {
      final now = DateTime.now();
      final startOfWeek = weekStartDate ?? now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 7));

      final snapshot = await _firestore
          .collection('gym_revenues')
          .where('gymAdminId', isEqualTo: gymAdminId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
          .where('date', isLessThan: Timestamp.fromDate(endOfWeek))
          .get();

      Map<String, double> weeklyStats = {
        'Monday': 0.0,
        'Tuesday': 0.0,
        'Wednesday': 0.0,
        'Thursday': 0.0,
        'Friday': 0.0,
        'Saturday': 0.0,
        'Sunday': 0.0,
      };

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0.0).toDouble();
        final dayOfWeek = data['dayOfWeek'] ?? 1;

        final dayName = _getDayName(dayOfWeek);
        weeklyStats[dayName] = (weeklyStats[dayName] ?? 0.0) + amount;
      }

      return weeklyStats;
    } catch (e) {
      print('❌ Failed to get weekly revenue stats: $e');
      return {};
    }
  }

  // 获取月收入统计
  static Future<Map<String, double>> getMonthlyRevenueStats({
    required String gymAdminId,
    int? year,
    int? month,
  }) async {
    try {
      final now = DateTime.now();
      final targetYear = year ?? now.year;
      final targetMonth = month ?? now.month;

      final startOfMonth = DateTime(targetYear, targetMonth, 1);
      final endOfMonth = DateTime(targetYear, targetMonth + 1, 1);

      final snapshot = await _firestore
          .collection('gym_revenues')
          .where('gymAdminId', isEqualTo: gymAdminId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThan: Timestamp.fromDate(endOfMonth))
          .get();

      Map<String, double> monthlyStats = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0.0).toDouble();
        final date = (data['date'] as Timestamp).toDate();
        final week = ((date.day - 1) ~/ 7) + 1;
        final weekKey = 'Week $week';

        monthlyStats[weekKey] = (monthlyStats[weekKey] ?? 0.0) + amount;
      }

      return monthlyStats;
    } catch (e) {
      print('❌ Failed to get monthly revenue stats: $e');
      return {};
    }
  }

  // 获取收入来源统计
  static Future<Map<String, double>> getRevenueBySource({
    required String gymAdminId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('gym_revenues')
          .where('gymAdminId', isEqualTo: gymAdminId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThan: Timestamp.fromDate(endDate))
          .get();

      Map<String, double> sourceStats = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0.0).toDouble();
        final source = data['source'] ?? 'Unknown';

        sourceStats[source] = (sourceStats[source] ?? 0.0) + amount;
      }

      return sourceStats;
    } catch (e) {
      print('❌ Failed to get revenue by source: $e');
      return {};
    }
  }

  // 获取总收入统计
  static Future<RevenueSummary> getRevenueSummary({
    required String gymAdminId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final now = DateTime.now();
      final start = startDate ?? DateTime(now.year, 1, 1); // 默认从年初开始
      final end = endDate ?? now;

      final snapshot = await _firestore
          .collection('gym_revenues')
          .where('gymAdminId', isEqualTo: gymAdminId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .get();

      double totalRevenue = 0.0;
      int totalRecords = snapshot.docs.length;
      Map<String, double> sourceBreakdown = {};
      double maxDailyRevenue = 0.0;
      DateTime? bestDay;

      Map<String, double> dailyTotals = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0.0).toDouble();
        final source = data['source'] ?? 'Unknown';
        final date = (data['date'] as Timestamp).toDate();
        final dateKey = '${date.year}-${date.month}-${date.day}';

        totalRevenue += amount;
        sourceBreakdown[source] = (sourceBreakdown[source] ?? 0.0) + amount;
        dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0.0) + amount;

        if (dailyTotals[dateKey]! > maxDailyRevenue) {
          maxDailyRevenue = dailyTotals[dateKey]!;
          bestDay = date;
        }
      }

      final averageDaily = totalRecords > 0 ? totalRevenue / totalRecords : 0.0;

      return RevenueSummary(
        totalRevenue: totalRevenue,
        totalRecords: totalRecords,
        averageDaily: averageDaily,
        maxDailyRevenue: maxDailyRevenue,
        bestDay: bestDay,
        sourceBreakdown: sourceBreakdown,
        startDate: start,
        endDate: end,
      );
    } catch (e) {
      print('❌ Failed to get revenue summary: $e');
      return RevenueSummary.empty();
    }
  }

  // 获取健身房费用设置 - 简化版，不再定义重复的类
  static Future<Map<String, dynamic>?> getGymFeeSettings(String gymAdminId) async {
    try {
      final doc = await _firestore
          .collection('gym_settings')
          .doc(gymAdminId)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('❌ Failed to get gym fee settings: $e');
      return null;
    }
  }

  // 更新健身房费用设置 (修复类型问题)
  static Future<bool> updateGymFeeSettings({
    required String gymAdminId,
    required double additionalFee,
    String? feeDescription,
  }) async {
    try {
      // 使用正确的类型
      final Map<String, Object> updateData = {
        'additionalFee': additionalFee,
        'feeDescription': feeDescription ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'gymAdminId': gymAdminId,
      };

      await _firestore.collection('gym_settings').doc(gymAdminId).set(
          updateData,
          SetOptions(merge: true)
      );

      print('✅ Gym fee settings updated: RM ${additionalFee.toStringAsFixed(2)}');
      return true;
    } catch (e) {
      print('❌ Failed to update gym fee settings: $e');
      return false;
    }
  }

  // 实时收入流
  static Stream<List<RevenueRecord>> getRevenueStream({
    required String gymAdminId,
    int limit = 20,
  }) {
    return _firestore
        .collection('gym_revenues')
        .where('gymAdminId', isEqualTo: gymAdminId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return RevenueRecord.fromFirestore(doc.id, doc.data());
      }).toList();
    });
  }

  // 辅助方法：获取星期几的名称
  static String _getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Monday';
    }
  }
}

// 收入记录数据模型 - 只在这里定义，避免重复
class RevenueRecord {
  final String id;
  final String gymAdminId;
  final double amount;
  final String source;
  final String description;
  final DateTime date;
  final String? courseTitle;
  final String? coursePlanId;
  final String? userId;
  final Map<String, dynamic> additionalData;

  RevenueRecord({
    required this.id,
    required this.gymAdminId,
    required this.amount,
    required this.source,
    required this.description,
    required this.date,
    this.courseTitle,
    this.coursePlanId,
    this.userId,
    this.additionalData = const {},
  });

  factory RevenueRecord.fromFirestore(String id, Map<String, dynamic> data) {
    final timestamp = data['date'] as Timestamp;
    return RevenueRecord(
      id: id,
      gymAdminId: data['gymAdminId'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      source: data['source'] ?? '',
      description: data['description'] ?? '',
      date: timestamp.toDate(),
      courseTitle: data['courseTitle'],
      coursePlanId: data['coursePlanId'],
      userId: data['userId'],
      additionalData: Map<String, dynamic>.from(data),
    );
  }

  String get formattedDate {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String get formattedAmount => 'RM ${amount.toStringAsFixed(2)}';
}

// 收入统计摘要
class RevenueSummary {
  final double totalRevenue;
  final int totalRecords;
  final double averageDaily;
  final double maxDailyRevenue;
  final DateTime? bestDay;
  final Map<String, double> sourceBreakdown;
  final DateTime startDate;
  final DateTime endDate;

  RevenueSummary({
    required this.totalRevenue,
    required this.totalRecords,
    required this.averageDaily,
    required this.maxDailyRevenue,
    this.bestDay,
    required this.sourceBreakdown,
    required this.startDate,
    required this.endDate,
  });

  factory RevenueSummary.empty() {
    return RevenueSummary(
      totalRevenue: 0.0,
      totalRecords: 0,
      averageDaily: 0.0,
      maxDailyRevenue: 0.0,
      sourceBreakdown: {},
      startDate: DateTime.now(),
      endDate: DateTime.now(),
    );
  }

  String get formattedTotalRevenue => 'RM ${totalRevenue.toStringAsFixed(2)}';
  String get formattedAverageDaily => 'RM ${averageDaily.toStringAsFixed(2)}';
  String get formattedMaxDaily => 'RM ${maxDailyRevenue.toStringAsFixed(2)}';
}