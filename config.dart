import 'package:shared_preferences/shared_preferences.dart';

/// Holds connection + session settings for the whole app.
/// Loaded from / saved to SharedPreferences so the user only sets it up once.
class AppConfig {
  static final AppConfig instance = AppConfig._internal();
  AppConfig._internal();

  String apiBase = 'http://10.0.2.2:4000'; // 10.0.2.2 = localhost when using Android emulator
  int hostelId = 1;
  String role = ''; // 'student' or 'warden'
  int? studentId;
  String? studentName;

  bool get isSetupComplete => role.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    apiBase = prefs.getString('apiBase') ?? apiBase;
    hostelId = prefs.getInt('hostelId') ?? hostelId;
    role = prefs.getString('role') ?? '';
    studentId = prefs.getInt('studentId');
    studentName = prefs.getString('studentName');
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiBase', apiBase);
    await prefs.setInt('hostelId', hostelId);
    await prefs.setString('role', role);
    if (studentId != null) await prefs.setInt('studentId', studentId!);
    if (studentName != null) await prefs.setString('studentName', studentName!);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('role');
    await prefs.remove('studentId');
    await prefs.remove('studentName');
    role = '';
    studentId = null;
    studentName = null;
  }
}
