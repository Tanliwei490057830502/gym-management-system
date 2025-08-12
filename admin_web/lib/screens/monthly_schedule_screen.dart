// lib/screens/monthly_schedule_screen.dart
// 用途：月行程日历管理页面 - 支持双重批准系统

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/schedule_service.dart';
import '../utils/utils.dart';

class MonthlyScheduleScreen extends StatefulWidget {
  const MonthlyScheduleScreen({Key? key}) : super(key: key);

  @override
  State<MonthlyScheduleScreen> createState() => _MonthlyScheduleScreenState();
}

class _MonthlyScheduleScreenState extends State<MonthlyScheduleScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Row(
              children: [
                // 左侧：日历视图
                Expanded(
                  flex: 3,
                  child: _buildCalendarView(),
                ),
                // 右侧：选中日期的详细信息
                Container(
                  width: 400,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 5,
                        offset: const Offset(-2, 0),
                      ),
                    ],
                  ),
                  child: _buildSelectedDateDetails(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade600, Colors.purple.shade400],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade200,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_month,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Monthly Reservation',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Text(
                'Dual Approval System',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              Text(
                _formatMonthYear(_currentMonth),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const Spacer(),
          // 月份导航
          Row(
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
              ),
              const SizedBox(width: 20),
              Text(
                _formatMonthYear(_currentMonth),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 20),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    return Container(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          _buildCalendarHeader(),
          const SizedBox(height: 20),
          Expanded(
            child: _buildCalendarGrid(),
          ),
          const SizedBox(height: 20),
          _buildCalendarLegend(),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    final weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: weekdays.map((day) => Expanded(
          child: Center(
            child: Text(
              day,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
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

    // 计算需要显示的前一个月的天数
    final prevMonthDays = firstDayWeekday;
    final totalCells = ((daysInMonth + prevMonthDays + 6) ~/ 7) * 7;

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        if (index < prevMonthDays) {
          // 前一个月的日期
          final prevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
          final lastDayPrevMonth = DateTime(_currentMonth.year, _currentMonth.month, 0).day;
          final day = lastDayPrevMonth - (prevMonthDays - index - 1);
          final date = DateTime(prevMonth.year, prevMonth.month, day);

          return _buildCalendarDay(date, isCurrentMonth: false, monthlyStats: monthlyStats);
        } else if (index < prevMonthDays + daysInMonth) {
          // 当前月的日期
          final day = index - prevMonthDays + 1;
          final date = DateTime(_currentMonth.year, _currentMonth.month, day);

          return _buildCalendarDay(date, isCurrentMonth: true, monthlyStats: monthlyStats);
        } else {
          // 下一个月的日期
          final nextMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
          final day = index - prevMonthDays - daysInMonth + 1;
          final date = DateTime(nextMonth.year, nextMonth.month, day);

          return _buildCalendarDay(date, isCurrentMonth: false, monthlyStats: monthlyStats);
        }
      },
    );
  }

  Widget _buildCalendarDay(DateTime date, {required bool isCurrentMonth, required MonthlyScheduleStats monthlyStats}) {
    final dayStats = monthlyStats.getStatsForDate(date);
    final isToday = _isToday(date);
    final isSelected = _selectedDate != null && _isSameDay(date, _selectedDate!);
    final hasAppointments = dayStats?.hasAppointments ?? false;

    Color backgroundColor;
    Color textColor;

    if (isSelected) {
      backgroundColor = Colors.purple.shade600;
      textColor = Colors.white;
    } else if (isToday) {
      backgroundColor = Colors.blue.shade100;
      textColor = Colors.blue.shade700;
    } else if (!isCurrentMonth) {
      backgroundColor = Colors.transparent;
      textColor = Colors.grey.shade400;
    } else if (hasAppointments) {
      backgroundColor = _getAppointmentBackgroundColor(dayStats!);
      textColor = Colors.white;
    } else {
      backgroundColor = Colors.white;
      textColor = Colors.black87;
    }

    return GestureDetector(
      onTap: isCurrentMonth ? () => _selectDate(date) : null,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.purple.shade600 : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Colors.purple.shade200,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date.day.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                color: textColor,
              ),
            ),
            if (hasAppointments) ...[
              const SizedBox(height: 2),
              Text(
                dayStats!.total.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textColor.withOpacity(0.8),
                ),
              ),
              // 添加批准状态指示器
              _buildApprovalIndicators(dayStats, textColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalIndicators(DayScheduleStats dayStats, Color textColor) {
    List<Widget> indicators = [];

    if (dayStats.hasWaitingCoachApproval) {
      indicators.add(Container(
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          color: Colors.orange,
          shape: BoxShape.circle,
        ),
      ));
    }

    if (dayStats.hasWaitingAdminApproval) {
      indicators.add(Container(
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ));
    }

    if (dayStats.hasPartiallyApproved) {
      indicators.add(Container(
        width: 4,
        height: 4,
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
      ));
    }

    if (indicators.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: indicators
            .expand((widget) => [widget, const SizedBox(width: 2)])
            .toList()
          ..removeLast(), // 移除最后一个SizedBox
      ),
    );
  }

  Widget _buildCalendarLegend() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Legend',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // 基本状态
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('No Appointments', Colors.white, Colors.black87),
              _buildLegendItem('Pending', Colors.orange, Colors.white),
              _buildLegendItem('Confirmed', Colors.green, Colors.white),
              _buildLegendItem('Completed', Colors.purple, Colors.white),
              _buildLegendItem('Cancelled', Colors.red, Colors.white),
            ],
          ),
          const SizedBox(height: 8),
          // 批准状态指示器
          const Text(
            'Approval Indicators',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDotLegendItem('Waiting Coach', Colors.orange),
              _buildDotLegendItem('Waiting Admin', Colors.red),
              _buildDotLegendItem('Partially Approved', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: color == Colors.white ? Border.all(color: Colors.grey.shade300) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildDotLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDateDetails() {
    if (_selectedDate == null) {
      return _buildDateSelectionPrompt();
    }

    return StreamBuilder<List<Appointment>>(
      stream: ScheduleService.getMonthlyAppointments(_selectedDate!.year, _selectedDate!.month),
      builder: (context, snapshot) {
        final allAppointments = snapshot.data ?? [];
        final dayAppointments = allAppointments.where((appointment) =>
            _isSameDay(appointment.date, _selectedDate!)).toList();

        return Column(
          children: [
            _buildSelectedDateHeader(),
            Expanded(
              child: dayAppointments.isEmpty
                  ? _buildNoAppointmentsForDate()
                  : _buildDateAppointmentsList(dayAppointments),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateSelectionPrompt() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Select a Date',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Click on any date to view appointments',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDateHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.purple.shade100),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: Colors.purple.shade600),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppDateUtils.formatDate(_selectedDate!),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _formatWeekday(_selectedDate!),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoAppointmentsForDate() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.free_breakfast,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Appointments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No appointments scheduled for this date',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateAppointmentsList(List<Appointment> appointments) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        return _buildAppointmentListItem(appointments[index]);
      },
    );
  }

  Widget _buildAppointmentListItem(Appointment appointment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: appointment.statusColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                appointment.timeSlot,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: appointment.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      appointment.statusIcon,
                      color: appointment.statusColor,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      appointment.overallStatus.toUpperCase(),
                      style: TextStyle(
                        color: appointment.statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            appointment.userName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Coach: ${appointment.coachName}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            'Gym: ${appointment.gymName}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          // 添加批准状态显示
          _buildAppointmentApprovalStatus(appointment),
        ],
      ),
    );
  }

  Widget _buildAppointmentApprovalStatus(Appointment appointment) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          _buildApprovalStatusBadge('Coach', appointment.coachApproval),
          const SizedBox(width: 8),
          _buildApprovalStatusBadge('Admin', appointment.adminApproval),
          const Spacer(),
          Text(
            appointment.detailedStatusText,
            style: TextStyle(
              fontSize: 10,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalStatusBadge(String label, String status) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.close;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 10, color: statusColor),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getAppointmentBackgroundColor(DayScheduleStats dayStats) {
    final detailedStatus = dayStats.detailedStatus;
    switch (detailedStatus) {
      case 'pending':
      case 'waiting':
        return Colors.orange;
      case 'partial':
        return Colors.blue;
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      case 'none':
        return Colors.grey;
      default:
        return Colors.blue; // Mixed 状态或其他未知状态
    }
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

  String _formatWeekday(DateTime date) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return weekdays[date.weekday - 1];
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selectedDate = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _selectedDate = null;
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }
}