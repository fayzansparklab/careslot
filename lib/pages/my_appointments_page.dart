import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:careslot/core/theme/app_theme.dart';

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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
                    onPressed: () => setDialogState(() => rating = starIndex),
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

  Widget _buildStatusBadge(String status, String paymentStatus) {
    Color color;
    Color bgColor;
    switch (status) {
      case 'confirmed':
        color = Colors.green.shade700;
        bgColor = Colors.green.shade50;
        break;
      case 'cancelled':
        color = Colors.red.shade700;
        bgColor = Colors.red.shade50;
        break;
      case 'completed':
        color = Colors.blueGrey.shade700;
        bgColor = Colors.blueGrey.shade50;
        break;
      default:
        color = Colors.orange.shade800;
        bgColor = Colors.orange.shade50;
    }
    final label = status[0].toUpperCase() + status.substring(1);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: paymentStatus == 'paid' ? Colors.green.shade50 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            paymentStatus == 'paid' ? 'Paid' : 'Unpaid',
            style: TextStyle(
              color: paymentStatus == 'paid' ? Colors.green.shade700 : Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w700,
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
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Doctor Info & Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryTint,
                  child: const Icon(Icons.person, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?['full_name'] ?? 'Doctor',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${spec?['name'] ?? 'General'} · \$${doctor?['fee'] ?? 0}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            _buildStatusBadge(status, paymentStatus),
            
            const Divider(height: 24),
            
            // Date & Time
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  _formatDateTime(appt['start_at'] as String),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Full-Width Action Buttons (Standard U.S. UX)
            if (paymentStatus == 'unpaid' && status != 'cancelled' && status != 'completed') ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final fee = (doctor?['fee'] as num?)?.toDouble() ?? 0.0;
                    context.go('/pay/$apptId/$fee');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Pay Now'),
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (status == 'completed' && !alreadyReviewed) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _leaveReview(appt),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Leave a Review'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            if (status == 'completed' && alreadyReviewed) ...[
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 6),
                    Text('You reviewed this visit', style: TextStyle(color: Colors.green.shade600)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            if (upcoming && status != 'cancelled' && status != 'completed') ...[
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _cancel(appt),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel Appointment'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Appointments'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Upcoming Tab
                  RefreshIndicator(
                    onRefresh: _load,
                    child: _upcoming.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 100),
                              Center(child: Text('No upcoming appointments.')),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _upcoming.length,
                            itemBuilder: (context, i) =>
                                _appointmentCard(_upcoming[i], upcoming: true),
                          ),
                  ),
                  // Past Tab
                  RefreshIndicator(
                    onRefresh: _load,
                    child: _past.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 100),
                              Center(child: Text('No past appointments.')),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _past.length,
                            itemBuilder: (context, i) =>
                                _appointmentCard(_past[i], upcoming: false),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}