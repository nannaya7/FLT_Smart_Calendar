import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../shared/models/holiday.dart';

/// 공공데이터포털 한국천문연구원 특일 정보 API 래퍼
///
/// API 키는 빌드 시 --dart-define=HOLIDAY_API_KEY=<디코딩된_키> 로 주입.
/// 키가 없으면 모든 메서드가 빈 리스트를 반환(앱은 정상 동작).
class HolidayApiService {
  static const _apiKey =
      String.fromEnvironment('HOLIDAY_API_KEY', defaultValue: '');
  static const _base =
      'https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService';

  /// [year] 년도 공휴일 목록 반환
  Future<List<Holiday>> fetchHolidays(int year) =>
      _fetch(endpoint: 'getHoliDeInfo', year: year, type: 'holiday');

  /// [year] 년도 24절기 목록 반환
  Future<List<Holiday>> fetchSolarTerms(int year) =>
      _fetch(endpoint: 'get24DivisionsInfo', year: year, type: 'solar_term');

  Future<List<Holiday>> _fetch({
    required String endpoint,
    required int year,
    required String type,
  }) async {
    if (_apiKey.isEmpty) return [];

    final uri = Uri.parse('$_base/$endpoint').replace(queryParameters: {
      'serviceKey': _apiKey,
      'solYear': year.toString(),
      'numOfRows': '100',
      'pageNo': '1',
      '_type': 'json',
    });

    try {
      final res =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final body = jsonDecode(res.body);
      final items = body['response']?['body']?['items']?['item'];
      if (items == null) return [];

      // 공공데이터포털 API는 결과가 1건이면 Map, 복수이면 List 반환
      final list = items is List ? items : [items];

      return list
          .where((e) => type == 'solar_term' || e['isHoliday'] == 'Y')
          .map((e) {
            final raw = e['locdate'].toString();
            final date =
                '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}';
            return Holiday(
                date: date, name: e['dateName'] as String, type: type);
          })
          .toList();
    } catch (_) {
      return [];
    }
  }
}
