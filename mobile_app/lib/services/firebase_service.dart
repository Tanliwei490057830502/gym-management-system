// services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // ================================
  // Appointment Related Methods
  // ================================

  // Create appointment
  static Future<bool> createAppointment({
    required String coachId,
    required String gymId,
    required DateTime date,
    required String timeSlot,
    required String userId,
  }) async {
    try {
      await _firestore.collection('appointments').add({
        'userId': userId,
        'coachId': coachId,
        'gymId': gymId,
        'date': Timestamp.fromDate(date),
        'timeSlot': timeSlot,
        'status': 'pending', // 新预约状态为 pending
        'createdAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print('Error creating appointment: $e');
      return false;
    }
  }
  static Future<void> bookAppointment(Map<String, dynamic> appointmentData) async {
    try {
      await _firestore.collection('appointments').add({
        'userId': appointmentData['userId'],
        'userEmail': appointmentData['userEmail'],
        'coachId': appointmentData['coachId'],
        'coachName': appointmentData['coachName'],
        'gymId': appointmentData['gymId'],
        'gymName': appointmentData['gymName'],
        'date': Timestamp.fromDate(DateTime.parse(appointmentData['date'])),
        'timeSlot': appointmentData['timeSlot'],
        'status': appointmentData['status'],
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error booking appointment: $e');
      rethrow; // 保证外部调用能捕捉到错误
    }
  }

  // Get user appointments
  static Future<List<Map<String, dynamic>>> getUserAppointments(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: false)
          .get();

      List<Map<String, dynamic>> appointments = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        // Get coach and gym details
        final coachDoc = await _firestore.collection('coaches').doc(data['coachId']).get();

        // 获取健身房信息 - 使用预设数据
        final gymInfo = _getGymInfo(data['gymId']);

        appointments.add({
          'id': doc.id,
          ...data,
          'coachName': coachDoc.exists ? coachDoc.data()!['name'] : 'Unknown Coach',
          'gymName': gymInfo['name'],
          'gymAddress': gymInfo['address'],
        });
      }
      return appointments;
    } catch (e) {
      print('Error getting user appointments: $e');
      return [];
    }
  }

  // Get appointments for specific date and coach/gym combination
  static Future<List<String>> getBookedTimeSlots({
    required DateTime date,
    required String coachId,
    required String gymId,
  }) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final querySnapshot = await _firestore
          .collection('appointments')
          .where('coachId', isEqualTo: coachId)
          .where('gymId', isEqualTo: gymId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .where('status', isEqualTo: 'confirmed') // 只计算已确认的预约
          .get();

      return querySnapshot.docs.map((doc) => doc.data()['timeSlot'] as String).toList();
    } catch (e) {
      print('Error getting booked time slots: $e');
      return [];
    }
  }

  // ================================
  // Coach Related Methods
  // ================================

  // Get all coaches
  static Future<List<Map<String, dynamic>>> getCoaches() async {
    try {
      final querySnapshot = await _firestore
          .collection('coaches')
          .where('role', isEqualTo: 'coach')
          .get();
      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting coaches: $e');
      return [];
    }
  }

  // Get coach by ID
  static Future<Map<String, dynamic>?> getCoachById(String coachId) async {
    try {
      final doc = await _firestore.collection('coaches').doc(coachId).get();
      if (doc.exists) {
        return {'id': doc.id, ...doc.data()!};
      }
      return null;
    } catch (e) {
      print('Error getting coach: $e');
      return null;
    }
  }

  // Get coach's assigned gyms
  static Future<List<Map<String, dynamic>>> getCoachAssignedGyms(String coachId) async {
    try {
      final coachDoc = await _firestore.collection('coaches').doc(coachId).get();

      if (!coachDoc.exists) {
        print('Coach not found: $coachId');
        return [];
      }

      final List<dynamic> assignedGymIds = coachDoc.data()?['assignedGyms'] ?? [];

      // 获取预设健身房数据
      final allGyms = _getAllGyms();

      // 过滤出教练分配的健身房
      return allGyms.where((gym) => assignedGymIds.contains(gym['id'])).toList();
    } catch (e) {
      print('Error getting coach assigned gyms: $e');
      return [];
    }
  }

  // ================================
  // Gym Related Methods
  // ================================

  // Get all gyms (预设数据，与CoachVenueSelectionScreen保持一致)
  static List<Map<String, dynamic>> _getAllGyms() {
    return [
      {
        'id': 'gym1',
        'name': 'Skudai Fitness Hub',
        'address': 'No. 21, Jalan Sutera Danga, Taman Sutera Utama, Skudai, Johor',
        'monthlyPrice': 120,
        'yearlyPrice': 1200,
      },
      {
        'id': 'gym2',
        'name': 'Iron Pulse Gym',
        'address': 'Lot 2, Sutera Mall, Jalan Sutera Taman, Skudai, Johor',
        'monthlyPrice': 150,
        'yearlyPrice': 1500,
      },
      {
        'id': 'gym3',
        'name': 'Titan Training Center',
        'address': 'Taman Universiti, Jalan Kebudayaan, Skudai, Johor',
        'monthlyPrice': 100,
        'yearlyPrice': 1000,
      },
    ];
  }

  // Get gym info by ID
  static Map<String, dynamic> _getGymInfo(String gymId) {
    final gyms = _getAllGyms();
    try {
      return gyms.firstWhere((gym) => gym['id'] == gymId);
    } catch (e) {
      return {
        'id': gymId,
        'name': 'Unknown Gym',
        'address': 'Unknown Address',
        'monthlyPrice': 0,
        'yearlyPrice': 0,
      };
    }
  }

  // Get all gyms
  static Future<List<Map<String, dynamic>>> getGyms() async {
    // 返回预设的健身房数据
    return _getAllGyms();
  }

  // Get gym by ID
  static Future<Map<String, dynamic>?> getGymById(String gymId) async {
    try {
      return _getGymInfo(gymId);
    } catch (e) {
      print('Error getting gym: $e');
      return null;
    }
  }

  // ================================
  // User Related Methods
  // ================================

  // Get user data
  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Update user data
  static Future<bool> updateUserData(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
      return true;
    } catch (e) {
      print('Error updating user data: $e');
      return false;
    }
  }

  // ================================
  // Course Related Methods
  // ================================

  // Get user purchased courses
  static Future<List<Map<String, dynamic>>> getUserCourses(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('user_courses')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .get();

      List<Map<String, dynamic>> courses = [];
      for (var doc in querySnapshot.docs) {
        final courseData = doc.data();
        // Get course details
        final courseDoc = await _firestore
            .collection('courses')
            .doc(courseData['courseId'])
            .get();

        if (courseDoc.exists) {
          courses.add({
            ...courseDoc.data()!,
            'userCourseId': doc.id,
            'purchaseDate': courseData['purchaseDate'],
            'expiryDate': courseData['expiryDate'],
            'remainingSessions': courseData['remainingSessions'] ?? 0,
          });
        }
      }
      return courses;
    } catch (e) {
      print('Error getting user courses: $e');
      return [];
    }
  }

  // ================================
  // Training Schedule Methods
  // ================================

  // Get today's training for user
  static Future<Map<String, dynamic>?> getTodayTraining(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final querySnapshot = await _firestore
          .collection('training_schedules')
          .where('userId', isEqualTo: userId)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      print('Error getting today training: $e');
      return null;
    }
  }

  // ================================
  // Check-in Related Methods
  // ================================

  // Check if user has checked in today
  static Future<bool> hasCheckedInToday(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final querySnapshot = await _firestore
          .collection('check_ins')
          .where('userId', isEqualTo: userId)
          .where('checkInDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('checkInDate', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking today check-in: $e');
      return false;
    }
  }

  // Create check-in record
  static Future<bool> createCheckIn(String userId) async {
    try {
      await _firestore.collection('check_ins').add({
        'userId': userId,
        'checkInDate': Timestamp.now(),
        'type': 'daily',
        'createdAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print('Error creating check-in: $e');
      return false;
    }
  }
}