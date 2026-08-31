import 'package:flutter/material.dart';
import '../../config.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

class StudentAttendanceTab extends StatefulWidget {
  const StudentAttendanceTab({super.key});

  @override
  State<StudentAttendanceTab> createState() => _StudentAttendanceTabState();
}

class _StudentAttendanceTabState extends State<StudentAttendanceTab> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getAttendance(studentId: AppConfig.instance.studentId);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {
        _future = ApiService.getAttendance(studentId: AppConfig.instance.studentId);
      }),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('My Attendance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Tap your RFID card at the gate — this updates automatically.', style: TextStyle(color: kSlate)),
          const SizedBox(height: 16),
          AsyncListView<dynamic>(
            future: _future,
            emptyMessage: 'No attendance records yet.',
            builder: (context, rows) => Column(
              children: rows.map((r) {
                final isIn = r['event_type'] == 'in';
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
                      Icon(isIn ? Icons.login : Icons.logout, color: isIn ? kGood : kWarn),
                      const SizedBox(width: 12),
                      Expanded(child: Text('${r['timestamp']}')),
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
