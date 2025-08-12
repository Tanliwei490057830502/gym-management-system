// lib/models/coach.dart
// 用途：教练数据模型定义（支持多健身房绑定）

import 'package:cloud_firestore/cloud_firestore.dart';

/// 教练数据模型（支持多健身房绑定）
class Coach {
  final String id;
  final String name;
  final String email;
  final String? assignedGymId; // 保持兼容性
  final String? assignedGymName; // 保持兼容性
  final List<String> boundGyms; // 新增：绑定的健身房列表
  final String status; // 'active', 'inactive', 'break'
  final String? role;
  final DateTime? joinedAt;
  final DateTime? updatedAt;

  Coach({
    required this.id,
    required this.name,
    required this.email,
    this.assignedGymId,
    this.assignedGymName,
    this.boundGyms = const [],
    required this.status,
    this.role,
    this.joinedAt,
    this.updatedAt,
  });

  factory Coach.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // 处理多健身房绑定
    List<String> boundGymsList = [];
    if (data['boundGyms'] != null) {
      boundGymsList = List<String>.from(data['boundGyms']);
    } else if (data['assignedGymId'] != null) {
      boundGymsList.add(data['assignedGymId']);
    }

    return Coach(
      id: doc.id,
      name: data['name'] ?? 'Unknown Coach',
      email: data['email'] ?? '',
      assignedGymId: data['assignedGymId'],
      assignedGymName: data['assignedGymName'],
      boundGyms: boundGymsList,
      status: data['status'] ?? 'inactive',
      role: data['role'],
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'assignedGymId': assignedGymId,
      'assignedGymName': assignedGymName,
      'boundGyms': boundGyms,
      'status': status,
      'role': role,
      'joinedAt': joinedAt != null ? Timestamp.fromDate(joinedAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // 状态显示文本
  String get statusDisplayText {
    switch (status) {
      case 'active':
        return 'Working';
      case 'break':
        return 'On Break';
      case 'inactive':
        return 'Inactive';
      default:
        return 'Unknown';
    }
  }

  // 获取绑定的健身房数量
  int get boundGymCount => boundGyms.length;

  // 检查是否绑定到特定健身房
  bool isBoundTo(String gymId) => boundGyms.contains(gymId);

  // 复制对象并修改某些字段
  Coach copyWith({
    String? id,
    String? name,
    String? email,
    String? assignedGymId,
    String? assignedGymName,
    List<String>? boundGyms,
    String? status,
    String? role,
    DateTime? joinedAt,
    DateTime? updatedAt,
  }) {
    return Coach(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      assignedGymId: assignedGymId ?? this.assignedGymId,
      assignedGymName: assignedGymName ?? this.assignedGymName,
      boundGyms: boundGyms ?? this.boundGyms,
      status: status ?? this.status,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Coach(id: $id, name: $name, email: $email, status: $status, boundGyms: $boundGyms)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Coach &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    name.hashCode ^
    email.hashCode ^
    status.hashCode;
  }
}