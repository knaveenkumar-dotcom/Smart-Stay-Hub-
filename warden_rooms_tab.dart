import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

class WardenRoomsTab extends StatefulWidget {
  const WardenRoomsTab({super.key});

  @override
  State<WardenRoomsTab> createState() => _WardenRoomsTabState();
}

class _WardenRoomsTabState extends State<WardenRoomsTab> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getRooms();
  }

  void _reload() => setState(() => _future = ApiService.getRooms());

  Future<void> _openAllocateDialog(int roomId) async {
    final studentIdCtrl = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allocate / Vacate'),
        content: TextField(
          controller: studentIdCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Student ID'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'vacate'), child: const Text('Vacate')),
          ElevatedButton(onPressed: () => Navigator.pop(context, 'allocate'), child: const Text('Allocate')),
        ],
      ),
    );
    final studentId = int.tryParse(studentIdCtrl.text.trim());
    if (action == null || studentId == null) return;
    try {
      if (action == 'allocate') {
        await ApiService.allocateStudent(roomId, studentId);
      } else {
        await ApiService.vacateStudent(roomId, studentId);
      }
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Room Allocation', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Tap a room to allocate or vacate a student.', style: TextStyle(color: kSlate)),
          const SizedBox(height: 16),
          AsyncListView<dynamic>(
            future: _future,
            emptyMessage: 'No rooms added yet.',
            builder: (context, rows) => Column(
              children: rows.map((r) {
                final vacancy = r['vacancy'] ?? 0;
                return InkWell(
                  onTap: () => _openAllocateDialog(r['id']),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
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
                              Text('Room ${r['room_number']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('Floor ${r['floor'] ?? '-'} · ${r['room_type']} · ₹${r['monthly_rent'] ?? '-'}',
                                  style: const TextStyle(fontSize: 12, color: kSlate)),
                            ],
                          ),
                        ),
                        Text('${r['occupied']}/${r['capacity']}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: vacancy > 0 ? kGood : kBad)),
                      ],
                    ),
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
