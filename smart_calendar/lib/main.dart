import 'dart:async';

import 'package:flutter/material.dart';
import 'core/notifications/notification_service.dart';
import 'features/calendar/calendar_page.dart';

void main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  binding.deferFirstFrame();

  final splashDelay = Future<void>.delayed(const Duration(seconds: 1));
  await NotificationService.instance.init();

  runApp(const SmartCalendarApp());
  await splashDelay;
  binding.allowFirstFrame();
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
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: TextScaler.noScaling),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const CalendarPage(),
    );
  }
}
