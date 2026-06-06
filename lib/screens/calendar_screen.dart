// screens/calendar_screen.dart
import 'package:flutter/material.dart';
import './workout_calendar.dart'; // Adjust import path if necessary
import './AthleteDashboard.dart'; // For AppColors and potentially other theme constants

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Calendar'),
        backgroundColor: AppColors.cardBackground, // Use your custom app bar background
        foregroundColor: AppColors.textDark, // Use your custom app bar text color
        elevation: 0,
      ),
      body: const WorkoutCalendar(), // Your WorkoutCalendar is now correctly placed inside a Scaffold
      backgroundColor: AppColors.backgroundLightGrey, // Use your custom background color
    );
  }
}