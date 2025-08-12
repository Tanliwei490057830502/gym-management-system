// lib/widgets/courses_tab.dart
// 用途：课程管理标签页

import 'package:flutter/material.dart';
import '../services/coach_service.dart';
import '../models/models.dart';
import '../widgets/course_card.dart';
import '../dialogs/add_course_dialog.dart';
import '../utils/snackbar_utils.dart';

class CoursesTab extends StatelessWidget {
  final VoidCallback onRefreshStatistics;

  const CoursesTab({
    Key? key,
    required this.onRefreshStatistics,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Course>>(
      stream: CoachService.getCoursesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final courses = snapshot.data ?? [];

        if (courses.isEmpty) {
          return _buildEmptyCoursesState(context);
        }

        return GridView.builder(
          padding: const EdgeInsets.all(30),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.3,
          ),
          itemCount: courses.length,
          itemBuilder: (context, index) {
            return CourseCard(
              course: courses[index],
              onDelete: () => _deleteCourse(context, courses[index].id),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyCoursesState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.class_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          const Text(
            'No Courses Available',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Add courses for your coaches to manage and teach.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => _showAddCourseDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add First Course'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCourseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddCourseDialog(
        onCourseAdded: onRefreshStatistics,
      ),
    );
  }

  Future<void> _deleteCourse(BuildContext context, String courseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: const Text('Are you sure you want to delete this course? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await CoachService.deleteCourse(courseId);

      if (context.mounted) {
        if (success) {
          SnackbarUtils.showSuccess(context, 'Course deleted successfully');
          onRefreshStatistics();
        } else {
          SnackbarUtils.showError(context, 'Failed to delete course');
        }
      }
    }
  }
}