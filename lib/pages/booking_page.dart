import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingPage extends StatefulWidget {
  final String doctorId;
  const BookingPage({super.key, required this.doctorId});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _doctor;
  List<Map<String, dynamic>> _availability = [];
  List<Map<String, dynamic>> _existingAppointments = [];
  bool _loading = true;

  DateTime _selectedDate = DateTime.now();
  String? _selectedSlot; // e.g. "09:30"
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doctor = await _supabase
          .from('doctors')
          .select(
            'id, fee, '
            'profiles(full_name), '
            'specialties(name)',
          )
          .eq('id', widget.doctorId)
          .single();

      final availability = await _supabase
          .from('availability')
          .select()
          .eq('doctor_id', widget.doctorId);

      final appointments = await _supabase
          .from('appointments')
          .select('start_at, end_at, status')
          .eq('doctor_id', widget.doctorId)
          .inFilter('status', ['pending', 'confirmed']);

      if (!mounted) return;
      setState(() {
        _doctor = doctor;
        _availability = List<Map<String, dynamic>>.from(availability);
        _existingAppointments =
            List<Map<String, dynamic>>.from(appointments);
        _selectedSlot = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load booking data: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Build slots for the selected date by expanding availability rows
  /// for that weekday and removing slots already booked.
  List<String> _slotsForSelectedDate() {
    final weekday = _selectedDate.weekday; // 1=Mon ... 7=Sun
    final rows = _availability
        .where((a) => (a['day_of_week'] as int) == weekday)
        .toList();
    if (rows.isEmpty) return [];

    final slots = <String>[];
    for (final row in rows) {
      final start = _parseTime(row['start_time'] as String);
      final end = _parseTime(row['end_time'] as String);
      final step = (row['slot_minutes'] as int?) ?? 30;

 int startMin = start.hour * 60 + start.minute;
final endMin = end.hour * 60 + end.minute;
while (startMin < endMin) {
  final h = (startMin ~/ 60).toString().padLeft(2, '0');
  final m = (startMin % 60).toString().padLeft(2, '0');
  slots.add('$h:$m');
  startMin += step;
}
    }

    // Remove slots already taken on that date
    final taken = <String>{};
    for (final appt in _existingAppointments) {
      final startAt = DateTime.parse(appt['start_at'] as String).toLocal();
      if (_sameDay(startAt, _selectedDate)) {
        final h = startAt.hour.toString().padLeft(2, '0');
        final m = startAt.minute.toString().padLeft(2, '0');
        taken.add('$h:$m');
      }
    }

    return slots.where((s) => !taken.contains(s)).toList();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  TimeOfDay _parseTime(String hhmmss) {
    final parts = hhmmss.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }



  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedSlot = null;
      });
    }
  }

  Future<void> _book() async {
    final slot = _selectedSlot;
    if (slot == null) return;
    setState(() => _booking = true);
    try {
      final parts = slot.split(':');
      final startLocal = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      final endLocal = startLocal.add(const Duration(minutes: 30));

      final userId = _supabase.auth.currentUser!.id;

      await _supabase.from('appointments').insert({
        'patient_id': userId,
        'doctor_id': widget.doctorId,
        'start_at': startLocal.toUtc().toIso8601String(),
        'end_at': endLocal.toUtc().toIso8601String(),
        'status': 'pending',
        'payment_status': 'unpaid',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment booked!')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book appointment')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _doctor == null
              ? const Center(child: Text('Doctor not found'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _doctor!['profiles']?['full_name'] ?? 'Doctor',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${_doctor!['specialties']?['name'] ?? 'General'} · '
                        '\$${_doctor!['fee']}',
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          '${_selectedDate.year}-'
                          '${_selectedDate.month.toString().padLeft(2, '0')}-'
                          '${_selectedDate.day.toString().padLeft(2, '0')}',
                        ),
                        onPressed: _pickDate,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Available slots',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final slots = _slotsForSelectedDate();
                            if (slots.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No slots available for this date.\nPick another day.',
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: slots.map((s) {
                                final selected = _selectedSlot == s;
                                return ChoiceChip(
                                  label: Text(s),
                                  selected: selected,
                                  onSelected: (_) =>
                                      setState(() => _selectedSlot = s),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _selectedSlot == null || _booking
                              ? null
                              : _book,
                          child: _booking
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Text('Confirm booking'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}