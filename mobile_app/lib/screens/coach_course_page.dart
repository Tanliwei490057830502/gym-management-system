// screens/coach_course_page.dart (Coach版本)
import 'package:flutter/material.dart';
import 'coach_create_course_screen.dart';
import 'coach_course_folder_screen.dart';
import 'coach_venue_selection_screen.dart';


class CoursePage extends StatelessWidget {
  const CoursePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Course Production
          _buildCourseSection(
            title: 'course production',
            icon: Icons.video_library,
            backgroundColor: Colors.orange,
            gradientColors: [Colors.purple[800]!, Colors.purple[600]!],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CoachCreateCourseScreen(),
                ),
              );
            },
          ),


          const SizedBox(height: 16),

          // Course Folder
          _buildCourseSection(
            title: 'course folder',
            icon: Icons.folder_open,
            backgroundColor: Colors.orange,
            gradientColors: [Colors.blue[800]!, Colors.blue[600]!],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CoachCourseFolderScreen()),
              );
            },
          ),

            const SizedBox(height: 16),

          // Venue Selection
          _buildCourseSection(
            title: 'Venue selection',
            icon: Icons.location_on,
            backgroundColor: Colors.orange,
            gradientColors: [Colors.green[800]!, Colors.green[600]!],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CoachVenueSelectionScreen()),
              );
            },

          ),
        ],
      ),
    );
  }

  Widget _buildCourseSection({
    required String title,
    required IconData icon,
    required Color backgroundColor,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // 背景渐变
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradientColors,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40), // 为标题栏留出空间
                      Icon(
                        icon,
                        size: 80,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _getSubtitle(title),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 橙色标题栏
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  color: backgroundColor,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // 点击效果
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    child: Container(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSubtitle(String title) {
    switch (title) {
      case 'course production':
        return 'Create & Edit Courses';
      case 'course folder':
        return 'Manage Course Library';
      case 'Venue selection':
        return 'Choose Training Location';
      default:
        return '';
    }
  }
}