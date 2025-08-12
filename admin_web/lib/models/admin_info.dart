// lib/models/admin_info.dart
// 用途：管理员信息数据模型

/// 管理员信息模型
class AdminInfo {
  final String uid;
  final String email;
  final String name;
  final String role;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  AdminInfo({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.lastLogin,
  });

  /// 从 Map 创建对象
  factory AdminInfo.fromMap(Map<String, dynamic> map) {
    return AdminInfo(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      isActive: map['isActive'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : null,
      lastLogin: map['lastLogin'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastLogin'])
          : null,
    );
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'isActive': isActive,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'lastLogin': lastLogin?.millisecondsSinceEpoch,
    };
  }

  /// 创建副本
  AdminInfo copyWith({
    String? uid,
    String? email,
    String? name,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return AdminInfo(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  /// 检查是否为管理员
  bool get isAdmin => role == 'admin';

  /// 检查是否为超级管理员
  bool get isSuperAdmin => role == 'super_admin';

  /// 获取状态显示文本
  String get statusText => isActive ? 'Active' : 'Inactive';

  /// 获取角色显示文本
  String get roleDisplayText {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'super_admin':
        return 'Super Administrator';
      default:
        return 'Unknown';
    }
  }

  /// 获取格式化的创建时间
  String get formattedCreatedAt {
    if (createdAt == null) return 'Unknown';
    return '${createdAt!.day}/${createdAt!.month}/${createdAt!.year}';
  }

  /// 获取格式化的最后登录时间
  String get formattedLastLogin {
    if (lastLogin == null) return 'Never';
    return '${lastLogin!.day}/${lastLogin!.month}/${lastLogin!.year}';
  }

  /// 获取详细的最后登录时间
  String get detailedLastLogin {
    if (lastLogin == null) return 'Never logged in';
    final now = DateTime.now();
    final difference = now.difference(lastLogin!);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// 检查账户是否有效
  bool get isValidAccount => isActive && uid.isNotEmpty && email.isNotEmpty;

  /// 检查是否为新用户（今天创建的）
  bool get isNewUser {
    if (createdAt == null) return false;
    final now = DateTime.now();
    return now.difference(createdAt!).inDays == 0;
  }

  /// 检查是否长时间未登录（超过30天）
  bool get isLongTimeInactive {
    if (lastLogin == null) return true;
    final now = DateTime.now();
    return now.difference(lastLogin!).inDays > 30;
  }

  @override
  String toString() {
    return 'AdminInfo(uid: $uid, email: $email, name: $name, role: $role, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminInfo &&
        other.uid == uid &&
        other.email == email &&
        other.name == name &&
        other.role == role &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
    email.hashCode ^
    name.hashCode ^
    role.hashCode ^
    isActive.hashCode;
  }
}