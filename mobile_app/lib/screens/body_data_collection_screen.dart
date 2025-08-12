// screens/body_data_collection_screen.dart
import 'package:flutter/material.dart';
import 'main_app_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BodyDataCollectionScreen extends StatefulWidget {
  const BodyDataCollectionScreen({super.key});

  @override
  State<BodyDataCollectionScreen> createState() => _BodyDataCollectionScreenState();
}

class _BodyDataCollectionScreenState extends State<BodyDataCollectionScreen> {
  int currentStep = 0;

  String? selectedGender;
  int? selectedAge;
  double? selectedWeight;
  int? selectedHeight;

  final List<String> genders = ['Male', 'Female'];
  final List<int> ages = List.generate(60, (index) => 18 + index); // 18-77岁
  final List<double> weights = List.generate(100, (index) => 40.0 + index); // 40-139kg
  final List<int> heights = List.generate(100, (index) => 140 + index); // 140-239cm

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Text(
                _getStepTitle(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildStepContent(),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Previous',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  if (currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isStepValid() ? _nextStep : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        currentStep == 3 ? 'Finish' : 'Next',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (currentStep) {
      case 0:
        return 'Tell us about yourself';
      case 1:
        return 'How old are you?';
      case 2:
        return 'What is your weight?';
      case 3:
        return 'What is your height?';
      default:
        return '';
    }
  }

  Widget _buildStepContent() {
    switch (currentStep) {
      case 0:
        return _buildGenderSelection();
      case 1:
        return _buildAgeSelection();
      case 2:
        return _buildWeightSelection();
      case 3:
        return _buildHeightSelection();
      default:
        return Container();
    }
  }

  Widget _buildGenderSelection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  selectedGender = 'Male';
                });
              },
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (selectedGender == 'Male') ? Colors.orange : Colors.white,
                  border: (selectedGender == 'Male') ? Border.all(color: Colors.blue, width: 3) : null,
                ),
                child: Icon(
                  Icons.male,
                  size: 60,
                  color: (selectedGender == 'Male') ? Colors.white : Colors.black,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  selectedGender = 'Female';
                });
              },
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (selectedGender == 'Female') ? Colors.orange : Colors.white,
                  border: (selectedGender == 'Female') ? Border.all(color: Colors.blue, width: 3) : null,
                ),
                child: Icon(
                  Icons.female,
                  size: 60,
                  color: (selectedGender == 'Female') ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAgeSelection() {
    return _buildScrollableSelection<int>(
      items: ages,
      selectedItem: selectedAge,
      displayText: (age) => age.toString(),
      onSelect: (age) => setState(() => selectedAge = age),
    );
  }

  Widget _buildWeightSelection() {
    return _buildScrollableSelection<double>(
      items: weights,
      selectedItem: selectedWeight,
      displayText: (weight) => '${weight.toInt()}kg',
      onSelect: (weight) => setState(() => selectedWeight = weight),
    );
  }

  Widget _buildHeightSelection() {
    return _buildScrollableSelection<int>(
      items: heights,
      selectedItem: selectedHeight,
      displayText: (height) => '${height}cm',
      onSelect: (height) => setState(() => selectedHeight = height),
    );
  }

  Widget _buildScrollableSelection<T>({
    required List<T> items,
    required T? selectedItem,
    required String Function(T) displayText,
    required void Function(T) onSelect,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 300,
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = item == selectedItem;
              return GestureDetector(
                onTap: () => onSelect(item),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 40),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected ? Colors.orange : Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      displayText(item),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isStepValid() {
    switch (currentStep) {
      case 0:
        return selectedGender != null;
      case 1:
        return selectedAge != null;
      case 2:
        return selectedWeight != null;
      case 3:
        return selectedHeight != null;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (currentStep < 3) {
      setState(() {
        currentStep++;
      });
    } else {
      _saveUserData();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainAppScreen()),
      );
    }
  }

  void _previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
    }
  }

  void _saveUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not logged in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'gender': selectedGender,
        'age': selectedAge,
        'weight': selectedWeight,
        'height': selectedHeight,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Body data saved to Firestore!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
