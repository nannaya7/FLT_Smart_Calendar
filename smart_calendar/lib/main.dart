import 'package:flutter/material.dart';
import 'features/calendar/calendar_page.dart';

void main() {
  runApp(const SmartCalendarApp());
}

class SmartCalendarApp extends StatelessWidget {
  const SmartCalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Calendar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3A7272)),
        useMaterial3: true,
      ),
      home: const CalendarPage(),
    );
  }
}
