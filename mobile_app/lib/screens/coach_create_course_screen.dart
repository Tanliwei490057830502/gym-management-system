import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Exercise {
  String name;
  String reps;
  String duration;
  String rest;

  Exercise({this.name = '', this.reps = '', this.duration = '', this.rest = ''});
}

class DayConfig {
  bool hasCourse;
  int warmUpDuration;
  int coolDownDuration;
  List<Exercise> exercises;

  DayConfig({
    this.hasCourse = false,
    this.warmUpDuration = 5,
    this.coolDownDuration = 5,
    List<Exercise>? exercises,
  }) : exercises = exercises ?? List.generate(3, (_) => Exercise());
}

class CoachCreateCourseScreen extends StatefulWidget {
  final bool isEditMode;
  final String? courseId;
  final Map<String, dynamic>? existingCourseData;

  const CoachCreateCourseScreen({
    super.key,
    this.isEditMode = false,
    this.courseId,
    this.existingCourseData,
  });

  @override
  State<CoachCreateCourseScreen> createState() => _CoachCreateCourseScreenState();
}

class _CoachCreateCourseScreenState extends State<CoachCreateCourseScreen> {
  final TextEditingController _titleController = TextEditingController();
  int _selectedDayIndex = 0;
  final List<DayConfig> _dayConfigs = List.generate(7, (_) => DayConfig());

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode && widget.existingCourseData != null) {
      _populateData(widget.existingCourseData!);
    }
  }

  void _populateData(Map<String, dynamic> data) {
    _titleController.text = data['title'] ?? '';

    if (data['days'] != null && data['days'] is Map) {
      final daysMap = data['days'] as Map<String, dynamic>;
      for (int i = 0; i < 7; i++) {
        final dayKey = 'day${i + 1}';
        if (daysMap.containsKey(dayKey)) {
          final day = daysMap[dayKey];
          _dayConfigs[i].hasCourse = day['hasCourse'] ?? false;
          _dayConfigs[i].warmUpDuration = day['warmUp'] ?? 5;
          _dayConfigs[i].coolDownDuration = day['coolDown'] ?? 5;

          final exercises = day['exercises'] as List<dynamic>? ?? [];
          _dayConfigs[i].exercises = exercises
              .map((e) => Exercise(
            name: e['name'] ?? '',
            reps: e['reps'] ?? '',
            duration: e['duration'] ?? '',
            rest: e['rest'] ?? '',
          ))
              .toList();

          // 保证至少有 3 个空框
          while (_dayConfigs[i].exercises.length < 3) {
            _dayConfigs[i].exercises.add(Exercise());
          }
        }
      }
    }
  }

  void _editExercise(int dayIndex, int exerciseIndex) async {
    final exercise = _dayConfigs[dayIndex].exercises[exerciseIndex];
    final nameController = TextEditingController(text: exercise.name);
    final repsController = TextEditingController(text: exercise.reps);
    final durationController = TextEditingController(text: exercise.duration);
    final restController = TextEditingController(text: exercise.rest);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Exercise'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: repsController, decoration: const InputDecoration(labelText: 'Reps')),
              TextField(controller: durationController, decoration: const InputDecoration(labelText: 'Duration')),
              TextField(controller: restController, decoration: const InputDecoration(labelText: 'Rest Time')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                exercise.name = nameController.text;
                exercise.reps = repsController.text;
                exercise.duration = durationController.text;
                exercise.rest = restController.text;

                final list = _dayConfigs[dayIndex].exercises;
                if (exerciseIndex == list.length - 1 && list.length < 10) {
                  list.add(Exercise());
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCourse() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a course title')));
      return;
    }

    final Map<String, dynamic> courseData = {
      'title': title,
      'coachId': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'days': {},
    };

    for (int i = 0; i < 7; i++) {
      final key = 'day${i + 1}';
      final config = _dayConfigs[i];
      courseData['days'][key] = {
        'hasCourse': config.hasCourse,
        'warmUp': config.warmUpDuration,
        'coolDown': config.coolDownDuration,
        'exercises': config.exercises
            .where((e) => e.name.isNotEmpty)
            .map((e) => {
          'name': e.name,
          'reps': e.reps,
          'duration': e.duration,
          'rest': e.rest,
        })
            .toList(),
      };
    }

    try {
      if (widget.isEditMode && widget.courseId != null) {
        await FirebaseFirestore.instance.collection('courses').doc(widget.courseId).update(courseData);
      } else {
        await FirebaseFirestore.instance.collection('courses').add(courseData);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.isEditMode ? '✅ Course updated successfully' : '✅ Course created successfully'),
      ));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = _dayConfigs[_selectedDayIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Course' : 'Create Course', style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Course Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Enter course title',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Select Day (1~7)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(7, (index) {
                final isSelected = index == _selectedDayIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDayIndex = index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange : Colors.white,
                      border: Border.all(color: Colors.orange, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Day ${index + 1}',
                      style: TextStyle(color: isSelected ? Colors.white : Colors.orange),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Has Course on this Day?'),
              Switch(
                value: selectedDay.hasCourse,
                onChanged: (value) => setState(() => selectedDay.hasCourse = value),
                activeColor: Colors.orange,
              ),
            ],
          ),
          if (selectedDay.hasCourse) ...[
            const SizedBox(height: 12),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Warm-up Duration (min)'),
              onChanged: (val) => setState(() => selectedDay.warmUpDuration = int.tryParse(val) ?? 5),
            ),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cool-down Duration (min)'),
              onChanged: (val) => setState(() => selectedDay.coolDownDuration = int.tryParse(val) ?? 5),
            ),
            const SizedBox(height: 12),
            const Text('Exercises:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Column(
              children: List.generate(selectedDay.exercises.length, (i) {
                final e = selectedDay.exercises[i];
                return ListTile(
                  onTap: () => _editExercise(_selectedDayIndex, i),
                  title: Text(e.name.isEmpty ? 'Tap to edit' : e.name),
                  subtitle: Text('Reps: ${e.reps} | Time: ${e.duration} | Rest: ${e.rest}', style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.edit),
                );
              }),
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _submitCourse,
              child: Text(widget.isEditMode ? 'Update Course' : 'Save Course', style: const TextStyle(fontSize: 16, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}
