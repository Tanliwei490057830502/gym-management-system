// lib/models/auth_result.dart
// 用途：认证结果数据模型

/// 认证结果类
class AuthResult {
  final bool isSuccess;
  final String message;

  AuthResult._(this.isSuccess, this.message);

  /// 创建成功结果
  factory AuthResult.success(String message) => AuthResult._(true, message);

  /// 创建失败结果
  factory AuthResult.error(String message) => AuthResult._(false, message);

  /// 检查是否成功
  bool get isError => !isSuccess;

  /// 复制并修改消息
  AuthResult copyWith({
    bool? isSuccess,
    String? message,
  }) {
    return AuthResult._(
      isSuccess ?? this.isSuccess,
      message ?? this.message,
    );
  }

  @override
  String toString() {
    return 'AuthResult(isSuccess: $isSuccess, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthResult &&
        other.isSuccess == isSuccess &&
        other.message == message;
  }

  @override
  int get hashCode => isSuccess.hashCode ^ message.hashCode;
}