import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/notifications/notification_service.dart';
import '../../shared/models/schedule.dart';
import 'schedule_form_sheet.dart';

class DayScheduleSheet extends StatefulWidget {
  final DateTime date;
  const DayScheduleSheet({super.key, required this.date});

  @override
  State<DayScheduleSheet> createState() => _DayScheduleSheetState();
}

class _DayScheduleSheetState extends State<DayScheduleSheet> {
  List<Schedule> _schedules = [];

  static const _bg = Color(0xFF1A3535);
  static const _accent = Color(0xFFE8C090);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = _fmtDate(widget.date);
    final list = await DatabaseHelper.instance.getSchedulesByDate(key);
    if (mounted) setState(() => _schedules = list);
  }

  Future<void> _delete(Schedule s) async {
    await DatabaseHelper.instance.deleteSchedule(s.id!);
    if (s.alarmMinutesBefore != null) {
      await NotificationService.instance.cancel(s.id!);
    }
    _load();
  }

  Future<void> _openForm() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleFormSheet(date: widget.date),
    );
    _load();
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _dateLabel(DateTime d) {
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.month}월 ${d.day}일 (${wd[d.weekday - 1]})';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                Text(_dateLabel(widget.date),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(
                  onTap: _openForm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('+ 일정 추가',
                        style: TextStyle(
                            color: Color(0xFF3D1E0A),
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
            const Divider(color: Colors.white12, height: 1),
            _schedules.isEmpty ? _empty() : _list(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(children: const [
          Icon(Icons.event_note_outlined, color: Colors.white24, size: 44),
          SizedBox(height: 10),
          Text('등록된 일정이 없습니다',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
        ]),
      );

  Widget _list() => Flexible(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _schedules.length,
          separatorBuilder: (_, _) =>
              const Divider(color: Colors.white12, height: 1),
          itemBuilder: (_, i) => _item(_schedules[i]),
        ),
      );

  Widget _item(Schedule s) {
    return Dismissible(
      key: Key('s_${s.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: const Color(0xFFFF5050),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _delete(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
                color: Color(s.categoryColor),
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                if (s.time != null || s.memo != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    [if (s.time != null) s.time!, if (s.memo != null) s.memo!]
                        .join('  ·  '),
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          if (s.alarmMinutesBefore != null)
            const Icon(Icons.notifications_outlined,
                color: Colors.white38, size: 18),
        ]),
      ),
    );
  }
}
