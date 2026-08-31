import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

class WardenFeesTab extends StatefulWidget {
  const WardenFeesTab({super.key});

  @override
  State<WardenFeesTab> createState() => _WardenFeesTabState();
}

class _WardenFeesTabState extends State<WardenFeesTab> {
  late Future<List<dynamic>> _future;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getFees();
  }

  void _reload() => setState(() => _future = ApiService.getFees());

  Future<void> _sendReminders() async {
    setState(() => _sending = true);
    try {
      final count = await ApiService.sendFeeReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reminders sent: $count')));
      }
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Fee Reminders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _sending ? null : _sendReminders,
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(_sending ? 'Sending...' : 'Send Reminders Now (Pending + Overdue)'),
            ),
          ),
          const SizedBox(height: 16),
          AsyncListView<dynamic>(
            future: _future,
            emptyMessage: 'No fee records yet.',
            builder: (context, rows) => Column(
              children: rows.map((f) {
                final paid = f['status'] == 'paid';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
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
                            Text(f['student_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('${f['month']} · ₹${f['amount']}', style: const TextStyle(fontSize: 12, color: kSlate)),
                            Text('Reminders sent: ${f['reminder_sent_count']}', style: const TextStyle(fontSize: 11, color: kSlate)),
                          ],
                        ),
                      ),
                      StatusBadge(status: f['status']),
                      if (!paid)
                        TextButton(
                          onPressed: () async {
                            await ApiService.markFeePaid(f['id']);
                            _reload();
                          },
                          child: const Text('Mark Paid'),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
