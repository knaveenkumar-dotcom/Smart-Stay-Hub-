# HostelOS — Flutter Mobile App

Student + Warden app for the Smart PG/Hostel Management Platform. Connects to
the same Node.js backend (`../backend/server.js`) as the web dashboard.

## What's inside

- **Setup screen** — one-time: enter backend server address, hostel ID, and
  your role. Students log in with their registered phone number (simple
  lookup, no password — see "Before real deployment" below).
- **Student app** (bottom nav): Home (status + pending fees), Attendance
  history, Fees status, Maintenance (raise + track own requests).
- **Warden app** (drawer nav, 7 sections): Overview dashboard, Attendance
  log, Visitor check-in/out, Maintenance tickets, Fee reminders, Room
  allocation, live Sensor readings (from the 6-sensor ESP32 kit).

## Prerequisites

You need the Flutter SDK installed on your own machine (not available in
this sandbox) — https://docs.flutter.dev/get-started/install

Check it's ready:
```bash
flutter doctor
```

## Run it

```bash
cd mobile_app
flutter pub get
flutter run
```

Pick a device when prompted (Android emulator, iOS simulator, or a connected
phone). On the **Android emulator**, use `10.0.2.2` instead of `localhost` in
the server address field — the setup screen already defaults to this. On a
**real phone**, use your laptop's actual LAN IP (e.g. `192.168.1.100`) and
make sure the phone and laptop are on the same WiFi, same as the ESP32.

## First-time flow

1. Start the backend first (`cd ../backend && node server.js`).
2. Launch the app → Setup screen → enter server address + Hostel ID 1
   (or whichever you created) → pick **Warden** → Continue.
3. As warden: go to Rooms → add a room. Then add students via the backend
   API directly for now (no student-creation screen in the app yet):
   ```bash
   curl -X POST http://localhost:4000/api/students \
     -H "Content-Type: application/json" \
     -d '{"hostel_id":1,"name":"Arun","phone":"9876543210","rfid_tag":"A1B2C3D4","monthly_fee":6000,"fee_due_day":5}'
   ```
4. To test the **student** side: logout (top-right icon) → pick **Student**
   → enter the phone number you just registered (`9876543210`) → Continue.

## Project structure

```
mobile_app/
├── lib/
│   ├── main.dart                  ← entry point, routes to Setup/Student/Warden
│   ├── config.dart                ← saved settings (server, hostel ID, role, login)
│   ├── services/api_service.dart  ← all backend API calls in one place
│   ├── widgets/common.dart        ← shared UI pieces (stat tiles, badges, cards)
│   └── screens/
│       ├── setup_screen.dart
│       ├── student/               ← 4 tabs
│       └── warden/                ← 7 sections
└── pubspec.yaml
```

## Before real deployment

- **Auth**: student login is just a phone-number lookup — no password, no
  token. Fine for a college demo; add proper login (Firebase Auth, JWT, or
  OTP) before this handles real people's data.
- **Warden login**: currently anyone who picks "Warden" gets full admin
  access — add a real login for this role too.
- **HTTPS**: `http://` is used throughout for simplicity; switch to `https://`
  once your backend is deployed somewhere with a proper certificate.
- **Push notifications**: fee reminders and maintenance updates currently
  require opening the app to see. Firebase Cloud Messaging would let you
  push these instead.
