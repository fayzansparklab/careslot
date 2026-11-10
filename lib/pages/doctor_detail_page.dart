import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:careslot/core/theme/app_theme.dart';

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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (_doctor == null) {
      return const Scaffold(body: Center(child: Text('Doctor not found')));
    }

    final textTheme = Theme.of(context).textTheme;
    final profile = _doctor!['profiles'] as Map<String, dynamic>?;
    final spec = _doctor!['specialties'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/doctors'),
        ),
      ),
      // Sticky Bottom Button
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => context.go('/book/${widget.doctorId}'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Book Appointment'),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Profile
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primaryTint,
                    backgroundImage: profile?['avatar_url'] != null
                        ? NetworkImage(profile!['avatar_url'])
                        : null,
                    child: profile?['avatar_url'] == null
                        ? Icon(Icons.person, size: 50, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    profile?['full_name'] ?? 'Doctor',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spec?['name'] ?? 'General',
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_reviews.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _stars(_avgRating),
                        const SizedBox(width: 8),
                        Text(
                          '${_avgRating.toStringAsFixed(1)} (${_reviews.length} reviews)',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 32),

            // 2. Visit Details Cards
            Row(
              children: [
                Expanded(
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.attach_money, color: AppColors.primary, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            '\$${_doctor!['fee']}',
                            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text('Visit Fee', style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.work_outline, color: AppColors.primary, size: 28),
                          const SizedBox(height: 8),
                          Text(
                            '${_doctor!['years_experience']} Years',
                            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text('Experience', style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),

            // 3. About
            Text(
              'About',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _doctor!['bio'] ?? 'No bio available.',
              style: textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 24),

            // 4. Reviews
            if (_reviews.isNotEmpty) ...[
              Text(
                'Patient Reviews',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ..._reviews.map((r) {
                final patientName = (r['profiles'] as Map<String, dynamic>?)?['full_name'] ?? 'Patient';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if ((r['comment'] as String?)?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 8),
                          Text(
                            r['comment'] as String,
                            style: textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}