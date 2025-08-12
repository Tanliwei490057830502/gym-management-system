// screens/coach_schedule_page.dart (Updated with navigation)
import 'package:flutter/material.dart';
import 'coach_reservation_status_screen.dart';
import 'coach_today_schedule_screen.dart';
import 'coach_appointment_schedule_screen.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Today Schedule - 导航到今日行程界面
          _buildScheduleSection(
            title: 'Today schedule',
            icon: Icons.today,
            backgroundColor: Colors.orange,
            gradientColors: [Colors.grey[800]!, Colors.black],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CoachTodayScheduleScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Appointment Schedule - 导航到月历预约界面
          _buildScheduleSection(
            title: 'appointment schedule',
            icon: Icons.event_note,
            backgroundColor: Colors.orange,
            gradientColors: [Colors.teal[800]!, Colors.teal[600]!],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CoachAppointmentScheduleScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Reservation Status - 导航到预约管理界面
          _buildScheduleSection(
            title: 'Reservation status',
            icon: Icons.assignment_turned_in,
            backgroundColor: Colors.orange,
            gradientColors: [Colors.indigo[800]!, Colors.indigo[600]!],
            onTap: () {
              // 导航到预约状态管理界面
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CoachReservationStatusScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection({
    required String title,
    required IconData icon,
    required Color backgroundColor,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // 背景渐变
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradientColors,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40), // 为标题栏留出空间
                          Icon(
                            icon,
                            size: 80,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _getSubtitle(title),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 添加一些装饰性图标（类似原版的星星）
                    if (title == 'Reservation status') ...[
                      const Positioned(
                        top: 60,
                        left: 16,
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 24,
                        ),
                      ),
                      const Positioned(
                        bottom: 16,
                        right: 16,
                        child: Icon(
                          Icons.verified,
                          color: Colors.lightBlue,
                          size: 24,
                        ),
                      ),
                    ],
                    if (title == 'Today schedule') ...[
                      const Positioned(
                        top: 60,
                        left: 16,
                        child: Icon(
                          Icons.schedule,
                          color: Colors.yellow,
                          size: 20,
                        ),
                      ),
                      const Positioned(
                        bottom: 16,
                        right: 16,
                        child: Icon(
                          Icons.access_time,
                          color: Colors.orange,
                          size: 20,
                        ),
                      ),
                    ],
                    if (title == 'appointment schedule') ...[
                      const Positioned(
                        top: 60,
                        left: 16,
                        child: Icon(
                          Icons.calendar_month,
                          color: Colors.lightBlue,
                          size: 20,
                        ),
                      ),
                      const Positioned(
                        bottom: 16,
                        right: 16,
                        child: Icon(
                          Icons.event_available,
                          color: Colors.cyan,
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 橙色标题栏
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  color: backgroundColor,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // 点击效果
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    child: Container(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSubtitle(String title) {
    switch (title) {
      case 'Today schedule':
        return 'View Today\'s Student Appointments';
      case 'appointment schedule':
        return 'Monthly Calendar View';
      case 'Reservation status':
        return 'Manage Student Bookings';
      default:
        return '';
    }
  }
}