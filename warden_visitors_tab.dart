import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

class WardenVisitorsTab extends StatefulWidget {
  const WardenVisitorsTab({super.key});

  @override
  State<WardenVisitorsTab> createState() => _WardenVisitorsTabState();
}

class _WardenVisitorsTabState extends State<WardenVisitorsTab> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getVisitors();
  }

  void _reload() => setState(() => _future = ApiService.getVisitors());

  Future<void> _openCheckinDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final studentIdCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Check In Visitor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Visitor name')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Visitor phone')),
              TextField(controller: studentIdCtrl, decoration: const InputDecoration(labelText: 'Visiting Student ID'), keyboardType: TextInputType.number),
              TextField(controller: purposeCtrl, decoration: const InputDecoration(labelText: 'Purpose')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Check In')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.checkinVisitor(
          name: nameCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
          visitingStudentId: int.tryParse(studentIdCtrl.text.trim()),
          purpose: purposeCtrl.text.trim(),
        );
        _reload();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCheckinDialog,
        backgroundColor: kAccent,
        icon: const Icon(Icons.person_add),
        label: const Text('Check In'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Visitors', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            AsyncListView<dynamic>(
              future: _future,
              emptyMessage: 'No visitors logged yet.',
              builder: (context, rows) => Column(
                children: rows.map((v) {
                  final isActive = v['check_out'] == null;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE4E2DC)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v['visitor_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('Visiting: ${v['student_name'] ?? '-'}', style: const TextStyle(fontSize: 12, color: kSlate)),
                              Text('In: ${v['check_in']}', style: const TextStyle(fontSize: 11, color: kSlate)),
                            ],
                          ),
                        ),
                        if (isActive)
                          TextButton(
                            onPressed: () async {
                              await ApiService.checkoutVisitor(v['id']);
                              _reload();
                            },
                            child: const Text('Check Out'),
                          )
                        else
                          const StatusBadge(status: 'resolved'),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 70), // space for FAB
          ],
        ),
      ),
    );
  }
}
