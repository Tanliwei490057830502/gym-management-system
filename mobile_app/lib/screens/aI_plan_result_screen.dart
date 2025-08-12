import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AIPlanResultScreen extends StatefulWidget {
  final String goalType;
  final double weightChange;
  final int durationDays;
  final double currentWeight;
  final double height;
  final String advice;
  final double dailyFoodBudget;
  final Function(String) onPlanGenerated;

  const AIPlanResultScreen({
    super.key,
    required this.goalType,
    required this.weightChange,
    required this.durationDays,
    required this.currentWeight,
    required this.height,
    required this.advice,
    required this.onPlanGenerated,
    required this.dailyFoodBudget,
  });

  @override
  State<AIPlanResultScreen> createState() => _AIPlanResultScreenState();
}

class _AIPlanResultScreenState extends State<AIPlanResultScreen> {
  String? _trainingPlan;
  String? _dietPlan;
  bool _loading = true;
  bool _saving = false;
  String? _planId;
  String? _generatedTitle;

  final String _apiKey = 'AIzaSyDo1nsxo1P-FFWOOkcqzyNwOV6DVYSEdwo';

  @override
  void initState() {
    super.initState();
    _generatePlan();
  }

  Future<void> _generatePlan() async {
    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          topK: 40,
          topP: 0.95,
          maxOutputTokens: 2048,
        ),
      );

      final prompt = '''
You are a professional fitness trainer and nutritionist. Please create a **7-day rotating** fitness and diet plan for the user. Each day should be different to ensure variation.

User Information:
- Goal: ${widget.goalType}
- Current Weight: ${widget.currentWeight}kg
- Height: ${widget.height}cm
- Expected Change: ${widget.weightChange}kg
- Plan Duration: ${widget.durationDays} days
- Daily Food Budget: RM ${widget.dailyFoodBudget.toStringAsFixed(2)}

Please generate the plan in the following format:

Training Plan:
Day 1:
- [list of exercises with duration and intensity]
Day 2:
...
Day 7:
Each day should include:
- Specific exercise items (e.g., running 5km, sit-ups 30 times)
- Intensity and duration
- A short explanation of the focus (e.g., endurance, strength)
- For each exercise, include estimated calories burned (based on a 70-80kg person)


Diet Plan:
Please structure the diet plan by day (Day 1 ~ Day 7).
For each day:
- List breakfast, lunch, and dinner
- Include food item name, estimated cost in RM, and estimated calories (e.g., "Oatmeal with banana - RM 2.50, 250 kcal")
- Ensure total daily food cost is within RM ${widget.dailyFoodBudget.toStringAsFixed(2)}
- Ensure total daily calories are aligned with the user's goal:
  - Weight loss: 1500–1800 kcal/day
  - Maintenance: 2000–2200 kcal/day
  - Muscle gain: 2200–2500+ kcal/day
- Use simple meals that are affordable and common in Malaysia
- Avoid supplements or rare ingredients

Avoid using Markdown formatting like ** or bullet points. Keep everything plain and easy to read.
''';



      final content = await model.generateContent([Content.text(prompt)]);
      final text = content.text ?? 'Generation failed, please try again';

      // Parse training plan and diet plan
      final parts = text.split(RegExp(r'Diet Plan[:：]'));
      _generatedTitle = "AI Fitness Plan - ${DateTime.now().day}/${DateTime.now().month}";

      setState(() {
        if (parts.length >= 2) {
          _trainingPlan = parts[0]
              .replaceAll(RegExp(r'Training Plan[:：]'), '')
              .trim();
          _dietPlan = parts[1].trim();
        } else {
          // Backup parsing method
          final lines = text.split('\n');
          bool isDietSection = false;
          List<String> trainingLines = [];
          List<String> dietLines = [];

          for (String line in lines) {
            if (line.toLowerCase().contains('diet') || line.toLowerCase().contains('nutrition')) {
              isDietSection = true;
              continue;
            }

            if (isDietSection) {
              dietLines.add(line);
            } else if (line.trim().isNotEmpty) {
              trainingLines.add(line);
            }
          }

          _trainingPlan = trainingLines.join('\n').trim();
          _dietPlan = dietLines.isNotEmpty ? dietLines.join('\n').trim() : 'Please consult a nutritionist for specific diet plan';
        }

        if (_trainingPlan?.isEmpty ?? true) {
          _trainingPlan = 'Problem occurred during plan generation, please regenerate';
        }
        if (_dietPlan?.isEmpty ?? true) {
          _dietPlan = 'Problem occurred during diet plan generation, please regenerate';
        }

        _loading = false;
      });

    } catch (e) {
      debugPrint('Plan generation failed: $e');
      setState(() {
        _trainingPlan = 'Generation failed: ${e.toString()}\n\nPlease check network connection or try again later.';
        _dietPlan = 'Please consult a professional nutritionist for diet plan.';
        _loading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generation failed: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                setState(() => _loading = true);
                _generatePlan();
              },
            ),
          ),
        );
      }
    }
  }

  // 修复：保存计划时不自动设置体重
  Future<void> _savePlanToFirestore({bool isCompleted = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not logged in, cannot save plan'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 如果是完成计划，先显示体重输入对话框
    if (isCompleted) {
      final finalWeight = await _showWeightInputDialog();
      if (finalWeight == null) return; // 用户取消了对话框

      // 使用用户输入的实际体重保存
      await _savePlanWithActualWeight(finalWeight);
    } else {
      // 普通保存，不涉及体重更新
      await _savePlanNormally();
    }
  }

  // 显示体重输入对话框
  Future<double?> _showWeightInputDialog() async {
    final TextEditingController weightController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Complete Plan & Update Weight'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please enter your current weight to complete this plan:',
                style: TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Current Weight (kg)',
                  border: OutlineInputBorder(),
                  suffixText: 'kg',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your weight';
                  }
                  final weight = double.tryParse(value);
                  if (weight == null || weight <= 0 || weight > 300) {
                    return 'Please enter a valid weight (1-300 kg)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Starting weight: ${widget.currentWeight}kg',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Goal: ${widget.goalType == 'Muscle Gain' ? 'Gain' : 'Lose'} ${widget.weightChange}kg',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Target weight: ${(widget.goalType == 'Muscle Gain'
                    ? widget.currentWeight + widget.weightChange
                    : widget.currentWeight - widget.weightChange).toStringAsFixed(1)}kg',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.purple[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final finalWeight = double.parse(weightController.text);
                Navigator.of(context).pop(finalWeight);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete Plan'),
          ),
        ],
      ),
    );
  }

  // 使用实际体重保存完成的计划
  Future<void> _savePlanWithActualWeight(double finalWeight) async {
    final user = FirebaseAuth.instance.currentUser!;

    setState(() => _saving = true);

    try {
      // 计算预期的最终体重（用于记录目标）
      double expectedFinalWeight = widget.goalType == 'Muscle Gain'
          ? widget.currentWeight + widget.weightChange
          : widget.currentWeight - widget.weightChange;

      final planData = {
        'title': _generatedTitle ?? 'AI Fitness Plan',
        'goalType': widget.goalType,
        'weightChange': widget.weightChange,
        'durationDays': widget.durationDays,
        'currentWeight': widget.currentWeight,
        'expectedFinalWeight': expectedFinalWeight, // 记录目标体重
        'actualFinalWeight': finalWeight, // 记录实际体重
        'height': widget.height,
        'trainingPlan': _trainingPlan,
        'dietPlan': _dietPlan,
        'advice': widget.advice,
        'createdAt': FieldValue.serverTimestamp(),
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
        'progressPercentage': 100.0,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ai_plans')
          .add(planData);

      _planId = docRef.id;

      // 使用用户输入的实际体重更新用户档案
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'weight': finalWeight, // 使用实际体重
        'lastWeightUpdate': FieldValue.serverTimestamp(),
      });

      // Call callback function to notify parent page
      widget.onPlanGenerated(_generatedTitle ?? 'AI Fitness Plan');

      if (mounted) {
        // 计算体重变化
        double weightDifference = finalWeight - widget.currentWeight;
        String changeMessage = '';

        if (weightDifference > 0) {
          changeMessage = 'gained ${weightDifference.toStringAsFixed(1)}kg';
        } else if (weightDifference < 0) {
          changeMessage = 'lost ${(-weightDifference).toStringAsFixed(1)}kg';
        } else {
          changeMessage = 'maintained weight';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan completed! You $changeMessage. Weight updated to ${finalWeight.toStringAsFixed(1)}kg'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Return to AI Plan Modal
        Navigator.of(context).pop('completed');
      }

    } catch (e) {
      debugPrint('Failed to save plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // 普通保存（不完成计划）
  Future<void> _savePlanNormally() async {
    final user = FirebaseAuth.instance.currentUser!;

    setState(() => _saving = true);

    try {
      // 计算预期的最终体重
      double expectedFinalWeight = widget.goalType == 'Muscle Gain'
          ? widget.currentWeight + widget.weightChange
          : widget.currentWeight - widget.weightChange;

      final planData = {
        'title': _generatedTitle ?? 'AI Fitness Plan',
        'goalType': widget.goalType,
        'weightChange': widget.weightChange,
        'durationDays': widget.durationDays,
        'currentWeight': widget.currentWeight,
        'expectedFinalWeight': expectedFinalWeight,
        'height': widget.height,
        'trainingPlan': _trainingPlan,
        'dietPlan': _dietPlan,
        'advice': widget.advice,
        'createdAt': FieldValue.serverTimestamp(),
        'isCompleted': false,
        'progressPercentage': 0.0,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ai_plans')
          .add(planData);

      _planId = docRef.id;

      // Call callback function to notify parent page
      widget.onPlanGenerated(_generatedTitle ?? 'AI Fitness Plan');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Return to AI Plan Modal
        Navigator.of(context).pop('saved');
      }

    } catch (e) {
      debugPrint('Failed to save plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // Return without saving
  void _returnWithoutSaving() {
    Navigator.of(context).pop('not_saved');
  }

  // Regenerate plan
  Future<void> _regeneratePlan() async {
    setState(() => _loading = true);
    await _generatePlan();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // When user presses back button, also return to AI Plan Modal
        Navigator.of(context).pop('cancelled');
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AI Plan Results', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _returnWithoutSaving,
          ),
          actions: [
            if (!_loading && !_saving)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _regeneratePlan,
                tooltip: 'Regenerate',
              ),
          ],
        ),
        body: _loading
            ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('AI is creating your personalized fitness plan...'),
            ],
          ),
        )
            : Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Expert advice card
                    if (widget.advice.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.shade100, Colors.orange.shade50],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline,
                                color: Colors.orange.shade700, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Expert Advice',
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.advice,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Goal information card
                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.track_changes, color: Colors.purple),
                                const SizedBox(width: 8),
                                const Text(
                                  'Goal Information',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            _buildInfoRow('Goal Type', widget.goalType),
                            _buildInfoRow('Current Weight', '${widget.currentWeight}kg'),
                            _buildInfoRow('Expected Change', '${widget.weightChange}kg'),
                            _buildInfoRow('Plan Duration', '${widget.durationDays} days'),
                            _buildInfoRow('Target Weight',
                                '${(widget.goalType == 'Muscle Gain'
                                    ? widget.currentWeight + widget.weightChange
                                    : widget.currentWeight - widget.weightChange).toStringAsFixed(1)}kg'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Training plan card
                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.fitness_center, color: Colors.purple),
                                const SizedBox(width: 8),
                                const Text(
                                  'Training Plan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            Text(
                              _trainingPlan ?? '',
                              style: const TextStyle(
                                color: Colors.black,
                                height: 1.6,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Diet plan card
                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.restaurant, color: Colors.orange),
                                const SizedBox(width: 8),
                                const Text(
                                  'Diet Plan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            Text(
                              _dietPlan ?? '',
                              style: const TextStyle(
                                color: Colors.black,
                                height: 1.6,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 100), // Space for bottom buttons
                  ],
                ),
              ),
            ),

            // Loading overlay
            if (_saving)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Saving plan...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),

        // Bottom action buttons
        bottomNavigationBar: _loading || _saving
            ? null
            : Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Don't save button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _returnWithoutSaving,
                  icon: const Icon(Icons.close),
                  label: const Text('Don\'t Save'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[400]!),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Save button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _savePlanToFirestore(isCompleted: false),
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple,
                    side: const BorderSide(color: Colors.purple),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Complete button - 修复：显示体重输入对话框
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _savePlanToFirestore(isCompleted: true),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}