import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:careslot/core/theme/app_theme.dart';

class AdminAppointmentsPage extends StatefulWidget {
  const AdminAppointmentsPage({super.key});

  @override
  State<AdminAppointmentsPage> createState() =>
      _AdminAppointmentsPageState();
}

class _AdminAppointmentsPageState extends State<AdminAppointmentsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allAppointments = [];
  List<Map<String, dynamic>> _filteredAppointments = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('appointments')
          .select(
            'id, start_at, status, payment_status, '
            'doctors(profiles(full_name)), '
            'profiles!appointments_patient_id_fkey(full_name)',
          )
          .order('start_at', ascending: false)
          .limit(200);

      if (!mounted) return;
      setState(() {
        _allAppointments = List<Map<String, dynamic>>.from(data);
        _applyFilter();
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

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredAppointments = _allAppointments;
    } else {
      _filteredAppointments = _allAppointments.where((appt) {
        final patientName = (appt['profiles']?['full_name'] as String? ?? '').toLowerCase();
        final doctorName = (appt['doctors']?['profiles']?['full_name'] as String? ?? '').toLowerCase();
        return patientName.contains(_searchQuery) || doctorName.contains(_searchQuery);
      }).toList();
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
    return '${months[dt.month - 1]} ${dt.day} · $h:$m $ampm';
  }

  Widget _buildStatusBadge(String status, String paymentStatus) {
    Color statusColor;
    Color statusBg;
    switch (status) {
      case 'confirmed':
        statusColor = Colors.green.shade700;
        statusBg = Colors.green.shade50;
        break;
      case 'cancelled':
        statusColor = Colors.red.shade700;
        statusBg = Colors.red.shade50;
        break;
      case 'completed':
        statusColor = Colors.blueGrey.shade700;
        statusBg = Colors.blueGrey.shade50;
        break;
      default:
        statusColor = Colors.orange.shade800;
        statusBg = Colors.orange.shade50;
    }

    return Wrap(
      spacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: paymentStatus == 'paid' ? Colors.green.shade50 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            paymentStatus.toUpperCase(),
            style: TextStyle(
              color: paymentStatus == 'paid' ? Colors.green.shade700 : Colors.grey.shade700,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Appointments'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                  _applyFilter();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by patient or doctor...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAppointments.isEmpty
                    ? Center(
                        child: Text(
                          'No appointments found.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredAppointments.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final r = _filteredAppointments[i];
                            final patientName = r['profiles']?['full_name'] ?? '—';
                            final doctorName = r['doctors']?['profiles']?['full_name'] ?? '—';
                            
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryTint,
                                child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
                              ),
                              title: Text(
                                '$patientName → $doctorName',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _formatDateTime(r['start_at'] as String),
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ),
                              trailing: _buildStatusBadge(
                                r['status'] as String,
                                r['payment_status'] as String,
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
}