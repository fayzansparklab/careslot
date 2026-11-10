import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:careslot/core/theme/app_theme.dart';

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

    // Basic validation
    for (final r in _rules.where((r) => r.enabled)) {
      final startMin = r.start.hour * 60 + r.start.minute;
      final endMin = r.end.hour * 60 + r.end.minute;
      if (endMin <= startMin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${r.dayName}: End time must be after start time'),
            backgroundColor: Colors.red,
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
        const SnackBar(content: Text('Availability updated successfully')),
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Availability'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Weekly Schedule',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Toggle the days you work and set your hours. Patients will book 30-minute slots within these times.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      ..._rules.map((rule) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        rule.dayName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: rule.enabled ? FontWeight.bold : FontWeight.normal,
                                          color: rule.enabled ? AppColors.textPrimary : Colors.grey,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: rule.enabled,
                                      activeColor: AppColors.primary,
                                      onChanged: (v) => setState(() => rule.enabled = v),
                                    ),
                                  ],
                                ),
                                if (rule.enabled) ...[
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _pickTime(rule, isStart: true),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryTint,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Start Time', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                                const SizedBox(height: 4),
                                                Text(_fmt(rule.start), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _pickTime(rule, isStart: false),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryTint,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('End Time', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                                const SizedBox(height: 4),
                                                Text(_fmt(rule.end), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                
                // Sticky Save Button
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Save Schedule'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}