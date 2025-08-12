import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'goal_input_screen.dart';
import 'today_training_screen.dart';

class AIPlanModal extends StatefulWidget {
  final List<String> aiPlans;
  final Function(String) onNewPlanSaved;

  const AIPlanModal({
    super.key,
    required this.aiPlans,
    required this.onNewPlanSaved,
  });

  @override
  State<AIPlanModal> createState() => _AIPlanModalState();
}

class _AIPlanModalState extends State<AIPlanModal> {
  RewardedAd? _rewardedAd;
  bool _isAdReady = false;
  List<Map<String, dynamic>> _savedPlans = [];
  bool _loadingPlans = true;

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
    _loadSavedPlans();
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
            _isAdReady = true;
          });
        },
        onAdFailedToLoad: (error) {
          debugPrint('Failed to load rewarded ad: $error');
        },
      ),
    );
  }

  Future<void> _loadSavedPlans() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loadingPlans = false);
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ai_plans')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> plans = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        await _calculateActualProgress(data, user.uid);
        plans.add(data);
      }

      setState(() {
        _savedPlans = plans;
        _loadingPlans = false;
      });
    } catch (e) {
      debugPrint('Failed to load plans: $e');
      setState(() => _loadingPlans = false);
    }
  }

  Future<void> _calculateActualProgress(Map<String, dynamic> planData, String userId) async {
    try {
      final planId = planData['id'];
      final totalDays = planData['durationDays'] as int? ?? 0;
      final createdAt = planData['createdAt'] as Timestamp?;

      if (createdAt == null || totalDays == 0) {
        planData['actualTrainingDays'] = 0;
        planData['progressPercentage'] = 0.0;
        planData['isCompleted'] = false;
        return;
      }

      final planStartDate = createdAt.toDate();

      final checkInQuery = await FirebaseFirestore.instance
          .collection('check_ins')
          .where('userId', isEqualTo: userId)
          .where('aiPlanId', isEqualTo: planId)
          .where('checkInType', isEqualTo: 'training_completed')
          .where('checkInDate', isGreaterThanOrEqualTo: Timestamp.fromDate(planStartDate))
          .get();

      final actualTrainingDays = checkInQuery.docs.length;
      final progressPercentage = totalDays > 0
          ? (actualTrainingDays / totalDays * 100).clamp(0.0, 100.0)
          : 0.0;

      final wasManuallyCompleted = planData['isCompleted'] == true;
      final shouldAutoComplete = actualTrainingDays >= totalDays;
      final isCompleted = wasManuallyCompleted || shouldAutoComplete;

      if (shouldAutoComplete && !wasManuallyCompleted) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('ai_plans')
              .doc(planId)
              .update({
            'isCompleted': true,
            'completedAt': FieldValue.serverTimestamp(),
            'progressPercentage': 100.0,
            'autoCompletedByTraining': true,
          });
        } catch (e) {
          debugPrint('Auto complete failed: $e');
        }
      }

      planData['actualTrainingDays'] = actualTrainingDays;
      planData['progressPercentage'] = progressPercentage;
      planData['isCompleted'] = isCompleted;
      planData['remainingDays'] = (totalDays - actualTrainingDays).clamp(0, totalDays);

    } catch (e) {
      debugPrint('Error calculating progress: $e');
      planData['actualTrainingDays'] = 0;
      planData['progressPercentage'] = 0.0;
      planData['isCompleted'] = false;
    }
  }

  void _showAdAndNavigate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Watch Ad to Unlock',
          style: TextStyle(color: Colors.black),
        ),
        content: const Text(
          'This feature requires watching an ad. Continue?',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'No',
              style: TextStyle(color: Colors.black),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Yes',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadRewardedAd();
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GoalInputScreen(
                onPlanGenerated: (planTitle) {
                  widget.onNewPlanSaved(planTitle);
                  _loadSavedPlans();
                },
              ),
            ),
          );

          if (mounted) {
            _loadSavedPlans();
          }
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ad is not ready yet, please try again later.")),
      );
    }
  }

  Future<bool> _hasTrainedToday(String planId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final querySnapshot = await FirebaseFirestore.instance
          .collection('check_ins')
          .where('userId', isEqualTo: user.uid)
          .where('aiPlanId', isEqualTo: planId)
          .where('checkInType', isEqualTo: 'training_completed')
          .where('checkInDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('checkInDate', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking today training: $e');
      return false;
    }
  }

  void _startTodayTraining(Map<String, dynamic> plan) async {
    final hasTrainedToday = await _hasTrainedToday(plan['id']);

    if (hasTrainedToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have completed your training today！'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final trainingItems = _createSimpleTrainingItemForAI(plan);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TodayTrainingScreen(
          trainingItems: trainingItems,
          courseId: plan['id'],
          aiPlanId: plan['id'],
          fullTrainingPlan: plan['trainingPlan'],
        ),
      ),
    );

    if (result == 'completed' && mounted) {
      _loadSavedPlans();
    }
  }

  List<TrainingItem> _createSimpleTrainingItemForAI(Map<String, dynamic> plan) {
    return [
      TrainingItem(
        name: plan['trainingPlan'] ?? '',
        durationMinutes: 30,
        color: Colors.purple,
        icon: Icons.auto_awesome,
        courseId: plan['id'],
        title: plan['title'] ?? 'AI Training',
        category: plan['goalType'] ?? 'Fitness',
      ),
    ];
  }

  void _showPlanDetails(Map<String, dynamic> plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                plan['title'] ?? 'AI Plan',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (plan['isCompleted'] ?? false)
                                    ? Colors.green
                                    : Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                (plan['isCompleted'] ?? false) ? 'Completed' : 'In Progress',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Training Progress',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    '${(plan['progressPercentage'] ?? 0).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: (plan['isCompleted'] ?? false) ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: (plan['progressPercentage'] ?? 0) / 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: (plan['isCompleted'] ?? false) ? Colors.green : Colors.orange,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Training Days: ${plan['actualTrainingDays'] ?? 0}/${plan['durationDays'] ?? 0}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                              if (!(plan['isCompleted'] ?? false))
                                Text(
                                  'Remaining: ${plan['remainingDays'] ?? 0} days',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildDetailCard(
                          'Goal Information',
                          Icons.track_changes,
                          Colors.purple,
                          [
                            _buildDetailRow('Goal Type', plan['goalType'] ?? ''),
                            _buildDetailRow('Current Weight', '${plan['currentWeight'] ?? 0}kg'),
                            _buildDetailRow('Expected Change', '${plan['weightChange'] ?? 0}kg'),
                            _buildDetailRow('Plan Duration', '${plan['durationDays'] ?? 0} days'),
                            if (plan['finalWeight'] != null)
                              _buildDetailRow('Final Weight', '${plan['finalWeight']}kg'),
                          ],
                        ),

                        _buildDetailCard(
                          'Training Plan',
                          Icons.fitness_center,
                          Colors.blue,
                          [
                            Text(
                              plan['trainingPlan'] ?? 'No training plan',
                              style: const TextStyle(
                                height: 1.5,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),

                        _buildDetailCard(
                          'Diet Plan',
                          Icons.restaurant,
                          Colors.orange,
                          [
                            Text(
                              plan['dietPlan'] ?? 'No diet plan',
                              style: const TextStyle(
                                height: 1.5,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),

                        if (plan['advice'] != null && plan['advice'].isNotEmpty)
                          _buildDetailCard(
                            'Expert Advice',
                            Icons.lightbulb_outline,
                            Colors.amber,
                            [
                              Text(
                                plan['advice'],
                                style: const TextStyle(
                                  height: 1.5,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 20),

                        if (!(plan['isCompleted'] ?? false))
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _startTodayTraining(plan);
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Start Today\'s Training'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailCard(String title, IconData icon, Color color, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'AI Training Plans',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: _loadingPlans
                ? const Center(child: CircularProgressIndicator())
                : _savedPlans.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No AI plans yet.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create your first plan below!',
                    style: TextStyle(color: Colors.black),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _savedPlans.length,
              itemBuilder: (context, index) {
                final plan = _savedPlans[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (plan['isCompleted'] ?? false)
                          ? Colors.green
                          : Colors.purple,
                      child: Icon(
                        (plan['isCompleted'] ?? false)
                            ? Icons.check
                            : Icons.auto_awesome,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      plan['title'] ?? 'AI Plan',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${plan['goalType'] ?? ''} • ${plan['durationDays'] ?? 0} days',
                          style: const TextStyle(color: Colors.black),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (plan['progressPercentage'] ?? 0) / 100,
                            child: Container(
                              decoration: BoxDecoration(
                                color: (plan['isCompleted'] ?? false) ? Colors.green : Colors.purple,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(plan['progressPercentage'] ?? 0).toInt()}% Complete',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              'Trained: ${plan['actualTrainingDays'] ?? 0}/${plan['durationDays'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _showPlanDetails(plan),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAdReady ? _showAdAndNavigate : null,
                icon: const Icon(Icons.add),
                label: const Text('Create New AI Plan (Watch Ad)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}