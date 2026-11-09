import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  int _total = 0;
  int _paid = 0;
  int _completed = 0;
  int _cancelled = 0;
  double _revenue = 0;

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
        _total = rows.length;
        _paid = paid;
        _completed = completed;
        _cancelled = cancelled;
        _revenue = revenue;
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

  Widget _card(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label, style: TextStyle(color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: 2,
                childAspectRatio: 1.4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: [
                  _card('Total appointments', '$_total',
                      Icons.event, Colors.teal),
                  _card('Revenue (paid)', '\$${_revenue.toStringAsFixed(0)}',
                      Icons.attach_money, Colors.green),
                  _card('Paid', '$_paid', Icons.check_circle, Colors.green),
                  _card('Completed', '$_completed',
                      Icons.done_all, Colors.blueGrey),
                  _card('Cancelled', '$_cancelled',
                      Icons.cancel, Colors.red),
                ],
              ),
            ),
    );
  }
}