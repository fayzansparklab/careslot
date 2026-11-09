import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorAvailabilityPage extends StatefulWidget {
  const DoctorAvailabilityPage({super.key});

  @override
  State<DoctorAvailabilityPage> createState() =>
      _DoctorAvailabilityPageState();
}

class _DayRule {
  _DayRule({
    required this.dayOfWeek,
    this.enabled = false,
    this.start = const TimeOfDay(hour: 9, minute: 0),
    this.end = const TimeOfDay(hour: 17, minute: 0),
  });

  final int dayOfWeek; // 1=Mon ... 7=Sun
  bool enabled;
  TimeOfDay start;
  TimeOfDay end;

  String get dayName => const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ][dayOfWeek - 1];
}

class _DoctorAvailabilityPageState extends State<DoctorAvailabilityPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  bool _saving = false;
  int? _doctorId;
  final List<_DayRule> _rules =
      List.generate(7, (i) => _DayRule(dayOfWeek: i + 1));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      final doctor = await _supabase
          .from('doctors')
          .select('id')
          .eq('profile_id', userId)
          .single();
      _doctorId = doctor['id'] as int;

      final rows = await _supabase
          .from('availability')
          .select()
          .eq('doctor_id', _doctorId!);

      for (final rule in _rules) {
        rule.enabled = false;
      }
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final dow = row['day_of_week'] as int;
        final idx = dow - 1;
        if (idx < 0 || idx >= 7) continue;
        _rules[idx]
          ..enabled = true
          ..start = _parseTime(row['start_time'] as String)
          ..end = _parseTime(row['end_time'] as String);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load availability: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  TimeOfDay _parseTime(String hhmmss) {
    final p = hhmmss.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String _toSqlTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  Future<void> _pickTime(_DayRule rule, {required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? rule.start : rule.end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        rule.start = picked;
      } else {
        rule.end = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_doctorId == null) return;

    // Basic validation: end after start for enabled days
    for (final r in _rules.where((r) => r.enabled)) {
      final startMin = r.start.hour * 60 + r.start.minute;
      final endMin = r.end.hour * 60 + r.end.minute;
      if (endMin <= startMin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${r.dayName}: end time must be after start time'),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      // Replace all rows for this doctor
      await _supabase
          .from('availability')
          .delete()
          .eq('doctor_id', _doctorId!);

      final rows = _rules
          .where((r) => r.enabled)
          .map((r) => {
                'doctor_id': _doctorId!,
                'day_of_week': r.dayOfWeek,
                'start_time': _toSqlTime(r.start),
                'end_time': _toSqlTime(r.end),
                'slot_minutes': 30,
              })
          .toList();

      if (rows.isNotEmpty) {
        await _supabase.from('availability').insert(rows);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmt(TimeOfDay t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Availability')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Toggle the days you work and set your hours. '
                  'Slots are 30 minutes.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                ..._rules.map((rule) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(rule.dayName),
                            value: rule.enabled,
                            onChanged: (v) =>
                                setState(() => rule.enabled = v),
                          ),
                          if (rule.enabled)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _pickTime(rule,
                                          isStart: true),
                                      child: Text(
                                          'Start: ${_fmt(rule.start)}'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          _pickTime(rule, isStart: false),
                                      child:
                                          Text('End: ${_fmt(rule.end)}'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save availability'),
                  ),
                ),
              ],
            ),
    );
  }
}