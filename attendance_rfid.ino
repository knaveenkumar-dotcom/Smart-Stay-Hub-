/*
  Smart PG/Hostel Management Platform
  ESP32 + RC522 RFID Reader - Digital Attendance Node
  -----------------------------------------------------
  Wiring (ESP32 <-> RC522):
    RC522 SDA  -> GPIO 5
    RC522 SCK  -> GPIO 18
    RC522 MOSI -> GPIO 23
    RC522 MISO -> GPIO 19
    RC522 RST  -> GPIO 22
    RC522 GND  -> GND
    RC522 3.3V -> 3.3V   (RC522 is NOT 5V tolerant)

  Libraries needed (Arduino Library Manager):
    - MFRC522 by GithubCommunity
    - ArduinoJson by Benoit Blanchon
    - WiFi (built-in for ESP32)
    - HTTPClient (built-in for ESP32)

  Flow:
    1. Student taps RFID card on reader.
    2. ESP32 reads the card UID.
    3. Sends UID + device_id + hostel_id to backend via HTTPS POST.
    4. Backend decides IN/OUT automatically and returns result.
    5. Buzzer/LED gives feedback (green=success, red=error).
*/

#include <SPI.h>
#include <MFRC522.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ------------- CONFIG: EDIT THESE -------------
const char* WIFI_SSID     = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// Backend endpoint (use your server's IP/domain; https:// recommended in production)
const char* SERVER_URL    = "http://192.168.1.100:4000/api/attendance/scan";
const char* DEVICE_API_KEY = "change_this_to_a_secret_key"; // must match backend .env

const char* DEVICE_ID   = "ESP32-GATE-01";  // unique per device (e.g. main gate, floor 2 gate)
const int   HOSTEL_ID   = 1;                // this device's hostel ID from backend DB
// ------------------------------------------------

#define SS_PIN   5
#define RST_PIN  22
#define GREEN_LED 25
#define RED_LED   26
#define BUZZER    27

MFRC522 rfid(SS_PIN, RST_PIN);

void setup() {
  Serial.begin(115200);
  SPI.begin();
  rfid.PCD_Init();

  pinMode(GREEN_LED, OUTPUT);
  pinMode(RED_LED, OUTPUT);
  pinMode(BUZZER, OUTPUT);

  connectWiFi();
  Serial.println("Attendance node ready. Tap your RFID card...");
}

void loop() {
  // Reconnect WiFi if dropped
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
  }

  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) {
    return;
  }

  String uid = getUID();
  Serial.println("Card scanned: " + uid);

  sendAttendance(uid);

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
  delay(1500); // debounce so the same tap isn't registered twice
}

String getUID() {
  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

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

void sendAttendance(String uid) {
  if (WiFi.status() != WL_CONNECTED) {
    signalError();
    return;
  }

  HTTPClient http;
  http.begin(SERVER_URL);
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
    String response = http.getString();
    Serial.println("Response: " + response);
    signalSuccess();
  } else {
    Serial.printf("HTTP error: %d\n", httpCode);
    signalError();
  }

  http.end();
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
