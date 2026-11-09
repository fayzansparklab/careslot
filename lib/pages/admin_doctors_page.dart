import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
            'profiles(full_name), specialties(name)',
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
        title: const Text('New specialty'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
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
        SnackBar(content: Text('Add specialty failed: $e')),
      );
    }
  }

  Future<void> _deleteSpecialty(Map<String, dynamic> spec) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete specialty?'),
        content: Text('Delete "${spec['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
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
    final feeController =
        TextEditingController(text: (doc['fee'] ?? '').toString());
    final yearsController =
        TextEditingController(text: (doc['years_experience'] ?? '').toString());
    final bioController = TextEditingController(text: doc['bio'] ?? '');
    int? specialtyId = doc['specialty_id'] as int?;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(doc['profiles']?['full_name'] ?? 'Edit doctor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: feeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Fee (\$)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Years experience',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: specialtyId,
                  decoration: const InputDecoration(
                    labelText: 'Specialty',
                    border: OutlineInputBorder(),
                  ),
                  items: _specialties
                      .map(
                        (s) => DropdownMenuItem<int>(
                          value: s['id'] as int,
                          child: Text(s['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => specialtyId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
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
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    try {
      await _supabase.from('doctors').update({
        'fee': num.tryParse(feeController.text.trim()) ?? 0,
        'years_experience':
            int.tryParse(yearsController.text.trim()) ?? 0,
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
          title: const Text('Doctors & Specialties'),
          bottom: const TabBar(
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
                  RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: _doctors.length,
                      itemBuilder: (context, i) {
                        final d = _doctors[i];
                        return ListTile(
                          title: Text(
                            d['profiles']?['full_name'] ?? 'Doctor',
                          ),
                          subtitle: Text(
                            '${d['specialties']?['name'] ?? '—'} · '
                            '\$${d['fee']} · ${d['years_experience']} yrs',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editDoctor(d),
                          ),
                        );
                      },
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: _specialties.length,
                      itemBuilder: (context, i) {
                        final s = _specialties[i];
                        return ListTile(
                          title: Text(s['name'] as String),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteSpecialty(s),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addSpecialty,
          icon: const Icon(Icons.add),
          label: const Text('Add specialty'),
        ),
      ),
    );
  }
}