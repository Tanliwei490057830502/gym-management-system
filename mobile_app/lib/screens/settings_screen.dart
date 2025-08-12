// screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'welcome_screen.dart'; // ✅ 加在其他 import 下面


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isUpdating = false;

  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  int? _originalAge;
  double? _originalWeight;
  int? _originalHeight;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _userData = doc.data();
          _populateControllers();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _populateControllers() {
    if (_userData != null) {
      _nameController.text = _userData!['name'] ?? '';
      _ageController.text = (_userData!['age'] ?? '').toString();
      _weightController.text = (_userData!['weight'] ?? '').toString();
      _heightController.text = (_userData!['height'] ?? '').toString();

      _originalAge = _userData!['age'];
      _originalWeight = _userData!['weight']?.toDouble();
      _originalHeight = _userData!['height'];
    }
  }

  Future<void> _changeProfilePicture() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image == null) return;

      setState(() => _isUpdating = true);
      final user = _auth.currentUser;
      if (user == null) return;

      // delete old photo if exists and is valid URL
      final oldUrl = _userData?['profileImageUrl'];
      if (oldUrl != null && oldUrl.toString().startsWith("https://")) {
        try {
          final oldRef = _storage.refFromURL(oldUrl);
          await oldRef.delete();
        } catch (e) {
          print("Old image delete failed (may not exist): $e");
        }
      }

      final fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('profile_pictures').child(fileName);
      final uploadTask = ref.putFile(File(image.path));
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await _firestore.collection('users').doc(user.uid).update({
        'profileImageUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _userData!['profileImageUrl'] = downloadUrl;
        _isUpdating = false;
      });

      _showSuccessSnackBar('Profile picture updated successfully!');
    } catch (e) {
      setState(() => _isUpdating = false);
      _showErrorSnackBar('Failed to update profile picture: $e');
    }
  }

  Future<void> _updateUserInfo() async {
    if (!_validateInputs()) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final newAge = int.tryParse(_ageController.text);
    final newWeight = double.tryParse(_weightController.text);
    final newHeight = int.tryParse(_heightController.text);

    final weightChanged = newWeight != _originalWeight;
    final heightChanged = newHeight != _originalHeight;

    if (weightChanged || heightChanged) {
      final shouldContinue = await _showDataLossWarningDialog();
      if (!shouldContinue) return;
    }

    setState(() => _isUpdating = true);

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'age': newAge,
        'weight': newWeight,
        'height': newHeight,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (weightChanged || heightChanged) {
        await _clearWeightRecords(user.uid);
      }

      setState(() {
        _userData!['name'] = _nameController.text.trim();
        _userData!['age'] = newAge;
        _userData!['weight'] = newWeight;
        _userData!['height'] = newHeight;
        _originalAge = newAge;
        _originalWeight = newWeight;
        _originalHeight = newHeight;
        _isUpdating = false;
      });

      _showSuccessSnackBar('Profile updated successfully!');
    } catch (e) {
      setState(() => _isUpdating = false);
      _showErrorSnackBar('Failed to update profile: $e');
    }
  }

  Future<void> _clearWeightRecords(String userId) async {
    try {
      final weightRecords = await _firestore
          .collection('weight_records')
          .where('userId', isEqualTo: userId)
          .get();
      final batch = _firestore.batch();
      for (var doc in weightRecords.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error clearing weight records: $e');
    }
  }

  Future<bool> _showDataLossWarningDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange[600]),
              const SizedBox(width: 8),
              const Text(
                'Data Loss Warning',
                style: TextStyle(color: Colors.black),
              ),
            ],
          ),
          content: const Text(
            'Changing your weight or height will clear your weight records and reset progress. Continue?',
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Continue',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    ) ??
        false;
  }

  bool _validateInputs() {
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar('Name cannot be empty');
      return false;
    }

    final age = int.tryParse(_ageController.text);
    if (age == null || age < 1 || age > 120) {
      _showErrorSnackBar('Please enter a valid age (1-120)');
      return false;
    }

    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight < 20 || weight > 300) {
      _showErrorSnackBar('Please enter a valid weight (20-300 kg)');
      return false;
    }

    final height = int.tryParse(_heightController.text);
    if (height == null || height < 100 || height > 250) {
      _showErrorSnackBar('Please enter a valid height (100-250 cm)');
      return false;
    }

    return true;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message, style: const TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _logoutToWelcome(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    // 清空导航栈并跳转到 Welcome
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
    );
  }


  Widget _buildProfilePictureSection() {
    return Center(
      child: Column(
        children: [
          const Text(
            'Profile Picture',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage: _userData?['profileImageUrl'] != null
                    ? NetworkImage(_userData!['profileImageUrl'])
                    : null,
                child: _userData?['profileImageUrl'] == null
                    ? const Icon(Icons.person, size: 60, color: Colors.grey)
                    : null,
              ),
              if (_isUpdating)
                const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUpdating ? null : _changeProfilePicture,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap the camera icon to change',
            style: TextStyle(color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isUpdating ? null : _updateUserInfo,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isUpdating
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
          'Update Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfilePictureSection(),
            const SizedBox(height: 24),
            _buildInputField('Full Name', _nameController, Icons.person),
            _buildInputField('Age', _ageController, Icons.cake, suffix: 'years'),
            _buildInputField('Weight', _weightController, Icons.monitor_weight, suffix: 'kg'),
            _buildInputField('Height', _heightController, Icons.height, suffix: 'cm'),
            const SizedBox(height: 24),
            _buildUpdateButton(),
            const SizedBox(height: 20), // 👈 间距

            ElevatedButton.icon(
              onPressed: () => _logoutToWelcome(context),
              icon: const Icon(Icons.logout),
              label: const Text('              Log out and return to the Welcome page              '),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon,
      {String? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: suffix == 'kg'),
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black),
          prefixIcon: Icon(icon, color: Colors.black),
          suffixText: suffix,
          suffixStyle: const TextStyle(color: Colors.black),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
          ),
        ),
      ),
    );
  }
}