import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DoctorListPage extends StatefulWidget {
  const DoctorListPage({super.key});

  @override
  State<DoctorListPage> createState() => _DoctorListPageState();
}

class _DoctorListPageState extends State<DoctorListPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _specialties = [];
  String? _selectedSpecialtyId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final specialties = await _supabase
          .from('specialties')
          .select()
          .order('name');
final selectedId = _selectedSpecialtyId;
var query = _supabase.from('doctors').select(
      'id, bio, fee, years_experience, '
     'profiles(full_name, avatar_url), '
      'specialties(name)',
    );
if (selectedId != null) {
  query = query.eq('specialty_id', selectedId);
}
      final doctors = await query.order('years_experience', ascending: false);
      if (!mounted) return;
      setState(() {
        _specialties = List<Map<String, dynamic>>.from(specialties);
        _doctors = List<Map<String, dynamic>>.from(doctors);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load doctors: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: AppBar(
  title: const Text('Find a doctor'),
  actions: [
    IconButton(
      tooltip: 'Log out',
      icon: const Icon(Icons.logout),
      onPressed: () async {
        await Supabase.instance.client.auth.signOut();
      },
    ),
  ],
),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedSpecialtyId == null,
                    onSelected: (_) {
                      setState(() => _selectedSpecialtyId = null);
                      _load();
                    },
                  ),
                ),
..._specialties.map(
  (s) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(s['name'] as String),
      selected: _selectedSpecialtyId == s['id'].toString(),
      onSelected: (_) {
        setState(() => _selectedSpecialtyId = s['id'].toString());
        _load();
      },
    ),
  ),
),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _doctors.isEmpty
                    ? const Center(child: Text('No doctors found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _doctors.length,
                        itemBuilder: (context, index) {
                          final d = _doctors[index];
                          final profile = d['profiles'] as Map<String, dynamic>?;
                          final spec = d['specialties'] as Map<String, dynamic>?;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: profile?['avatar_url'] != null
                                    ? NetworkImage(profile!['avatar_url'])
                                    : null,
                                child: profile?['avatar_url'] == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(
                                profile?['full_name'] ?? 'Doctor',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${spec?['name'] ?? 'General'} · '
                                '${d['years_experience'] ?? 0} yrs · '
                              '\$${d['fee'] ?? 0}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.go('/doctor/${d['id']}'),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}