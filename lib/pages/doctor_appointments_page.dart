import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:careslot/core/theme/app_theme.dart';

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
        title: const Text('Clinical Notes'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Add clinical notes for this visit...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save Note'),
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

  Widget _buildStatusBadge(String status) {
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

    return Container(
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
    );
  }

  Widget _appointmentCard(Map<String, dynamic> appt, {required bool upcoming}) {
    final patient = appt['profiles'] as Map<String, dynamic>?;
    final status = appt['status'] as String;
    final paymentStatus = appt['payment_status'] as String;
    final notes = appt['notes'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Patient Info & Status / Menu
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
                        patient?['full_name'] ?? 'Patient',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (patient?['phone'] != null)
                        Text(
                          patient!['phone'],
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
                
                // Secondary Actions Menu
                if (status != 'cancelled')
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'notes') _editNotes(appt);
                      if (value == 'cancel') _updateStatus(appt, 'cancelled');
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'notes',
                        child: Text(notes == null || notes.isEmpty ? 'Add Notes' : 'Edit Notes'),
                      ),
                      if (upcoming && status == 'pending')
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Text('Cancel Appointment', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
              ],
            ),
            
            const Divider(height: 24),

            // Date, Time & Payment Indicator
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  _formatDateTime(appt['start_at'] as String),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                if (paymentStatus == 'paid')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text('Paid', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('Unpaid', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),

            // Clinical Notes
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note_alt_outlined, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notes,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Primary Full-Width Action Button
            if (status == 'pending') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _updateStatus(appt, 'confirmed'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Confirm Appointment'),
                ),
              ),
            ] else if (status == 'confirmed') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _updateStatus(appt, 'completed'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blueGrey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Mark as Completed'),
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
          title: const Text('My Schedule'),
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
            : _doctorId == null
                ? const Center(child: Text('No doctor profile linked.'))
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