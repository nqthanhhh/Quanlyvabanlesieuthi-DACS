import 'package:flutter/material.dart';

import '../models/user.dart';
import '../models/work_shift.dart';
import '../repositories/work_shift_repository.dart';
import '../services/api_service.dart';

/// Lịch ca làm theo tháng — tổng quan dễ đọc.
class EmployeeShiftScheduleScreen extends StatefulWidget {
  final int employeeId;
  final String employeeName;
  final bool canManageShift;

  const EmployeeShiftScheduleScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    this.canManageShift = false,
  });

  @override
  State<EmployeeShiftScheduleScreen> createState() =>
      _EmployeeShiftScheduleScreenState();
}

class _EmployeeShiftScheduleScreenState extends State<EmployeeShiftScheduleScreen> {
  late DateTime _month;
  bool _loading = true;
  String? _error;
  List<WorkShift> _shifts = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await WorkShiftRepository.fetchShiftsForMonth(
        employeeId: widget.employeeId,
        year: _month.year,
        month: _month.month,
      );
      if (!mounted) return;
      setState(() {
        _shifts = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
    _load();
  }

  String _monthLabel() => 'Tháng ${_month.month}/${_month.year}';

  int get _workingCount => _shifts.where((s) => s.isOpen).length;

  Duration _shiftDuration(WorkShift s) {
    if (s.startTime == null) return Duration.zero;
    final date = s.workDate ?? '';
    final start = DateTime.tryParse('$date ${s.startTime}');
    if (start == null) return Duration.zero;
    if (s.isOpen) return DateTime.now().difference(start);
    if (s.endTime == null) return Duration.zero;
    final end = DateTime.tryParse('$date ${s.endTime}');
    if (end == null) return Duration.zero;
    return end.difference(start);
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes <= 0) return '—';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}g ${m}ph';
    return '${m}ph';
  }

  String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '—';
    return t.length >= 5 ? t.substring(0, 5) : t;
  }

  String _formatDate(String? d) {
    if (d == null) return '—';
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final totalMinutes = _shifts.fold<int>(
      0,
      (sum, s) => sum + _shiftDuration(s).inMinutes,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text('Lịch ca — ${widget.employeeName}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _monthLabel(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _statChip('Tổng ca', '${_shifts.length}', Colors.blue),
                const SizedBox(width: 8),
                _statChip('Đang mở', '$_workingCount', Colors.orange),
                const SizedBox(width: 8),
                _statChip(
                  'Giờ làm',
                  _formatDuration(Duration(minutes: totalMinutes)),
                  Colors.green,
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _shifts.isEmpty
                ? Center(
                    child: Text(
                      'Chưa có ca làm trong ${_monthLabel().toLowerCase()}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _shifts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final s = _shifts[index];
                        final working = s.isOpen;
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: working
                                  ? Colors.blue.shade50
                                  : Colors.green.shade50,
                              child: Icon(
                                working ? Icons.timelapse : Icons.check,
                                color: working
                                    ? Colors.blue.shade700
                                    : Colors.green.shade700,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              _formatDate(s.workDate),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${_formatTime(s.startTime)} → ${working ? 'đang làm' : _formatTime(s.endTime)} · ${_formatDuration(_shiftDuration(s))}',
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (working
                                        ? Colors.blue
                                        : Colors.green)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                working ? 'Đang làm' : 'Xong',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: working
                                      ? Colors.blue.shade800
                                      : Colors.green.shade800,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.shade100),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: color.shade900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color.shade800),
            ),
          ],
        ),
      ),
    );
  }
}

void openEmployeeShiftSchedule(
  BuildContext context, {
  required User user,
  bool canManageShift = false,
}) {
  if (user.userId == null) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => EmployeeShiftScheduleScreen(
        employeeId: user.userId!,
        employeeName: user.fullName.isNotEmpty ? user.fullName : user.email,
        canManageShift: canManageShift,
      ),
    ),
  );
}
