import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../shared/models/holiday.dart';

/// Google Calendar API — 대한민국 공휴일 캘린더
///
/// API 키는 --dart-define=GOOGLE_CALENDAR_KEY=<키> 로 주입.
/// 키가 없으면 빈 리스트 반환.
class GoogleCalendarService {
  static const _apiKey =
      String.fromEnvironment('GOOGLE_CALENDAR_KEY', defaultValue: '');

  // Google 공개 한국 공휴일 캘린더 ID (URL 인코딩된 형태)
  static const _calendarId =
      'ko.south_korea%23holiday%40group.v.calendar.google.com';

  static const _base =
      'https://www.googleapis.com/calendar/v3/calendars/$_calendarId/events';

  Future<List<Holiday>> fetchHolidays(int year) async {
    if (_apiKey.isEmpty) return [];

    final uri = Uri.parse(_base).replace(queryParameters: {
      'key': _apiKey,
      'timeMin': '$year-01-01T00:00:00Z',
      'timeMax': '$year-12-31T23:59:59Z',
      'singleEvents': 'true',
      'orderBy': 'startTime',
      'maxResults': '200',
    });

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final body = jsonDecode(res.body);
      final items = body['items'] as List?;
      if (items == null) return [];

      final holidays = <Holiday>[];
      for (final item in items) {
        final startStr = item['start']?['date'] as String?;
        final endStr = item['end']?['date'] as String?;
        final name = (item['summary'] as String? ?? '').trim();
        if (startStr == null || name.isEmpty) continue;

        // Google은 종료일을 exclusive로 반환 (마지막 날 다음날)
        // 예: 설날연휴 start=01-28, end=01-31 → 28, 29, 30 각각 등록
        var current = DateTime.parse(startStr);
        final end = endStr != null
            ? DateTime.parse(endStr)
            : current.add(const Duration(days: 1));

        while (current.isBefore(end)) {
          final dateKey =
              '${current.year}-${current.month.toString().padLeft(2, '0')}'
              '-${current.day.toString().padLeft(2, '0')}';
          holidays.add(Holiday(date: dateKey, name: name, type: 'holiday'));
          current = current.add(const Duration(days: 1));
        }
      }
      return holidays;
    } catch (_) {
      return [];
    }
  }
}
