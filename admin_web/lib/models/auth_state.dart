// lib/models/auth_state.dart
// 用途：认证状态管理模型

/// 认证状态枚举
enum AuthStatus {
  /// 初始状态
  initial,

  /// 加载中
  loading,

  /// 已认证
  authenticated,

  /// 未认证
  unauthenticated,

  /// 错误状态
  error,
}

/// 认证状态管理器
class AuthStateManager {
  static AuthStatus _status = AuthStatus.initial;
  static String _errorMessage = '';
  static DateTime? _lastUpdated;

  /// 获取当前状态
  static AuthStatus get status => _status;

  /// 获取错误消息
  static String get errorMessage => _errorMessage;

  /// 获取最后更新时间
  static DateTime? get lastUpdated => _lastUpdated;

  /// 设置加载状态
  static void setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = '';
    _lastUpdated = DateTime.now();
  }

  /// 设置已认证状态
  static void setAuthenticated() {
    _status = AuthStatus.authenticated;
    _errorMessage = '';
    _lastUpdated = DateTime.now();
  }

  /// 设置未认证状态
  static void setUnauthenticated() {
    _status = AuthStatus.unauthenticated;
    _errorMessage = '';
    _lastUpdated = DateTime.now();
  }

  /// 设置错误状态
  static void setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    _lastUpdated = DateTime.now();
  }

  /// 重置状态
  static void reset() {
    _status = AuthStatus.initial;
    _errorMessage = '';
    _lastUpdated = null;
  }

  /// 检查是否为加载状态
  static bool get isLoading => _status == AuthStatus.loading;

  /// 检查是否已认证
  static bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// 检查是否未认证
  static bool get isUnauthenticated => _status == AuthStatus.unauthenticated;

  /// 检查是否有错误
  static bool get hasError => _status == AuthStatus.error;

  /// 检查是否为初始状态
  static bool get isInitial => _status == AuthStatus.initial;

  /// 获取状态显示文本
  static String get statusText {
    switch (_status) {
      case AuthStatus.initial:
        return 'Initializing...';
      case AuthStatus.loading:
        return 'Loading...';
      case AuthStatus.authenticated:
        return 'Authenticated';
      case AuthStatus.unauthenticated:
        return 'Not authenticated';
      case AuthStatus.error:
        return 'Error: $_errorMessage';
    }
  }

  /// 获取状态历史记录（简单实现）
  static List<AuthStateHistory> _history = [];

  /// 添加状态历史记录
  static void _addHistory(AuthStatus status, String? message) {
    _history.add(AuthStateHistory(
      status: status,
      message: message,
      timestamp: DateTime.now(),
    ));

    // 保持最近50条记录
    if (_history.length > 50) {
      _history.removeAt(0);
    }
  }

  /// 获取状态历史
  static List<AuthStateHistory> get history => List.unmodifiable(_history);

  /// 重写状态设置方法以包含历史记录
  static void setLoadingWithHistory() {
    setLoading();
    _addHistory(AuthStatus.loading, null);
  }

  static void setAuthenticatedWithHistory() {
    setAuthenticated();
    _addHistory(AuthStatus.authenticated, null);
  }

  static void setUnauthenticatedWithHistory() {
    setUnauthenticated();
    _addHistory(AuthStatus.unauthenticated, null);
  }

  static void setErrorWithHistory(String message) {
    setError(message);
    _addHistory(AuthStatus.error, message);
  }

  /// 清除历史记录
  static void clearHistory() {
    _history.clear();
  }

  /// 获取调试信息
  static Map<String, dynamic> getDebugInfo() {
    return {
      'status': _status.toString(),
      'errorMessage': _errorMessage,
      'lastUpdated': _lastUpdated?.toIso8601String(),
      'historyCount': _history.length,
      'isLoading': isLoading,
      'isAuthenticated': isAuthenticated,
      'hasError': hasError,
    };
  }
}

/// 认证状态历史记录
class AuthStateHistory {
  final AuthStatus status;
  final String? message;
  final DateTime timestamp;

  AuthStateHistory({
    required this.status,
    this.message,
    required this.timestamp,
  });

  /// 获取格式化的时间戳
  String get formattedTimestamp {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// 获取状态描述
  String get description {
    String statusText = status.toString().split('.').last;
    if (message != null) {
      return '$statusText: $message';
    }
    return statusText;
  }

  @override
  String toString() {
    return 'AuthStateHistory(status: $status, message: $message, timestamp: $timestamp)';
  }
}

/// 认证状态扩展
extension AuthStatusExtension on AuthStatus {
  /// 检查是否为终态（成功或失败）
  bool get isFinal => this == AuthStatus.authenticated || this == AuthStatus.error;

  /// 检查是否为进行中状态
  bool get isInProgress => this == AuthStatus.loading;

  /// 检查是否需要用户操作
  bool get needsUserAction => this == AuthStatus.unauthenticated || this == AuthStatus.error;

  /// 获取状态颜色（用于UI显示）
  String get colorHex {
    switch (this) {
      case AuthStatus.initial:
        return '#9E9E9E'; // 灰色
      case AuthStatus.loading:
        return '#2196F3'; // 蓝色
      case AuthStatus.authenticated:
        return '#4CAF50'; // 绿色
      case AuthStatus.unauthenticated:
        return '#FF9800'; // 橙色
      case AuthStatus.error:
        return '#F44336'; // 红色
    }
  }

  /// 获取状态图标
  String get iconName {
    switch (this) {
      case AuthStatus.initial:
        return 'more_horiz';
      case AuthStatus.loading:
        return 'refresh';
      case AuthStatus.authenticated:
        return 'check_circle';
      case AuthStatus.unauthenticated:
        return 'account_circle';
      case AuthStatus.error:
        return 'error';
    }
  }
}