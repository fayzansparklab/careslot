import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:careslot/core/theme/app_theme.dart';

class AdminDoctorsPage extends StatefulWidget {
  const AdminDoctorsPage({super.key});

  @override
  State<AdminDoctorsPage> createState() => _AdminDoctorsPageState();
}

class _AdminDoctorsPageState extends State<AdminDoctorsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _specialties = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final docs = await _supabase
          .from('doctors')
          .select(
            'id, fee, years_experience, bio, specialty_id, '
            'profiles(full_name, avatar_url), specialties(name)',
          )
          .order('id');
      final specs =
          await _supabase.from('specialties').select().order('name');
          
      if (!mounted) return;
      setState(() {
        _doctors = List<Map<String, dynamic>>.from(docs);
        _specialties = List<Map<String, dynamic>>.from(specs);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addSpecialty() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Specialty'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Specialty Name',
            hintText: 'e.g. Neurology',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    
    try {
      await _supabase.from('specialties').insert({'name': name});
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add failed: $e')),
      );
    }
  }

  Future<void> _deleteSpecialty(Map<String, dynamic> spec) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Specialty?'),
        content: Text('Are you sure you want to delete "${spec['name']}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    
    try {
      await _supabase
          .from('specialties')
          .delete()
          .eq('id', spec['id']);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  Future<void> _editDoctor(Map<String, dynamic> doc) async {
    final feeController = TextEditingController(text: (doc['fee'] ?? '').toString());
    final yearsController = TextEditingController(text: (doc['years_experience'] ?? '').toString());
    final bioController = TextEditingController(text: doc['bio'] ?? '');
    int? specialtyId = doc['specialty_id'] as int?;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(doc['profiles']?['full_name'] ?? 'Edit Doctor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: feeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Fee (\$)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Years Experience',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: specialtyId,
                  decoration: const InputDecoration(
                    labelText: 'Specialty',
                  ),
                  items: _specialties
                      .map((s) => DropdownMenuItem<int>(
                            value: s['id'] as int,
                            child: Text(s['name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) => setDialogState(() => specialtyId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    try {
      await _supabase.from('doctors').update({
        'fee': num.tryParse(feeController.text.trim()) ?? 0,
        'years_experience': int.tryParse(yearsController.text.trim()) ?? 0,
        'specialty_id': specialtyId,
        'bio': bioController.text.trim(),
      }).eq('id', doc['id']);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Catalog'),
          centerTitle: true,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Doctors'),
              Tab(text: 'Specialties'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Doctors Tab
                  RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _doctors.length,
                      itemBuilder: (context, i) {
                        final d = _doctors[i];
                        final profile = d['profiles'] as Map<String, dynamic>?;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.primaryTint,
                              backgroundImage: profile?['avatar_url'] != null
                                  ? NetworkImage(profile!['avatar_url'])
                                  : null,
                              child: profile?['avatar_url'] == null
                                  ? const Icon(Icons.person, color: AppColors.primary)
                                  : null,
                            ),
                            title: Text(
                              profile?['full_name'] ?? 'Doctor',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${d['specialties']?['name'] ?? '—'} · \$${d['fee']} · ${d['years_experience']} yrs',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit, color: AppColors.primary),
                              onPressed: () => _editDoctor(d),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Specialties Tab
                  RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _specialties.length,
                      itemBuilder: (context, i) {
                        final s = _specialties[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.medical_services, color: AppColors.primary),
                            title: Text(
                              s['name'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteSpecialty(s),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addSpecialty,
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add),
          label: const Text('Add Specialty'),
        ),
      ),
    );
  }
}