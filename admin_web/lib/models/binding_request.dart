// lib/models/binding_request.dart
// 用途：绑定请求数据模型定义（支持绑定/解绑类型）

import 'package:cloud_firestore/cloud_firestore.dart';

/// 绑定请求数据模型（支持绑定/解绑类型）
class BindingRequest {
  final String id;
  final String coachId;
  final String coachName;
  final String coachEmail;
  final String gymId;
  final String gymName;
  final String message;
  final String type; // 'bind' 或 'unbind'
  final String status; // 'pending', 'approved', 'rejected', 'cancelled'
  final DateTime? createdAt;
  final DateTime? processedAt;
  final String? rejectReason;
  final String? targetAdminUid;

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
    this.targetAdminUid,
  });

  factory BindingRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BindingRequest(
      id: doc.id,
      coachId: data['coachId'] ?? '',
      coachName: data['coachName'] ?? 'Unknown Coach',
      coachEmail: data['coachEmail'] ?? '',
      gymId: data['gymId'] ?? '',
      gymName: data['gymName'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'bind', // 默认为绑定类型
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      processedAt: (data['processedAt'] as Timestamp?)?.toDate(),
      rejectReason: data['rejectReason'],
      targetAdminUid: data['targetAdminUid'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'coachId': coachId,
      'coachName': coachName,
      'coachEmail': coachEmail,
      'gymId': gymId,
      'gymName': gymName,
      'message': message,
      'type': type,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'rejectReason': rejectReason,
      if (targetAdminUid != null) 'targetAdminUid': targetAdminUid,
    };
  }

  // 状态显示文本
  String get statusDisplayText {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  // 请求类型显示文本
  String get typeDisplayText {
    return type == 'unbind' ? 'Unbind' : 'Bind';
  }

  // 是否可以处理（批准/拒绝）
  bool get canProcess => status == 'pending';

  // 格式化创建时间
  String get formattedCreatedAt {
    if (createdAt == null) return 'Unknown';
    return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
  }

  // 格式化处理时间
  String get formattedProcessedAt {
    if (processedAt == null) return 'Not processed';
    return '${processedAt!.day}/${processedAt!.month}/${processedAt!.year}';
  }

  // 获取详细的创建时间（包含时分秒）
  String get detailedCreatedAt {
    if (createdAt == null) return 'Unknown';
    final date = createdAt!;
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // 获取详细的处理时间（包含时分秒）
  String get detailedProcessedAt {
    if (processedAt == null) return 'Not processed';
    final date = processedAt!;
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // 判断是否为绑定请求
  bool get isBindRequest => type == 'bind';

  // 判断是否为解绑请求
  bool get isUnbindRequest => type == 'unbind';

  // 判断是否为待处理状态
  bool get isPending => status == 'pending';

  // 判断是否为已批准状态
  bool get isApproved => status == 'approved';

  // 判断是否为已拒绝状态
  bool get isRejected => status == 'rejected';

  // 判断是否为已取消状态
  bool get isCancelled => status == 'cancelled';

  // 复制对象并修改某些字段
  BindingRequest copyWith({
    String? id,
    String? coachId,
    String? coachName,
    String? coachEmail,
    String? gymId,
    String? gymName,
    String? message,
    String? type,
    String? status,
    DateTime? createdAt,
    DateTime? processedAt,
    String? rejectReason,
  }) {
    return BindingRequest(
      id: id ?? this.id,
      coachId: coachId ?? this.coachId,
      coachName: coachName ?? this.coachName,
      coachEmail: coachEmail ?? this.coachEmail,
      gymId: gymId ?? this.gymId,
      gymName: gymName ?? this.gymName,
      message: message ?? this.message,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      rejectReason: rejectReason ?? this.rejectReason,
    );
  }

  @override
  String toString() {
    return 'BindingRequest(id: $id, coachName: $coachName, gymName: $gymName, type: $type, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BindingRequest &&
        other.id == id &&
        other.coachId == coachId &&
        other.gymId == gymId &&
        other.type == type &&
        other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    coachId.hashCode ^
    gymId.hashCode ^
    type.hashCode ^
    status.hashCode;
  }
}