import 'package:flutter/material.dart';
import '../../config.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

class StudentMaintenanceTab extends StatefulWidget {
  const StudentMaintenanceTab({super.key});

  @override
  State<StudentMaintenanceTab> createState() => _StudentMaintenanceTabState();
}

class _StudentMaintenanceTabState extends State<StudentMaintenanceTab> {
  late Future<List<dynamic>> _future;
  final _descCtrl = TextEditingController();
  String _category = 'electrical';
  String _priority = 'medium';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ApiService.getMaintenance(studentId: AppConfig.instance.studentId);
  }

  Future<void> _submit() async {
    if (_descCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ApiService.raiseMaintenance(
        studentId: AppConfig.instance.studentId,
        category: _category,
        description: _descCtrl.text.trim(),
        priority: _priority,
      );
      _descCtrl.clear();
      setState(_reload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request submitted to your warden.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e.toString().replaceAll('Exception: ', '')}')));
      }
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(_reload),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Maintenance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          SectionCard(
            title: 'Raise a new request',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(labelText: 'Category', isDense: true),
                        items: ['electrical', 'plumbing', 'cleaning', 'wifi', 'other']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => _category = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _priority,
                        decoration: const InputDecoration(labelText: 'Priority', isDense: true),
                        items: ['low', 'medium', 'high']
                            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) => setState(() => _priority = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Describe the issue', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.white),
                    child: _submitting ? const Text('Submitting...') : const Text('Submit Request'),
                  ),
                ),
              ],
            ),
          ),

          const Text('My Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          AsyncListView<dynamic>(
            future: _future,
            emptyMessage: 'No requests raised yet.',
            builder: (context, rows) => Column(
              children: rows.map((m) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE4E2DC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(m['category'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        StatusBadge(status: m['status']),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(m['description'] ?? '', style: const TextStyle(color: kSlate, fontSize: 13)),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
