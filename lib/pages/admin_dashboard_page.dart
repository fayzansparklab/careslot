import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:careslot/core/theme/app_theme.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  
  int _totalAppointments = 0;
  int _paidAppointments = 0;
  int _completedAppointments = 0;
  int _cancelledAppointments = 0;
  double _totalRevenue = 0;

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
          .select('status, payment_status, doctors(fee)');
          
      final rows = List<Map<String, dynamic>>.from(data);
      
      int paid = 0, completed = 0, cancelled = 0;
      double revenue = 0;
      
      for (final r in rows) {
        final ps = r['payment_status'] as String;
        final st = r['status'] as String;
        
        if (ps == 'paid') {
          paid++;
          final fee = (r['doctors']?['fee'] as num?)?.toDouble() ?? 0;
          revenue += fee;
        }
        if (st == 'completed') completed++;
        if (st == 'cancelled') cancelled++;
      }
      
      if (!mounted) return;
      setState(() {
        _totalAppointments = rows.length;
        _paidAppointments = paid;
        _completedAppointments = completed;
        _cancelledAppointments = cancelled;
        _totalRevenue = revenue;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load dashboard: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Revenue Overview',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    color: AppColors.primary,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.attach_money, color: Colors.white, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            '\$${_totalRevenue.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Text(
                            'Total Revenue (Paid)',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text(
                    'Appointments',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 120,
                          child: _buildMetricCard(
                            'Total Bookings',
                            '$_totalAppointments',
                            Icons.calendar_today,
                            AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 120,
                          child: _buildMetricCard(
                            'Paid',
                            '$_paidAppointments',
                            Icons.check_circle,
                            Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 120,
                          child: _buildMetricCard(
                            'Completed',
                            '$_completedAppointments',
                            Icons.task_alt,
                            Colors.blueGrey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 120,
                          child: _buildMetricCard(
                            'Cancelled',
                            '$_cancelledAppointments',
                            Icons.cancel,
                            Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}