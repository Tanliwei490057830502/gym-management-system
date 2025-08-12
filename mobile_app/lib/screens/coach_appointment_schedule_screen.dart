// screens/coach_appointment_schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CoachAppointmentScheduleScreen extends StatefulWidget {
  const CoachAppointmentScheduleScreen({super.key});

  @override
  State<CoachAppointmentScheduleScreen> createState() => _CoachAppointmentScheduleScreenState();
}

class _CoachAppointmentScheduleScreenState extends State<CoachAppointmentScheduleScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _selectedMonth = DateTime.now();
  Map<String, List<Map<String, dynamic>>> _monthlyAppointments = {};

  @override
  void initState() {
    super.initState();
    _loadMonthlyAppointments();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to continue')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'LTC',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Header section with gradient background
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue[800]!,
                  Colors.blue[600]!,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Appointment SCHEDULE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _getMonthYearString(_selectedMonth),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Month navigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _previousMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  _getMonthYearString(_selectedMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),

          // Calendar
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildCalendar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Column(
      children: [
        // Week days header
        _buildWeekDaysHeader(),
        const SizedBox(height: 8),
        // Calendar grid
        Expanded(
          child: _buildCalendarGrid(),
        ),
      ],
    );
  }

  Widget _buildWeekDaysHeader() {
    const weekDays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    return Row(
      children: weekDays.map((day) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            day,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday

    final totalDays = lastDayOfMonth.day;
    final totalCells = ((totalDays + firstDayWeekday - 1) / 7).ceil() * 7;

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayNumber = index - firstDayWeekday + 1;

        if (dayNumber < 1 || dayNumber > totalDays) {
          return Container(); // Empty cell
        }

        final date = DateTime(_selectedMonth.year, _selectedMonth.month, dayNumber);
        final dateKey = _formatDateKey(date);
        final appointments = _monthlyAppointments[dateKey] ?? [];

        return _buildCalendarDay(dayNumber, date, appointments);
      },
    );
  }

  Widget _buildCalendarDay(int day, DateTime date, List<Map<String, dynamic>> appointments) {
    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final hasAppointments = appointments.isNotEmpty;
    final isToday = _isToday(date);

    Color backgroundColor;
    Color textColor = Colors.black;
    Widget? icon;

    if (isToday) {
      backgroundColor = Colors.orange;
      textColor = Colors.white;
    } else if (hasAppointments) {
      backgroundColor = Colors.red[400]!;
      textColor = Colors.white;
      icon = const Icon(Icons.fitness_center, color: Colors.white, size: 16);
    } else if (isWeekend) {
      backgroundColor = Colors.yellow[200]!;
    } else {
      backgroundColor = Colors.green[200]!;
    }

    return GestureDetector(
      onTap: () => _showDayDetails(date, appointments),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              day.toString(),
              style: TextStyle(
                color: textColor,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(height: 2),
              icon,
            ],
            if (hasAppointments && !isToday) ...[
              const SizedBox(height: 2),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDayDetails(DateTime date, List<Map<String, dynamic>> appointments) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appointments - ${_formatDate(date)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (appointments.isEmpty)
              const Text('No appointments on this day')
            else
              ...appointments.map((appointment) => ListTile(
                leading: const Icon(Icons.person),
                title: Text(appointment['studentName'] ?? 'Unknown'),
                subtitle: Text(appointment['timeSlot'] ?? ''),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(appointment['status']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    appointment['status'] ?? 'pending',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  void _loadMonthlyAppointments() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    try {
      final querySnapshot = await _firestore
          .collection('appointments')
          .where('coachId', isEqualTo: currentUser.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();

      final Map<String, List<Map<String, dynamic>>> appointmentsByDate = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final dateKey = _formatDateKey(date);

        // Get student name
        final studentDoc = await _firestore.collection('users').doc(data['userId']).get();
        final studentName = studentDoc.data()?['username'] ?? 'Unknown';

        final appointmentData = {
          ...data,
          'studentName': studentName,
        };

        if (appointmentsByDate[dateKey] == null) {
          appointmentsByDate[dateKey] = [];
        }
        appointmentsByDate[dateKey]!.add(appointmentData);
      }

      setState(() {
        _monthlyAppointments = appointmentsByDate;
      });
    } catch (e) {
      print('Error loading monthly appointments: $e');
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadMonthlyAppointments();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
    _loadMonthlyAppointments();
  }

  String _getMonthYearString(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }
}