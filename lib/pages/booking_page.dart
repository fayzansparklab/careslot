import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:careslot/core/theme/app_theme.dart';

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
  String? _selectedSlot; 
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

  List<String> _slotsForSelectedDate() {
    final weekday = _selectedDate.weekday;
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
      context.go('/patient/appointments'); // Go to appointments after booking
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/doctor/${widget.doctorId}'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _doctor == null
              ? const Center(child: Text('Doctor not found'))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Doctor Info Header
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: AppColors.primaryTint,
                                  child: const Icon(Icons.person, color: AppColors.primary),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _doctor!['profiles']?['full_name'] ?? 'Doctor',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${_doctor!['specialties']?['name'] ?? 'General'} · \$${_doctor!['fee']}',
                                      style: textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Select Date Header with Calendar Icon
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Select a Date',
                                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.calendar_month, color: AppColors.primary),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDate,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 90)),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _selectedDate = picked;
                                        _selectedSlot = null;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),

                            // Horizontal Date Picker (Next 7 days)
                            SizedBox(
                              height: 70,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: 7,
                                itemBuilder: (context, index) {
                                  final date = DateTime.now().add(Duration(days: index));
                                  final isSelected = _sameDay(date, _selectedDate);
                                  
                                  return GestureDetector(
                                    onTap: () => setState(() {
                                      _selectedDate = date;
                                      _selectedSlot = null;
                                    }),
                                    child: Container(
                                      width: 64,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.primary : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1],
                                            style: TextStyle(
                                              color: isSelected ? Colors.white70 : Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            date.day.toString(),
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : AppColors.textPrimary,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            Text(
                              'Available Times',
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),

                            // Time Slots
                            Builder(
                              builder: (context) {
                                final slots = _slotsForSelectedDate();
                                if (slots.isEmpty) {
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Text('No slots available for this date.\nPlease pick another day.'),
                                    ),
                                  );
                                }
                                return Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: slots.map((s) {
                                    final selected = _selectedSlot == s;
                                    return ChoiceChip(
                                      label: Text(s),
                                      selected: selected,
                                      onSelected: (_) => setState(() => _selectedSlot = s),
                                      selectedColor: AppColors.primary,
                                      labelStyle: TextStyle(
                                        color: selected ? Colors.white : AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Sticky Bottom Confirm Button
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _selectedSlot == null || _booking ? null : _book,
                            child: _booking
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Confirm Booking'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}