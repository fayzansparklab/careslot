import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:careslot/core/widgets/app_logo.dart';

import 'package:careslot/core/theme/app_theme.dart';

class DoctorListPage extends StatefulWidget {
  const DoctorListPage({super.key});

  @override
  State<DoctorListPage> createState() => _DoctorListPageState();
}

class _DoctorListPageState extends State<DoctorListPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _specialties = [];
  List<Map<String, dynamic>> _filteredDoctors = [];
  
  String? _selectedSpecialtyId;
  String _searchQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final specialties = await _supabase.from('specialties').select().order('name');
      
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
        _applyFilters();
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

  void _applyFilters() {
    if (_searchQuery.isEmpty) {
      _filteredDoctors = _doctors;
    } else {
      _filteredDoctors = _doctors.where((d) {
        final name = (d['profiles']?['full_name'] as String? ?? '').toLowerCase();
        final spec = (d['specialties']?['name'] as String? ?? '').toLowerCase();
        return name.contains(_searchQuery) || spec.contains(_searchQuery);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(height: 40),
        centerTitle: true,
        // If you want the logout button here, you can add it back:
        // actions: [ ... ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                  _applyFilters();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search doctors, specialties...',
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

          // 2. Specialty Chips
          SizedBox(
            height: 40,
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
          
          const SizedBox(height: 16),

          // 3. Doctor Cards
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDoctors.isEmpty
                    ? Center(
                        child: Text(
                          'No doctors found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredDoctors.length,
                        itemBuilder: (context, index) {
                          final d = _filteredDoctors[index];
                          final profile = d['profiles'] as Map<String, dynamic>?;
                          final spec = d['specialties'] as Map<String, dynamic>?;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => context.go('/doctor/${d['id']}'),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Avatar
                                    CircleAvatar(
                                      radius: 32,
                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                      backgroundImage: profile?['avatar_url'] != null
                                          ? NetworkImage(profile!['avatar_url'])
                                          : null,
                                      child: profile?['avatar_url'] == null
                                          ? const Icon(Icons.person, size: 32, color: AppColors.primary)
                                          : null,
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            profile?['full_name'] ?? 'Doctor',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            spec?['name'] ?? 'General',
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.star, size: 16, color: Colors.amber),
                                              const SizedBox(width: 4),
                                              const Text('4.8', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              const SizedBox(width: 12),
                                              Icon(Icons.work_outline, size: 16, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Text('${d['years_experience']} yrs', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Fee
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '\$${d['fee']}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'per visit',
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
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