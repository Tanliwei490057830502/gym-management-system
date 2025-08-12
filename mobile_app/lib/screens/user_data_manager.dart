// services/user_data_manager.dart
import 'package:shared_preferences/shared_preferences.dart';

class UserDataManager {
  static final UserDataManager _instance = UserDataManager._internal();
  factory UserDataManager() => _instance;
  UserDataManager._internal();

  // 用户数据
  String? _gender;
  int? _age;
  double? _weight;
  int? _height;

  // Getters
  String? get gender => _gender;
  int? get age => _age;
  double? get weight => _weight;
  int? get height => _height;

  // Setters
  set gender(String? value) {
    _gender = value;
    _saveToPrefs();
  }

  set age(int? value) {
    _age = value;
    _saveToPrefs();
  }

  set weight(double? value) {
    _weight = value;
    _saveToPrefs();
  }

  set height(int? value) {
    _height = value;
    _saveToPrefs();
  }

  // 批量设置数据
  void setUserData({
    String? gender,
    int? age,
    double? weight,
    int? height,
  }) {
    _gender = gender;
    _age = age;
    _weight = weight;
    _height = height;
    _saveToPrefs();
  }

  // 检查是否有完整的用户数据
  bool get hasCompleteData {
    return _gender != null && _age != null && _weight != null && _height != null;
  }

  // 获取BMI值
  double? get bmi {
    if (_weight == null || _height == null) return null;
    final heightInMeters = _height! / 100.0;
    return _weight! / (heightInMeters * heightInMeters);
  }

  // 获取BMI状态
  String get bmiStatus {
    final bmiValue = bmi;
    if (bmiValue == null) return 'Unknown';

    if (bmiValue < 18.5) return 'Underweight';
    if (bmiValue < 25) return 'Normal';
    if (bmiValue < 30) return 'Overweight';
    return 'Obese';
  }

  // 保存到本地存储
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_gender != null) prefs.setString('gender', _gender!);
    if (_age != null) prefs.setInt('age', _age!);
    if (_weight != null) prefs.setDouble('weight', _weight!);
    if (_height != null) prefs.setInt('height', _height!);
  }

  // 从本地存储加载数据
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _gender = prefs.getString('gender');
    _age = prefs.getInt('age');
    _weight = prefs.getDouble('weight');
    _height = prefs.getInt('height');
  }

  // 清除所有数据
  Future<void> clearData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gender');
    await prefs.remove('age');
    await prefs.remove('weight');
    await prefs.remove('height');

    _gender = null;
    _age = null;
    _weight = null;
    _height = null;
  }
}