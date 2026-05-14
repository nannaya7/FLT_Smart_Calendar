import 'package:flutter/material.dart';

import '../../core/calendar_engine.dart';
import '../../core/db/database_helper.dart';
import '../../core/notifications/notification_service.dart';
import '../../shared/models/schedule.dart';

enum _Alarm {
  none('없음', null),
  onTime('정시', 0),
  ten('10분 전', 10),
  fifteen('15분 전', 15),
  thirty('30분 전', 30),
  hour('1시간 전', 60),
  day('하루 전', 1440);

  final String label;
  final int? minutes;
  const _Alarm(this.label, this.minutes);
}

enum _Repeat {
  none('없음'),
  daily('매일'),
  weekly('매주'),
  monthly('매월'),
  yearly('매년');

  final String label;
  const _Repeat(this.label);

  String? get value => this == none ? null : name;
}

class ScheduleFormSheet extends StatefulWidget {
  final DateTime date;
  final Schedule? initialSchedule;

  const ScheduleFormSheet({
    super.key,
    required this.date,
    this.initialSchedule,
  });

  @override
  State<ScheduleFormSheet> createState() => _ScheduleFormSheetState();
}

class _ScheduleFormSheetState extends State<ScheduleFormSheet> {
  final _titleCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();

  TimeOfDay? _startTime;
  _Alarm _alarm = _Alarm.fifteen;
  _Repeat _repeat = _Repeat.none;
  bool _isLunar = false;
  late int _lunarMonth;
  late int _lunarDay;
  bool _saving = false;
  bool _alarmExpanded = false;
  bool _repeatExpanded = false;
  int _selectedColor = _palette.first;

  // 일정 추가 카드 전체의 주요 색상입니다. 버튼/선택 상태 색을 바꾸려면 _accent를 수정하세요.
  static const _accent = Color(0xFFFF8999);
  static const _text = Color(0xFF202124);
  static const _muted = Color(0xFF9EA2A8);
  static const _fieldBorder = Color(0xFFE8E1DF);
  // 색상 선택 팔레트입니다. 저장된 일정 제목의 폰트색으로 사용됩니다.
  static const _palette = [
    0xFFFF8999,
    0xFF83C8AA,
    0xFFB48BD0,
    0xFFE9B174,
    0xFF8CB4E8,
  ];

  bool get _isEditing => widget.initialSchedule != null;

  @override
  void initState() {
    super.initState();
    final lunar = CalendarEngine.instance.solarToLunar(widget.date);
    _lunarMonth = lunar.month;
    _lunarDay = lunar.day;

    final s = widget.initialSchedule;
    if (s != null) {
      _titleCtrl.text = s.title;
      _memoCtrl.text = s.memo ?? '';
      _isLunar = s.isLunar;
      _selectedColor = s.categoryColor;
      if (s.lunarMonth != null) _lunarMonth = s.lunarMonth!;
      if (s.lunarDay != null) _lunarDay = s.lunarDay!;
      _startTime = _parseTime(s.time);
      _alarm = _Alarm.values.firstWhere(
        (a) => a.minutes == s.alarmMinutesBefore,
        orElse: () => _Alarm.none,
      );
      _repeat = _Repeat.values.firstWhere(
        (r) => r.value == s.repeatType,
        orElse: () => _Repeat.none,
      );
    } else {
      // 새 일정을 열었을 때 기본 시작 시간입니다.
      _startTime = const TimeOfDay(hour: 10, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  static TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String? _formatTimeForStorage(TimeOfDay? time) {
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() => _startTime = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);

    try {
      final startTime = _formatTimeForStorage(_startTime);
      final schedule = Schedule(
        id: widget.initialSchedule?.id,
        title: title,
        memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
        location: null,
        solarDate: _fmtDate(widget.date),
        time: startTime,
        endTime: null,
        isLunar: _isLunar,
        alarmMinutesBefore: _alarm.minutes,
        categoryColor: _selectedColor,
        repeatType: _repeat.value,
        lunarMonth: _isLunar ? _lunarMonth : null,
        lunarDay: _isLunar ? _lunarDay : null,
      );

      int id;
      if (_isEditing) {
        await DatabaseHelper.instance.updateSchedule(schedule);
        id = schedule.id!;
        if (widget.initialSchedule!.alarmMinutesBefore != null) {
          await NotificationService.instance.cancel(id);
        }
      } else {
        id = await DatabaseHelper.instance.insertSchedule(schedule);
      }

      if (_alarm.minutes != null && _startTime != null) {
        final notifyAt = DateTime(
          widget.date.year,
          widget.date.month,
          widget.date.day,
          _startTime!.hour,
          _startTime!.minute,
        ).subtract(Duration(minutes: _alarm.minutes!));
        await NotificationService.instance.schedule(
          id: id,
          title: title,
          at: notifyAt,
          repeatType: _repeat.value,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _dateLabel(DateTime d) {
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.year}. ${d.month}. ${d.day} (${wd[d.weekday - 1]})';
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 390;

    // 키보드가 올라올 때 카드가 자연스럽게 위로 이동하도록 감싸는 영역입니다.
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SizedBox(
        height: size.height,
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            // 화면 가장자리와 일정 추가 카드 사이의 바깥 여백입니다.
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              // 일정 추가 카드의 최대 너비입니다. 큰 화면에서 너무 넓어지는 것을 막습니다.
              constraints: const BoxConstraints(maxWidth: 640),
              child: Container(
                // 일정 추가 카드 내부 여백입니다. 작은 화면과 큰 화면 값을 따로 둡니다.
                padding: EdgeInsets.fromLTRB(
                  compact ? 20 : 30,
                  compact ? 20 : 28,
                  compact ? 20 : 30,
                  compact ? 20 : 28,
                ),
                decoration: BoxDecoration(
                  // 일정 추가 카드 배경색과 투명도입니다.
                  color: Colors.white.withValues(alpha: 0.96),
                  // 일정 추가 카드 모서리 둥글기입니다.
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      // 일정 추가 카드 그림자입니다.
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 34,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 상단 제목과 닫기 버튼 영역입니다.
                    Row(
                      children: [
                        Text(
                          _isEditing ? '일정 수정' : '일정 추가',
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _text,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close, size: 28),
                          color: const Color(0xFF4C4F55),
                          tooltip: '닫기',
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    // 제목 입력 영역입니다.
                    _formField(
                      label: '제목',
                      child: _plainInput(
                        controller: _titleCtrl,
                        hint: '일정 제목을 입력하세요',
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 날짜 표시 영역입니다. 현재는 선택한 날짜를 보여주기만 합니다.
                    _formField(
                      label: '날짜',
                      trailing: const Icon(
                        Icons.calendar_month_outlined,
                        size: 22,
                        color: Color(0xFF555B63),
                      ),
                      child: Text(
                        _dateLabel(widget.date),
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 17,
                          color: _text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 양력/음력 기준 선택 영역입니다.
                    _calendarModeSelector(),
                    const SizedBox(height: 10),
                    // 시작 시간 선택 영역입니다.
                    _timeRow(),
                    const SizedBox(height: 10),
                    // 일정 제목에 적용할 색상 선택 영역입니다.
                    _colorSelector(),
                    const SizedBox(height: 10),
                    // 반복 주기 선택 영역입니다. 월별/년별 반복도 여기에서 선택합니다.
                    _repeatSelector(),
                    const SizedBox(height: 10),
                    // 알림 시간 선택 영역입니다.
                    _alarmSelector(),
                    const SizedBox(height: 10),
                    // 내용 입력 영역입니다.
                    _formField(
                      label: '내용',
                      minHeight: 92,
                      alignment: Alignment.topLeft,
                      child: _plainInput(
                        controller: _memoCtrl,
                        hint: '내용을 입력하세요',
                        maxLines: 3,
                      ),
                    ),
                    const SizedBox(height: 22),
                    // 하단 취소/저장 버튼 영역입니다.
                    Row(
                      children: [
                        Expanded(
                          child: _bottomButton(
                            label: '취소',
                            onTap: () => Navigator.of(context).pop(false),
                            filled: false,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _bottomButton(
                            label: '저장',
                            onTap: _saving ? null : _save,
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeRow() {
    return Container(
      // 시간 입력 박스의 최소 높이입니다.
      constraints: const BoxConstraints(minHeight: 48),
      // 시간 입력 박스 내부 여백입니다.
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _fieldBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            // 왼쪽 라벨 영역 너비입니다. 제목/날짜/내용 입력칸과 맞추려면 이 값을 조절하세요.
            width: 78,
            child: Text(
              '시간',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _text,
              ),
            ),
          ),
          Expanded(
            child: _timeButton(
              text: _startTime?.format(context) ?? '시간 없음',
              onTap: _pickTime,
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendarModeSelector() {
    return Row(
      children: [
        const SizedBox(
          // 기준 라벨 영역 너비입니다. 다른 행의 라벨 너비와 맞추는 값입니다.
          width: 94,
          child: Padding(
            padding: EdgeInsets.only(left: 15),
            child: Text(
              '기준',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _text,
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            // 양력/음력 선택 컨트롤 높이입니다.
            height: 38,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _modeButton(
                    label: '양력',
                    selected: !_isLunar,
                    onTap: () => setState(() => _isLunar = false),
                  ),
                ),
                Expanded(
                  child: _modeButton(
                    label: '음력',
                    selected: _isLunar,
                    onTap: () => setState(() => _isLunar = true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _modeButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        // 양력/음력 선택 시 배경 전환 속도입니다.
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? _accent : const Color(0xFF6C737C),
          ),
        ),
      ),
    );
  }

  Widget _timeButton({required String text, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFFFBFBFC),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          // 시간 버튼 높이입니다.
          height: 36,
          // 시간 버튼 내부 좌우 여백입니다.
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    text,
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      color: _text,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formField({
    required String label,
    required Widget child,
    Widget? trailing,
    VoidCallback? onTap,
    double minHeight = 48,
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          // 공통 입력 박스의 최소 높이입니다.
          constraints: BoxConstraints(minHeight: minHeight),
          // 공통 입력 박스 내부 여백입니다.
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _fieldBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: minHeight > 60
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              SizedBox(
                // 공통 입력 박스 왼쪽 라벨 영역 너비입니다.
                width: 78,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
              ),
              Expanded(
                child: Align(alignment: alignment, child: child),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
        ),
      ),
    );
  }

  Widget _plainInput({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        // 입력 텍스트 폰트 크기입니다.
        fontFamily: 'Pretendard',
        fontSize: 16,
        color: _text,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Pretendard',
          color: _muted,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _colorSelector() {
    return Row(
      children: [
        const SizedBox(
          // 색상 라벨 영역 너비입니다.
          width: 94,
          child: Padding(
            padding: EdgeInsets.only(left: 15),
            child: Text(
              '색상',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _text,
              ),
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            // 색상 원 사이의 가로/세로 간격입니다.
            spacing: 14,
            runSpacing: 8,
            children: _palette.map((color) {
              final selected = _selectedColor == color;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: AnimatedContainer(
                  // 색상 원 선택 애니메이션 속도입니다.
                  duration: const Duration(milliseconds: 160),
                  // 색상 원 크기입니다.
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Color(color),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(color).withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: selected
                      // 선택된 색상에 표시되는 체크 아이콘입니다.
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _alarmSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _fieldBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _alarmExpanded = !_alarmExpanded),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 78,
                    child: Text(
                      '알림',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _text,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _alarm.label,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        color: _text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _alarmExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down, size: 24),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _alarmExpanded
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(height: 1, indent: 14, endIndent: 14),
                      ..._Alarm.values.map(_alarmOption),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _alarmOption(_Alarm a) {
    final selected = _alarm == a;
    final icon = switch (a) {
      _Alarm.none  => Icons.notifications_off_outlined,
      _Alarm.onTime => Icons.notifications_outlined,
      _Alarm.ten   => Icons.alarm,
      _Alarm.fifteen => Icons.alarm,
      _Alarm.thirty => Icons.alarm,
      _Alarm.hour  => Icons.alarm,
      _Alarm.day   => Icons.wb_twilight,
    };
    return InkWell(
      onTap: () => setState(() {
        _alarm = a;
        _alarmExpanded = false;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? _accent : _muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                a.label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? _accent : _text,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_rounded, size: 18, color: _accent),
          ],
        ),
      ),
    );
  }

  Widget _repeatSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _fieldBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _repeatExpanded = !_repeatExpanded),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 78,
                    child: Text(
                      '반복',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _text,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _repeat.label,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        color: _text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _repeatExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down, size: 24),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _repeatExpanded
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(height: 1, indent: 14, endIndent: 14),
                      ..._Repeat.values.map(_repeatOption),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _repeatOption(_Repeat r) {
    final selected = _repeat == r;
    final icon = switch (r) {
      _Repeat.none    => Icons.remove_circle_outline,
      _Repeat.daily   => Icons.loop,
      _Repeat.weekly  => Icons.date_range,
      _Repeat.monthly => Icons.calendar_month,
      _Repeat.yearly  => Icons.event_repeat,
    };
    return InkWell(
      onTap: () => setState(() {
        _repeat = r;
        _repeatExpanded = false;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? _accent : _muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                r.label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? _accent : _text,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_rounded, size: 18, color: _accent),
          ],
        ),
      ),
    );
  }

  Widget _bottomButton({
    required String label,
    required VoidCallback? onTap,
    required bool filled,
  }) {
    return SizedBox(
      // 취소/저장 버튼 높이입니다.
      height: 58,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: filled ? _accent : Colors.white,
          disabledBackgroundColor: _accent.withValues(alpha: 0.55),
          foregroundColor: filled ? Colors.white : _text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: filled
                ? BorderSide.none
                : const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: _saving && filled
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
