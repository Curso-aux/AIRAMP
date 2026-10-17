/*
 ============================================================================
  AIRA / AIRAMP - ESP32 Offline Learning Hub Firmware
  Hardware:
    - ESP32 DevKit V1 (30-pin or 38-pin)
    - 0.96" I2C OLED Display (SSD1306 128x64)
    - MicroSD Card Module (SPI) + SanDisk 16GB MicroSD
    - Active Buzzer (Success & connection alerts)
    - Push Button (OLED Screen ON / OFF toggle)
 ============================================================================
*/

#include <WiFi.h>
#include <WebServer.h>
#include <SPI.h>
#include <SD.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "aira_qrcode.h"
#include <ArduinoJson.h>

// ─── PIN DEFINITIONS ────────────────────────────────────────────────────────
// OLED Display (I2C)
#define I2C_SDA_PIN    21
#define I2C_SCL_PIN    22
#define SCREEN_WIDTH   128
#define SCREEN_HEIGHT  64
#define OLED_RESET     -1
#define SCREEN_ADDRESS 0x3C  // Common I2C address for 0.96" OLED

// MicroSD Card Module (VSPI)
#define SD_CS_PIN      5
#define SD_MOSI_PIN    23
#define SD_CLK_PIN     18
#define SD_MISO_PIN    19

// Peripherals
#define BUTTON_PIN     4   // Push button to toggle OLED ON/OFF (uses INPUT_PULLUP)
#define BUZZER_PIN     25  // Active buzzer (+) positive leg

// ─── WI-FI ACCESS POINT CREDENTIALS ─────────────────────────────────────────
const char* AP_SSID = "AIRAMP-HUB-01";
const char* AP_PASS = "aira1234";

// ─── GLOBAL OBJECTS ─────────────────────────────────────────────────────────
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
WebServer server(80);
QRCode qrcode;

// ─── STATE VARIABLES ────────────────────────────────────────────────────────
enum DisplayMode {
  MODE_QR,
  MODE_MANUAL
};

DisplayMode currentMode = MODE_QR;
bool oledOn = true;
bool sdReady = false;
unsigned long lastButtonPress = 0;
int lastConnectedClients = 0;

// QR Payload matching AIRAMP Flutter Mobile App:
const String QR_PAYLOAD = "WIFI:S:AIRAMP-HUB-01;T:WPA;P:aira1234;;AIRAMP:SEC=Grade 10;IP=192.168.4.1";

// ─── BUZZER BEEP HELPER ─────────────────────────────────────────────────────
void soundBeep(int durationMs = 120, int repeatCount = 1) {
  for (int i = 0; i < repeatCount; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(durationMs);
    digitalWrite(BUZZER_PIN, LOW);
    if (repeatCount > 1) delay(80);
  }
}

// ─── DRAW MANUAL CREDENTIALS SCREEN ─────────────────────────────────────────
void drawManualScreen() {
  if (!oledOn) return;

  display.clearDisplay();

  // Top Title Bar (Inverted White Background for high visibility)
  display.fillRect(0, 0, 128, 12, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK, SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(18, 2);
  display.print("MANUAL CONNECT");

  // Field 1: Wi-Fi SSID
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(2, 16);
  display.print("SSID: ");
  display.print(AP_SSID);

  // Field 2: Wi-Fi Password
  display.setCursor(2, 27);
  display.print("PASS: ");
  display.print(AP_PASS);

  // Field 3: IP Gateway
  display.setCursor(2, 38);
  display.print("IP  : 192.168.4.1");

  // Subtle separator line
  display.drawFastHLine(0, 49, 128, SSD1306_WHITE);

  // Bottom Status & Hint
  display.setCursor(2, 54);
  display.print("Users: ");
  display.print(WiFi.softAPgetStationNum());

  display.setCursor(72, 54);
  display.print("[BTN: QR]");

  display.display();
}

// ─── DRAW QR CODE & STATION STATS ON OLED ────────────────────────────────────
void drawHubScreen() {
  if (!oledOn) return;

  // If in Manual Mode, render the text credentials screen
  if (currentMode == MODE_MANUAL) {
    drawManualScreen();
    return;
  }

  display.clearDisplay();

  // Generate QR Code (Version 3, 29x29 matrix, ECC_LOW)
  uint8_t qrcodeData[qrcode_getBufferSize(3)];
  qrcode_initText(&qrcode, qrcodeData, 3, ECC_LOW, QR_PAYLOAD.c_str());

  // Render QR Code on the left side of OLED (x=4, y=4, scale 2 pixels per dot)
  const int scale = 2;
  const int xOffset = 4;
  const int yOffset = 4;

  // Background white box for high contrast
  display.fillRect(xOffset - 2, yOffset - 2, (qrcode.size * scale) + 4, (qrcode.size * scale) + 4, SSD1306_WHITE);

  for (uint8_t y = 0; y < qrcode.size; y++) {
    for (uint8_t x = 0; x < qrcode.size; x++) {
      if (qrcode_getModule(&qrcode, x, y)) {
        display.fillRect(xOffset + (x * scale), yOffset + (y * scale), scale, scale, SSD1306_BLACK);
      }
    }
  }

  // Draw Status info on the right side of the OLED
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(68, 6);
  display.println("AIRA HUB");

  display.drawLine(68, 16, 126, 16, SSD1306_WHITE);

  display.setCursor(68, 20);
  if (sdReady) {
    display.println("SD: READY");
  } else {
    display.println("SD: NO CARD");
  }

  display.setCursor(68, 32);
  display.print("Users: ");
  display.println(WiFi.softAPgetStationNum());

  display.setCursor(68, 44);
  display.println("IP: .4.1");

  display.setCursor(68, 54);
  display.println("[BTN:MAN]");

  display.display();
}

// ─── HTTP API HANDLERS ──────────────────────────────────────────────────────

// GET /api/ping -> Device handshake
void handlePing() {
  soundBeep(80); // Quick chirp to indicate mobile client reached the hub
  StaticJsonDocument<128> doc;
  doc["status"] = "online";
  doc["hub"] = "AIRAMP-HUB-01";
  doc["sd_ready"] = sdReady;
  doc["clients"] = WiFi.softAPgetStationNum();

  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

// GET /api/manifest -> Returns the curriculum manifest
void handleManifest() {
  if (sdReady && SD.exists("/manifest.json")) {
    File file = SD.open("/manifest.json", FILE_READ);
    if (file) {
      server.streamFile(file, "application/json");
      file.close();
      return;
    }
  }

  // Fallback default manifest if SD card is missing or unformatted
  StaticJsonDocument<768> doc;
  doc["hubId"] = "AIRAMP-HUB-DEVKIT-01";
  doc["hubName"] = "AIRA Offline Classroom Station";
  doc["sectionName"] = "Grade 10";
  doc["teacherName"] = "Faculty Instructor";

  JsonArray items = doc.createNestedArray("items");
  JsonObject item1 = items.createNestedObject();
  item1["id"] = "mat_01";
  item1["title"] = "Module 1: Cellular Biology & Mitosis";
  item1["subjectName"] = "General Science";
  item1["fileType"] = "pdf";
  item1["sizeBytes"] = 1450000;
  item1["fileName"] = "bio_module1.pdf";

  JsonObject item2 = items.createNestedObject();
  item2["id"] = "mat_02";
  item2["title"] = "Unit 2: Quadratic Functions & Parabolas";
  item2["subjectName"] = "Mathematics";
  item2["fileType"] = "pdf";
  item2["sizeBytes"] = 980000;
  item2["fileName"] = "math_unit2.pdf";

  JsonObject item3 = items.createNestedObject();
  item3["id"] = "mat_03";
  item3["title"] = "Quarter 1 Diagnostic Assessment (20 Items)";
  item3["subjectName"] = "General Science";
  item3["fileType"] = "quiz";
  item3["sizeBytes"] = 320000;
  item3["fileName"] = "science_quiz_q1.json";

  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

// GET /download?file=filename.pdf -> Streams file from MicroSD
void handleDownload() {
  if (!server.hasArg("file")) {
    server.send(400, "text/plain", "Missing 'file' parameter");
    return;
  }

  String filename = server.arg("file");
  if (!filename.startsWith("/")) {
    filename = "/modules/" + filename;
  }

  if (!sdReady || !SD.exists(filename)) {
    server.send(404, "text/plain", "File not found on SD card: " + filename);
    return;
  }

  File file = SD.open(filename, FILE_READ);
  if (!file) {
    server.send(500, "text/plain", "Failed to open file");
    return;
  }

  String contentType = "application/octet-stream";
  if (filename.endsWith(".pdf")) contentType = "application/pdf";
  else if (filename.endsWith(".json")) contentType = "application/json";
  else if (filename.endsWith(".txt")) contentType = "text/plain";

  server.streamFile(file, contentType);
  file.close();

  // Play a happy 2-tone beep upon successful download transfer!
  soundBeep(80, 2);
}

// ─── WIRELESS FILE UPLOAD OVER WI-FI ────────────────────────────────────────
File uploadFile;

void handleUploadPage() {
  String html = "<!DOCTYPE html><html><head><meta name='viewport' content='width=device-width, initial-scale=1'>";
  html += "<title>AIRA Hub - File Uploader</title>";
  html += "<style>body{font-family:sans-serif;background:#0F172A;color:#F8FAFC;padding:24px;text-align:center;}";
  html += ".card{background:#1E293B;padding:24px;border-radius:16px;max-width:440px;margin:0 auto;box-shadow:0 8px 24px rgba(0,0,0,0.3);}";
  html += "h1{color:#10B981;font-size:20px;margin-bottom:8px;}";
  html += "input[type=file]{margin:20px 0;display:block;width:100%;color:#94A3B8;}";
  html += "input[type=submit]{background:#10B981;color:#fff;border:none;padding:12px 24px;border-radius:10px;font-weight:bold;cursor:pointer;width:100%;font-size:15px;}";
  html += "</style></head><body><div class='card'>";
  html += "<h1>Upload Files to SD Card</h1>";
  html += "<p style='color:#94A3B8;font-size:13px;'>Upload <b>manifest.json</b> or <b>.pdf</b> modules wirelessly directly to the MicroSD card without an adapter!</p>";
  html += "<form method='POST' action='/upload' enctype='multipart/form-data'>";
  html += "<input type='file' name='data' required>";
  html += "<input type='submit' value='Upload to MicroSD Card'>";
  html += "</form>";
  html += "<p style='margin-top:20px;'><a href='/' style='color:#38BDF8;font-size:13px;text-decoration:none;'>&larr; Back to Hub Home</a></p>";
  html += "</div></body></html>";
  server.send(200, "text/html", html);
}

void handleFileUpload() {
  HTTPUpload& upload = server.upload();
  if (upload.status == UPLOAD_FILE_START) {
    String filename = upload.filename;
    if (!filename.startsWith("/")) {
      if (filename.endsWith(".pdf")) {
        if (!SD.exists("/modules")) SD.mkdir("/modules");
        filename = "/modules/" + filename;
      } else {
        filename = "/" + filename;
      }
    }
    Serial.printf("[Upload] Starting: %s\n", filename.c_str());
    uploadFile = SD.open(filename, FILE_WRITE);
  } else if (upload.status == UPLOAD_FILE_WRITE) {
    if (uploadFile) {
      uploadFile.write(upload.buf, upload.currentSize);
    }
  } else if (upload.status == UPLOAD_FILE_END) {
    if (uploadFile) {
      uploadFile.close();
      Serial.printf("[Upload] Complete! Size: %u bytes\n", upload.totalSize);
      soundBeep(80, 2);
    }
  }
}

// GET / -> Zero-install HTML fallback portal
void handleRoot() {
  String html = "<!DOCTYPE html><html><head><meta name='viewport' content='width=device-width, initial-scale=1'>";
  html += "<title>AIRA Offline Classroom Hub</title>";
  html += "<style>body{font-family:sans-serif;background:#0F172A;color:#F8FAFC;padding:24px;text-align:center;}";
  html += ".card{background:#1E293B;padding:20px;border-radius:16px;max-width:440px;margin:0 auto;box-shadow:0 8px 24px rgba(0,0,0,0.3);}";
  html += "h1{color:#10B981;font-size:22px;margin-bottom:4px;}";
  html += ".badge{background:#10B98126;color:#10B981;padding:4px 10px;border-radius:8px;font-size:12px;font-weight:bold;display:inline-block;}";
  html += ".btn{display:block;background:#10B981;color:#fff;text-decoration:none;padding:12px;margin-top:14px;border-radius:10px;font-weight:bold;}";
  html += ".btn-sec{display:block;background:#334155;color:#fff;text-decoration:none;padding:10px;margin-top:10px;border-radius:10px;font-size:13px;}";
  html += "</style></head><body><div class='card'>";
  html += "<h1>AIRA Offline Station</h1>";
  html += "<p class='badge'>NO DATA OR INTERNET REQUIRED</p>";
  html += "<p style='color:#94A3B8;font-size:14px;'>You are connected directly to the ESP32 Classroom Hub. Open the <b>AIRAMP App</b> to sync your modules and quizzes automatically!</p>";
  html += "<a href='/api/manifest' class='btn'>View Hub Manifest (JSON)</a>";
  html += "<a href='/upload' class='btn-sec'>Wireless File Uploader</a>";
  html += "</div></body></html>";
  server.send(200, "text/html", html);
}

// ─── SETUP ──────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n[AIRA] Initializing ESP32 Offline Learning Hub...");

  // Setup Button & Buzzer Pins
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  // Initialize OLED Display (I2C)
  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
  if (display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println("[OLED] Display initialized successfully.");
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(14, 26);
    display.println("Starting AIRA Hub...");
    display.display();
  } else {
    Serial.println("[OLED] SSD1306 allocation failed. Check wiring!");
  }

  // Initialize MicroSD Card (SPI)
  SPI.begin(SD_CLK_PIN, SD_MISO_PIN, SD_MOSI_PIN, SD_CS_PIN);
  if (SD.begin(SD_CS_PIN)) {
    sdReady = true;
    uint64_t cardSize = SD.cardSize() / (1024 * 1024);
    Serial.printf("[SD] MicroSD Card Mounted! Size: %llu MB\n", cardSize);
  } else {
    sdReady = false;
    Serial.println("[SD] MicroSD card not detected or mount failed. Using fallback internal memory.");
  }

  // Start Wi-Fi SoftAP (No router / internet needed)
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASS);
  IPAddress IP = WiFi.softAPIP();
  Serial.printf("[WiFi] SoftAP Started! SSID: %s | IP: %s\n", AP_SSID, IP.toString().c_str());

  // Register Web Server Routes
  server.on("/", handleRoot);
  server.on("/api/ping", handlePing);
  server.on("/api/manifest", handleManifest);
  server.on("/download", handleDownload);
  server.on("/upload", HTTP_GET, handleUploadPage);
  server.on("/upload", HTTP_POST, []() {
    server.send(200, "text/html", "<html><body style='background:#0F172A;color:#10B981;font-family:sans-serif;text-align:center;padding:40px;'><h2>File Uploaded Successfully!</h2><p><a href='/upload' style='color:#38BDF8;'>Upload Another File</a> | <a href='/' style='color:#38BDF8;'>Back to Home</a></p></body></html>");
  }, handleFileUpload);
  server.enableCORS(true); // Allow mobile app fetch without CORS errors
  server.begin();
  Serial.println("[HTTP] Web Server started on port 80.");

  // Draw initial QR code and info on OLED
  drawHubScreen();

  // Startup Sound (Joyful 3-beep chime)
  soundBeep(70, 3);
}

// ─── MAIN LOOP ──────────────────────────────────────────────────────────────
void loop() {
  server.handleClient();

  // Check Button to toggle OLED screen between QR Mode and Manual Mode (debounced 250ms)
  int btnState = digitalRead(BUTTON_PIN);
  if (btnState == LOW && (millis() - lastButtonPress > 250)) {
    lastButtonPress = millis();
    if (currentMode == MODE_QR) {
      currentMode = MODE_MANUAL;
      Serial.println("[BUTTON] Clicked! Switched to MANUAL MODE");
    } else {
      currentMode = MODE_QR;
      Serial.println("[BUTTON] Clicked! Switched to QR CODE MODE");
    }
    soundBeep(60); // Satisfying tactile click chime
    drawHubScreen();
  }

  // Update OLED when student client connects or disconnects
  int currentClients = WiFi.softAPgetStationNum();
  if (currentClients != lastConnectedClients) {
    lastConnectedClients = currentClients;
    drawHubScreen();
    if (currentClients > 0) {
      soundBeep(100); // Beep when a student connects
    }
  }
}
