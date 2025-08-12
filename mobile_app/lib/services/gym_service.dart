// gym_app_system/lib/services/gym_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class GymService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'gym_info';
  static const String _docId = 'main';

  /// 获取健身房信息流 (实时监听)
  static Stream<GymInfo?> gymInfoStream() {
    return _firestore.collection(_collection).doc(_docId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return GymInfo.fromMap(doc.data()!);
      }
      return GymInfo.defaultInfo();
    });
  }

  /// 获取健身房信息 (一次性获取)
  static Future<GymInfo?> getGymInfo() async {
    try {
      final doc = await _firestore.collection(_collection).doc(_docId).get();

      if (doc.exists && doc.data() != null) {
        return GymInfo.fromMap(doc.data()!);
      }

      return GymInfo.defaultInfo();
    } catch (e) {
      print('Error getting gym info: $e');
      return GymInfo.defaultInfo();
    }
  }

  /// 检查健身房是否已配置
  static Future<bool> isGymConfigured() async {
    try {
      final doc = await _firestore.collection(_collection).doc(_docId).get();
      if (!doc.exists) return false;

      final gymInfo = GymInfo.fromMap(doc.data()!);
      return !gymInfo.isDefault;
    } catch (e) {
      return false;
    }
  }
}

/// 健身房信息数据模型
class GymInfo {
  final String name;
  final String description;
  final String phone;
  final String email;
  final String address;
  final String website;
  final Map<String, String> operatingHours;
  final List<String> amenities;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GymInfo({
    required this.name,
    required this.description,
    required this.phone,
    required this.email,
    required this.address,
    this.website = '',
    required this.operatingHours,
    this.amenities = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// 从 Firestore 数据创建对象
  factory GymInfo.fromMap(Map<String, dynamic> map) {
    return GymInfo(
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      website: map['website'] ?? '',
      operatingHours: Map<String, String>.from(map['operatingHours'] ?? {}),
      amenities: List<String>.from(map['amenities'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// 默认健身房信息
  factory GymInfo.defaultInfo() {
    return GymInfo(
      name: 'Your Gym Name',
      description: 'Enter your gym description here...',
      phone: '+60 XX-XXX XXXX',
      email: 'contact@yourgym.com',
      address: 'Your gym address\nCity, State\nCountry',
      website: 'www.yourgym.com',
      operatingHours: {
        'Monday': '7:00 AM - 11:00 PM',
        'Tuesday': '7:00 AM - 11:00 PM',
        'Wednesday': '7:00 AM - 11:00 PM',
        'Thursday': '7:00 AM - 11:00 PM',
        'Friday': '7:00 AM - 11:00 PM',
        'Saturday': '7:00 AM - 11:00 PM',
        'Sunday': '7:00 AM - 11:00 PM',
      },
      amenities: [
        'Free Weights',
        'Cardio Equipment',
        'Group Classes',
        'Personal Training',
        'Locker Rooms',
        'Showers',
        'Free WiFi',
        'Parking',
      ],
    );
  }

  /// 检查是否为默认信息
  bool get isDefault {
    return name == 'Your Gym Name';
  }
}