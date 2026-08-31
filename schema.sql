-- ============================================
-- Smart PG/Hostel Management Platform - Schema
-- ============================================

CREATE TABLE IF NOT EXISTS hostels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    address TEXT,
    owner_name TEXT,
    owner_phone TEXT,
    subscription_plan TEXT DEFAULT 'basic', -- basic / premium
    subscription_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS rooms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostel_id INTEGER NOT NULL,
    room_number TEXT NOT NULL,
    capacity INTEGER NOT NULL,
    occupied INTEGER DEFAULT 0,
    floor INTEGER,
    room_type TEXT DEFAULT 'shared', -- single / shared / dorm
    monthly_rent REAL,
    FOREIGN KEY (hostel_id) REFERENCES hostels(id)
);

CREATE TABLE IF NOT EXISTS students (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostel_id INTEGER NOT NULL,
    room_id INTEGER,
    name TEXT NOT NULL,
    phone TEXT,
    email TEXT,
    rfid_tag TEXT UNIQUE,          -- RFID card UID linked to student
    guardian_name TEXT,
    guardian_phone TEXT,
    joining_date TEXT,
    fee_due_day INTEGER DEFAULT 5, -- day of month fee is due
    monthly_fee REAL,
    status TEXT DEFAULT 'active',  -- active / vacated
    FOREIGN KEY (hostel_id) REFERENCES hostels(id),
    FOREIGN KEY (room_id) REFERENCES rooms(id)
);

CREATE TABLE IF NOT EXISTS attendance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    student_id INTEGER NOT NULL,
    hostel_id INTEGER NOT NULL,
    rfid_tag TEXT,
    event_type TEXT NOT NULL,   -- 'in' or 'out'
    device_id TEXT,             -- which ESP32 device scanned
    timestamp TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (student_id) REFERENCES students(id),
    FOREIGN KEY (hostel_id) REFERENCES hostels(id)
);

CREATE TABLE IF NOT EXISTS visitors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostel_id INTEGER NOT NULL,
    visitor_name TEXT NOT NULL,
    visitor_phone TEXT,
    visiting_student_id INTEGER,
    purpose TEXT,
    check_in TEXT DEFAULT (datetime('now')),
    check_out TEXT,
    id_proof_type TEXT,       -- Aadhar / License / etc
    id_proof_number TEXT,
    FOREIGN KEY (hostel_id) REFERENCES hostels(id),
    FOREIGN KEY (visiting_student_id) REFERENCES students(id)
);

CREATE TABLE IF NOT EXISTS maintenance_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostel_id INTEGER NOT NULL,
    student_id INTEGER,
    room_id INTEGER,
    category TEXT,             -- electrical / plumbing / cleaning / wifi / other
    description TEXT,
    priority TEXT DEFAULT 'medium', -- low / medium / high
    status TEXT DEFAULT 'open',      -- open / in_progress / resolved
    created_at TEXT DEFAULT (datetime('now')),
    resolved_at TEXT,
    FOREIGN KEY (hostel_id) REFERENCES hostels(id),
    FOREIGN KEY (student_id) REFERENCES students(id),
    FOREIGN KEY (room_id) REFERENCES rooms(id)
);

CREATE TABLE IF NOT EXISTS fee_payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostel_id INTEGER NOT NULL,
    student_id INTEGER NOT NULL,
    amount REAL NOT NULL,
    month TEXT NOT NULL,        -- e.g. '2026-07'
    status TEXT DEFAULT 'pending', -- pending / paid / overdue
    paid_on TEXT,
    reminder_sent_count INTEGER DEFAULT 0,
    last_reminder_at TEXT,
    FOREIGN KEY (hostel_id) REFERENCES hostels(id),
    FOREIGN KEY (student_id) REFERENCES students(id)
);

CREATE TABLE IF NOT EXISTS sensor_readings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostel_id INTEGER NOT NULL,
    device_id TEXT,
    motion_detected INTEGER,     -- 1/0 from PIR
    temperature_c REAL,          -- from DHT22
    humidity_pct REAL,           -- from DHT22
    gas_raw INTEGER,             -- raw ADC value from MQ-2
    water_level_pct REAL,        -- from HC-SR04 tank level
    door_closed INTEGER,         -- 1/0 from reed switch
    timestamp TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (hostel_id) REFERENCES hostels(id)
);

CREATE INDEX IF NOT EXISTS idx_sensor_hostel_time ON sensor_readings(hostel_id, timestamp);
CREATE INDEX IF NOT EXISTS idx_attendance_student ON attendance(student_id);
CREATE INDEX IF NOT EXISTS idx_fee_student_month ON fee_payments(student_id, month);
CREATE INDEX IF NOT EXISTS idx_students_rfid ON students(rfid_tag);
