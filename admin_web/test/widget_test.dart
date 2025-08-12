// Flutter widget test for Gym Admin Web application

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gym_admin_web/main.dart';

void main() {
  group('Gym Admin App Tests', () {
    testWidgets('App loads and shows login page', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(GymAdminApp());

      // Verify that login page elements are present
      expect(find.text('LTC'), findsOneWidget);
      expect(find.text('Name :'), findsOneWidget);
      expect(find.text('Password :'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('Login button navigation works', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(GymAdminApp());

      // Find and tap the login button
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle(); // Wait for navigation animation

      // Verify that we navigated to the main page with sidebar
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Appointment\nmanagement'), findsOneWidget);
      expect(find.text('Coaches and\ncourses'), findsOneWidget);
      expect(find.text('Chart'), findsOneWidget);
    });

    testWidgets('Sidebar navigation works', (WidgetTester tester) async {
      // Build app and navigate past login
      await tester.pumpWidget(GymAdminApp());
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Test navigation to different pages
      // Navigate to Chart page
      await tester.tap(find.text('Chart'));
      await tester.pumpAndSettle();

      // Verify chart page content
      expect(find.text('Total estimated revenue for\nthe week: RM 5,720'), findsOneWidget);
      expect(find.text('Daily Statistics'), findsOneWidget);

      // Navigate to Coaches page
      await tester.tap(find.text('Coaches and\ncourses'));
      await tester.pumpAndSettle();

      // Verify coaches page content
      expect(find.text('courses'), findsOneWidget);
      expect(find.text('Key Highlights of the 7-Day Workout Plan'), findsWidgets);
    });

    testWidgets('Home page displays gym information', (WidgetTester tester) async {
      // Build app and navigate past login
      await tester.pumpWidget(GymAdminApp());
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      // Verify home page content
      expect(find.text('R3 FITNESS'), findsOneWidget);
      expect(find.text('R3 Fitness'), findsOneWidget);
      expect(find.text('07-338 3103'), findsOneWidget);
      expect(find.text('customerservice@r3fitness.com.my'), findsOneWidget);
      expect(find.textContaining('Introduction :'), findsOneWidget);
    });

    testWidgets('Appointment page shows calendar and pending approvals', (WidgetTester tester) async {
      // Build app and navigate to appointment page
      await tester.pumpWidget(GymAdminApp());
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Appointment\nmanagement'));
      await tester.pumpAndSettle();

      // Verify appointment page content
      expect(find.text('Monthly reservation'), findsOneWidget);
      expect(find.text('Appointment Booking'), findsOneWidget);
      expect(find.text('March 2025'), findsOneWidget);
      expect(find.text('appointment today'), findsOneWidget);
      expect(find.text('Pending approval'), findsOneWidget);

      // Verify some pending approval names
      expect(find.text('Tan Li Wei'), findsOneWidget);
      expect(find.text('Ryan'), findsOneWidget);
    });
  });
}