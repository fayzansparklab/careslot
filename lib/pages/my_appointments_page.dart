import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class MyAppointmentsPage extends StatefulWidget {
  const MyAppointmentsPage({super.key});

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _upcoming = [];
  List<Map<String, dynamic>> _past = [];
  Set<int> _reviewedAppointmentIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = await _supabase
          .from('appointments')
          .select(
            'id, start_at, end_at, status, payment_status, '
            'doctors(id, fee, profiles(full_name), specialties(name))',
          )
          .eq('patient_id', userId)
          .order('start_at', ascending: true);

      final reviews = await _supabase
          .from('reviews')
          .select('appointment_id')
          .eq('patient_id', userId);

      final reviewed = <int>{
        for (final r in List<Map<String, dynamic>>.from(reviews))
          r['appointment_id'] as int,
      };

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
        _reviewedAppointmentIds = reviewed;
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

  Future<void> _cancel(Map<String, dynamic> appt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: const Text(
          'This will free the slot for other patients. '
          'The record will remain in your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _supabase
          .from('appointments')
          .update({'status': 'cancelled'}).eq('id', appt['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment cancelled')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cancel failed: $e')),
      );
    }
  }

  Future<void> _leaveReview(Map<String, dynamic> appt) async {
    final doctor = appt['doctors'] as Map<String, dynamic>?;
    final doctorId = doctor?['id'] as int?;
    if (doctorId == null) return;

    int rating = 5;
    final commentController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate your visit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  return IconButton(
                    onPressed: () =>
                        setDialogState(() => rating = starIndex),
                    icon: Icon(
                      starIndex <= rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Share details about your experience (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (submitted != true) return;

    try {
      await _supabase.from('reviews').insert({
        'appointment_id': appt['id'],
        'patient_id': _supabase.auth.currentUser!.id,
        'doctor_id': doctorId,
        'rating': rating,
        'comment': commentController.text.trim().isEmpty
            ? null
            : commentController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your review!')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review failed: $e')),
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

  Widget _statusChip(String status, String paymentStatus) {
    Color color;
    switch (status) {
      case 'confirmed':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      case 'completed':
        color = Colors.blueGrey;
        break;
      default:
        color = Colors.orange;
    }
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
    final doctor = appt['doctors'] as Map<String, dynamic>?;
    final profile = doctor?['profiles'] as Map<String, dynamic>?;
    final spec = doctor?['specialties'] as Map<String, dynamic>?;
    final status = appt['status'] as String;
    final paymentStatus = appt['payment_status'] as String;
    final apptId = appt['id'] as int;
    final alreadyReviewed = _reviewedAppointmentIds.contains(apptId);

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
                    profile?['full_name'] ?? 'Doctor',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _statusChip(status, paymentStatus),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${spec?['name'] ?? 'General'} · \$${doctor?['fee'] ?? 0}',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16),
                const SizedBox(width: 6),
                Text(_formatDateTime(appt['start_at'] as String)),
              ],
            ),
            if (status == 'completed' && !alreadyReviewed) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () => _leaveReview(appt),
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Leave a review'),
                ),
              ),
            ],
            if (status == 'completed' && alreadyReviewed) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    'Reviewed',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
                     if (paymentStatus == 'unpaid' && status != 'cancelled') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () {
                    final fee = (doctor?['fee'] as num?)?.toDouble() ?? 0.0;
                    context.go('/pay/$apptId/$fee');
                  },
                  icon: const Icon(Icons.payment),
                  label: const Text('Pay now'),
                ),
              ),
            ],
            if (upcoming && status != 'cancelled' && status != 'completed') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => _cancel(appt),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
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