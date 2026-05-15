import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/api/holiday_api_service.dart';
import '../../core/calendar_engine.dart';
import '../../core/db/database_helper.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/repeat_schedule_helper.dart';
import '../../shared/models/holiday.dart';
import '../../shared/models/schedule.dart';
import '../schedule/schedule_form_sheet.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  // ── 상태 ────────────────────────────────────────────────────────────────────

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  int _monthTransitionDirection = 1;
  bool _apiKeyPromptShown = false;
  bool _isActionBarVisible = false;
  double _verticalSwipeDelta = 0;
  bool _actionBarSwipeHandled = false;
  String? _customBackgroundPath;

  Map<String, int> _scheduleCounts = {};
  List<Schedule> _selectedDaySchedules = [];

  /// 정보 패널용 특일 맵 (기념일 포함)
  final Map<String, Holiday> _holidays = {};

  /// 달력 셀용 특일 맵 (기념일 제외)
  final Map<String, Holiday> _calendarHolidays = {};
  final Set<int> _loadedHolidayYears = {};

  final _engine = CalendarEngine.instance;
  final _apiService = HolidayApiService();

  // ── 상수 ────────────────────────────────────────────────────────────────────

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _monthImages = [
    'image/01_JAN.png',
    'image/02_FEB.png',
    'image/03_MAR.png',
    'image/04_APR.png',
    'image/05_MAY.png',
    'image/06_JUN.png',
    'image/07_JUL.png',
    'image/08_AUG.png',
    'image/09_SEP.png',
    'image/10_OCT.png',
    'image/11_NOV.png',
    'image/12_DEC.png',
  ];

  static const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

  // ── 유틸 ────────────────────────────────────────────────────────────────────

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static int _monthIndex(DateTime d) => d.year * 12 + d.month;

  String get _monthPageKey => '${_focusedDay.year}-${_focusedDay.month}';

  String get _focusedMonthBackgroundKey =>
      _monthBackgroundKey(_focusedDay.year, _focusedDay.month);

  static String _monthBackgroundKey(int year, int month) =>
      'month_background_${year}_${month.toString().padLeft(2, '0')}';

  // ── 라이프사이클 ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadSchedules(_focusedDay);
    _loadHolidays(_focusedDay.year);
    _loadMonthBackground(_focusedDay);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait(
        _monthImages.map((p) => precacheImage(AssetImage(p), context)),
      );
      if (!mounted) return;
      NotificationService.instance.requestAndroidPermission();
      if (!_apiService.hasBuildTimeApiKey) await _ensureHolidayApiKey();
      await _refreshHolidaysIfNeeded();
    });
  }

  // ── 공휴일 로딩 ─────────────────────────────────────────────────────────────

  Future<void> _refreshHolidaysIfNeeded() async {
    if (!await _apiService.hasApiKey()) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final initialized = prefs.getBool('holiday_initialized') ?? false;
    if (!initialized) {
      await Future.wait([
        _loadHolidays(now.year, forceRefresh: true),
        _loadHolidays(now.year + 1, forceRefresh: true),
      ]);
      await prefs.setBool('holiday_initialized', true);
      return;
    }

    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    if (now.day != lastDay) return;

    final refreshKey = 'holiday_refreshed_${now.year}_${now.month}';
    if (prefs.getBool(refreshKey) ?? false) return;

    final nextYear = DateTime(now.year, now.month + 1).year;
    await _loadHolidays(nextYear, forceRefresh: true);
    await prefs.setBool(refreshKey, true);
  }

  Future<void> _ensureHolidayApiKey() async {
    if (_apiKeyPromptShown || await _apiService.hasApiKey()) return;
    if (!mounted) return;
    _apiKeyPromptShown = true;

    final key = await _showApiKeyDialog();
    if (key == null || key.isEmpty) return;

    await _apiService.saveApiKey(key);
    final now = DateTime.now();
    await Future.wait([
      _loadHolidays(now.year, forceRefresh: true),
      _loadHolidays(now.year + 1, forceRefresh: true),
    ]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('holiday_initialized', true);
  }

  Future<String?> _showApiKeyDialog() async {
    final ctrl = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('특일 API 키 입력'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(hintText: '공공데이터포털 일반 인증키'),
            minLines: 1,
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('나중에'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
              child: const Text('저장'),
            ),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _loadHolidays(int year, {bool forceRefresh = false}) async {
    if (!forceRefresh && _loadedHolidayYears.contains(year)) return;

    if (forceRefresh) {
      await DatabaseHelper.instance.clearHolidaysByYear(year);
      _loadedHolidayYears.remove(year);
    }

    final cached = await DatabaseHelper.instance.getHolidaysByYear(year);
    List<Holiday> all;
    if (cached.isNotEmpty) {
      all = cached;
    } else {
      all = await _apiService.fetchAllSpecialDays(year);
      if (all.isNotEmpty) await DatabaseHelper.instance.insertHolidays(all);
    }

    if (!mounted) return;
    setState(() {
      final prefix = '$year-';
      _holidays.removeWhere((k, _) => k.startsWith(prefix));
      _calendarHolidays.removeWhere((k, _) => k.startsWith(prefix));
      for (final h in all) {
        Holiday.insertPriority(_holidays, h);
        if (!h.isAnniversary) Holiday.insertPriority(_calendarHolidays, h);
      }
      _loadedHolidayYears.add(year);
    });
  }

  // ── 일정 로딩 ───────────────────────────────────────────────────────────────

  Future<void> _loadSchedules(DateTime month) async {
    final ym = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final list = await DatabaseHelper.instance.getSchedulesByMonth(ym);
    final repeats = await DatabaseHelper.instance.getAllRepeatSchedules();
    if (!mounted) return;

    final counts = <String, int>{};
    for (final s in list) {
      if (s.repeatType != null) continue;
      counts[s.solarDate] = (counts[s.solarDate] ?? 0) + 1;
    }
    for (final s in repeats) {
      for (final key in RepeatScheduleHelper.datesInMonth(s, month, _engine)) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    setState(() => _scheduleCounts = counts);
  }

  Future<void> _loadSelectedDaySchedules(DateTime day) async {
    final regular = await DatabaseHelper.instance.getSchedulesByDate(
      _dateKey(day),
    );
    final ids = regular.map((s) => s.id).toSet();
    final repeats = await DatabaseHelper.instance.getAllRepeatSchedules();
    final matching = repeats.where(
      (s) =>
          RepeatScheduleHelper.matchesDay(s, day, _engine) &&
          !ids.contains(s.id),
    );
    if (!mounted) return;
    setState(() => _selectedDaySchedules = [...regular, ...matching]);
  }

  // ── 월별 배경 이미지 ─────────────────────────────────────────────────────────

  Future<void> _loadMonthBackground(DateTime month) async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_monthBackgroundKey(month.year, month.month));
    final validPath = (path != null && await File(path).exists()) ? path : null;
    if (!mounted) return;
    setState(() => _customBackgroundPath = validPath);
  }

  Future<void> _openBackgroundPicker() async {
    _hideActionBar();
    final action = await showModalBottomSheet<_BackgroundAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _BackgroundPickerSheet(
        year: _focusedDay.year,
        month: _focusedDay.month,
      ),
    );

    if (action == null) return;
    switch (action) {
      case _BackgroundAction.photo:
        await _pickMonthBackgroundPhoto();
      case _BackgroundAction.defaultImage:
        await _resetMonthBackground();
    }
  }

  Future<void> _pickMonthBackgroundPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (picked == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final backgroundsDir = Directory(p.join(dir.path, 'month_backgrounds'));
      if (!await backgroundsDir.exists()) {
        await backgroundsDir.create(recursive: true);
      }

      final extension = p.extension(picked.path).isEmpty
          ? '.jpg'
          : p.extension(picked.path);
      final fileName =
          '${_focusedDay.year}_${_focusedDay.month.toString().padLeft(2, '0')}_'
          '${DateTime.now().millisecondsSinceEpoch}$extension';
      final savedPath = p.join(backgroundsDir.path, fileName);
      await File(picked.path).copy(savedPath);

      final prefs = await SharedPreferences.getInstance();
      final previousPath = prefs.getString(_focusedMonthBackgroundKey);
      await prefs.setString(_focusedMonthBackgroundKey, savedPath);

      if (previousPath != null && previousPath != savedPath) {
        final previousFile = File(previousPath);
        if (await previousFile.exists()) await previousFile.delete();
      }

      if (!mounted) return;
      setState(() => _customBackgroundPath = savedPath);
      _showBarMessage('배경 사진을 적용했습니다');
    } catch (e) {
      if (!mounted) return;
      _showBarMessage('사진을 적용하지 못했습니다');
    }
  }

  Future<void> _resetMonthBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final previousPath = prefs.getString(_focusedMonthBackgroundKey);
    await prefs.remove(_focusedMonthBackgroundKey);

    if (previousPath != null) {
      final previousFile = File(previousPath);
      if (await previousFile.exists()) await previousFile.delete();
    }

    if (!mounted) return;
    setState(() => _customBackgroundPath = null);
    _showBarMessage('기본 배경으로 변경했습니다');
  }

  // ── 이벤트 핸들러 ────────────────────────────────────────────────────────────

  Future<void> _onDayTap(DateTime selected, DateTime focused) async {
    setState(() {
      _selectedDay = selected;
      _focusedDay = focused;
    });
    await _loadSelectedDaySchedules(selected);
  }

  void _showActionBar() {
    if (_isActionBarVisible) return;
    setState(() => _isActionBarVisible = true);
  }

  void _hideActionBar() {
    if (!_isActionBarVisible) return;
    setState(() => _isActionBarVisible = false);
  }

  void _resetActionBarSwipe() {
    _verticalSwipeDelta = 0;
    _actionBarSwipeHandled = false;
  }

  void _handleActionBarVerticalDragUpdate(DragUpdateDetails details) {
    if (_actionBarSwipeHandled) return;

    _verticalSwipeDelta += details.primaryDelta ?? 0;
    if (_verticalSwipeDelta.abs() < 28) return;

    _actionBarSwipeHandled = true;
    if (_verticalSwipeDelta < 0) {
      _showActionBar();
    } else {
      _hideActionBar();
    }
  }

  Future<void> _openMonthlyScheduleSheet() async {
    _hideActionBar();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MonthlyScheduleSheet(
        month: _focusedDay,
        holidays: _holidays,
        engine: _engine,
      ),
    );
  }

  void _showBarMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  void _showInfoOverlay() {
    _hideActionBar();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _AppInfoPage()),
    );
  }

  Future<void> _openAddForm() async {
    if (_selectedDay == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleFormSheet(date: _selectedDay!),
    );
    if (mounted && _selectedDay != null) {
      await _loadSelectedDaySchedules(_selectedDay!);
      _loadSchedules(_focusedDay);
    }
  }

  Future<void> _openEditForm(Schedule s) async {
    final date = DateTime.parse(s.solarDate);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleFormSheet(date: date, initialSchedule: s),
    );
    if (mounted && _selectedDay != null) {
      await _loadSelectedDaySchedules(_selectedDay!);
      _loadSchedules(_focusedDay);
    }
  }

  Future<void> _deleteSchedule(Schedule s) async {
    await DatabaseHelper.instance.deleteSchedule(s.id!);
    if (s.alarmMinutesBefore != null) {
      await NotificationService.instance.cancel(s.id!);
    }
    if (mounted && _selectedDay != null) {
      await _loadSelectedDaySchedules(_selectedDay!);
      _loadSchedules(_focusedDay);
    }
  }

  // ── 빌드 ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final isIncoming = child.key == ValueKey(_monthPageKey);
          final dir = _monthTransitionDirection.toDouble();
          final tween = Tween<Offset>(
            begin: Offset(isIncoming ? dir : -dir, 0),
            end: Offset.zero,
          );
          return ClipRect(
            child: SlideTransition(
              position: tween.animate(animation),
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey(_monthPageKey),
          color: const Color(0xFFF7F8F6),
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final layout = _CalendarLayout.from(constraints);
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragStart: (_) => _resetActionBarSwipe(),
                      onVerticalDragUpdate: _handleActionBarVerticalDragUpdate,
                      onVerticalDragEnd: (_) => _resetActionBarSwipe(),
                      onVerticalDragCancel: _resetActionBarSwipe,
                      child: Stack(
                        children: [
                          _buildHeroBackground(layout),
                          SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  layout.horizontalPadding,
                                  layout.topPadding,
                                  layout.horizontalPadding,
                                  18,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: layout.contentMaxWidth,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildHeader(layout),
                                        SizedBox(height: layout.headerGap),
                                        _buildCalendar(layout),
                                        SizedBox(height: layout.panelGap),
                                        _buildInfoPanel(layout),
                                        const SizedBox(height: 22),
                                        _buildFooter(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _buildSwipeActionBar(layout),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 배경 히어로 ─────────────────────────────────────────────────────────────

  ImageProvider _heroBackgroundImage() {
    final path = _customBackgroundPath;
    if (path != null) return FileImage(File(path));
    return AssetImage(_monthImages[_focusedDay.month - 1]);
  }

  Widget _buildHeroBackground(_CalendarLayout layout) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: layout.heroHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3F8),
            image: DecorationImage(
              image: _heroBackgroundImage(),
              fit: BoxFit.cover,
              alignment: _customBackgroundPath != null
                  ? Alignment.center
                  : Alignment.topCenter,
              colorFilter: const ColorFilter.mode(
                Color(0x1AFFFFFF),
                BlendMode.screen,
              ),
            ),
          ),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x1AF2FAFF),
                  Color(0x14F7FBFF),
                  Color(0x08FFFFFF),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 헤더 ────────────────────────────────────────────────────────────────────

  Widget _buildHeader(_CalendarLayout layout) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _glassBox(
          padding: EdgeInsets.symmetric(
            horizontal: layout.glassHorizontalPadding,
            vertical: 4,
          ),
          child: Text(
            '${_focusedDay.month}',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: layout.monthNumberFont,
              height: 0.86,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF2F3135),
            ),
          ),
        ),
        SizedBox(width: layout.headerSideGap),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Align(
              alignment: Alignment.bottomRight,
              child: _glassBox(
                padding: EdgeInsets.symmetric(
                  horizontal: layout.glassHorizontalPadding,
                  vertical: 6,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_focusedDay.year}',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: layout.yearFont,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4D535B),
                        ),
                      ),
                      SizedBox(height: layout.yearMonthGap),
                      Text(
                        _monthNames[_focusedDay.month - 1],
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: layout.monthNameFont,
                          height: 1.0,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF2F3135),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _glassBox({
    required Widget child,
    required EdgeInsetsGeometry padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding,
          color: Colors.white.withValues(alpha: 0.5),
          child: child,
        ),
      ),
    );
  }

  // ── 달력 카드 ────────────────────────────────────────────────────────────────

  Widget _buildCalendar(_CalendarLayout layout) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(DateTime.now().year + 10, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
          onDaySelected: _onDayTap,
          onPageChanged: (focused) {
            final dir = _monthIndex(focused) >= _monthIndex(_focusedDay)
                ? 1
                : -1;
            setState(() {
              _monthTransitionDirection = dir;
              _focusedDay = focused;
              _customBackgroundPath = null;
            });
            _loadSchedules(focused);
            _loadHolidays(focused.year);
            _loadMonthBackground(focused);
          },
          headerVisible: false,
          startingDayOfWeek: StartingDayOfWeek.sunday,
          availableGestures: AvailableGestures.horizontalSwipe,
          rowHeight: layout.calendarRowHeight,
          daysOfWeekHeight: layout.daysOfWeekHeight,
          sixWeekMonthsEnforced: true,
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: true,
            cellMargin: EdgeInsets.zero,
            cellPadding: EdgeInsets.zero,
          ),
          calendarBuilders: CalendarBuilders(
            dowBuilder: (_, day) => _DowCell(day: day, layout: layout),
            defaultBuilder: (_, day, _) => _dayCellWidget(day, layout),
            todayBuilder: (_, day, _) =>
                _dayCellWidget(day, layout, isToday: true),
            selectedBuilder: (_, day, _) =>
                _dayCellWidget(day, layout, isSelected: true),
            outsideBuilder: (_, day, _) =>
                _dayCellWidget(day, layout, isOutside: true),
          ),
        ),
      ),
    );
  }

  _CalendarDayCell _dayCellWidget(
    DateTime day,
    _CalendarLayout layout, {
    bool isSelected = false,
    bool isToday = false,
    bool isOutside = false,
  }) {
    return _CalendarDayCell(
      day: day,
      layout: layout,
      isSelected: isSelected,
      isToday: isToday,
      isOutside: isOutside,
      scheduleCount: _scheduleCounts[_dateKey(day)] ?? 0,
      apiEntry: _calendarHolidays[_dateKey(day)],
      cellInfo: _engine.cellInfo(day),
    );
  }

  // ── 인라인 정보창 ─────────────────────────────────────────────────────────────

  Widget _buildInfoPanel(_CalendarLayout layout) {
    return Container(
      height: layout.infoPanelHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _selectedDay == null ? _panelPlaceholder() : _panelContent(layout),
    );
  }

  Widget _panelPlaceholder() => const Center(
    child: Text(
      '날짜를 선택하면 일정이 표시됩니다',
      style: TextStyle(
        fontFamily: 'Pretendard',
        color: Color(0xFF8A8F98),
        fontSize: 13,
      ),
    ),
  );

  Widget _panelContent(_CalendarLayout layout) {
    final d = _selectedDay!;
    final lunar = _engine.solarToLunar(d);
    final apiEntry = _holidays[_dateKey(d)];
    final cellInfo = _engine.cellInfo(d);

    String? specialLabel;
    Color specialColor = Colors.transparent;
    if (apiEntry != null) {
      specialLabel = apiEntry.name;
      specialColor = _specialDayColor(apiEntry.type);
    } else if (cellInfo.holiday != null) {
      specialLabel = cellInfo.holiday;
      specialColor = const Color(0xFFFF8A65);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            layout.panelHorizontalPadding,
            12,
            layout.panelHorizontalPadding,
            8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          '${d.month}월 ${d.day}일 (${_weekdayNames[d.weekday - 1]})',
                          style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontFamilyFallback: const ['Pretendard'],
                            fontSize: layout.panelDateFont,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3E4248),
                          ),
                        ),
                        Text(
                          '(음) ${lunar.month}월 ${lunar.day}일',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontFamilyFallback: const ['Pretendard'],
                            fontSize: layout.panelSubFont,
                            color: const Color(0xFF7A818C),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (specialLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          specialLabel,
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: layout.panelSubFont,
                            color: specialColor,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _openAddForm,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.addButtonHorizontalPadding,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4F8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+ 일정 추가',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      color: const Color(0xFF3C74D9),
                      fontSize: layout.addButtonFont,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEAECEF)),
        Expanded(
          child: _selectedDaySchedules.isEmpty
              ? const Center(
                  child: Text(
                    '등록된 일정이 없습니다',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      color: Color(0xFF8A8F98),
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _selectedDaySchedules.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFEAECEF)),
                  itemBuilder: (_, i) {
                    final s = _selectedDaySchedules[i];
                    return _ScheduleListItem(
                      schedule: s,
                      onEdit: () => _openEditForm(s),
                      onDelete: () => _deleteSchedule(s),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFooter() => const Center(
    child: Text(
      '오늘도 당신의 하루를 응원합니다',
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 12,
        color: Color(0xFF8A8F98),
      ),
    ),
  );

  Widget _buildSwipeActionBar(_CalendarLayout layout) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: layout.horizontalPadding,
      right: layout.horizontalPadding,
      bottom: bottomPadding + 8,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: layout.actionBarMaxWidth),
          child: IgnorePointer(
            ignoring: !_isActionBarVisible,
            child: AnimatedSlide(
              offset: _isActionBarVisible ? Offset.zero : const Offset(0, 1.15),
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _isActionBarVisible ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: AspectRatio(
                  aspectRatio: 1536 / 346,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset('image/bar/BAR.png', fit: BoxFit.contain),
                      Row(
                        children: [
                          Expanded(
                            child: _BarTapArea(
                              label: '앨범',
                              onTap: _openBackgroundPicker,
                            ),
                          ),
                          Expanded(
                            child: _BarTapArea(
                              label: '일정',
                              onTap: _openMonthlyScheduleSheet,
                            ),
                          ),
                          Expanded(
                            child: _BarTapArea(
                              label: '정보',
                              onTap: _showInfoOverlay,
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
      ),
    );
  }
}

enum _BackgroundAction { photo, defaultImage }

// ── 배경 선택 시트 ────────────────────────────────────────────────────────────

class _BackgroundPickerSheet extends StatelessWidget {
  final int year;
  final int month;

  const _BackgroundPickerSheet({required this.year, required this.month});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8DCE3),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EDE0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    color: Color(0xFFC4936A),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '배경 선택',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF202124),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '캘린더 배경을 변경해 보세요.',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        color: Color(0xFF9EA2A8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _BackgroundActionTile(
              iconBgColor: const Color(0xFFEEEFF2),
              icon: Icons.photo_library_outlined,
              iconColor: const Color(0xFF7A818C),
              title: '사진에서 선택',
              subtitle: '앨범의 사진을 배경으로 설정합니다.',
              onTap: () => Navigator.of(context).pop(_BackgroundAction.photo),
            ),
            const SizedBox(height: 10),
            _BackgroundActionTile(
              iconBgColor: const Color(0xFFFFEAE4),
              icon: Icons.landscape_outlined,
              iconColor: const Color(0xFFD4907A),
              title: '기본 배경 사용',
              subtitle: '내장된 배경 중에서 선택합니다.',
              onTap: () =>
                  Navigator.of(context).pop(_BackgroundAction.defaultImage),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '취소',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF50545C),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _BackgroundActionTile extends StatelessWidget {
  final Color iconBgColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BackgroundActionTile({
    required this.iconBgColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEEEFF2)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        color: Color(0xFF9EA2A8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFBCC0C8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 반응형 레이아웃 값 ────────────────────────────────────────────────────────

class _CalendarLayout {
  final double contentMaxWidth;
  final double horizontalPadding;
  final double topPadding;
  final double heroHeight;
  final double headerGap;
  final double panelGap;
  final double headerSideGap;
  final double glassHorizontalPadding;
  final double yearMonthGap;
  final double monthNumberFont;
  final double yearFont;
  final double monthNameFont;
  final double calendarRowHeight;
  final double daysOfWeekHeight;
  final double dayCellWidth;
  final double dayCellHeight;
  final double dayNumberFont;
  final double daySubFont;
  final double dayDotSize;
  final double dayDotAreaHeight;
  final double dayCellRadius;
  final double infoPanelHeight;
  final double panelHorizontalPadding;
  final double panelDateFont;
  final double panelSubFont;
  final double addButtonFont;
  final double addButtonHorizontalPadding;
  final double actionBarMaxWidth;

  const _CalendarLayout({
    required this.contentMaxWidth,
    required this.horizontalPadding,
    required this.topPadding,
    required this.heroHeight,
    required this.headerGap,
    required this.panelGap,
    required this.headerSideGap,
    required this.glassHorizontalPadding,
    required this.yearMonthGap,
    required this.monthNumberFont,
    required this.yearFont,
    required this.monthNameFont,
    required this.calendarRowHeight,
    required this.daysOfWeekHeight,
    required this.dayCellWidth,
    required this.dayCellHeight,
    required this.dayNumberFont,
    required this.daySubFont,
    required this.dayDotSize,
    required this.dayDotAreaHeight,
    required this.dayCellRadius,
    required this.infoPanelHeight,
    required this.panelHorizontalPadding,
    required this.panelDateFont,
    required this.panelSubFont,
    required this.addButtonFont,
    required this.addButtonHorizontalPadding,
    required this.actionBarMaxWidth,
  });

  factory _CalendarLayout.from(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final compact = width < 370;
    final expanded = width >= 430;
    final horizontalPadding = compact ? 14.0 : (expanded ? 22.0 : 20.0);
    final contentMaxWidth = width >= 500 ? 430.0 : width;
    final effectiveWidth = (width - horizontalPadding * 2)
        .clamp(292.0, contentMaxWidth)
        .toDouble();
    final scale = ((effectiveWidth - 292) / (390 - 292))
        .clamp(0.0, 1.0)
        .toDouble();

    double lerp(double min, double max) => min + (max - min) * scale;

    return _CalendarLayout(
      // 전체 콘텐츠 최대 폭: 큰 화면에서 달력 영역이 너무 넓어지지 않게 제한
      contentMaxWidth: contentMaxWidth,
      // 화면 좌우 기본 여백
      horizontalPadding: horizontalPadding,
      // 상단 SafeArea 아래에서 헤더가 시작되는 위치
      topPadding: compact ? 30 : 44,
      // 월별 배경 이미지 영역 높이
      heroHeight: compact ? 292 : (expanded ? 350 : 330),
      // 헤더와 달력 카드 사이 간격
      headerGap: compact ? 10 : 14,
      // 달력 카드와 일정 정보 패널 사이 간격
      panelGap: compact ? 10 : 12,
      // 왼쪽 월 숫자와 오른쪽 연도/영문 월 사이 간격
      headerSideGap: lerp(10, 16),
      // 헤더 글래스 박스 내부 좌우 여백
      glassHorizontalPadding: lerp(8, 10),
      // 오른쪽 연도와 영문 월 사이 간격
      yearMonthGap: lerp(4, 6),
      // 상단 왼쪽 월 숫자 크기: 작은 화면 65, 큰 화면 80
      monthNumberFont: lerp(71, 91),
      // 상단 오른쪽 연도 글자 크기
      yearFont: lerp(19, 22),
      // 상단 오른쪽 영문 월 글자 크기
      monthNameFont: lerp(27, 33),
      // 달력 날짜 행 높이
      calendarRowHeight: lerp(58, 66),
      // 요일 헤더 행 높이
      daysOfWeekHeight: lerp(32, 38),
      // 날짜 선택/오늘 표시 배경 박스 너비
      dayCellWidth: lerp(37, 43),
      // 날짜 선택/오늘 표시 배경 박스 높이
      dayCellHeight: lerp(54, 62),
      // 날짜 숫자 글자 크기
      dayNumberFont: lerp(18, 22),
      // 날짜 아래 음력/공휴일 텍스트 크기
      daySubFont: lerp(10.5, 13),
      // 일정 표시 점 크기
      dayDotSize: lerp(4, 5),
      // 일정 표시 점이 차지하는 세로 공간
      dayDotAreaHeight: lerp(6, 7),
      // 날짜 선택/오늘 표시 배경 박스 모서리 둥글기
      dayCellRadius: lerp(10, 12),
      // 하단 일정 정보 패널 높이
      infoPanelHeight: compact ? 146 : 152,
      // 일정 정보 패널 내부 좌우 여백
      panelHorizontalPadding: compact ? 14 : 18,
      // 일정 정보 패널의 선택 날짜 글자 크기
      panelDateFont: compact ? 13 : 14,
      // 일정 정보 패널의 음력/특일 보조 글자 크기
      panelSubFont: compact ? 10.5 : 11,
      // '+ 일정 추가' 버튼 글자 크기
      addButtonFont: compact ? 11 : 12,
      // '+ 일정 추가' 버튼 내부 좌우 여백
      addButtonHorizontalPadding: compact ? 10 : 14,
      // 아래에서 올라오는 3버튼 바 최대 폭
      actionBarMaxWidth: expanded ? 430 : contentMaxWidth,
    );
  }
}

// ── 공통 색상 헬퍼 ────────────────────────────────────────────────────────────

Color _specialDayColor(String type) =>
    type == 'rest_day' ? const Color(0xFFFF6E4A) : const Color(0xFF4FA96A);

// ── 요일 헤더 셀 ─────────────────────────────────────────────────────────────

class _DowCell extends StatelessWidget {
  final DateTime day;
  final _CalendarLayout layout;
  const _DowCell({required this.day, required this.layout});

  static const _names = {
    1: 'MON',
    2: 'TUE',
    3: 'WED',
    4: 'THU',
    5: 'FRI',
    6: 'SAT',
    7: 'SUN',
  };

  @override
  Widget build(BuildContext context) {
    final isSun = day.weekday == DateTime.sunday;
    final isSat = day.weekday == DateTime.saturday;
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(vertical: layout.daysOfWeekHeight * 0.18),
      child: Text(
        _names[day.weekday] ?? '',
        style: TextStyle(
          fontFamily: 'Pretendard',
          color: isSun
              ? const Color(0xFFFF3B30)
              : isSat
              ? const Color(0xFF2E73D8)
              : const Color(0xFF50545C),
          fontSize: layout.daySubFont - 3,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── 날짜 셀 ──────────────────────────────────────────────────────────────────

class _CalendarDayCell extends StatelessWidget {
  final DateTime day;
  final _CalendarLayout layout;
  final bool isSelected;
  final bool isToday;
  final bool isOutside;
  final int scheduleCount;
  final Holiday? apiEntry;
  final ({String lunarLabel, String? holiday, bool isSpecial}) cellInfo;

  const _CalendarDayCell({
    required this.day,
    required this.layout,
    required this.scheduleCount,
    required this.apiEntry,
    required this.cellInfo,
    this.isSelected = false,
    this.isToday = false,
    this.isOutside = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSun = day.weekday == DateTime.sunday;
    final isSat = day.weekday == DateTime.saturday;
    final isPublicHoliday = apiEntry?.isPublicHoliday ?? false;

    final dayColor = (isPublicHoliday || isSun)
        ? const Color(0xFFFF3B30)
        : isSat
        ? const Color(0xFF2E73D8)
        : const Color(0xFF2F3135);

    final String subText;
    final Color subColor;
    if (apiEntry != null) {
      subText = apiEntry!.name;
      subColor = _specialDayColor(apiEntry!.type);
    } else if (cellInfo.holiday != null) {
      subText = cellInfo.holiday!;
      subColor = const Color(0xFFFF6E4A);
    } else {
      subText = cellInfo.lunarLabel;
      subColor = cellInfo.isSpecial
          ? const Color(0xFFB8920A)
          : const Color(0xFF656B75);
    }

    return Opacity(
      opacity: isOutside ? 0.28 : 1.0,
      child: Center(
        child: Container(
          width: layout.dayCellWidth,
          height: layout.dayCellHeight,
          decoration: isSelected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(layout.dayCellRadius),
                  color: const Color(0xFFEDEFF5),
                )
              : isToday
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(layout.dayCellRadius),
                  color: const Color(0xFFEAF2FF),
                )
              : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  color: dayColor,
                  fontSize: layout.dayNumberFont,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(
                height: layout.dayDotAreaHeight,
                child: scheduleCount > 0
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          scheduleCount.clamp(1, 3),
                          (_) => Container(
                            width: layout.dayDotSize,
                            height: layout.dayDotSize,
                            margin: const EdgeInsets.symmetric(horizontal: 1.2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF3678CF),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
              Text(
                subText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontFamilyFallback: const ['Pretendard'],
                  color: subColor,
                  fontSize: layout.daySubFont,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 하단 바 터치 영역 ─────────────────────────────────────────────────────────

class _BarTapArea extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BarTapArea({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ── 앱 정보 페이지 ────────────────────────────────────────────────────────────

class _AppInfoPage extends StatelessWidget {
  const _AppInfoPage();

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5EDE6),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5EDE6),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF2F2F2F),
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            '앱 정보',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2F2F2F),
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Image.asset(
                'image/splash/app_info1.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
                errorBuilder: (_, _, _) => Container(
                  height: 220,
                  color: const Color(0xFFEEE0D0),
                  child: const Center(
                    child: Text(
                      '이미지 준비 중',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        color: Color(0xFFB09070),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: const [
                          _AppInfoRow(
                            icon: Icons.info_outline,
                            label: '버전 정보',
                            value: '1.0.0',
                          ),
                          Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                            color: Color(0xFFEEEFF2),
                          ),
                          _AppInfoRow(
                            icon: Icons.calendar_month_outlined,
                            label: '앱 이름',
                            value: '까사음력달력',
                          ),
                          Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                            color: Color(0xFFEEEFF2),
                          ),
                          _AppInfoRow(
                            icon: Icons.task_alt_outlined,
                            label: '개발자',
                            value: 'LEES CASAWARE LAB',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '기타',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC4936A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _AppActionRow(
                            icon: Icons.code,
                            label: '오픈소스 라이선스',
                            subtitle: '사용된 오픈소스 라이선스 정보',
                            showArrow: true,
                            onTap: () => showLicensePage(
                              context: context,
                              applicationName: '까사음력달력',
                              applicationVersion: '1.0.0',
                              applicationLegalese:
                                  '© 2026 LEES CASAWARE LAB',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Center(
                      child: Column(
                        children: [
                          Text(
                            '© 2026 LEES CASAWARE LAB',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12,
                              color: Color(0xFF9EA2A8),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'All rights reserved.',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12,
                              color: Color(0xFF9EA2A8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AppInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFC4936A), size: 22),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2F2F2F),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              color: Color(0xFF9EA2A8),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _AppActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool showArrow;

  const _AppActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.showArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFC4936A), size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2F2F2F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      color: Color(0xFF9EA2A8),
                    ),
                  ),
                ],
              ),
            ),
            if (showArrow)
              const Icon(Icons.chevron_right, color: Color(0xFFBCC0C8), size: 18),
          ],
        ),
      ),
    );
  }
}

// ── 일정 목록 아이템 ──────────────────────────────────────────────────────────

class _ScheduleListItem extends StatelessWidget {
  final Schedule schedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ScheduleListItem({
    required this.schedule,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final s = schedule;
    return Slidable(
      key: Key('sp_${s.id}'),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.4,
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: const Color(0xFF5B8DEF),
            foregroundColor: Colors.white,
            icon: Icons.edit_outlined,
            label: '수정',
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: const Color(0xFFFF6B6B),
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: '삭제',
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: Color(s.categoryColor),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(s.categoryColor),
                    ),
                  ),
                  if (s.time != null || s.memo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (s.time != null) s.time!,
                        if (s.memo != null) s.memo!,
                      ].join('  ·  '),
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 11,
                        color: Color(0xFF747B86),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (s.isLunar)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFB8920A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '음력',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 10,
                    color: Color(0xFFB8920A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (s.repeatType != null)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.repeat, color: Color(0xFF8B7CB8), size: 15),
              ),
            if (s.alarmMinutesBefore != null)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFFAA9898),
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 월별 일정 시트 데이터 ───────────────────────────────────────────────────────

class _MonthItem {
  final DateTime date;
  final String title;
  final Color dotColor;
  final String rightLabel;
  final Color rightLabelColor;
  final Color? titleColor;

  const _MonthItem({
    required this.date,
    required this.title,
    required this.dotColor,
    required this.rightLabel,
    required this.rightLabelColor,
    this.titleColor,
  });
}

// ── 월별 일정 시트 ────────────────────────────────────────────────────────────

class _MonthlyScheduleSheet extends StatefulWidget {
  final DateTime month;
  final Map<String, Holiday> holidays;
  final CalendarEngine engine;

  const _MonthlyScheduleSheet({
    required this.month,
    required this.holidays,
    required this.engine,
  });

  @override
  State<_MonthlyScheduleSheet> createState() => _MonthlyScheduleSheetState();
}

class _MonthlyScheduleSheetState extends State<_MonthlyScheduleSheet>
    with SingleTickerProviderStateMixin {
  late DateTime _month;
  List<_MonthItem>? _mySchedules;
  List<_MonthItem>? _publicHolidays;
  List<_MonthItem>? _anniversaries;
  List<_MonthItem>? _allItems;
  late final TabController _tabController;
  late Map<String, Holiday> _sheetHolidays;

  static const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  void initState() {
    super.initState();
    _month = widget.month;
    _sheetHolidays = Map.of(widget.holidays);
    _tabController = TabController(length: 4, vsync: this);
    _loadItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _changeMonth(int delta, {int targetTab = 0}) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _mySchedules = null;
      _publicHolidays = null;
      _anniversaries = null;
      _allItems = null;
    });
    _tabController.animateTo(targetTab);
    _loadItems();
    _ensureSheetHolidaysLoaded(_month.year);
  }

  Future<void> _ensureSheetHolidaysLoaded(int year) async {
    final prefix = '$year-';
    if (_sheetHolidays.keys.any((k) => k.startsWith(prefix))) return;

    final holidays = await DatabaseHelper.instance.getHolidaysByYear(year);
    if (!mounted || holidays.isEmpty) return;

    for (final h in holidays) {
      Holiday.insertPriority(_sheetHolidays, h);
    }
    await _loadItems();
  }

  Future<void> _loadItems() async {
    final month = _month;
    final ym = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final prefix = '$ym-';

    final regular = await DatabaseHelper.instance.getSchedulesByMonth(ym);
    final repeats = await DatabaseHelper.instance.getAllRepeatSchedules();

    final mySchedules = <_MonthItem>[];
    final publicHolidays = <_MonthItem>[];
    final anniversaries = <_MonthItem>[];

    // 공휴일·절기·기념일 분류
    for (final entry in _sheetHolidays.entries) {
      if (!entry.key.startsWith(prefix)) continue;
      final h = entry.value;
      final date = DateTime.parse(entry.key);
      final item = _MonthItem(
        date: date,
        title: h.name,
        dotColor: _dotColor(h.type),
        rightLabel: _rightLabel(h.type),
        rightLabelColor: _rightColor(h.type),
      );
      if (h.type == 'rest_day' || h.type == 'national_holiday') {
        publicHolidays.add(item);
      } else {
        anniversaries.add(item);
      }
    }

    // 일반(비반복) 일정
    for (final s in regular) {
      if (s.repeatType != null) continue;
      mySchedules.add(_fromSchedule(s, DateTime.parse(s.solarDate)));
    }

    // 반복 일정
    for (final s in repeats) {
      for (final key
          in RepeatScheduleHelper.datesInMonth(s, month, widget.engine)) {
        mySchedules.add(_fromSchedule(s, DateTime.parse(key)));
      }
    }

    // 샌드위치 휴일 감지
    final lastDay = DateTime(month.year, month.month + 1, 0);
    for (var d = DateTime(month.year, month.month, 1);
        !d.isAfter(lastDay);
        d = d.add(const Duration(days: 1))) {
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
        continue;
      }
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      if (_sheetHolidays.containsKey(key)) continue;
      if (_isNonWorking(d.subtract(const Duration(days: 1))) &&
          _isNonWorking(d.add(const Duration(days: 1)))) {
        publicHolidays.add(_MonthItem(
          date: d,
          title: '사잇날',
          dotColor: const Color(0xFF4FA96A),
          rightLabel: '',
          rightLabelColor: Colors.transparent,
          titleColor: const Color(0xFF4FA96A),
        ));
      }
    }

    mySchedules.sort((a, b) => a.date.compareTo(b.date));
    publicHolidays.sort((a, b) => a.date.compareTo(b.date));
    anniversaries.sort((a, b) => a.date.compareTo(b.date));

    final all = [...mySchedules, ...publicHolidays, ...anniversaries]
      ..sort((a, b) => a.date.compareTo(b.date));

    if (!mounted || month != _month) return;
    setState(() {
      _mySchedules = mySchedules;
      _publicHolidays = publicHolidays;
      _anniversaries = anniversaries;
      _allItems = all;
    });
  }

  static Color _dotColor(String type) => switch (type) {
        'rest_day' || 'national_holiday' => const Color(0xFFFF3B30),
        'solar_term' => const Color(0xFF4FA96A),
        'anniversary' => const Color(0xFFE9B174),
        _ => const Color(0xFF747B86),
      };

  static String _rightLabel(String type) => switch (type) {
        'rest_day' => '공휴일',
        'national_holiday' => '국경일',
        'solar_term' => '절기',
        'anniversary' => '기념일',
        _ => '',
      };

  static Color _rightColor(String type) => switch (type) {
        'rest_day' || 'national_holiday' => const Color(0xFFFF3B30),
        'solar_term' => const Color(0xFF4FA96A),
        'anniversary' => const Color(0xFFE9B174),
        _ => const Color(0xFF747B86),
      };

  bool _isNonWorking(DateTime date) {
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return true;
    }
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final h = _sheetHolidays[key];
    return h != null && (h.type == 'rest_day' || h.type == 'national_holiday');
  }

  static _MonthItem _fromSchedule(Schedule s, DateTime date) => _MonthItem(
        date: date,
        title: s.title,
        dotColor: Color(s.categoryColor),
        rightLabel: _fmtTime(s.time),
        rightLabelColor: const Color(0xFF747B86),
      );

  static String _fmtTime(String? t) {
    if (t == null) return '';
    final parts = t.split(':');
    if (parts.length != 2) return t;
    final h = int.tryParse(parts[0]);
    if (h == null) return t;
    final m = parts[1];
    if (h == 0) return '오전 12:$m';
    if (h < 12) return '오전 $h:$m';
    if (h == 12) return '오후 12:$m';
    return '오후 ${h - 12}:$m';
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 390;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SizedBox(
        height: size.height * 0.90,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    final v = details.primaryVelocity ?? 0;
                    if (v < -300) {
                      // 우→좌: 다음 탭, 마지막 탭이면 다음 달 첫 탭
                      final tab = _tabController.index;
                      if (tab < 3) {
                        _tabController.animateTo(tab + 1);
                      } else {
                        _changeMonth(1, targetTab: 0);
                      }
                    } else if (v > 300) {
                      // 좌→우: 이전 탭, 첫 탭이면 이전 달 마지막 탭
                      final tab = _tabController.index;
                      if (tab > 0) {
                        _tabController.animateTo(tab - 1);
                      } else {
                        _changeMonth(-1, targetTab: 3);
                      }
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(compact),
                      _buildTabBar(compact),
                      const Divider(height: 1, color: Color(0xFFEAECEF)),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildList(_mySchedules, compact, '이달의 나의 일정이 없습니다'),
                            _buildList(_publicHolidays, compact, '이달의 공휴일이 없습니다'),
                            _buildList(_anniversaries, compact, '이달의 기념일·절기가 없습니다'),
                            _buildList(_allItems, compact, '이달의 일정이 없습니다'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool compact) {
    final m = _month;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 20 : 28,
        compact ? 18 : 22,
        compact ? 16 : 20,
        compact ? 14 : 18,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${m.year}년 ${m.month}월 일정',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: compact ? 17 : 19,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF202124),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, color: Color(0xFF9EA2A8), size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool compact) {
    return TabBar(
      controller: _tabController,
      labelStyle: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: compact ? 13 : 14,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: compact ? 13 : 14,
        fontWeight: FontWeight.w400,
      ),
      labelColor: const Color(0xFF202124),
      unselectedLabelColor: const Color(0xFF9EA2A8),
      indicatorColor: const Color(0xFF3A7272),
      indicatorWeight: 2,
      dividerColor: Colors.transparent,
      tabs: const [
        Tab(text: '나의 일정'),
        Tab(text: '공휴일'),
        Tab(text: '기념일'),
        Tab(text: '전체'),
      ],
    );
  }

  Widget _buildList(List<_MonthItem>? items, bool compact, String emptyMsg) {
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMsg,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            color: Color(0xFF9EA2A8),
            fontSize: 14,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        color: Color(0xFFEAECEF),
        indent: 20,
        endIndent: 20,
      ),
      itemBuilder: (_, i) => _buildRow(items[i], compact),
    );
  }

  Widget _buildRow(_MonthItem item, bool compact) {
    final d = item.date;
    final dateStr =
        '${d.month}. ${d.day} (${_weekdayNames[d.weekday - 1]})';

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 18 : 24,
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: item.dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: compact ? 80 : 88,
            child: Text(
              dateStr,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF50545C),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.title,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: compact ? 13 : 13.5,
                fontWeight: FontWeight.w600,
                color: item.titleColor ?? const Color(0xFF202124),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (item.rightLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              item.rightLabel,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w500,
                color: item.rightLabelColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
