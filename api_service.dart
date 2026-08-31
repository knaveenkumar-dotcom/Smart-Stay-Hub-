import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

/// Thin wrapper around the Node.js backend REST API (see backend/server.js).
/// Every method throws a String-message Exception on failure so screens can
/// just try/catch and show the message in a SnackBar.
class ApiService {
  static String get _base => AppConfig.instance.apiBase;
  static int get _hostelId => AppConfig.instance.hostelId;

  static Future<dynamic> _get(String path) async {
    final res = await http.get(Uri.parse('$_base$path'));
    return _handle(res);
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$_base$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  static Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final res = await http.patch(
      Uri.parse('$_base$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  static dynamic _handle(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(res.body);
    }
    String message = 'Request failed (${res.statusCode})';
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['error'] != null) message = decoded['error'];
    } catch (_) {}
    throw Exception(message);
  }

  // ---------------- Students / login ----------------
  static Future<Map<String, dynamic>> lookupStudentByPhone(String phone) async {
    final result = await _get('/api/students/$_hostelId/lookup?phone=$phone');
    return Map<String, dynamic>.from(result);
  }

  static Future<List<dynamic>> getStudents() =>
      _get('/api/students/$_hostelId').then((r) => List<dynamic>.from(r));

  // ---------------- Dashboard ----------------
  static Future<Map<String, dynamic>> getDashboard() async {
    final result = await _get('/api/dashboard/$_hostelId');
    return Map<String, dynamic>.from(result);
  }

  // ---------------- Attendance ----------------
  static Future<List<dynamic>> getAttendance({int? studentId, String? date}) async {
    final params = <String, String>{};
    if (studentId != null) params['student_id'] = studentId.toString();
    if (date != null) params['date'] = date;
    final query = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    final result = await _get('/api/attendance/$_hostelId$query');
    return List<dynamic>.from(result);
  }

  // ---------------- Visitors ----------------
  static Future<List<dynamic>> getVisitors() =>
      _get('/api/visitors/$_hostelId').then((r) => List<dynamic>.from(r));

  static Future<void> checkinVisitor({
    required String name,
    required String phone,
    int? visitingStudentId,
    String? purpose,
    String? idProofType,
    String? idProofNumber,
  }) =>
      _post('/api/visitors/checkin', {
        'hostel_id': _hostelId,
        'visitor_name': name,
        'visitor_phone': phone,
        'visiting_student_id': visitingStudentId,
        'purpose': purpose,
        'id_proof_type': idProofType,
        'id_proof_number': idProofNumber,
      });

  static Future<void> checkoutVisitor(int id) =>
      _post('/api/visitors/$id/checkout', {});

  // ---------------- Maintenance ----------------
  static Future<List<dynamic>> getMaintenance({int? studentId, String? status}) async {
    final params = <String, String>{};
    if (studentId != null) params['student_id'] = studentId.toString();
    if (status != null) params['status'] = status;
    final query = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    final result = await _get('/api/maintenance/$_hostelId$query');
    return List<dynamic>.from(result);
  }

  static Future<void> raiseMaintenance({
    int? studentId,
    int? roomId,
    required String category,
    required String description,
    required String priority,
  }) =>
      _post('/api/maintenance', {
        'hostel_id': _hostelId,
        'student_id': studentId,
        'room_id': roomId,
        'category': category,
        'description': description,
        'priority': priority,
      });

  static Future<void> updateMaintenanceStatus(int id, String status) =>
      _patch('/api/maintenance/$id', {'status': status});

  // ---------------- Fees ----------------
  static Future<List<dynamic>> getFees({int? studentId, String? status}) async {
    final params = <String, String>{};
    if (studentId != null) params['student_id'] = studentId.toString();
    if (status != null) params['status'] = status;
    final query = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    final result = await _get('/api/fees/$_hostelId$query');
    return List<dynamic>.from(result);
  }

  static Future<void> markFeePaid(int id) => _patch('/api/fees/$id/pay', {});

  static Future<int> sendFeeReminders() async {
    final result = await _post('/api/fees/send-reminders', {});
    return result['remindersSent'] ?? 0;
  }

  // ---------------- Rooms ----------------
  static Future<List<dynamic>> getRooms() =>
      _get('/api/rooms/$_hostelId').then((r) => List<dynamic>.from(r));

  static Future<void> allocateStudent(int roomId, int studentId) =>
      _post('/api/rooms/$roomId/allocate', {'student_id': studentId});

  static Future<void> vacateStudent(int roomId, int studentId) =>
      _post('/api/rooms/$roomId/vacate', {'student_id': studentId});

  // ---------------- Sensors ----------------
  static Future<List<dynamic>> getLatestSensors() =>
      _get('/api/sensors/$_hostelId/latest').then((r) => List<dynamic>.from(r));
}
