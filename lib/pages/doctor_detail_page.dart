import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';


class DoctorDetailPage extends StatefulWidget {
  final String doctorId;
  const DoctorDetailPage({super.key, required this.doctorId});

  @override
  State<DoctorDetailPage> createState() => _DoctorDetailPageState();
}

class _DoctorDetailPageState extends State<DoctorDetailPage> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _doctor;
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
      if (!mounted) return;
      setState(() => _doctor = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load doctor: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _doctor == null
              ? const Center(child: Text('Doctor not found'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundImage: _doctor!['profiles']
                                        ?['avatar_url'] !=
                                    null
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge,
                                ),
                                Text(
                                  _doctor!['specialties']?['name'] ??
                                      'General',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium,
                                ),
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
                      const Spacer(),
    SizedBox(
  width: double.infinity,
  child: FilledButton(
    onPressed: () => context.go('/book/${widget.doctorId}'),
    child: const Text('Book appointment'),
  ),
),
                    ],
                  ),
                ),
    );
  }
}