import 'package:flutter/material.dart';
import 'core/notifications/notification_service.dart';
import 'features/calendar/calendar_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
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
