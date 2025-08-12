// gym_app_system/lib/screens/appointment_schedule_screen.dart
// 用途：用户预约教练课程界面 - 支持双重批准系统
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/coach_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentScheduleScreen extends StatefulWidget {
  final DateTime? preselectedDate;
  final String? preselectedCoachId;
  final String? preselectedGymId;

  const AppointmentScheduleScreen({
    super.key,
    this.preselectedDate,
    this.preselectedCoachId,
    this.preselectedGymId,
  });

  @override
  State<AppointmentScheduleScreen> createState() => _AppointmentScheduleScreenState();
}

class _AppointmentScheduleScreenState extends State<AppointmentScheduleScreen> {
  late DateTime selectedDate;
  String? selectedTimeSlot;
  String? selectedCoachId;
  String? selectedGymId;
  int _selectedIndex = 1;

  // 从Firebase获取的数据
  List<Map<String, dynamic>> coaches = [];
  List<Map<String, dynamic>> availableGyms = [];
  List<String> bookedTimeSlots = [];

  final List<String> allTimeSlots = [
    '8:00 AM - 10:00 AM',
    '10:00 AM - 12:00 PM',
    '1:00 PM - 3:00 PM',
    '3:00 PM - 5:00 PM',
    '5:00 PM - 7:00 PM',
  ];

  bool _isLoading = false;
  bool _isBooking = false;
  bool _loadingGyms = false;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.preselectedDate ?? DateTime.now();
    selectedCoachId = widget.preselectedCoachId;
    selectedGymId = widget.preselectedGymId;
    _loadCoaches();
  }

  // 加载所有教练
  Future<void> _loadCoaches() async {
    setState(() => _isLoading = true);

    try {
      final loadedCoaches = await CoachService.getCoaches();
      setState(() {
        coaches = loadedCoaches;
        // 如果没有预选教练且有可用教练，选择第一个
        if (selectedCoachId == null && coaches.isNotEmpty) {
          selectedCoachId = coaches.first['id'];
        }
        // 如果有预选教练，验证它是否在列表中
        else if (selectedCoachId != null && !coaches.any((c) => c['id'] == selectedCoachId)) {
          selectedCoachId = coaches.isNotEmpty ? coaches.first['id'] : null;
        }
      });

      // 加载选定教练的健身房
      if (selectedCoachId != null) {
        await _loadCoachGyms();
      }
    } catch (e) {
      print('Error loading coaches: $e');
      _showErrorDialog('Failed to load coaches: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 加载选定教练的分配健身房
  Future<void> _loadCoachGyms() async {
    if (selectedCoachId == null) return;

    setState(() => _loadingGyms = true);

    try {
      final gyms = await CoachService.getCoachAssignedGyms(selectedCoachId!);
      setState(() {
        availableGyms = gyms;

        // 如果当前选择的健身房不在可用列表中，重置选择
        if (selectedGymId != null && !availableGyms.any((gym) => gym['id'] == selectedGymId)) {
          selectedGymId = null;
          selectedTimeSlot = null; // 重置时间选择
        }

        // 如果没有选择健身房且有可用健身房，选择第一个
        if (selectedGymId == null && availableGyms.isNotEmpty) {
          selectedGymId = availableGyms.first['id'];
        }
      });

      // 加载已预订的时间段
      await _loadBookedTimeSlots();
    } catch (e) {
      print('Error loading coach gyms: $e');
      _showErrorDialog('Failed to load available gyms for this coach');
    } finally {
      setState(() => _loadingGyms = false);
    }
  }

  Future<void> _loadBookedTimeSlots() async {
    if (selectedCoachId == null || selectedGymId == null) return;

    try {
      final slots = await CoachService.getBookedTimeSlots(
        date: selectedDate,
        coachId: selectedCoachId!,
        gymId: selectedGymId!,
      );

      setState(() {
        bookedTimeSlots = slots;
        // 如果当前选择的时间段已被预订，重置选择
        if (selectedTimeSlot != null && bookedTimeSlots.contains(selectedTimeSlot)) {
          selectedTimeSlot = null;
        }
      });
    } catch (e) {
      print('Error loading booked time slots: $e');
    }
  }

  List<String> get availableSlots =>
      allTimeSlots.where((slot) => !bookedTimeSlots.contains(slot)).toList();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pushReplacementNamed(context, '/main', arguments: {'initialIndex': index});
  }

  Future<void> _bookAppointment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || selectedCoachId == null || selectedGymId == null || selectedTimeSlot == null) {
      _showErrorDialog('Please select all required fields');
      return;
    }

    setState(() => _isBooking = true);

    try {
      final selectedCoach = coaches.firstWhere((c) => c['id'] == selectedCoachId);
      final selectedGym = availableGyms.firstWhere((g) => g['id'] == selectedGymId);

      // 使用新的双重批准系统创建预约
      final success = await _createDualApprovalAppointment(
        coachId: selectedCoachId!,
        gymId: selectedGymId!,
        date: selectedDate,
        timeSlot: selectedTimeSlot!,
        userId: user.uid,
        coachName: selectedCoach['name'],
        gymName: selectedGym['name'],
      );

      if (success && mounted) {
        // 创建预约数据用于显示
        final appointmentData = {
          'userId': user.uid,
          'userName': user.displayName ?? user.email?.split('@')[0] ?? 'User',
          'userEmail': user.email,
          'coachId': selectedCoachId,
          'coachName': selectedCoach['name'],
          'gymId': selectedGymId,
          'gymName': selectedGym['name'],
          'date': Timestamp.fromDate(selectedDate),
          'timeSlot': selectedTimeSlot,
          'coachApproval': 'pending',
          'adminApproval': 'pending',
          'overallStatus': 'pending',
          'createdAt': Timestamp.now(),
        };

        // 导航到成功页面
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppointmentSuccessScreen(
              appointmentData: appointmentData,
            ),
          ),
        );
      } else if (mounted) {
        _showErrorDialog('Failed to book appointment. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to book appointment: $e');
      }
    } finally {
      setState(() => _isBooking = false);
    }
  }

  Future<bool> _createDualApprovalAppointment({
    required String coachId,
    required String gymId,
    required DateTime date,
    required String timeSlot,
    required String userId,
    required String coachName,
    required String gymName,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // 确保健身房名称不为空，如果为空则从数据库重新获取
      String finalGymName = gymName;
      if (finalGymName.isEmpty || finalGymName == 'Unknown Gym') {
        try {
          final gymDoc = await FirebaseFirestore.instance
              .collection('gyms')
              .doc(gymId)
              .get();

          if (gymDoc.exists) {
            final gymData = gymDoc.data() as Map<String, dynamic>;
            finalGymName = gymData['name'] ?? 'Unknown Gym';
          }
        } catch (e) {
          print('Error fetching gym name: $e');
          finalGymName = 'Unknown Gym';
        }
      }

      // 同样确保教练名称正确
      String finalCoachName = coachName;
      if (finalCoachName.isEmpty || finalCoachName == 'Unknown Coach') {
        try {
          final coachDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(coachId)
              .get();

          if (coachDoc.exists) {
            final coachData = coachDoc.data() as Map<String, dynamic>;
            finalCoachName = coachData['name'] ?? 'Unknown Coach';
          }
        } catch (e) {
          print('Error fetching coach name: $e');
          finalCoachName = 'Unknown Coach';
        }
      }

      final appointmentData = {
        'userId': userId,
        'userName': user.displayName ?? user.email?.split('@')[0] ?? 'User',
        'userEmail': user.email ?? '',
        'coachId': coachId,
        'coachName': finalCoachName,
        'gymId': gymId,
        'gymName': finalGymName,
        'date': Timestamp.fromDate(date),
        'timeSlot': timeSlot,
        'coachApproval': 'pending',      // 教练批准状态
        'adminApproval': 'pending',      // 管理员批准状态
        'overallStatus': 'pending',      // 总体状态
        'notes': null,
        'coachRejectReason': null,
        'adminRejectReason': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'coachApprovedAt': null,
        'adminApprovedAt': null,
      };

      await FirebaseFirestore.instance
          .collection('appointments')
          .add(appointmentData);

      return true;
    } catch (e) {
      print('Error creating dual approval appointment: $e');
      return false;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min, // 关键：使用最小尺寸
            children: [
              // 双重批准系统提示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dual Approval System',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          Text(
                            'Your appointment needs approval from both the coach and admin.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Coach Selection
              DropdownButtonFormField<String>(
                value: selectedCoachId,
                items: coaches
                    .map((c) => DropdownMenuItem<String>(
                  value: c['id'] as String,
                  child: Text(
                    c['name'] ?? 'Unknown Coach',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
                    .toList(),
                onChanged: (val) async {
                  setState(() {
                    selectedCoachId = val;
                    selectedGymId = null;
                    selectedTimeSlot = null;
                    availableGyms = [];
                  });
                  if (val != null) {
                    await _loadCoachGyms();
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Select Coach',
                  labelStyle: TextStyle(color: Colors.black),
                  prefixIcon: Icon(Icons.person, color: Colors.deepPurple),
                ),
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 16),

              // Gym Selection
              if (_loadingGyms)
                const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (availableGyms.isEmpty && selectedCoachId != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Text(
                    'This coach is not assigned to any gym yet.',
                    style: TextStyle(color: Colors.orange),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: selectedGymId,
                  items: availableGyms
                      .map((g) => DropdownMenuItem<String>(
                    value: g['id'] as String,
                    child: Text(
                      g['name'] ?? 'Unknown Gym',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
                      .toList(),
                  onChanged: (val) async {
                    setState(() {
                      selectedGymId = val;
                      selectedTimeSlot = null;
                    });
                    await _loadBookedTimeSlots();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Select Gym',
                    labelStyle: TextStyle(color: Colors.black),
                    prefixIcon: Icon(Icons.fitness_center, color: Colors.deepPurple),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
              const SizedBox(height: 16),

              // Date Selection
              ElevatedButton(
                onPressed: _selectDate,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.black,
                  backgroundColor: Colors.grey[200],
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Text('Select Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Time Slot Selection
              if (availableSlots.isEmpty && selectedCoachId != null && selectedGymId != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Text(
                    'No available time slots for this date.',
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: selectedTimeSlot,
                  items: availableSlots
                      .map((s) => DropdownMenuItem<String>(
                    value: s,
                    child: Text(s),
                  ))
                      .toList(),
                  onChanged: (val) => setState(() => selectedTimeSlot = val),
                  decoration: const InputDecoration(
                    labelText: 'Select Time Slot',
                    labelStyle: TextStyle(color: Colors.black),
                    prefixIcon: Icon(Icons.access_time, color: Colors.deepPurple),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),

              // 添加更多间距，确保按钮不被底部导航栏遮挡
              const SizedBox(height: 24),

              // Book Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isBooking ||
                      selectedCoachId == null ||
                      selectedGymId == null ||
                      selectedTimeSlot == null)
                      ? null
                      : _bookAppointment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: _isBooking
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Submit Appointment Request',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // 底部额外间距，确保内容完全可见
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedTimeSlot = null; // 重置时间选择
      });
      await _loadBookedTimeSlots();
    }
  }
}

// Appointment Success Screen
class AppointmentSuccessScreen extends StatelessWidget {
  final Map<String, dynamic> appointmentData;

  const AppointmentSuccessScreen({
    super.key,
    required this.appointmentData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // 关键：防止溢出
            children: [
              // 添加顶部间距以居中显示
              SizedBox(height: MediaQuery.of(context).size.height * 0.05),
              // Success icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Colors.white,
                  size: 60,
                ),
              ),

              const SizedBox(height: 40),

              // Success message
              const Text(
                'Appointment Request Submitted!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              const Text(
                'Your appointment request has been sent for dual approval. Both the coach and admin need to approve your request.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 30),

              // Approval process indicator
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      'Approval Process',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min, // 防止溢出
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.person, color: Colors.orange.shade600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Coach\nApproval',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'PENDING',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.add, color: Colors.blue.shade600),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min, // 防止溢出
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.admin_panel_settings, color: Colors.orange.shade600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Admin\nApproval',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'PENDING',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward, color: Colors.blue.shade600),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min, // 防止溢出
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.check_circle, color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Confirmed\nAppointment',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'WAITING',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Appointment details card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurple.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // 防止溢出
                  children: [
                    const Text(
                      'Appointment Request Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Date:', (appointmentData['date'] as Timestamp).toDate().toLocal().toString().split(' ')[0]),
                    _buildDetailRow('Time:', appointmentData['timeSlot'] ?? ''),
                    _buildDetailRow('Coach:', appointmentData['coachName'] ?? ''),
                    _buildDetailRow('Gym:', appointmentData['gymName'] ?? ''),
                    _buildDetailRow('Status:', 'Waiting for Dual Approval'),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              Column(
                mainAxisSize: MainAxisSize.min, // 防止溢出
                children: [
                  // Go Home
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/main',
                              (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Go Home',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // View My Appointments
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/main',
                              (route) => false,
                          arguments: {'initialIndex': 1},
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.deepPurple),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'View My Appointments',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 底部间距，确保内容不被截断但不会溢出
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}