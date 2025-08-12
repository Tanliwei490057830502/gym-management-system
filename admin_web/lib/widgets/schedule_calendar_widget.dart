// lib/widgets/schedule_calendar_widget.dart
// 用途：可复用的行程日历组件（精简版，专注月行程）

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/schedule_service.dart';

class ScheduleCalendarWidget extends StatefulWidget {
  final DateTime initialMonth;
  final Function(DateTime)? onDateSelected;
  final Function(DateTime)? onMonthChanged;
  final bool showHeader;
  final bool showLegend;
  final bool enableNavigation;
  final MaterialColor primaryColor;

  static final DateTime _defaultMonth = DateTime(2025, 3);

  ScheduleCalendarWidget({
    Key? key,
    DateTime? initialMonth,
    this.onDateSelected,
    this.onMonthChanged,
    this.showHeader = true,
    this.showLegend = true,
    this.enableNavigation = true,
    this.primaryColor = Colors.purple,
  })  : initialMonth = initialMonth ?? _defaultMonth,
        super(key: key);

  @override
  State<ScheduleCalendarWidget> createState() => _ScheduleCalendarWidgetState();
}

class _ScheduleCalendarWidgetState extends State<ScheduleCalendarWidget> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _currentMonth = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[200]!,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (widget.showHeader) _buildCalendarHeader(),
          _buildWeekdaysHeader(),
          Expanded(child: _buildCalendarGrid()),
          if (widget.showLegend) _buildCalendarLegend(),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.primaryColor[600]!, widget.primaryColor[400]!],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (widget.enableNavigation)
            IconButton(
              onPressed: _previousMonth,
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                minimumSize: const Size(36, 36),
              ),
            )
          else
            const SizedBox(width: 36),

          Text(
            _formatMonthYear(_currentMonth),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          if (widget.enableNavigation)
            IconButton(
              onPressed: _nextMonth,
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                minimumSize: const Size(36, 36),
              ),
            )
          else
            const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildWeekdaysHeader() {
    final weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: weekdays.map((day) => Expanded(
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 12,
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    return StreamBuilder<List<Appointment>>(
      stream: ScheduleService.getMonthlyAppointments(_currentMonth.year, _currentMonth.month),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final appointments = snapshot.data ?? [];
        final monthlyStats = ScheduleService.getMonthlyStats(appointments);

        return _buildCalendarDays(monthlyStats);
      },
    );
  }

  Widget _buildCalendarDays(MonthlyScheduleStats monthlyStats) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    final prevMonthDays = firstDayWeekday;
    final totalCells = ((daysInMonth + prevMonthDays + 6) ~/ 7) * 7;

    return Container(
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.0,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: totalCells,
        itemBuilder: (context, index) {
          DateTime date;
          bool isCurrentMonth;

          if (index < prevMonthDays) {
            // 前一个月的日期
            final prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
            final lastDayPrevMonth = DateTime(_currentMonth.year, _currentMonth.month, 0).day;
            final day = lastDayPrevMonth - (prevMonthDays - index - 1);
            date = DateTime(prevMonth.year, prevMonth.month, day);
            isCurrentMonth = false;
          } else if (index < prevMonthDays + daysInMonth) {
            // 当前月的日期
            final day = index - prevMonthDays + 1;
            date = DateTime(_currentMonth.year, _currentMonth.month, day);
            isCurrentMonth = true;
          } else {
            // 下一个月的日期
            final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
            final day = index - prevMonthDays - daysInMonth + 1;
            date = DateTime(nextMonth.year, nextMonth.month, day);
            isCurrentMonth = false;
          }

          return _buildCalendarDay(date, isCurrentMonth: isCurrentMonth, monthlyStats: monthlyStats);
        },
      ),
    );
  }

  Widget _buildCalendarDay(DateTime date, {required bool isCurrentMonth, required MonthlyScheduleStats monthlyStats}) {
    final dayStats = monthlyStats.getStatsForDate(date);
    final isToday = _isToday(date);
    final isSelected = _selectedDate != null && _isSameDay(date, _selectedDate!);
    final hasAppointments = dayStats?.hasAppointments ?? false;

    // 确定颜色方案
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    if (isSelected) {
      backgroundColor = widget.primaryColor[600]!;
      textColor = Colors.white;
      borderColor = widget.primaryColor[600]!;
    } else if (isToday) {
      backgroundColor = Colors.blue[100]!;
      textColor = Colors.blue[700]!;
      borderColor = Colors.blue[300]!;
    } else if (!isCurrentMonth) {
      backgroundColor = Colors.transparent;
      textColor = Colors.grey[400]!;
      borderColor = Colors.transparent;
    } else if (hasAppointments) {
      backgroundColor = _getAppointmentBackgroundColor(dayStats!);
      textColor = Colors.white;
      borderColor = backgroundColor;
    } else {
      backgroundColor = Colors.white;
      textColor = Colors.black87;
      borderColor = Colors.grey[200]!;
    }

    return GestureDetector(
      onTap: isCurrentMonth ? () => _selectDate(date) : null,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: isSelected ? [
            BoxShadow(
              color: widget.primaryColor[200]!,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date.day.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                color: textColor,
              ),
            ),
            if (hasAppointments) ...[
              const SizedBox(height: 2),
              Text(
                dayStats!.total.toString(),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: textColor.withValues(alpha: 0.8),
                ),
              ),
              if (dayStats.hasPendingAppointments)
                Container(
                  width: 3,
                  height: 3,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange[700],
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Legend',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem('Available', Colors.white, Colors.black87, true),
              _buildLegendItem('Pending', Colors.orange, Colors.white),
              _buildLegendItem('Confirmed', Colors.green, Colors.white),
              _buildLegendItem('Completed', Colors.purple, Colors.white),
              _buildLegendItem('Mixed', Colors.blue, Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, Color textColor, [bool hasBorder = false]) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: hasBorder ? Border.all(color: Colors.grey[300]!) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getAppointmentBackgroundColor(DayScheduleStats dayStats) {
    if (dayStats.total == 0) return Colors.white;

    // 如果只有一种状态，使用对应颜色
    final nonZeroStatuses = <String, int>{};
    if (dayStats.pending > 0) nonZeroStatuses['pending'] = dayStats.pending;
    if (dayStats.confirmed > 0) nonZeroStatuses['confirmed'] = dayStats.confirmed;
    if (dayStats.completed > 0) nonZeroStatuses['completed'] = dayStats.completed;
    if (dayStats.cancelled > 0) nonZeroStatuses['cancelled'] = dayStats.cancelled;

    if (nonZeroStatuses.length == 1) {
      final status = nonZeroStatuses.keys.first;
      switch (status) {
        case 'pending':
          return Colors.orange;
        case 'confirmed':
          return Colors.green;
        case 'completed':
          return Colors.purple;
        case 'cancelled':
          return Colors.red;
      }
    }

    // 多种状态混合，返回蓝色
    return Colors.blue;
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatMonthYear(DateTime date) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selectedDate = null;
    });
    widget.onMonthChanged?.call(_currentMonth);
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _selectedDate = null;
    });
    widget.onMonthChanged?.call(_currentMonth);
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    widget.onDateSelected?.call(date);
  }
}

/// 简化版日历组件，用于仪表盘等紧凑空间
class CompactScheduleCalendar extends StatelessWidget {
  final DateTime month;
  final Function(DateTime)? onDateSelected;
  final double size;

  const CompactScheduleCalendar({
    super.key,
    required this.month,
    this.onDateSelected,
    this.size = 300,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ScheduleCalendarWidget(
        initialMonth: month,
        onDateSelected: onDateSelected,
        showHeader: true,
        showLegend: false,
        enableNavigation: true,
        primaryColor: Colors.purple,
      ),
    );
  }
}