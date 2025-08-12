import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'aI_plan_result_screen.dart';

class GoalInputScreen extends StatefulWidget {
  final Function(String) onPlanGenerated;

  const GoalInputScreen({super.key, required this.onPlanGenerated});

  @override
  State<GoalInputScreen> createState() => _GoalInputScreenState();
}

class _GoalInputScreenState extends State<GoalInputScreen> {
  final _formKey = GlobalKey<FormState>();
  String _goalType = 'Fat Loss';
  double _weightChange = 0;
  int _durationDays = 30;
  double _dailyFoodBudget = 20;
  double? _currentWeight;
  double? _height;

  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      _currentWeight = (userDoc['weight'] ?? 70).toDouble();
      _height = (userDoc['height'] ?? 170).toDouble();

      final bmi = _currentWeight! / ((_height! / 100) * (_height! / 100));

      double realisticChange = _goalType == 'Fat Loss'
          ? (_durationDays / 7) * 0.7
          : (_durationDays / 7) * 0.5;

      bool isUnrealistic = _weightChange > realisticChange;

      String advice = '';
      if (isUnrealistic) {
        advice =
        'Based on your BMI (${bmi.toStringAsFixed(1)}) and duration, the maximum recommended ${_goalType.toLowerCase()} is ${realisticChange.toStringAsFixed(1)}kg';
        _weightChange = realisticChange;
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AIPlanResultScreen(
            goalType: _goalType,
            weightChange: _weightChange,
            durationDays: _durationDays,
            dailyFoodBudget: _dailyFoodBudget,
            currentWeight: _currentWeight!,
            height: _height!,
            advice: advice,
            onPlanGenerated: widget.onPlanGenerated,
          ),
        ),
      );

      if (mounted) {
        Navigator.of(context).pop(result ?? 'cancelled');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('获取用户信息失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildGoalTypeCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.purple,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _goalType = 'Fat Loss'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _goalType == 'Fat Loss'
                          ? Colors.purple[700]
                          : Colors.transparent,
                      border: _goalType == 'Fat Loss'
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: const Center(
                      child: Text(
                        'Fat Loss',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(width: 1, color: Colors.white),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _goalType = 'Muscle Gain'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _goalType == 'Muscle Gain'
                          ? Colors.purple[700]
                          : Colors.transparent,
                      border: _goalType == 'Muscle Gain'
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: const Center(
                      child: Text(
                        'Muscle Gain',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required String title,
    required TextEditingController controller,
    required String hintText,
    required String? Function(String?) validator,
    required void Function(String?) onSaved,
    TextInputType keyboardType = TextInputType.number,
    String? prefixText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Colors.purple,
              padding: const EdgeInsets.all(12),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              color: Colors.orange,
              padding: const EdgeInsets.all(16),
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  prefixText: prefixText,
                  prefixStyle: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                    const BorderSide(color: Colors.white, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                ),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                validator: validator,
                onSaved: onSaved,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _durationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop('cancelled');
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'Set Fitness Goal',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop('cancelled'),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildGoalTypeCard(),
                  _buildInputCard(
                    title: 'Expected Weight Change',
                    controller: _weightController,
                    hintText: 'Enter weight in kg',
                    validator: (val) =>
                    (val == null || double.tryParse(val) == null || double.parse(val) <= 0)
                        ? 'Please enter a positive number'
                        : null,
                    onSaved: (val) => _weightChange = double.parse(val!),
                  ),
                  _buildInputCard(
                    title: 'Target Duration',
                    controller: _durationController,
                    hintText: 'Enter days (7-365)',
                    validator: (val) {
                      int? days = int.tryParse(val ?? '');
                      if (days == null || days < 7 || days > 365) {
                        return 'Please enter a value between 7 - 365 days';
                      }
                      return null;
                    },
                    onSaved: (val) => _durationDays = int.parse(val!),
                  ),
                  _buildInputCard(
                    title: 'Daily Food Budget',
                    controller: _budgetController,
                    hintText: 'Enter RM 10 - 30',
                    prefixText: 'RM ',
                    validator: (val) {
                      double? budget = double.tryParse(val ?? '');
                      if (budget == null || budget < 10 || budget > 30) {
                        return 'Please enter a value between RM 10 - 30';
                      }
                      return null;
                    },
                    onSaved: (val) => _dailyFoodBudget = double.parse(val!),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'Generate AI Plan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
