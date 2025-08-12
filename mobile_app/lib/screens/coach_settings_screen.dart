// screens/coach_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'welcome_screen.dart'; // 根据您的项目路径调整

class CoachSettingsScreen extends StatefulWidget {
  const CoachSettingsScreen({super.key});

  @override
  State<CoachSettingsScreen> createState() => _CoachSettingsScreenState();
}

class _CoachSettingsScreenState extends State<CoachSettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, dynamic>? _coachData;
  bool _isLoading = true;
  bool _isUpdating = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _certificationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();

  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadCoachData();
    _loadStudents();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _certificationController.dispose();
    _experienceController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  Future<void> _loadCoachData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('coaches').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _coachData = doc.data();
          _populateControllers();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading coach data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _populateControllers() {
    if (_coachData != null) {
      _nameController.text = _coachData!['name'] ?? '';
      _certificationController.text = _coachData!['certification'] ?? '';
      _experienceController.text = (_coachData!['experience'] ?? '').toString();
      _specialtyController.text = _coachData!['specialty'] ?? '';
    }
  }

  Future<void> _loadStudents() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('coaches')
          .doc(user.uid)
          .collection('students')
          .get();

      final List<Map<String, dynamic>> loadedStudents = [];
      for (var doc in snapshot.docs) {
        final studentId = doc.id;
        final studentDoc = await _firestore.collection('users').doc(studentId).get();
        if (studentDoc.exists) {
          loadedStudents.add({
            'uid': studentId,
            'name': studentDoc['name'] ?? studentDoc['username'] ?? 'Unknown Student',
          });
        }
      }

      setState(() => _students = loadedStudents);
    } catch (e) {
      print('Error loading students: $e');
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

      // Delete old photo if exists
      final oldUrl = _coachData?['profileImageUrl'];
      if (oldUrl != null && oldUrl.toString().startsWith("https://")) {
        try {
          final oldRef = _storage.refFromURL(oldUrl);
          await oldRef.delete();
        } catch (e) {
          print("Old image delete failed: $e");
        }
      }

      final fileName = 'coach_profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('coach_profile_pictures').child(fileName);
      final uploadTask = ref.putFile(File(image.path));
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await _firestore.collection('coaches').doc(user.uid).update({
        'profileImageUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _coachData!['profileImageUrl'] = downloadUrl;
        _isUpdating = false;
      });

      _showSuccessSnackBar('Profile picture updated successfully!');
    } catch (e) {
      setState(() => _isUpdating = false);
      _showErrorSnackBar('Failed to update profile picture: $e');
    }
  }

  Future<void> _updateCoachInfo() async {
    if (!_validateInputs()) return;

    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isUpdating = true);

    try {
      final experience = int.tryParse(_experienceController.text);

      await _firestore.collection('coaches').doc(user.uid).update({
        'name': _nameController.text.trim(),
        'certification': _certificationController.text.trim(),
        'experience': experience,
        'specialty': _specialtyController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _coachData!['name'] = _nameController.text.trim();
        _coachData!['certification'] = _certificationController.text.trim();
        _coachData!['experience'] = experience;
        _coachData!['specialty'] = _specialtyController.text.trim();
        _isUpdating = false;
      });

      _showSuccessSnackBar('Profile updated successfully!');
    } catch (e) {
      setState(() => _isUpdating = false);
      _showErrorSnackBar('Failed to update profile: $e');
    }
  }

  bool _validateInputs() {
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar('Name cannot be empty');
      return false;
    }

    if (_certificationController.text.trim().isEmpty) {
      _showErrorSnackBar('Certification cannot be empty');
      return false;
    }

    final experience = int.tryParse(_experienceController.text);
    if (experience == null || experience < 0 || experience > 50) {
      _showErrorSnackBar('Please enter valid experience (0-50 years)');
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
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Coach Settings',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Profile Picture Section
            _buildProfilePictureSection(),
            const SizedBox(height: 24),

            // Coach Info Form
            _buildInputField('Coach Name', _nameController, Icons.person),
            _buildInputField('Certification', _certificationController, Icons.verified),
            _buildInputField('Experience', _experienceController, Icons.star, suffix: 'years'),
            _buildInputField('Specialty', _specialtyController, Icons.fitness_center),

            const SizedBox(height: 24),
            _buildUpdateButton(),
            const SizedBox(height: 24),

            // Students Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Students',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_students.isEmpty)
                    const Center(
                      child: Text(
                        'No students yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._students.map((student) => _buildStudentItem(student['name'])),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () => _logoutToWelcome(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.grey.shade600),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Center(
      child: Column(
        children: [
          const Text(
            'Profile Picture',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.orange.shade100,
                backgroundImage: _coachData?['profileImageUrl'] != null
                    ? NetworkImage(_coachData!['profileImageUrl'])
                    : null,
                child: _coachData?['profileImageUrl'] == null
                    ? const Icon(Icons.fitness_center, size: 60, color: Colors.orange)
                    : null,
              ),
              if (_isUpdating)
                const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.orange),
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
                      color: Colors.orange,
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
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon, {String? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: suffix == 'years' ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black),
          prefixIcon: Icon(icon, color: Colors.orange),
          suffixText: suffix,
          suffixStyle: const TextStyle(color: Colors.black),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.orange, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isUpdating ? null : _updateCoachInfo,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isUpdating
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
          'Update Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildStudentItem(String name) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.orange.shade100,
            child: Icon(
              Icons.person,
              color: Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Text(
              'Active',
              style: TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}