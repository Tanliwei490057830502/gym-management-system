// lib/models/gym_info.dart
// 用途：健身房信息数据模型

import 'package:cloud_firestore/cloud_firestore.dart';

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
  final List<String> socialMedia;
  final String logo;
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
    this.socialMedia = const [],
    this.logo = '',
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
      socialMedia: List<String>.from(map['socialMedia'] ?? []),
      logo: map['logo'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// 转换为 Firestore 数据
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'phone': phone,
      'email': email,
      'address': address,
      'website': website,
      'operatingHours': operatingHours,
      'amenities': amenities,
      'socialMedia': socialMedia,
      'logo': logo,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// 创建副本
  GymInfo copyWith({
    String? name,
    String? description,
    String? phone,
    String? email,
    String? address,
    String? website,
    Map<String, String>? operatingHours,
    List<String>? amenities,
    List<String>? socialMedia,
    String? logo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GymInfo(
      name: name ?? this.name,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      website: website ?? this.website,
      operatingHours: operatingHours ?? this.operatingHours,
      amenities: amenities ?? this.amenities,
      socialMedia: socialMedia ?? this.socialMedia,
      logo: logo ?? this.logo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
      ],
      socialMedia: [],
    );
  }

  /// 检查是否为默认信息
  bool get isDefault {
    return name == 'Your Gym Name';
  }

  /// 获取格式化的营业时间
  String get formattedHours {
    if (operatingHours.isEmpty) return 'Not specified';

    // 检查是否所有天都相同
    final uniqueHours = operatingHours.values.toSet();
    if (uniqueHours.length == 1) {
      return 'Daily: ${uniqueHours.first}';
    }

    // 返回完整的时间表
    return operatingHours.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
  }

  /// 验证数据完整性
  bool get isValid {
    return name.isNotEmpty &&
        email.isNotEmpty &&
        phone.isNotEmpty &&
        address.isNotEmpty;
  }

  /// 获取联系方式摘要
  String get contactSummary {
    final contacts = <String>[];
    if (phone.isNotEmpty && phone != '+60 XX-XXX XXXX') contacts.add(phone);
    if (email.isNotEmpty && email != 'contact@yourgym.com') contacts.add(email);
    if (website.isNotEmpty && website != 'www.yourgym.com') contacts.add(website);
    return contacts.join(' • ');
  }

  /// 获取设施摘要
  String get amenitiesSummary {
    if (amenities.isEmpty) return 'No amenities listed';
    if (amenities.length <= 3) return amenities.join(', ');
    return '${amenities.take(3).join(', ')} and ${amenities.length - 3} more';
  }

  /// 检查是否有社交媒体
  bool get hasSocialMedia => socialMedia.isNotEmpty;

  /// 获取社交媒体数量
  int get socialMediaCount => socialMedia.length;

  /// 检查是否有Logo
  bool get hasLogo => logo.isNotEmpty;

  /// 获取营业时间摘要
  String get operatingHoursSummary {
    if (operatingHours.isEmpty) return 'Hours not specified';

    final uniqueHours = operatingHours.values.toSet();
    if (uniqueHours.length == 1) {
      return 'Daily: ${uniqueHours.first}';
    }

    return 'Varies by day';
  }

  @override
  String toString() {
    return 'GymInfo(name: $name, email: $email, phone: $phone, address: $address)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GymInfo &&
        other.name == name &&
        other.email == email &&
        other.phone == phone &&
        other.address == address;
  }

  @override
  int get hashCode {
    return name.hashCode ^
    email.hashCode ^
    phone.hashCode ^
    address.hashCode;
  }
}