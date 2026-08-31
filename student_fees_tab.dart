import 'package:flutter/material.dart';
import '../../config.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

class StudentFeesTab extends StatefulWidget {
  const StudentFeesTab({super.key});

  @override
  State<StudentFeesTab> createState() => _StudentFeesTabState();
}

class _StudentFeesTabState extends State<StudentFeesTab> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getFees(studentId: AppConfig.instance.studentId);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {
        _future = ApiService.getFees(studentId: AppConfig.instance.studentId);
      }),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('My Fees', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Payment status by month. Pay your warden directly, then ask them to mark it paid.',
              style: TextStyle(color: kSlate)),
          const SizedBox(height: 16),
          AsyncListView<dynamic>(
            future: _future,
            emptyMessage: 'No fee records yet.',
            builder: (context, rows) => Column(
              children: rows.map((f) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE4E2DC)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f['month'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('₹${f['amount']}', style: const TextStyle(color: kSlate, fontSize: 13)),
                      ],
                    ),
                    StatusBadge(status: f['status']),
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
