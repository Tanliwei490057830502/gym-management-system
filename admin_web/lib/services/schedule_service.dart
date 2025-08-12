// lib/services/schedule_service.dart
// 用途：行程管理服务类 - 支持双重批准系统

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class ScheduleService {
  static final _firestore = FirebaseFirestore.instance;

  /// 获取指定月份的预约列表
  static Stream<List<Appointment>> getMonthlyAppointments(int year, int month) {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    return _firestore
        .collection('appointments')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .orderBy('date')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Appointment.fromFirestore(doc))
        .toList());
  }

  /// 获取当前月份的预约列表
  static Stream<List<Appointment>> getCurrentMonthAppointments() {
    final now = DateTime.now();
    return getMonthlyAppointments(now.year, now.month);
  }

  /// 获取月度预约统计
  static MonthlyScheduleStats getMonthlyStats(List<Appointment> appointments) {
    final stats = <DateTime, DayScheduleStats>{};

    for (final appointment in appointments) {
      final dateKey = DateTime(appointment.date.year, appointment.date.month, appointment.date.day);

      if (!stats.containsKey(dateKey)) {
        stats[dateKey] = DayScheduleStats(
          date: dateKey,
          total: 0,
          pending: 0,
          confirmed: 0,
          completed: 0,
          cancelled: 0,
          waitingCoachApproval: 0,
          waitingAdminApproval: 0,
          partiallyApproved: 0,
        );
      }

      final dayStat = stats[dateKey]!;
      stats[dateKey] = DayScheduleStats(
        date: dateKey,
        total: dayStat.total + 1,
        pending: dayStat.pending + (appointment.overallStatus == 'pending' ? 1 : 0),
        confirmed: dayStat.confirmed + (appointment.overallStatus == 'confirmed' ? 1 : 0),
        completed: dayStat.completed + (appointment.overallStatus == 'completed' ? 1 : 0),
        cancelled: dayStat.cancelled + (appointment.overallStatus == 'cancelled' ? 1 : 0),
        waitingCoachApproval: dayStat.waitingCoachApproval +
            (appointment.coachApproval == 'pending' && appointment.overallStatus == 'pending' ? 1 : 0),
        waitingAdminApproval: dayStat.waitingAdminApproval +
            (appointment.adminApproval == 'pending' && appointment.overallStatus == 'pending' ? 1 : 0),
        partiallyApproved: dayStat.partiallyApproved +
            ((appointment.coachApproval == 'approved' || appointment.adminApproval == 'approved') &&
                appointment.overallStatus == 'pending' ? 1 : 0),
      );
    }

    return MonthlyScheduleStats(dayStats: stats);
  }

  /// 批量更新预约的总体状态
  static Future<void> batchUpdateAppointmentStatus(
      List<String> appointmentIds,
      String newStatus,
      ) async {
    final batch = _firestore.batch();

    for (final id in appointmentIds) {
      final docRef = _firestore.collection('appointments').doc(id);
      batch.update(docRef, {
        'overallStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// 批量更新教练批准状态
  static Future<void> batchUpdateCoachApproval(
      List<String> appointmentIds,
      String approval,
      ) async {
    final batch = _firestore.batch();

    for (final id in appointmentIds) {
      final docRef = _firestore.collection('appointments').doc(id);
      final updateData = {
        'coachApproval': approval,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (approval == 'approved') {
        updateData['coachApprovedAt'] = FieldValue.serverTimestamp();
      }

      batch.update(docRef, updateData);
    }

    await batch.commit();

    // 检查每个预约是否需要自动确认
    for (final id in appointmentIds) {
      await _checkAndAutoConfirm(id);
    }
  }

  /// 批量更新管理员批准状态
  static Future<void> batchUpdateAdminApproval(
      List<String> appointmentIds,
      String approval,
      ) async {
    final batch = _firestore.batch();

    for (final id in appointmentIds) {
      final docRef = _firestore.collection('appointments').doc(id);
      final updateData = {
        'adminApproval': approval,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (approval == 'approved') {
        updateData['adminApprovedAt'] = FieldValue.serverTimestamp();
      }

      batch.update(docRef, updateData);
    }

    await batch.commit();

    // 检查每个预约是否需要自动确认
    for (final id in appointmentIds) {
      await _checkAndAutoConfirm(id);
    }
  }

  /// 检查并自动确认预约
  static Future<void> _checkAndAutoConfirm(String appointmentId) async {
    try {
      final doc = await _firestore.collection('appointments').doc(appointmentId).get();

      if (doc.exists) {
        final appointment = Appointment.fromFirestore(doc);

        if (appointment.shouldAutoConfirm) {
          await _firestore.collection('appointments').doc(appointmentId).update({
            'overallStatus': 'confirmed',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (appointment.shouldAutoCancel) {
          await _firestore.collection('appointments').doc(appointmentId).update({
            'overallStatus': 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error in auto-confirm check: $e');
    }
  }

  /// 获取待审批的预约数量（全部，不限今日）
  static Stream<int> getPendingAppointmentsCount() {
    return _firestore
        .collection('appointments')
        .where('overallStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// 获取等待教练批准的预约数量
  static Stream<int> getPendingCoachApprovalsCount() {
    return _firestore
        .collection('appointments')
        .where('coachApproval', isEqualTo: 'pending')
        .where('overallStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// 获取等待管理员批准的预约数量
  static Stream<int> getPendingAdminApprovalsCount() {
    return _firestore
        .collection('appointments')
        .where('adminApproval', isEqualTo: 'pending')
        .where('overallStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// 获取部分批准的预约数量
  static Stream<int> getPartiallyApprovedCount() {
    // 注意：Firestore不支持复杂的OR查询，所以需要在客户端进行过滤
    return _firestore
        .collection('appointments')
        .where('overallStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Appointment.fromFirestore(doc))
        .where((appointment) =>
    appointment.coachApproval == 'approved' ||
        appointment.adminApproval == 'approved')
        .length);
  }

  /// 获取特定教练待批准的预约数量
  static Stream<int> getPendingCoachApprovalsForCoach(String coachId) {
    return _firestore
        .collection('appointments')
        .where('coachId', isEqualTo: coachId)
        .where('coachApproval', isEqualTo: 'pending')
        .where('overallStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// 获取预约详细统计信息
  static Stream<AppointmentStats> getDetailedAppointmentStats() {
    return _firestore
        .collection('appointments')
        .snapshots()
        .map((snapshot) {
      final appointments = snapshot.docs
          .map((doc) => Appointment.fromFirestore(doc))
          .toList();
      return AppointmentStats.fromAppointments(appointments);
    });
  }

  /// 按状态获取预约流
  static Stream<List<Appointment>> getAppointmentsByStatus(String status) {
    if (status == 'all') {
      return _firestore
          .collection('appointments')
          .orderBy('date', descending: false)
          .snapshots()
          .map((snapshot) => snapshot.docs
          .map((doc) => Appointment.fromFirestore(doc))
          .toList());
    }

    return _firestore
        .collection('appointments')
        .where('overallStatus', isEqualTo: status)
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Appointment.fromFirestore(doc))
        .toList());
  }

  /// 按批准状态获取预约流
  static Stream<List<Appointment>> getAppointmentsByApprovalStatus({
    String? coachApproval,
    String? adminApproval,
    String? overallStatus,
  }) {
    Query query = _firestore.collection('appointments');

    if (coachApproval != null) {
      query = query.where('coachApproval', isEqualTo: coachApproval);
    }
    if (adminApproval != null) {
      query = query.where('adminApproval', isEqualTo: adminApproval);
    }
    if (overallStatus != null) {
      query = query.where('overallStatus', isEqualTo: overallStatus);
    }

    return query
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Appointment.fromFirestore(doc))
        .toList());
  }
}

/// 每日行程统计 - 更新为支持双重批准
class DayScheduleStats {
  final DateTime date;
  final int total;
  final int pending;
  final int confirmed;
  final int completed;
  final int cancelled;
  final int waitingCoachApproval;
  final int waitingAdminApproval;
  final int partiallyApproved;

  DayScheduleStats({
    required this.date,
    required this.total,
    required this.pending,
    required this.confirmed,
    required this.completed,
    required this.cancelled,
    required this.waitingCoachApproval,
    required this.waitingAdminApproval,
    required this.partiallyApproved,
  });

  /// 获取主要状态（数量最多的状态）
  String get primaryStatus {
    final statusCounts = {
      'pending': pending,
      'confirmed': confirmed,
      'completed': completed,
      'cancelled': cancelled,
    };

    // 过滤出计数大于 0 的状态
    final nonZeroEntries = statusCounts.entries.where((entry) => entry.value > 0);

    // 如果没有任何预约，返回默认状态
    if (nonZeroEntries.isEmpty) {
      return 'none';
    }

    // 返回计数最多的状态
    return nonZeroEntries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// 获取详细状态（考虑批准进度）
  String get detailedStatus {
    if (total == 0) return 'none';

    if (partiallyApproved > 0 && pending > 0) {
      return 'partial'; // 有部分批准的预约
    }

    if (waitingCoachApproval > 0 || waitingAdminApproval > 0) {
      return 'waiting'; // 等待批准
    }

    return primaryStatus;
  }

  /// 检查是否有预约
  bool get hasAppointments => total > 0;

  /// 检查是否有待审批的预约
  bool get hasPendingAppointments => pending > 0;

  /// 检查是否有等待教练批准的预约
  bool get hasWaitingCoachApproval => waitingCoachApproval > 0;

  /// 检查是否有等待管理员批准的预约
  bool get hasWaitingAdminApproval => waitingAdminApproval > 0;

  /// 检查是否有部分批准的预约
  bool get hasPartiallyApproved => partiallyApproved > 0;
}

/// 月度行程统计
class MonthlyScheduleStats {
  final Map<DateTime, DayScheduleStats> dayStats;

  MonthlyScheduleStats({required this.dayStats});

  /// 获取指定日期的统计
  DayScheduleStats? getStatsForDate(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    return dayStats[dateKey];
  }

  /// 获取月度总统计
  DayScheduleStats get monthlyTotal {
    int total = 0, pending = 0, confirmed = 0, completed = 0, cancelled = 0;
    int waitingCoachApproval = 0, waitingAdminApproval = 0, partiallyApproved = 0;

    for (final stats in dayStats.values) {
      total += stats.total;
      pending += stats.pending;
      confirmed += stats.confirmed;
      completed += stats.completed;
      cancelled += stats.cancelled;
      waitingCoachApproval += stats.waitingCoachApproval;
      waitingAdminApproval += stats.waitingAdminApproval;
      partiallyApproved += stats.partiallyApproved;
    }

    return DayScheduleStats(
      date: DateTime.now(),
      total: total,
      pending: pending,
      confirmed: confirmed,
      completed: completed,
      cancelled: cancelled,
      waitingCoachApproval: waitingCoachApproval,
      waitingAdminApproval: waitingAdminApproval,
      partiallyApproved: partiallyApproved,
    );
  }

  /// 获取有预约的日期列表
  List<DateTime> get datesWithAppointments => dayStats.keys.toList()..sort();

  /// 获取待审批预约的日期列表
  List<DateTime> get datesWithPendingAppointments =>
      dayStats.entries
          .where((entry) => entry.value.hasPendingAppointments)
          .map((entry) => entry.key)
          .toList()..sort();

  /// 获取等待教练批准的日期列表
  List<DateTime> get datesWithWaitingCoachApproval =>
      dayStats.entries
          .where((entry) => entry.value.hasWaitingCoachApproval)
          .map((entry) => entry.key)
          .toList()..sort();

  /// 获取等待管理员批准的日期列表
  List<DateTime> get datesWithWaitingAdminApproval =>
      dayStats.entries
          .where((entry) => entry.value.hasWaitingAdminApproval)
          .map((entry) => entry.key)
          .toList()..sort();

  /// 获取部分批准的日期列表
  List<DateTime> get datesWithPartiallyApproved =>
      dayStats.entries
          .where((entry) => entry.value.hasPartiallyApproved)
          .map((entry) => entry.key)
          .toList()..sort();
}