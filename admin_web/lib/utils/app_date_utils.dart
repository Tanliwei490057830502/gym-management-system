// lib/utils/app_date_utils.dart
// 用途：日期时间格式化工具类（扩展版）

class AppDateUtils {
  /// 格式化日期为字符串 (DD/MM/YYYY)
  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// 格式化日期为详细字符串 (DD MMMM YYYY)
  static String formatDateDetailed(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// 格式化时间为字符串 (HH:MM)
  static String formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化日期时间为完整字符串 (DD/MM/YYYY HH:MM)
  static String formatDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} ${formatTime(dateTime)}';
  }

  /// 获取月份名称
  static String getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    if (month < 1 || month > 12) return 'Invalid';
    return months[month - 1];
  }

  /// 获取月份简称
  static String getMonthShort(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    if (month < 1 || month > 12) return 'Invalid';
    return months[month - 1];
  }

  /// 获取星期名称
  static String getWeekdayName(int weekday) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];

    if (weekday < 1 || weekday > 7) return 'Invalid';
    return weekdays[weekday - 1];
  }

  /// 获取星期简称
  static String getWeekdayShort(int weekday) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    if (weekday < 1 || weekday > 7) return 'Invalid';
    return weekdays[weekday - 1];
  }

  /// 检查是否是今天
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// 检查是否是昨天
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// 检查是否是明天
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  /// 检查是否是本周
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
        date.isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  /// 检查是否是本月
  static bool isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  /// 获取月份的天数
  static int getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  /// 获取相对时间描述（新增 - 用于通知显示）
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes minute${minutes != 1 ? 's' : ''} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours hour${hours != 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days day${days != 1 ? 's' : ''} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks != 1 ? 's' : ''} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months != 1 ? 's' : ''} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years != 1 ? 's' : ''} ago';
    }
  }

  /// 格式化为相对日期（新增 - 用于通知显示）
  static String formatRelativeDate(DateTime dateTime) {
    if (isToday(dateTime)) {
      return 'Today ${formatTime(dateTime)}';
    } else if (isYesterday(dateTime)) {
      return 'Yesterday ${formatTime(dateTime)}';
    } else if (isTomorrow(dateTime)) {
      return 'Tomorrow ${formatTime(dateTime)}';
    } else if (isThisWeek(dateTime)) {
      return '${getWeekdayName(dateTime.weekday)} ${formatTime(dateTime)}';
    } else {
      return formatDateTime(dateTime);
    }
  }

  /// 获取友好的时间显示（新增 - 智能选择格式）
  static String formatFriendlyTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return formatTimeAgo(dateTime);
    } else if (isToday(dateTime)) {
      return 'Today ${formatTime(dateTime)}';
    } else if (isYesterday(dateTime)) {
      return 'Yesterday ${formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${getWeekdayShort(dateTime.weekday)} ${formatTime(dateTime)}';
    } else {
      return formatDate(dateTime);
    }
  }

  /// 格式化通知时间戳（新增 - 专门用于通知组件）
  static String formatNotificationTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 30) {
      return 'now';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return formatDate(dateTime);
    }
  }

  /// 检查日期是否在指定范围内
  static bool isDateInRange(DateTime date, DateTime start, DateTime end) {
    return date.isAfter(start.subtract(const Duration(days: 1))) &&
        date.isBefore(end.add(const Duration(days: 1)));
  }

  /// 获取日期范围的描述
  static String formatDateRange(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      return formatDate(start);
    } else if (start.year == end.year && start.month == end.month) {
      return '${start.day}-${end.day} ${getMonthName(start.month)} ${start.year}';
    } else if (start.year == end.year) {
      return '${start.day} ${getMonthShort(start.month)} - ${end.day} ${getMonthShort(end.month)} ${start.year}';
    } else {
      return '${formatDate(start)} - ${formatDate(end)}';
    }
  }

  /// 获取下一个工作日
  static DateTime getNextWorkday(DateTime date) {
    DateTime nextDay = date.add(const Duration(days: 1));

    // 跳过周末
    while (nextDay.weekday > 5) {
      nextDay = nextDay.add(const Duration(days: 1));
    }

    return nextDay;
  }

  /// 获取上一个工作日
  static DateTime getPreviousWorkday(DateTime date) {
    DateTime previousDay = date.subtract(const Duration(days: 1));

    // 跳过周末
    while (previousDay.weekday > 5) {
      previousDay = previousDay.subtract(const Duration(days: 1));
    }

    return previousDay;
  }

  /// 检查是否是工作日
  static bool isWorkday(DateTime date) {
    return date.weekday <= 5; // Monday to Friday
  }

  /// 检查是否是周末
  static bool isWeekend(DateTime date) {
    return date.weekday > 5; // Saturday and Sunday
  }
}