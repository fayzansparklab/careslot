import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorAppointmentsPage extends StatefulWidget {
  const DoctorAppointmentsPage({super.key});

  @override
  State<DoctorAppointmentsPage> createState() =>
      _DoctorAppointmentsPageState();
}

class _DoctorAppointmentsPageState extends State<DoctorAppointmentsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _past = [];
  bool _loading = true;
  int? _doctorId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      // Get this doctor's id
      final doctor = await _supabase
          .from('doctors')
          .select('id')
          .eq('profile_id', userId)
          .single();
      _doctorId = doctor['id'] as int;

      final data = await _supabase
          .from('appointments')
          .select(
            'id, start_at, end_at, status, payment_status, notes, '
            'profiles!appointments_patient_id_fkey(full_name, phone)',
          )
          .eq('doctor_id', _doctorId!)
          .order('start_at', ascending: true);

      final now = DateTime.now().toUtc();
      final upcoming = <Map<String, dynamic>>[];
      final past = <Map<String, dynamic>>[];

      for (final row in List<Map<String, dynamic>>.from(data)) {
        final startAt = DateTime.parse(row['start_at'] as String).toUtc();
        final status = row['status'] as String;
        final isDone = status == 'cancelled' || status == 'completed';
        if (!isDone && startAt.isAfter(now)) {
          upcoming.add(row);
        } else {
          past.add(row);
        }
      }

      if (!mounted) return;
      setState(() {
        _upcoming = upcoming;
        _past = past.reversed.toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load appointments: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> appt, String status) async {
    try {
      await _supabase
          .from('appointments')
          .update({'status': status}).eq('id', appt['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked as $status')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  Future<void> _editNotes(Map<String, dynamic> appt) async {
    final controller =
        TextEditingController(text: (appt['notes'] as String?) ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Appointment notes'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Add clinical notes for this visit…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == null) return;
    try {
      await _supabase
          .from('appointments')
          .update({'notes': saved}).eq('id', appt['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes saved')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saving notes failed: $e')),
      );
    }
  }

  String _formatDateTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$m $ampm';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blueGrey;
      default:
        return Colors.orange;
    }
  }

  Widget _statusChip(String status, String paymentStatus) {
    final color = _statusColor(status);
    final label = status[0].toUpperCase() + status.substring(1);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: paymentStatus == 'paid'
                ? Colors.green.withValues(alpha: 0.12)
                : Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            paymentStatus == 'paid' ? 'Paid' : 'Unpaid',
            style: TextStyle(
              color: paymentStatus == 'paid' ? Colors.green : Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _appointmentCard(Map<String, dynamic> appt, {required bool upcoming}) {
    final patient = appt['profiles'] as Map<String, dynamic>?;
    final status = appt['status'] as String;
    final paymentStatus = appt['payment_status'] as String;
    final notes = appt['notes'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    patient?['full_name'] ?? 'Patient',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _statusChip(status, paymentStatus),
              ],
            ),
            if (patient?['phone'] != null) ...[
              const SizedBox(height: 2),
              Text(
                patient!['phone'],
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16),
                const SizedBox(width: 6),
                Text(_formatDateTime(appt['start_at'] as String)),
              ],
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_alt_outlined, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      notes,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (status == 'pending')
                  FilledButton(
                    onPressed: () => _updateStatus(appt, 'confirmed'),
                    child: const Text('Confirm'),
                  ),
                if (status == 'confirmed')
                  FilledButton(
                    onPressed: () => _updateStatus(appt, 'completed'),
                    child: const Text('Complete'),
                  ),
                if (status != 'cancelled' && status != 'completed')
                  OutlinedButton(
                    onPressed: () => _editNotes(appt),
                    child: Text(notes == null || notes.isEmpty
                        ? 'Add notes'
                        : 'Edit notes'),
                  ),
                if (upcoming && status == 'pending')
                  OutlinedButton(
                    onPressed: () => _updateStatus(appt, 'cancelled'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        '$title ($count)',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Appointments')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _doctorId == null
              ? const Center(
                  child: Text('No doctor profile linked to this account.'),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _sectionHeader(context, 'Upcoming', _upcoming.length),
                      if (_upcoming.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text('No upcoming appointments.'),
                        )
                      else
                        ..._upcoming.map(
                          (a) => _appointmentCard(a, upcoming: true),
                        ),
                      const SizedBox(height: 8),
                      _sectionHeader(context, 'Past', _past.length),
                      if (_past.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text('No past appointments.'),
                        )
                      else
                        ..._past.map(
                          (a) => _appointmentCard(a, upcoming: false),
                        ),
                    ],
                  ),
                ),
    );
  }
}