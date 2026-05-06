import 'package:flutter/material.dart';
import '../../core/db/database_helper.dart';
import '../../core/notifications/notification_service.dart';
import '../../shared/models/schedule.dart';

enum _Alarm {
  none('없음', null),
  onTime('정시', 0),
  ten('10분 전', 10),
  thirty('30분 전', 30),
  hour('1시간 전', 60),
  day('하루 전', 1440);

  final String label;
  final int? minutes;
  const _Alarm(this.label, this.minutes);
}

class ScheduleFormSheet extends StatefulWidget {
  final DateTime date;
  const ScheduleFormSheet({super.key, required this.date});

  @override
  State<ScheduleFormSheet> createState() => _ScheduleFormSheetState();
}

class _ScheduleFormSheetState extends State<ScheduleFormSheet> {
  final _titleCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  TimeOfDay? _time;
  _Alarm _alarm = _Alarm.none;
  bool _saving = false;

  static const _bg = Color(0xFF1A3535);
  static const _accent = Color(0xFFE8C090);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);

    final timeStr = _time == null
        ? null
        : '${_time!.hour.toString().padLeft(2, '0')}:'
            '${_time!.minute.toString().padLeft(2, '0')}';

    final schedule = Schedule(
      title: title,
      memo: _memoCtrl.text.trim().isEmpty ? null : _memoCtrl.text.trim(),
      solarDate: _fmtDate(widget.date),
      time: timeStr,
      isLunar: false,
      alarmMinutesBefore: _alarm.minutes,
      categoryColor: 0xFF2196F3,
    );

    final id = await DatabaseHelper.instance.insertSchedule(schedule);

    if (_alarm.minutes != null && _time != null) {
      final notifyAt = DateTime(
        widget.date.year,
        widget.date.month,
        widget.date.day,
        _time!.hour,
        _time!.minute,
      ).subtract(Duration(minutes: _alarm.minutes!));
      await NotificationService.instance.schedule(
        id: id,
        title: title,
        at: notifyAt,
      );
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _dateLabel(DateTime d) {
    const wd = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.year}년 ${d.month}월 ${d.day}일 (${wd[d.weekday - 1]})';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _handle(),
              const SizedBox(height: 14),
              const Text('일정 추가',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(_dateLabel(widget.date),
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 18),
              _inputField(_titleCtrl, '제목 *'),
              const SizedBox(height: 10),
              _inputField(_memoCtrl, '메모 (선택)', maxLines: 2),
              const SizedBox(height: 16),
              _label('시간'),
              const SizedBox(height: 8),
              Row(children: [
                _chip(
                  _time == null ? '시간 없음' : _time!.format(context),
                  selected: true,
                  onTap: _pickTime,
                ),
                if (_time != null) ...[
                  const SizedBox(width: 8),
                  _chip('지우기', selected: false,
                      onTap: () => setState(() {
                            _time = null;
                            _alarm = _Alarm.none;
                          })),
                ],
              ]),
              if (_time != null) ...[
                const SizedBox(height: 16),
                _label('알림'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _Alarm.values
                      .map((a) => _chip(a.label,
                          selected: _alarm == a,
                          onTap: () => setState(() => _alarm = a)))
                      .toList(),
                ),
              ],
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: const Color(0xFF3D1E0A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Text('저장',
                            style:
                                TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2)),
        ),
      );

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w600));

  Widget _inputField(TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _chip(String label,
      {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: selected ? null : Border.all(color: Colors.white24),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? const Color(0xFF3D1E0A) : Colors.white70,
              fontSize: 13,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
            )),
      ),
    );
  }
}
