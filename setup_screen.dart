import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import 'student/student_shell.dart';
import 'warden/warden_shell.dart';

/// Shown once (or whenever the user logs out). Lets the user point the app
/// at the backend server, pick their role, and — for students — look
/// themselves up by phone number (simple stand-in for real auth).
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _apiBaseCtrl = TextEditingController(text: AppConfig.instance.apiBase);
  final _hostelIdCtrl = TextEditingController(text: AppConfig.instance.hostelId.toString());
  final _phoneCtrl = TextEditingController();
  String _role = 'warden';
  bool _loading = false;
  String? _error;

  Future<void> _continue() async {
    setState(() { _loading = true; _error = null; });
    try {
      AppConfig.instance.apiBase = _apiBaseCtrl.text.trim();
      AppConfig.instance.hostelId = int.tryParse(_hostelIdCtrl.text.trim()) ?? 1;
      AppConfig.instance.role = _role;

      if (_role == 'student') {
        final student = await ApiService.lookupStudentByPhone(_phoneCtrl.text.trim());
        AppConfig.instance.studentId = student['id'];
        AppConfig.instance.studentName = student['name'];
      }

      await AppConfig.instance.save();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => _role == 'student' ? const StudentShell() : const WardenShell(),
      ));
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text('Hostel', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kInk)),
              const Text('OS', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kAccent)),
              const SizedBox(height: 6),
              const Text('Set up your connection to get started', style: TextStyle(color: kSlate)),
              const SizedBox(height: 28),

              const Text('Server address', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _apiBaseCtrl,
                decoration: const InputDecoration(
                  hintText: 'http://192.168.1.100:4000',
                  border: OutlineInputBorder(),
                ),
              ),
              const Text(
                'Use your backend\'s LAN IP. On the Android emulator, 10.0.2.2 maps to your laptop\'s localhost.',
                style: TextStyle(fontSize: 11, color: kSlate),
              ),
              const SizedBox(height: 16),

              const Text('Hostel ID', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _hostelIdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),

              const Text('I am a...', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _RoleButton(
                      label: 'Warden / Owner',
                      selected: _role == 'warden',
                      onTap: () => setState(() => _role = 'warden'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RoleButton(
                      label: 'Student',
                      selected: _role == 'student',
                      onTap: () => setState(() => _role = 'student'),
                    ),
                  ),
                ],
              ),

              if (_role == 'student') ...[
                const SizedBox(height: 16),
                const Text('Your registered phone number', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: '9876543210', border: OutlineInputBorder()),
                ),
                const Text(
                  'Must match the phone number your warden used when adding you as a student.',
                  style: TextStyle(fontSize: 11, color: kSlate),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: kBad, fontSize: 13)),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kInk,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _loading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Continue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RoleButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? kAccent.withOpacity(0.12) : Colors.white,
          border: Border.all(color: selected ? kAccent : const Color(0xFFE4E2DC), width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600, color: selected ? kAccent : kInk),
        ),
      ),
    );
  }
}
