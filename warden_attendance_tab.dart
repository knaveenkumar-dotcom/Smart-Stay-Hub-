import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

class WardenAttendanceTab extends StatefulWidget {
  const WardenAttendanceTab({super.key});

  @override
  State<WardenAttendanceTab> createState() => _WardenAttendanceTabState();
}

class _WardenAttendanceTabState extends State<WardenAttendanceTab> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getAttendance();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() => _future = ApiService.getAttendance()),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Attendance Log', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Updates automatically from RFID taps at the gate.', style: TextStyle(color: kSlate)),
          const SizedBox(height: 16),
          AsyncListView<dynamic>(
            future: _future,
            emptyMessage: 'No attendance records yet.',
            builder: (context, rows) => Column(
              children: rows.map((r) {
                final isIn = r['event_type'] == 'in';
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
                      Icon(isIn ? Icons.login : Icons.logout, color: isIn ? kGood : kWarn, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['student_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('${r['timestamp']}', style: const TextStyle(fontSize: 12, color: kSlate)),
                          ],
                        ),
                      ),
                      StatusBadge(status: r['event_type']),
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
