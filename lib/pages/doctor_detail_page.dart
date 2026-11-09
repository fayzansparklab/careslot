import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorDetailPage extends StatefulWidget {
  final String doctorId;
  const DoctorDetailPage({super.key, required this.doctorId});

  @override
  State<DoctorDetailPage> createState() => _DoctorDetailPageState();
}

class _DoctorDetailPageState extends State<DoctorDetailPage> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _doctor;
  List<Map<String, dynamic>> _reviews = [];
  double _avgRating = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _supabase
          .from('doctors')
          .select(
            'id, bio, fee, years_experience, '
            'profiles(full_name, avatar_url), '
            'specialties(name)',
          )
          .eq('id', widget.doctorId)
          .single();

      final reviews = await _supabase
          .from('reviews')
          .select('rating, comment, created_at, profiles(full_name)')
          .eq('doctor_id', widget.doctorId)
          .order('created_at', ascending: false)
          .limit(5);

      final reviewList = List<Map<String, dynamic>>.from(reviews);
      double avg = 0;
      if (reviewList.isNotEmpty) {
        final total = reviewList
            .fold<int>(0, (sum, r) => sum + (r['rating'] as int));
        avg = total / reviewList.length;
      }

      if (!mounted) return;
      setState(() {
        _doctor = data;
        _reviews = reviewList;
        _avgRating = avg;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load doctor: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _stars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final fill = rating - i;
        IconData icon;
        if (fill >= 1) {
          icon = Icons.star;
        } else if (fill >= 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, color: Colors.amber, size: 18);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _doctor == null
              ? const Center(child: Text('Doctor not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundImage:
                              _doctor!['profiles']?['avatar_url'] != null
                                  ? NetworkImage(
                                      _doctor!['profiles']['avatar_url'])
                                  : null,
                          child: _doctor!['profiles']?['avatar_url'] == null
                              ? const Icon(Icons.person, size: 32)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _doctor!['profiles']?['full_name'] ??
                                    'Doctor',
                                style:
                                    Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                _doctor!['specialties']?['name'] ??
                                    'General',
                                style:
                                    Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (_reviews.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _stars(_avgRating),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_avgRating.toStringAsFixed(1)} · '
                                      '${_reviews.length} review'
                                      '${_reviews.length == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '\$${_doctor!['fee']} · '
                      '${_doctor!['years_experience']} years experience',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _doctor!['bio'] ?? 'No bio available.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    if (_reviews.isNotEmpty) ...[
                      Text(
                        'Recent reviews',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ..._reviews.map((r) {
                        final patientName = (r['profiles']
                                as Map<String, dynamic>?)?['full_name'] ??
                            'Patient';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _stars((r['rating'] as int).toDouble()),
                                    const Spacer(),
                                    Text(
                                      patientName,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                if ((r['comment'] as String?)
                                        ?.isNotEmpty ??
                                    false) ...[
                                  const SizedBox(height: 6),
                                  Text(r['comment'] as String),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () =>
                            context.go('/book/${widget.doctorId}'),
                        child: const Text('Book appointment'),
                      ),
                    ),
                  ],
                ),
    );
  }
}