import 'package:flutter/material.dart';
import 'config.dart';
import 'screens/setup_screen.dart';
import 'screens/student/student_shell.dart';
import 'screens/warden/warden_shell.dart';
import 'widgets/common.dart';

void main() {
  runApp(const HostelOSApp());
}

class HostelOSApp extends StatelessWidget {
  const HostelOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HostelOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kAccent),
        scaffoldBackgroundColor: const Color(0xFFF6F5F2),
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      home: const _StartupGate(),
    );
  }
}

/// Loads saved config first, then routes to Setup / Student / Warden.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await AppConfig.instance.load();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!AppConfig.instance.isSetupComplete) {
      return const SetupScreen();
    }
    return AppConfig.instance.role == 'student' ? const StudentShell() : const WardenShell();
  }
}
