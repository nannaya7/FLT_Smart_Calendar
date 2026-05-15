import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/holiday.dart';

class HolidayApiService {
  final _client = http.Client();
  static const _buildTimeApiKey = String.fromEnvironment(
    'HOLIDAY_API_KEY',
    defaultValue: '',
  );
  static const apiKeyPrefsKey = 'holiday_api_key';
  static const _base =
      'https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService';

  bool get hasBuildTimeApiKey => _buildTimeApiKey.trim().isNotEmpty;

  Future<bool> hasApiKey() async => (await getApiKey()).isNotEmpty;

  Future<String> getApiKey() async {
    final buildTimeApiKey = _buildTimeApiKey.trim();
    if (buildTimeApiKey.isNotEmpty) return buildTimeApiKey;

    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(apiKeyPrefsKey) ?? '').trim();
  }

  Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(apiKeyPrefsKey, apiKey.trim());
  }

  /// [year] 년도 기념일, 공휴일, 국경일, 24절기 전체 목록 반환
  Future<List<Holiday>> fetchAllSpecialDays(int year) async {
    final results = await Future.wait([
      fetchAnniversaries(year),
      fetchRestDays(year),
      fetchNationalHolidays(year),
      fetchSolarTerms(year),
    ]);
    return results.expand((items) => items).toList();
  }

  /// [year] 년도 기념일 목록 반환
  Future<List<Holiday>> fetchAnniversaries(int year) =>
      _fetch(endpoint: 'getAnniversaryInfo', year: year, type: 'anniversary');

  /// [year] 년도 공휴일 목록 반환
  Future<List<Holiday>> fetchRestDays(int year) =>
      _fetch(endpoint: 'getRestDeInfo', year: year, type: 'rest_day');

  /// [year] 년도 국경일 목록 반환
  Future<List<Holiday>> fetchNationalHolidays(int year) =>
      _fetch(endpoint: 'getHoliDeInfo', year: year, type: 'national_holiday');

  /// [year] 년도 24절기 목록 반환
  Future<List<Holiday>> fetchSolarTerms(int year) =>
      _fetch(endpoint: 'get24DivisionsInfo', year: year, type: 'solar_term');

  Future<List<Holiday>> _fetch({
    required String endpoint,
    required int year,
    required String type,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey.isEmpty) return [];

    final uri = Uri.parse('$_base/$endpoint').replace(
      queryParameters: {
        'serviceKey': apiKey,
        'solYear': year.toString(),
        'numOfRows': '100',
        'pageNo': '1',
        '_type': 'json',
      },
    );

    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final body = jsonDecode(res.body);
      final items = body['response']?['body']?['items']?['item'];
      if (items == null) return [];

      // 공공데이터포털 API는 결과가 1건이면 Map, 복수이면 List 반환
      final list = items is List ? items : [items];

      return list.whereType<Map>().map((e) {
        final raw = e['locdate'].toString();
        final date =
            '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}';
        return Holiday(date: date, name: e['dateName'].toString(), type: type);
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
