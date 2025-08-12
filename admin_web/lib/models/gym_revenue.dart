// lib/models/gym_revenue.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// 健身房收入记录模型
class GymRevenue {
  final String id;
  final String gymAdminId;
  final double amount;
  final String source;
  final String description;
  final DateTime date;
  final int year;
  final int month;
  final int day;
  final int dayOfWeek;
  final String? courseTitle;
  final String? coursePlanId;
  final String? userId;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  GymRevenue({
    required this.id,
    required this.gymAdminId,
    required this.amount,
    required this.source,
    required this.description,
    required this.date,
    required this.year,
    required this.month,
    required this.day,
    required this.dayOfWeek,
    this.courseTitle,
    this.coursePlanId,
    this.userId,
    required this.createdAt,
    this.metadata = const {},
  });

  /// 从Firestore文档创建GymRevenue对象
  factory GymRevenue.fromFirestore(String id, Map<String, dynamic> data) {
    final dateTimestamp = data['date'] as Timestamp;
    final createdAtTimestamp = data['createdAt'] as Timestamp;

    return GymRevenue(
      id: id,
      gymAdminId: data['gymAdminId'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      source: data['source'] ?? '',
      description: data['description'] ?? '',
      date: dateTimestamp.toDate(),
      year: data['year'] ?? 0,
      month: data['month'] ?? 0,
      day: data['day'] ?? 0,
      dayOfWeek: data['dayOfWeek'] ?? 1,
      courseTitle: data['courseTitle'],
      coursePlanId: data['coursePlanId'],
      userId: data['userId'],
      createdAt: createdAtTimestamp.toDate(),
      metadata: Map<String, dynamic>.from(data),
    );
  }

  /// 转换为Firestore文档数据
  Map<String, dynamic> toFirestore() {
    return {
      'gymAdminId': gymAdminId,
      'amount': amount,
      'source': source,
      'description': description,
      'date': Timestamp.fromDate(date),
      'year': year,
      'month': month,
      'day': day,
      'dayOfWeek': dayOfWeek,
      'courseTitle': courseTitle,
      'coursePlanId': coursePlanId,
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
      ...metadata,
    };
  }

  /// 格式化日期字符串
  String get formattedDate {
    return '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year';
  }

  /// 格式化时间字符串
  String get formattedDateTime {
    return '${formattedDate} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化金额字符串
  String get formattedAmount => 'RM ${amount.toStringAsFixed(2)}';

  /// 获取星期几的名称
  String get dayName {
    switch (dayOfWeek) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Unknown';
    }
  }

  /// 获取收入来源的显示名称
  String get sourceDisplayName {
    switch (source) {
      case 'course_purchase':
        return 'Course Purchase Fee';
      case 'membership':
        return 'Membership Fee';
      case 'equipment_rental':
        return 'Equipment Rental';
      case 'personal_training':
        return 'Personal Training';
      case 'other':
        return 'Other Revenue';
      default:
        return source.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  String toString() {
    return 'GymRevenue(id: $id, amount: $amount, source: $source, date: $formattedDate)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is GymRevenue &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 健身房收入统计模型
class GymRevenueStats {
  final String gymAdminId;
  final double totalRevenue;
  final int totalTransactions;
  final double averageTransaction;
  final double dailyAverage;
  final double weeklyTotal;
  final double monthlyTotal;
  final Map<String, double> sourceBreakdown;
  final Map<String, double> dailyBreakdown;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime lastUpdated;

  GymRevenueStats({
    required this.gymAdminId,
    required this.totalRevenue,
    required this.totalTransactions,
    required this.averageTransaction,
    required this.dailyAverage,
    required this.weeklyTotal,
    required this.monthlyTotal,
    required this.sourceBreakdown,
    required this.dailyBreakdown,
    required this.periodStart,
    required this.periodEnd,
    required this.lastUpdated,
  });

  /// 创建空的统计对象
  factory GymRevenueStats.empty(String gymAdminId) {
    final now = DateTime.now();
    return GymRevenueStats(
      gymAdminId: gymAdminId,
      totalRevenue: 0.0,
      totalTransactions: 0,
      averageTransaction: 0.0,
      dailyAverage: 0.0,
      weeklyTotal: 0.0,
      monthlyTotal: 0.0,
      sourceBreakdown: {},
      dailyBreakdown: {},
      periodStart: now,
      periodEnd: now,
      lastUpdated: now,
    );
  }

  /// 从收入记录列表计算统计
  factory GymRevenueStats.fromRevenues(
      String gymAdminId,
      List<GymRevenue> revenues,
      DateTime periodStart,
      DateTime periodEnd,
      ) {
    if (revenues.isEmpty) {
      return GymRevenueStats.empty(gymAdminId);
    }

    double totalRevenue = 0.0;
    Map<String, double> sourceBreakdown = {};
    Map<String, double> dailyBreakdown = {};

    for (final revenue in revenues) {
      totalRevenue += revenue.amount;

      // 按来源统计
      sourceBreakdown[revenue.source] =
          (sourceBreakdown[revenue.source] ?? 0.0) + revenue.amount;

      // 按日期统计
      final dateKey = revenue.formattedDate;
      dailyBreakdown[dateKey] =
          (dailyBreakdown[dateKey] ?? 0.0) + revenue.amount;
    }

    final totalTransactions = revenues.length;
    final averageTransaction = totalRevenue / totalTransactions;
    final periodDays = periodEnd.difference(periodStart).inDays + 1;
    final dailyAverage = totalRevenue / periodDays;

    // 计算周和月的总计
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final weeklyRevenues = revenues.where((r) =>
        r.date.isAfter(weekStart.subtract(const Duration(days: 1)))).toList();
    final monthlyRevenues = revenues.where((r) =>
        r.date.isAfter(monthStart.subtract(const Duration(days: 1)))).toList();

    final weeklyTotal = weeklyRevenues.fold(0.0, (sum, r) => sum + r.amount);
    final monthlyTotal = monthlyRevenues.fold(0.0, (sum, r) => sum + r.amount);

    return GymRevenueStats(
      gymAdminId: gymAdminId,
      totalRevenue: totalRevenue,
      totalTransactions: totalTransactions,
      averageTransaction: averageTransaction,
      dailyAverage: dailyAverage,
      weeklyTotal: weeklyTotal,
      monthlyTotal: monthlyTotal,
      sourceBreakdown: sourceBreakdown,
      dailyBreakdown: dailyBreakdown,
      periodStart: periodStart,
      periodEnd: periodEnd,
      lastUpdated: DateTime.now(),
    );
  }

  /// 格式化总收入
  String get formattedTotalRevenue => 'RM ${totalRevenue.toStringAsFixed(2)}';

  /// 格式化平均交易额
  String get formattedAverageTransaction => 'RM ${averageTransaction.toStringAsFixed(2)}';

  /// 格式化日均收入
  String get formattedDailyAverage => 'RM ${dailyAverage.toStringAsFixed(2)}';

  /// 格式化周收入
  String get formattedWeeklyTotal => 'RM ${weeklyTotal.toStringAsFixed(2)}';

  /// 格式化月收入
  String get formattedMonthlyTotal => 'RM ${monthlyTotal.toStringAsFixed(2)}';
}

/// 健身房费用设置模型
class GymFeeSettings {
  final String gymAdminId;
  final double additionalFee;
  final String feeDescription;
  final bool isEnabled;
  final DateTime? updatedAt;
  final DateTime createdAt;

  GymFeeSettings({
    required this.gymAdminId,
    required this.additionalFee,
    required this.feeDescription,
    required this.isEnabled,
    this.updatedAt,
    required this.createdAt,
  });

  /// 从Firestore文档创建GymFeeSettings对象
  factory GymFeeSettings.fromFirestore(Map<String, dynamic> data) {
    final updatedAtTimestamp = data['updatedAt'] as Timestamp?;
    final createdAtTimestamp = data['createdAt'] as Timestamp?;

    return GymFeeSettings(
      gymAdminId: data['gymAdminId'] ?? '',
      additionalFee: (data['additionalFee'] ?? 0.0).toDouble(),
      feeDescription: data['feeDescription'] ?? '',
      isEnabled: data['isEnabled'] ?? true,
      updatedAt: updatedAtTimestamp?.toDate(),
      createdAt: createdAtTimestamp?.toDate() ?? DateTime.now(),
    );
  }

  /// 转换为Firestore文档数据
  Map<String, dynamic> toFirestore() {
    return {
      'gymAdminId': gymAdminId,
      'additionalFee': additionalFee,
      'feeDescription': feeDescription,
      'isEnabled': isEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': createdAt,
    };
  }

  /// 创建默认设置
  factory GymFeeSettings.defaultSettings(String gymAdminId) {
    return GymFeeSettings(
      gymAdminId: gymAdminId,
      additionalFee: 0.0,
      feeDescription: '',
      isEnabled: false,
      createdAt: DateTime.now(),
    );
  }

  /// 格式化费用字符串
  String get formattedFee => 'RM ${additionalFee.toStringAsFixed(2)}';

  /// 获取状态文本
  String get statusText => isEnabled ? 'Enabled' : 'Disabled';

  /// 复制并修改
  GymFeeSettings copyWith({
    String? gymAdminId,
    double? additionalFee,
    String? feeDescription,
    bool? isEnabled,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) {
    return GymFeeSettings(
      gymAdminId: gymAdminId ?? this.gymAdminId,
      additionalFee: additionalFee ?? this.additionalFee,
      feeDescription: feeDescription ?? this.feeDescription,
      isEnabled: isEnabled ?? this.isEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'GymFeeSettings(gymAdminId: $gymAdminId, additionalFee: $additionalFee, isEnabled: $isEnabled)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is GymFeeSettings &&
              runtimeType == other.runtimeType &&
              gymAdminId == other.gymAdminId;

  @override
  int get hashCode => gymAdminId.hashCode;
}

/// 收入时间段枚举
enum RevenuePeriod {
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
  last3Months,
  thisYear,
  custom,
}

extension RevenuePeriodExtension on RevenuePeriod {
  String get displayName {
    switch (this) {
      case RevenuePeriod.today:
        return 'Today';
      case RevenuePeriod.yesterday:
        return 'Yesterday';
      case RevenuePeriod.thisWeek:
        return 'This Week';
      case RevenuePeriod.lastWeek:
        return 'Last Week';
      case RevenuePeriod.thisMonth:
        return 'This Month';
      case RevenuePeriod.lastMonth:
        return 'Last Month';
      case RevenuePeriod.last3Months:
        return 'Last 3 Months';
      case RevenuePeriod.thisYear:
        return 'This Year';
      case RevenuePeriod.custom:
        return 'Custom Period';
    }
  }

  /// 获取时间段的开始和结束日期
  (DateTime start, DateTime end) get dateRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (this) {
      case RevenuePeriod.today:
        return (today, today.add(const Duration(days: 1)));

      case RevenuePeriod.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        return (yesterday, today);

      case RevenuePeriod.thisWeek:
        final weekStart = today.subtract(Duration(days: now.weekday - 1));
        return (weekStart, weekStart.add(const Duration(days: 7)));

      case RevenuePeriod.lastWeek:
        final lastWeekStart = today.subtract(Duration(days: now.weekday - 1 + 7));
        return (lastWeekStart, lastWeekStart.add(const Duration(days: 7)));

      case RevenuePeriod.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 1);
        return (monthStart, monthEnd);

      case RevenuePeriod.lastMonth:
        final lastMonthStart = DateTime(now.year, now.month - 1, 1);
        final lastMonthEnd = DateTime(now.year, now.month, 1);
        return (lastMonthStart, lastMonthEnd);

      case RevenuePeriod.last3Months:
        final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 1);
        return (threeMonthsAgo, monthEnd);

      case RevenuePeriod.thisYear:
        final yearStart = DateTime(now.year, 1, 1);
        final yearEnd = DateTime(now.year + 1, 1, 1);
        return (yearStart, yearEnd);

      case RevenuePeriod.custom:
        return (today, today.add(const Duration(days: 1)));
    }
  }
}