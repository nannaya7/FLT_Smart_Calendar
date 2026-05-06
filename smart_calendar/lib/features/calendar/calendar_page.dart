import 'package:flutter/material.dart';
import 'package:korean_lunar_utils/korean_lunar_utils.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  static const _months = [
    '1월', '2월', '3월', '4월',
    '5월', '6월', '7월', '8월',
    '9월', '10월', '11월', '12월',
  ];

  // 양력 → 음력 변환 (월·일 형식 반환)
  String _lunarLabel(DateTime d) {
    final lunar = LunarSolarConverter.convertSolarToLunar(d);
    return '${lunar.month}·${lunar.day}';
  }

  String get _seasonText {
    final m = _focusedDay.month;
    if (m >= 3 && m <= 5) return '봄이 살랑살랑...';
    if (m >= 6 && m <= 8) return '여름이 활짝...';
    if (m >= 9 && m <= 11) return '가을이 물들어...';
    return '겨울이 꿈꾸고...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A7272), Color(0xFFCC7840)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(child: _buildCalendar()),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ── 헤더 (월/년/계절 문구 + 이전/다음 버튼) ──────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 왼쪽: 월, 연도, 계절 메시지
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _months[_focusedDay.month - 1],
                  style: const TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5C2A10),
                    height: 1.0,
                  ),
                ),
                Text(
                  '${_focusedDay.year}',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5C2A10),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _seasonText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF5C2A10),
                  ),
                ),
              ],
            ),
          ),
          // 오른쪽: 이전/다음 버튼
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _NavButton(
                label: '이전 달',
                onTap: () => setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
                }),
              ),
              const SizedBox(height: 10),
              _NavButton(
                label: '다음 달',
                isAccented: true,
                onTap: () => setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 달력 카드 ────────────────────────────────────────────────────────────────

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0x80203C3C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            });
          },
          onPageChanged: (focused) => setState(() => _focusedDay = focused),
          headerVisible: false,
          startingDayOfWeek: StartingDayOfWeek.sunday,
          rowHeight: 60,
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: false,
            cellMargin: EdgeInsets.zero,
            cellPadding: EdgeInsets.zero,
          ),
          calendarBuilders: CalendarBuilders(
            // 요일 헤더
            dowBuilder: (context, day) {
              const names = {
                1: '월', 2: '화', 3: '수',
                4: '목', 5: '금', 6: '토', 7: '일',
              };
              final isSun = day.weekday == DateTime.sunday;
              final isSat = day.weekday == DateTime.saturday;
              return Container(
                color: const Color(0xFF1B3A3A),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  names[day.weekday] ?? '',
                  style: TextStyle(
                    color: isSun
                        ? const Color(0xFFFF7070)
                        : isSat
                            ? const Color(0xFF70A8FF)
                            : Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              );
            },
            // 일반 날짜
            defaultBuilder: (context, day, _) => _dayCell(day),
            // 오늘
            todayBuilder: (context, day, _) =>
                _dayCell(day, isToday: true),
            // 선택된 날짜
            selectedBuilder: (context, day, _) =>
                _dayCell(day, isSelected: true),
          ),
        ),
      ),
    );
  }

  // ── 날짜 셀 (양력 + 음력) ────────────────────────────────────────────────────

  Widget _dayCell(DateTime day,
      {bool isSelected = false, bool isToday = false}) {
    final isSun = day.weekday == DateTime.sunday;
    final isSat = day.weekday == DateTime.saturday;

    final Color textColor = isSun
        ? const Color(0xFFFF7070)
        : isSat
            ? const Color(0xFF70A8FF)
            : Colors.white;

    return Center(
      child: Container(
        width: 42,
        height: 54,
        decoration: isSelected
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white70, width: 1.5),
              )
            : isToday
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                  )
                : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _lunarLabel(day),
              style: TextStyle(
                color: textColor.withValues(alpha: 0.55),
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 네비게이션 버튼 ──────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isAccented;

  const _NavButton({
    required this.label,
    required this.onTap,
    this.isAccented = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        decoration: BoxDecoration(
          color: isAccented
              ? const Color(0xFFE8C090)
              : const Color(0xFFF2E8D8),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF3D1E0A),
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
