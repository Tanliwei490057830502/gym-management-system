// lib/models/appointment.dart
// 用途：预约数据模型 - 支持教练和管理员双重批准

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 预约数据模型
class Appointment {
  final String id;
  final String userName;
  final String userEmail;
  final String userId;
  final String coachId;
  final String coachName;
  final String gymId;
  final String gymName;
  final DateTime date;
  final String timeSlot;
  final String coachApproval; // 'pending', 'approved', 'rejected'
  final String adminApproval; // 'pending', 'approved', 'rejected'
  final String overallStatus; // 'pending', 'confirmed', 'completed', 'cancelled'
  final String? notes;
  final String? coachRejectReason;
  final String? adminRejectReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? coachApprovedAt;
  final DateTime? adminApprovedAt;

  Appointment({
    required this.id,
    required this.userName,
    required this.userEmail,
    required this.userId,
    required this.coachId,
    required this.coachName,
    required this.gymId,
    required this.gymName,
    required this.date,
    required this.timeSlot,
    required this.coachApproval,
    required this.adminApproval,
    required this.overallStatus,
    this.notes,
    this.coachRejectReason,
    this.adminRejectReason,
    this.createdAt,
    this.updatedAt,
    this.coachApprovedAt,
    this.adminApprovedAt,
  });

  /// 从 Firestore 数据创建对象
  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appointment(
      id: doc.id,
      userName: data['userName'] ?? 'Unknown User',
      userEmail: data['userEmail'] ?? '',
      userId: data['userId'] ?? '',
      coachId: data['coachId'] ?? '',
      coachName: data['coachName'] ?? 'Unknown Coach',
      gymId: data['gymId'] ?? '',
      gymName: data['gymName'] ?? 'Unknown Gym',
      date: (data['date'] as Timestamp).toDate(),
      timeSlot: data['timeSlot'] ?? '',
      coachApproval: data['coachApproval'] ?? 'pending',
      adminApproval: data['adminApproval'] ?? 'pending',
      overallStatus: data['overallStatus'] ?? 'pending',
      notes: data['notes'],
      coachRejectReason: data['coachRejectReason'],
      adminRejectReason: data['adminRejectReason'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      coachApprovedAt: (data['coachApprovedAt'] as Timestamp?)?.toDate(),
      adminApprovedAt: (data['adminApprovedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// 转换为 Firestore 数据
  Map<String, dynamic> toMap() {
    return {
      'userName': userName,
      'userEmail': userEmail,
      'userId': userId,
      'coachId': coachId,
      'coachName': coachName,
      'gymId': gymId,
      'gymName': gymName,
      'date': Timestamp.fromDate(date),
      'timeSlot': timeSlot,
      'coachApproval': coachApproval,
      'adminApproval': adminApproval,
      'overallStatus': overallStatus,
      'notes': notes,
      'coachRejectReason': coachRejectReason,
      'adminRejectReason': adminRejectReason,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'coachApprovedAt': coachApprovedAt != null ? Timestamp.fromDate(coachApprovedAt!) : null,
      'adminApprovedAt': adminApprovedAt != null ? Timestamp.fromDate(adminApprovedAt!) : null,
    };
  }

  /// 总体状态显示文本
  String get statusDisplayText {
    switch (overallStatus) {
      case 'pending':
        return 'Pending Approval';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  /// 详细状态显示文本
  String get detailedStatusText {
    if (overallStatus == 'confirmed') return 'Fully Approved';
    if (overallStatus == 'cancelled') return 'Cancelled';
    if (overallStatus == 'completed') return 'Completed';

    // 对于pending状态，显示详细进度
    if (coachApproval == 'approved' && adminApproval == 'approved') {
      return 'Approved by Both';
    } else if (coachApproval == 'approved' && adminApproval == 'pending') {
      return 'Coach Approved, Waiting Admin';
    } else if (coachApproval == 'pending' && adminApproval == 'approved') {
      return 'Admin Approved, Waiting Coach';
    } else if (coachApproval == 'rejected' || adminApproval == 'rejected') {
      return 'Rejected';
    } else {
      return 'Waiting for Approval';
    }
  }

  /// 获取状态颜色
  Color get statusColor {
    switch (overallStatus) {
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
      // 对于pending，根据批准状态决定颜色
        if (coachApproval == 'approved' && adminApproval == 'approved') {
          return Colors.green; // 双重批准但尚未确认
        } else if (coachApproval == 'approved' || adminApproval == 'approved') {
          return Colors.blue; // 部分批准
        } else if (coachApproval == 'rejected' || adminApproval == 'rejected') {
          return Colors.red; // 被拒绝
        } else {
          return Colors.orange; // 等待批准
        }
    }
  }

  /// 获取状态图标
  IconData get statusIcon {
    switch (overallStatus) {
      case 'confirmed':
        return Icons.check_circle;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        if (coachApproval == 'approved' && adminApproval == 'approved') {
          return Icons.verified;
        } else if (coachApproval == 'approved' || adminApproval == 'approved') {
          return Icons.pending_actions;
        } else if (coachApproval == 'rejected' || adminApproval == 'rejected') {
          return Icons.cancel;
        } else {
          return Icons.schedule;
        }
    }
  }

  /// 检查教练是否可以批准
  bool get canCoachApprove => coachApproval == 'pending' && overallStatus == 'pending';

  /// 检查教练是否可以拒绝
  bool get canCoachReject => coachApproval == 'pending' && overallStatus == 'pending';

  /// 检查管理员是否可以批准
  bool get canAdminApprove => adminApproval == 'pending' && overallStatus == 'pending';

  /// 检查管理员是否可以拒绝
  bool get canAdminReject => adminApproval == 'pending' && overallStatus == 'pending';

  /// 检查是否可以完成
  bool get canComplete => overallStatus == 'confirmed';

  /// 检查是否可以取消
  bool get canCancel => overallStatus == 'pending' || overallStatus == 'confirmed';

  /// 检查是否需要自动确认（双重批准后）
  bool get shouldAutoConfirm =>
      coachApproval == 'approved' &&
          adminApproval == 'approved' &&
          overallStatus == 'pending';

  /// 检查是否应该自动取消（任一方拒绝后）
  bool get shouldAutoCancel =>
      (coachApproval == 'rejected' || adminApproval == 'rejected') &&
          overallStatus == 'pending';

  /// 获取批准进度 (0.0 到 1.0)
  double get approvalProgress {
    int approvedCount = 0;
    if (coachApproval == 'approved') approvedCount++;
    if (adminApproval == 'approved') approvedCount++;
    return approvedCount / 2.0;
  }

  /// 创建副本
  Appointment copyWith({
    String? id,
    String? userName,
    String? userEmail,
    String? userId,
    String? coachId,
    String? coachName,
    String? gymId,
    String? gymName,
    DateTime? date,
    String? timeSlot,
    String? coachApproval,
    String? adminApproval,
    String? overallStatus,
    String? notes,
    String? coachRejectReason,
    String? adminRejectReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? coachApprovedAt,
    DateTime? adminApprovedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userId: userId ?? this.userId,
      coachId: coachId ?? this.coachId,
      coachName: coachName ?? this.coachName,
      gymId: gymId ?? this.gymId,
      gymName: gymName ?? this.gymName,
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      coachApproval: coachApproval ?? this.coachApproval,
      adminApproval: adminApproval ?? this.adminApproval,
      overallStatus: overallStatus ?? this.overallStatus,
      notes: notes ?? this.notes,
      coachRejectReason: coachRejectReason ?? this.coachRejectReason,
      adminRejectReason: adminRejectReason ?? this.adminRejectReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      coachApprovedAt: coachApprovedAt ?? this.coachApprovedAt,
      adminApprovedAt: adminApprovedAt ?? this.adminApprovedAt,
    );
  }

  @override
  String toString() {
    return 'Appointment(id: $id, userName: $userName, overallStatus: $overallStatus, coachApproval: $coachApproval, adminApproval: $adminApproval)';
  }
}

/// 预约统计信息
class AppointmentStats {
  final int total;
  final int pending;
  final int confirmed;
  final int completed;
  final int cancelled;
  final int waitingCoachApproval;
  final int waitingAdminApproval;
  final int partiallyApproved;

  AppointmentStats({
    required this.total,
    required this.pending,
    required this.confirmed,
    required this.completed,
    required this.cancelled,
    required this.waitingCoachApproval,
    required this.waitingAdminApproval,
    required this.partiallyApproved,
  });

  factory AppointmentStats.fromAppointments(List<Appointment> appointments) {
    final waitingCoach = appointments.where((a) =>
    a.coachApproval == 'pending' && a.overallStatus == 'pending').length;
    final waitingAdmin = appointments.where((a) =>
    a.adminApproval == 'pending' && a.overallStatus == 'pending').length;
    final partiallyApproved = appointments.where((a) =>
    (a.coachApproval == 'approved' || a.adminApproval == 'approved') &&
        a.overallStatus == 'pending').length;

    return AppointmentStats(
      total: appointments.length,
      pending: appointments.where((a) => a.overallStatus == 'pending').length,
      confirmed: appointments.where((a) => a.overallStatus == 'confirmed').length,
      completed: appointments.where((a) => a.overallStatus == 'completed').length,
      cancelled: appointments.where((a) => a.overallStatus == 'cancelled').length,
      waitingCoachApproval: waitingCoach,
      waitingAdminApproval: waitingAdmin,
      partiallyApproved: partiallyApproved,
    );
  }
}