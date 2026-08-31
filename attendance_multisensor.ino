/*
  Smart PG/Hostel Management Platform
  ESP32 Multi-Sensor Node — Attendance + Safety + Utility Monitoring
  ---------------------------------------------------------------------
  SENSORS ON THIS BOARD (6 total):
    1. RC522 RFID reader   -> Digital attendance (tap in/out)
    2. PIR motion sensor   -> Corridor/room occupancy + night security
    3. DHT22               -> Room temperature + humidity
    4. MQ-2 gas/smoke      -> Fire/gas leak safety (kitchen/mess area)
    5. HC-SR04 ultrasonic  -> Overhead water tank level
    6. Reed/magnetic switch -> Door open/close detection (gate or room)

  ============================ WIRING TABLE ============================
  Component        | Pin on component | Pin on ESP32
  ------------------|-------------------|----------------
  RC522 RFID        | SDA               | GPIO 5
                     | SCK               | GPIO 18
                     | MOSI              | GPIO 23
                     | MISO              | GPIO 19
                     | RST               | GPIO 22
                     | 3.3V / GND        | 3.3V / GND   (NOT 5V — will damage it)
  ------------------|-------------------|----------------
  PIR (HC-SR501)     | OUT               | GPIO 13
                     | VCC / GND         | 5V / GND
  ------------------|-------------------|----------------
  DHT22              | DATA              | GPIO 4  (use a 10k pull-up resistor to 3.3V)
                     | VCC / GND         | 3.3V / GND
  ------------------|-------------------|----------------
  MQ-2 gas sensor     | AOUT              | GPIO 34 (ADC1 input-only pin)
                     | VCC / GND         | 5V / GND
  ------------------|-------------------|----------------
  HC-SR04 ultrasonic  | TRIG              | GPIO 26
                     | ECHO              | GPIO 27 (use a voltage divider: ECHO is 5V, ESP32 pins are 3.3V!)
                     | VCC / GND         | 5V / GND
  ------------------|-------------------|----------------
  Reed switch (door)  | one leg           | GPIO 32
                     | other leg         | GND   (uses internal pull-up, no resistor needed)
  ------------------|-------------------|----------------
  Status LEDs         | Green             | GPIO 25
                     | Red               | GPIO 33
  Buzzer               | +                 | GPIO 14
  ========================================================================

  Libraries needed (Arduino IDE Library Manager):
    - MFRC522 by GithubCommunity
    - DHT sensor library by Adafruit  (+ Adafruit Unified Sensor, its dependency)
    - ArduinoJson by Benoit Blanchon
    - WiFi, HTTPClient (built-in with ESP32 board package)

  DATA FLOW:
    - RFID tap  -> instantly POSTs to /api/attendance/scan (same as before)
    - Every 10s -> reads all other sensors, POSTs one combined reading to
                   /api/sensors/reading so the dashboard can show live values
                   and raise alerts (gas high / door open / tank low / motion).
*/

#include <SPI.h>
#include <MFRC522.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <DHT.h>

// ------------- CONFIG: EDIT THESE -------------
const char* WIFI_SSID     = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

const char* API_BASE       = "http://192.168.1.100:4000"; // your backend's LAN IP
const char* DEVICE_API_KEY = "change_this_to_a_secret_key"; // must match backend .env

const char* DEVICE_ID   = "ESP32-NODE-01";  // unique per device/room/floor
const int   HOSTEL_ID   = 1;                // this device's hostel ID from backend DB

const float TANK_HEIGHT_CM = 100.0; // full-tank height, for % calculation — measure your tank
// ------------------------------------------------

// ---- RFID pins ----
#define SS_PIN   5
#define RST_PIN  22

// ---- Sensor pins ----
#define PIR_PIN     13
#define DHT_PIN     4
#define DHT_TYPE    DHT22
#define GAS_PIN     34   // ADC1 channel, input-only
#define TRIG_PIN    26
#define ECHO_PIN    27
#define REED_PIN    32

// ---- Feedback pins ----
#define GREEN_LED 25
#define RED_LED   33
#define BUZZER    14

MFRC522 rfid(SS_PIN, RST_PIN);
DHT dht(DHT_PIN, DHT_TYPE);

unsigned long lastSensorPush = 0;
const unsigned long SENSOR_INTERVAL = 10000; // 10 seconds

void setup() {
  Serial.begin(115200);
  SPI.begin();
  rfid.PCD_Init();
  dht.begin();

  pinMode(GREEN_LED, OUTPUT);
  pinMode(RED_LED, OUTPUT);
  pinMode(BUZZER, OUTPUT);
  pinMode(PIR_PIN, INPUT);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(REED_PIN, INPUT_PULLUP); // reads LOW when door is closed (magnet touching)

  connectWiFi();
  Serial.println("Multi-sensor node ready.");
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  // ---- 1. RFID attendance (instant, event-driven) ----
  if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
    String uid = getUID();
    Serial.println("Card scanned: " + uid);
    sendAttendance(uid);
    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();
    delay(1500); // debounce
  }

  // ---- 2-6. Other sensors (every 10 seconds) ----
  if (millis() - lastSensorPush >= SENSOR_INTERVAL) {
    lastSensorPush = millis();
    pushSensorReadings();
  }
}

// ============ RFID ============
String getUID() {
  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

void sendAttendance(String uid) {
  if (WiFi.status() != WL_CONNECTED) { signalError(); return; }

  HTTPClient http;
  http.begin(String(API_BASE) + "/api/attendance/scan");
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-device-key", DEVICE_API_KEY);

  StaticJsonDocument<256> doc;
  doc["rfid_tag"] = uid;
  doc["device_id"] = DEVICE_ID;
  doc["hostel_id"] = HOSTEL_ID;
  String payload;
  serializeJson(doc, payload);

  int httpCode = http.POST(payload);
  if (httpCode == 200) {
    Serial.println("Attendance response: " + http.getString());
    signalSuccess();
  } else {
    Serial.printf("Attendance HTTP error: %d\n", httpCode);
    signalError();
  }
  http.end();
}

// ============ Other 5 sensors, combined push ============
void pushSensorReadings() {
  // -- PIR motion --
  bool motionDetected = digitalRead(PIR_PIN) == HIGH;

  // -- DHT22 temp/humidity --
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("DHT22 read failed, skipping this cycle's temp/humidity.");
    temperature = -1;
    humidity = -1;
  }

  // -- MQ-2 gas level (raw ADC 0-4095; calibrate threshold for your unit) --
  int gasRaw = analogRead(GAS_PIN);

  // -- HC-SR04 water tank level --
  float distanceCm = readUltrasonicCm();
  float waterLevelPercent = -1;
  if (distanceCm > 0) {
    float waterHeight = TANK_HEIGHT_CM - distanceCm; // distance is from sensor (top) to water surface
    waterLevelPercent = (waterHeight / TANK_HEIGHT_CM) * 100.0;
    waterLevelPercent = constrain(waterLevelPercent, 0, 100);
  }

  // -- Reed switch door status --
  bool doorClosed = digitalRead(REED_PIN) == LOW; // LOW = magnet present = closed

  // Local safety alert: buzz if gas is high (tune 1800 threshold to your MQ-2 after calibration)
  if (gasRaw > 1800) {
    signalError();
  }

  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  http.begin(String(API_BASE) + "/api/sensors/reading");
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-device-key", DEVICE_API_KEY);

  StaticJsonDocument<384> doc;
  doc["hostel_id"] = HOSTEL_ID;
  doc["device_id"] = DEVICE_ID;
  doc["motion_detected"] = motionDetected;
  doc["temperature_c"] = temperature;
  doc["humidity_pct"] = humidity;
  doc["gas_raw"] = gasRaw;
  doc["water_level_pct"] = waterLevelPercent;
  doc["door_closed"] = doorClosed;

  String payload;
  serializeJson(doc, payload);
  int httpCode = http.POST(payload);
  Serial.printf("Sensor push HTTP %d | motion=%d temp=%.1f hum=%.1f gas=%d water=%.0f%% door=%s\n",
    httpCode, motionDetected, temperature, humidity, gasRaw, waterLevelPercent, doorClosed ? "closed" : "open");
  http.end();
}

float readUltrasonicCm() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  long duration = pulseIn(ECHO_PIN, HIGH, 30000); // 30ms timeout
  if (duration == 0) return -1; // no echo received
  return duration * 0.0343 / 2.0; // speed of sound conversion
}

// ============ WiFi + feedback helpers ============
void connectWiFi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected. IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\nWiFi connection failed, will retry in loop.");
  }
}

void signalSuccess() {
  digitalWrite(GREEN_LED, HIGH);
  tone(BUZZER, 1000, 150);
  delay(400);
  digitalWrite(GREEN_LED, LOW);
}

void signalError() {
  digitalWrite(RED_LED, HIGH);
  tone(BUZZER, 300, 400);
  delay(600);
  digitalWrite(RED_LED, LOW);
}
