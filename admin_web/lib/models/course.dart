// lib/models/course.dart
// 用途：课程数据模型定义

import 'package:cloud_firestore/cloud_firestore.dart';

/// 课程数据模型
class Course {
  final String id;
  final String title;
  final String description;
  final String coachId;
  final String duration;
  final int maxParticipants;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.coachId,
    required this.duration,
    required this.maxParticipants,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  factory Course.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Course(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      coachId: data['coachId'] ?? '',
      duration: data['duration'] ?? '',
      maxParticipants: data['maxParticipants'] ?? 0,
      status: data['status'] ?? 'active',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'coachId': coachId,
      'duration': duration,
      'maxParticipants': maxParticipants,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // 格式化创建时间
  String get formattedCreatedAt {
    if (createdAt == null) return 'Unknown';
    return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
  }

  // 格式化更新时间
  String get formattedUpdatedAt {
    if (updatedAt == null) return 'Unknown';
    return '${updatedAt!.day}/${updatedAt!.month}/${updatedAt!.year}';
  }

  // 获取详细的创建时间（包含时分秒）
  String get detailedCreatedAt {
    if (createdAt == null) return 'Unknown';
    final date = createdAt!;
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // 获取详细的更新时间（包含时分秒）
  String get detailedUpdatedAt {
    if (updatedAt == null) return 'Unknown';
    final date = updatedAt!;
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // 状态显示文本
  String get statusDisplayText {
    switch (status) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      case 'cancelled':
        return 'Cancelled';
      case 'completed':
        return 'Completed';
      default:
        return 'Unknown';
    }
  }

  // 判断是否为活跃状态
  bool get isActive => status == 'active';

  // 判断是否为非活跃状态
  bool get isInactive => status == 'inactive';

  // 判断是否为已取消状态
  bool get isCancelled => status == 'cancelled';

  // 判断是否为已完成状态
  bool get isCompleted => status == 'completed';

  // 获取时长显示文本
  String get durationDisplayText {
    if (duration.isEmpty) return 'Unknown';

    // 如果已经包含单位，直接返回
    if (duration.contains('min') || duration.contains('hour') || duration.contains('分') || duration.contains('小时')) {
      return duration;
    }

    // 尝试解析为数字并添加分钟单位
    final minutes = int.tryParse(duration);
    if (minutes != null) {
      if (minutes >= 60) {
        final hours = minutes ~/ 60;
        final remainingMinutes = minutes % 60;
        if (remainingMinutes == 0) {
          return '${hours}h';
        } else {
          return '${hours}h ${remainingMinutes}min';
        }
      } else {
        return '${minutes}min';
      }
    }

    return duration;
  }

  // 复制对象并修改某些字段
  Course copyWith({
    String? id,
    String? title,
    String? description,
    String? coachId,
    String? duration,
    int? maxParticipants,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coachId: coachId ?? this.coachId,
      duration: duration ?? this.duration,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Course(id: $id, title: $title, coachId: $coachId, duration: $duration, maxParticipants: $maxParticipants, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Course &&
        other.id == id &&
        other.title == title &&
        other.coachId == coachId &&
        other.maxParticipants == maxParticipants &&
        other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    title.hashCode ^
    coachId.hashCode ^
    maxParticipants.hashCode ^
    status.hashCode;
  }
}