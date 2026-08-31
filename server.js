/**
 * Smart PG/Hostel Management Platform - Backend API
 * ---------------------------------------------------
 * Covers: Digital Attendance (RFID via ESP32), Visitor Management,
 * Maintenance Requests, Fee Reminders, Room Allocation.
 *
 * Run:
 *   npm install
 *   node server.js
 *
 * DB: SQLite file (hostel.db) created automatically on first run.
 */

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const path = require('path');
const fs = require('fs');
const Database = require('better-sqlite3');
const cron = require('node-cron');

const app = express();
const PORT = process.env.PORT || 4000;
const DB_PATH = path.join(__dirname, 'hostel.db');

// ---------- DB Setup ----------
const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
db.exec(schema);

app.use(cors());
app.use(bodyParser.json());

// Simple API key check for ESP32 devices (set DEVICE_API_KEY in .env)
function checkDeviceKey(req, res, next) {
  const key = req.headers['x-device-key'];
  if (!process.env.DEVICE_API_KEY || key === process.env.DEVICE_API_KEY) {
    return next();
  }
  return res.status(401).json({ error: 'Invalid device key' });
}

// =====================================================
// 1. HOSTELS
// =====================================================
app.post('/api/hostels', (req, res) => {
  const { name, address, owner_name, owner_phone, subscription_plan } = req.body;
  const stmt = db.prepare(`INSERT INTO hostels (name, address, owner_name, owner_phone, subscription_plan)
                            VALUES (?, ?, ?, ?, ?)`);
  const info = stmt.run(name, address, owner_name, owner_phone, subscription_plan || 'basic');
  res.json({ id: info.lastInsertRowid });
});

app.get('/api/hostels', (req, res) => {
  res.json(db.prepare('SELECT * FROM hostels').all());
});

// =====================================================
// 2. ROOM ALLOCATION
// =====================================================
app.post('/api/rooms', (req, res) => {
  const { hostel_id, room_number, capacity, floor, room_type, monthly_rent } = req.body;
  const stmt = db.prepare(`INSERT INTO rooms (hostel_id, room_number, capacity, floor, room_type, monthly_rent)
                            VALUES (?, ?, ?, ?, ?, ?)`);
  const info = stmt.run(hostel_id, room_number, capacity, floor, room_type || 'shared', monthly_rent);
  res.json({ id: info.lastInsertRowid });
});

app.get('/api/rooms/:hostel_id', (req, res) => {
  const rooms = db.prepare(`SELECT *, (capacity - occupied) AS vacancy FROM rooms WHERE hostel_id = ?`)
    .all(req.params.hostel_id);
  res.json(rooms);
});

// Allocate a student to a room
app.post('/api/rooms/:room_id/allocate', (req, res) => {
  const { student_id } = req.body;
  const room = db.prepare('SELECT * FROM rooms WHERE id = ?').get(req.params.room_id);
  if (!room) return res.status(404).json({ error: 'Room not found' });
  if (room.occupied >= room.capacity) return res.status(400).json({ error: 'Room is full' });

  db.prepare('UPDATE students SET room_id = ? WHERE id = ?').run(req.params.room_id, student_id);
  db.prepare('UPDATE rooms SET occupied = occupied + 1 WHERE id = ?').run(req.params.room_id);
  res.json({ success: true });
});

// Vacate a student from their room
app.post('/api/rooms/:room_id/vacate', (req, res) => {
  const { student_id } = req.body;
  db.prepare('UPDATE students SET room_id = NULL, status = ? WHERE id = ?').run('vacated', student_id);
  db.prepare('UPDATE rooms SET occupied = MAX(occupied - 1, 0) WHERE id = ?').run(req.params.room_id);
  res.json({ success: true });
});

// =====================================================
// 3. STUDENTS (with RFID tag mapping)
// =====================================================
app.post('/api/students', (req, res) => {
  const { hostel_id, name, phone, email, rfid_tag, guardian_name, guardian_phone,
          joining_date, fee_due_day, monthly_fee } = req.body;
  const stmt = db.prepare(`INSERT INTO students
    (hostel_id, name, phone, email, rfid_tag, guardian_name, guardian_phone, joining_date, fee_due_day, monthly_fee)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`);
  const info = stmt.run(hostel_id, name, phone, email, rfid_tag, guardian_name, guardian_phone,
    joining_date, fee_due_day || 5, monthly_fee);
  res.json({ id: info.lastInsertRowid });
});

app.get('/api/students/:hostel_id', (req, res) => {
  res.json(db.prepare('SELECT * FROM students WHERE hostel_id = ?').all(req.params.hostel_id));
});

// Simple lookup for the mobile app's "login" (phone number based, no password —
// fine for a college project; add real auth before any real-world deployment)
app.get('/api/students/:hostel_id/lookup', (req, res) => {
  const { phone } = req.query;
  if (!phone) return res.status(400).json({ error: 'phone query param required' });
  const student = db.prepare('SELECT * FROM students WHERE hostel_id = ? AND phone = ?')
    .get(req.params.hostel_id, phone);
  if (!student) return res.status(404).json({ error: 'No student found with this phone number' });
  res.json(student);
});

// =====================================================
// 4. DIGITAL ATTENDANCE (called by ESP32 on RFID scan)
// =====================================================
// ESP32 posts: { rfid_tag, device_id, hostel_id }
// Server auto-toggles in/out based on the student's last event.
app.post('/api/attendance/scan', checkDeviceKey, (req, res) => {
  const { rfid_tag, device_id, hostel_id } = req.body;
  if (!rfid_tag) return res.status(400).json({ error: 'rfid_tag required' });

  const student = db.prepare('SELECT * FROM students WHERE rfid_tag = ? AND hostel_id = ?')
    .get(rfid_tag, hostel_id);

  if (!student) {
    return res.status(404).json({ error: 'Unknown RFID tag', rfid_tag });
  }

  const lastEvent = db.prepare(`SELECT * FROM attendance WHERE student_id = ?
                                 ORDER BY timestamp DESC LIMIT 1`).get(student.id);
  const nextType = (!lastEvent || lastEvent.event_type === 'out') ? 'in' : 'out';

  db.prepare(`INSERT INTO attendance (student_id, hostel_id, rfid_tag, event_type, device_id)
              VALUES (?, ?, ?, ?, ?)`)
    .run(student.id, hostel_id, rfid_tag, nextType, device_id);

  res.json({
    student_name: student.name,
    event_type: nextType,
    message: `${student.name} marked ${nextType.toUpperCase()}`
  });
});

app.get('/api/attendance/:hostel_id', (req, res) => {
  const { date, student_id } = req.query; // optional filters
  let query = `SELECT a.*, s.name AS student_name FROM attendance a
               JOIN students s ON s.id = a.student_id WHERE a.hostel_id = ?`;
  const params = [req.params.hostel_id];
  if (date) { query += ' AND date(a.timestamp) = ?'; params.push(date); }
  if (student_id) { query += ' AND a.student_id = ?'; params.push(student_id); }
  query += ' ORDER BY a.timestamp DESC LIMIT 200';
  res.json(db.prepare(query).all(...params));
});

// =====================================================
// 4b. SENSOR MONITORING (PIR, DHT22, MQ-2, HC-SR04, Reed switch)
// =====================================================
// ESP32 posts every ~10s: { hostel_id, device_id, motion_detected,
// temperature_c, humidity_pct, gas_raw, water_level_pct, door_closed }
const GAS_ALERT_THRESHOLD = 1800; // tune after calibrating your MQ-2
const WATER_LOW_THRESHOLD = 20;   // percent

app.post('/api/sensors/reading', checkDeviceKey, (req, res) => {
  const { hostel_id, device_id, motion_detected, temperature_c, humidity_pct,
          gas_raw, water_level_pct, door_closed } = req.body;

  db.prepare(`INSERT INTO sensor_readings
    (hostel_id, device_id, motion_detected, temperature_c, humidity_pct, gas_raw, water_level_pct, door_closed)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)`)
    .run(hostel_id, device_id, motion_detected ? 1 : 0, temperature_c, humidity_pct,
         gas_raw, water_level_pct, door_closed ? 1 : 0);

  const alerts = [];
  if (gas_raw > GAS_ALERT_THRESHOLD) alerts.push('GAS/SMOKE LEVEL HIGH — check kitchen/mess area');
  if (water_level_pct !== undefined && water_level_pct !== null && water_level_pct < WATER_LOW_THRESHOLD) {
    alerts.push('WATER TANK LOW — below 20%');
  }
  if (door_closed === false) alerts.push('DOOR OPEN');

  if (alerts.length) console.log(`[ALERT] Hostel ${hostel_id} (${device_id}):`, alerts.join(' | '));

  res.json({ success: true, alerts });
});

// Latest reading per device for a hostel (for dashboard cards)
app.get('/api/sensors/:hostel_id/latest', (req, res) => {
  const rows = db.prepare(`
    SELECT sr.* FROM sensor_readings sr
    INNER JOIN (
      SELECT device_id, MAX(timestamp) AS max_ts FROM sensor_readings
      WHERE hostel_id = ? GROUP BY device_id
    ) latest ON sr.device_id = latest.device_id AND sr.timestamp = latest.max_ts
    WHERE sr.hostel_id = ?`).all(req.params.hostel_id, req.params.hostel_id);
  res.json(rows);
});

// Recent history (for a simple chart, e.g. last 50 readings for one device)
app.get('/api/sensors/:hostel_id/history', (req, res) => {
  const { device_id, limit } = req.query;
  let query = `SELECT * FROM sensor_readings WHERE hostel_id = ?`;
  const params = [req.params.hostel_id];
  if (device_id) { query += ' AND device_id = ?'; params.push(device_id); }
  query += ' ORDER BY timestamp DESC LIMIT ?';
  params.push(Number(limit) || 50);
  res.json(db.prepare(query).all(...params));
});

// =====================================================
// 5. VISITOR MANAGEMENT
// =====================================================
app.post('/api/visitors/checkin', (req, res) => {
  const { hostel_id, visitor_name, visitor_phone, visiting_student_id, purpose,
          id_proof_type, id_proof_number } = req.body;
  const stmt = db.prepare(`INSERT INTO visitors
    (hostel_id, visitor_name, visitor_phone, visiting_student_id, purpose, id_proof_type, id_proof_number)
    VALUES (?, ?, ?, ?, ?, ?, ?)`);
  const info = stmt.run(hostel_id, visitor_name, visitor_phone, visiting_student_id, purpose,
    id_proof_type, id_proof_number);
  res.json({ id: info.lastInsertRowid });
});

app.post('/api/visitors/:id/checkout', (req, res) => {
  db.prepare(`UPDATE visitors SET check_out = datetime('now') WHERE id = ?`).run(req.params.id);
  res.json({ success: true });
});

app.get('/api/visitors/:hostel_id', (req, res) => {
  const rows = db.prepare(`SELECT v.*, s.name AS student_name FROM visitors v
                            LEFT JOIN students s ON s.id = v.visiting_student_id
                            WHERE v.hostel_id = ? ORDER BY v.check_in DESC LIMIT 200`)
    .all(req.params.hostel_id);
  res.json(rows);
});

// Currently inside the premises (checked in, not checked out)
app.get('/api/visitors/:hostel_id/active', (req, res) => {
  const rows = db.prepare(`SELECT v.*, s.name AS student_name FROM visitors v
                            LEFT JOIN students s ON s.id = v.visiting_student_id
                            WHERE v.hostel_id = ? AND v.check_out IS NULL`)
    .all(req.params.hostel_id);
  res.json(rows);
});

// =====================================================
// 6. MAINTENANCE REQUESTS
// =====================================================
app.post('/api/maintenance', (req, res) => {
  const { hostel_id, student_id, room_id, category, description, priority } = req.body;
  const stmt = db.prepare(`INSERT INTO maintenance_requests
    (hostel_id, student_id, room_id, category, description, priority)
    VALUES (?, ?, ?, ?, ?, ?)`);
  const info = stmt.run(hostel_id, student_id, room_id, category, description, priority || 'medium');
  res.json({ id: info.lastInsertRowid });
});

app.get('/api/maintenance/:hostel_id', (req, res) => {
  const { status, student_id } = req.query;
  let query = `SELECT * FROM maintenance_requests WHERE hostel_id = ?`;
  const params = [req.params.hostel_id];
  if (status) { query += ' AND status = ?'; params.push(status); }
  if (student_id) { query += ' AND student_id = ?'; params.push(student_id); }
  query += ' ORDER BY created_at DESC';
  res.json(db.prepare(query).all(...params));
});

app.patch('/api/maintenance/:id', (req, res) => {
  const { status } = req.body;
  const resolvedAt = status === 'resolved' ? `datetime('now')` : 'NULL';
  db.prepare(`UPDATE maintenance_requests SET status = ?, resolved_at = ${resolvedAt} WHERE id = ?`)
    .run(status, req.params.id);
  res.json({ success: true });
});

// =====================================================
// 7. FEE REMINDERS
// =====================================================
app.post('/api/fees', (req, res) => {
  const { hostel_id, student_id, amount, month } = req.body;
  const stmt = db.prepare(`INSERT INTO fee_payments (hostel_id, student_id, amount, month)
                            VALUES (?, ?, ?, ?)`);
  const info = stmt.run(hostel_id, student_id, amount, month);
  res.json({ id: info.lastInsertRowid });
});

app.get('/api/fees/:hostel_id', (req, res) => {
  const { status, month, student_id } = req.query;
  let query = `SELECT f.*, s.name AS student_name, s.phone FROM fee_payments f
               JOIN students s ON s.id = f.student_id WHERE f.hostel_id = ?`;
  const params = [req.params.hostel_id];
  if (status) { query += ' AND f.status = ?'; params.push(status); }
  if (month) { query += ' AND f.month = ?'; params.push(month); }
  if (student_id) { query += ' AND f.student_id = ?'; params.push(student_id); }
  query += ' ORDER BY f.month DESC';
  res.json(db.prepare(query).all(...params));
});

app.patch('/api/fees/:id/pay', (req, res) => {
  db.prepare(`UPDATE fee_payments SET status = 'paid', paid_on = datetime('now') WHERE id = ?`)
    .run(req.params.id);
  res.json({ success: true });
});

// Manual trigger to send reminders (also runs on cron, see below)
app.post('/api/fees/send-reminders', async (req, res) => {
  const count = await sendPendingFeeReminders();
  res.json({ remindersSent: count });
});

// Reminder logic - integrate real SMS/WhatsApp API (Twilio placeholder below)
async function sendPendingFeeReminders() {
  const pending = db.prepare(`SELECT f.*, s.name, s.phone FROM fee_payments f
                               JOIN students s ON s.id = f.student_id
                               WHERE f.status IN ('pending', 'overdue')`).all();
  let sent = 0;
  for (const fee of pending) {
    // TODO: plug in real SMS/WhatsApp provider (Twilio, MSG91, etc.)
    console.log(`[REMINDER] To ${fee.name} (${fee.phone}): Fee of Rs.${fee.amount} for ${fee.month} is due.`);
    db.prepare(`UPDATE fee_payments SET reminder_sent_count = reminder_sent_count + 1,
                last_reminder_at = datetime('now') WHERE id = ?`).run(fee.id);
    sent++;
  }
  return sent;
}

// Mark fees overdue automatically (past due_day of the month, still pending)
function markOverdueFees() {
  const today = new Date();
  const students = db.prepare('SELECT * FROM students WHERE status = ?').all('active');
  for (const s of students) {
    if (today.getDate() > s.fee_due_day) {
      db.prepare(`UPDATE fee_payments SET status = 'overdue'
                  WHERE student_id = ? AND status = 'pending'`).run(s.id);
    }
  }
}

// Runs every day at 9 AM: mark overdue + send reminders automatically
cron.schedule('0 9 * * *', async () => {
  markOverdueFees();
  const count = await sendPendingFeeReminders();
  console.log(`[CRON] Daily fee reminder job done. Sent: ${count}`);
});

// =====================================================
// DASHBOARD SUMMARY (for frontend home screen)
// =====================================================
app.get('/api/dashboard/:hostel_id', (req, res) => {
  const hostelId = req.params.hostel_id;
  const totalStudents = db.prepare('SELECT COUNT(*) c FROM students WHERE hostel_id = ? AND status = ?')
    .get(hostelId, 'active').c;
  const totalRooms = db.prepare('SELECT COUNT(*) c FROM rooms WHERE hostel_id = ?').get(hostelId).c;
  const vacantBeds = db.prepare('SELECT SUM(capacity - occupied) v FROM rooms WHERE hostel_id = ?')
    .get(hostelId).v || 0;
  const openMaintenance = db.prepare(`SELECT COUNT(*) c FROM maintenance_requests
    WHERE hostel_id = ? AND status != 'resolved'`).get(hostelId).c;
  const pendingFees = db.prepare(`SELECT COUNT(*) c FROM fee_payments
    WHERE hostel_id = ? AND status IN ('pending','overdue')`).get(hostelId).c;
  const activeVisitors = db.prepare(`SELECT COUNT(*) c FROM visitors
    WHERE hostel_id = ? AND check_out IS NULL`).get(hostelId).c;
  const studentsInside = db.prepare(`
    SELECT COUNT(*) c FROM (
      SELECT student_id, event_type FROM attendance a1
      WHERE hostel_id = ? AND timestamp = (
        SELECT MAX(timestamp) FROM attendance a2 WHERE a2.student_id = a1.student_id
      )
    ) WHERE event_type = 'in'`).get(hostelId).c;

  res.json({ totalStudents, totalRooms, vacantBeds, openMaintenance, pendingFees, activeVisitors, studentsInside });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Smart PG/Hostel backend running on port ${PORT}`);
});
