/*
 ============================================================================
  AIRA / AIRAMP - ESP32 Offline Learning Hub Firmware
  Hardware:
    - ESP32 DevKit V1
    - 2.0" Color TFT Display (ST7789 SPI, 240x320)
    - MicroSD Card Module (SPI) + SanDisk 16GB MicroSD
    - Active Buzzer (Success & connection alerts)
    - Push Button (QR Code <-> Manual Screen toggle)
 ============================================================================
*/

#include <WiFi.h>
#include <WebServer.h>
#include <SPI.h>
#include <SD.h>
#include <Adafruit_GFX.h>
#include <Adafruit_ST7789.h>
#include "aira_qrcode.h"
#include <ArduinoJson.h>

// ESP32 Power, Flash & Wi-Fi Management
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
#include <nvs_flash.h>
#include <esp_wifi.h>

// ─── PIN DEFINITIONS ────────────────────────────────────────────────────────
// 2.0" ST7789 SPI Color TFT Display (240x320) - 100% Dedicated Pins
#define TFT_CS 21  // Screen Chip Select
#define TFT_DC 22  // Screen Data/Command
#define TFT_RST 2  // Screen Reset
#define TFT_SCL 14 // Screen SPI Clock (SCL)
#define TFT_SDA 27 // Screen SPI Data (SDA / MOSI)

// MicroSD Card Module (VSPI) - 100% Dedicated Pins
#define SD_CS_PIN 13   // User connected CS to D13
#define SD_CLK_PIN 18  // MicroSD SCK
#define SD_MOSI_PIN 23 // MicroSD MOSI
#define SD_MISO_PIN 19 // MicroSD MISO

// Peripherals
#define BUTTON_PIN                                                             \
  4 // Push button to toggle OLED/TFT screen mode (INPUT_PULLUP)
#define BUZZER_PIN 25 // Active buzzer (+) positive leg

// ─── 16-BIT 565 COLOR DEFINITIONS ──────────────────────────────────────────
#define COLOR_BG 0x0842    // Dark Slate Navy (#0F172A)
#define COLOR_CARD 0x18E5  // Slate Blue Card (#1E293B)
#define COLOR_CYAN 0x3DFE  // Bright Cyan (#38BDF8)
#define COLOR_GREEN 0x156A // Emerald Green (#10B981)
#define COLOR_AMBER 0xFD20 // Amber Orange (#F59E0B)
#define COLOR_RED 0xF800   // Red (#EF4444)
#define COLOR_WHITE 0xFFFF // White
#define COLOR_BLACK 0x0000 // Black
#define COLOR_MUTED 0x9CF3 // Light Slate Muted Text (#94A3B8)

// ─── WI-FI ACCESS POINT CREDENTIALS ─────────────────────────────────────────
const char *AP_SSID = "AIRAMP-HUB-01";
const char *AP_PASS = "aira1234";

// ─── GLOBAL OBJECTS ─────────────────────────────────────────────────────────
// Software SPI for ST7789 on dedicated pins (D21, D22, D27, D14, D2)
Adafruit_ST7789 tft =
    Adafruit_ST7789(TFT_CS, TFT_DC, TFT_SDA, TFT_SCL, TFT_RST);
WebServer server(80);
QRCode qrcode;

// ─── STATE VARIABLES ────────────────────────────────────────────────────────
enum DisplayMode { MODE_QR, MODE_MANUAL };

DisplayMode currentMode = MODE_QR;
bool sdReady = false;
unsigned long lastButtonPress = 0;
int lastConnectedClients = 0;

// Universal Wi-Fi QR Code standard (auto-connects natively on iOS, Android, and AIRAMP app):
const String QR_PAYLOAD = "WIFI:S:AIRAMP-HUB-01;T:WPA;P:aira1234;;";

// ─── BUZZER BEEP HELPER ─────────────────────────────────────────────────────
void soundBeep(int durationMs = 120, int repeatCount = 1) {
  for (int i = 0; i < repeatCount; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(durationMs);
    digitalWrite(BUZZER_PIN, LOW);
    if (repeatCount > 1)
      delay(80);
  }
}

// ─── DRAW MANUAL CREDENTIALS SCREEN (2.0" COLOR 320x240) ───────────────────
void drawManualScreen() {
  tft.fillScreen(COLOR_BG);

  // Top Header Banner
  tft.fillRect(0, 0, 320, 36, COLOR_CARD);
  tft.drawFastHLine(0, 36, 320, COLOR_CYAN);
  tft.setTextColor(COLOR_CYAN);
  tft.setTextSize(2);
  tft.setCursor(68, 10);
  tft.print("MANUAL CONNECT");

  // Field 1: Wi-Fi SSID
  tft.setTextColor(COLOR_MUTED);
  tft.setTextSize(1);
  tft.setCursor(20, 48);
  tft.print("ESP32 WI-FI SSID (NETWORK NAME):");

  tft.fillRoundRect(20, 60, 280, 34, 6, COLOR_CARD);
  tft.drawRoundRect(20, 60, 280, 34, 6, COLOR_CYAN);
  tft.setTextColor(COLOR_WHITE);
  tft.setTextSize(2);
  tft.setCursor(35, 70);
  tft.print(AP_SSID);

  // Field 2: Password
  tft.setTextColor(COLOR_MUTED);
  tft.setTextSize(1);
  tft.setCursor(20, 102);
  tft.print("WI-FI PASSWORD:");

  tft.fillRoundRect(20, 114, 280, 34, 6, COLOR_CARD);
  tft.drawRoundRect(20, 114, 280, 34, 6, 0x4A69);
  tft.setTextColor(COLOR_GREEN);
  tft.setTextSize(2);
  tft.setCursor(35, 124);
  tft.print(AP_PASS);

  // Field 3: IP Gateway
  tft.setTextColor(COLOR_MUTED);
  tft.setTextSize(1);
  tft.setCursor(20, 156);
  tft.print("ESP32 HUB IP GATEWAY:");

  tft.fillRoundRect(20, 168, 280, 34, 6, COLOR_CARD);
  tft.drawRoundRect(20, 168, 280, 34, 6, 0x4A69);
  tft.setTextColor(COLOR_CYAN);
  tft.setTextSize(2);
  tft.setCursor(35, 178);
  tft.print("192.168.4.1");

  // Bottom Status Bar
  tft.drawFastHLine(0, 212, 320, 0x2124);
  tft.setTextColor(COLOR_MUTED);
  tft.setTextSize(1);
  tft.setCursor(20, 222);
  tft.print("Users: ");
  tft.setTextColor(COLOR_WHITE);
  tft.print(WiFi.softAPgetStationNum());

  tft.setCursor(180, 222);
  tft.setTextColor(COLOR_AMBER);
  tft.print("[BTN: QR CODE]");
}

// ─── DRAW QR CODE SCREEN (2.0" COLOR 320x240) ───────────────────────────────
void drawQrScreen() {
  tft.fillScreen(COLOR_BG);

  // Generate Universal Wi-Fi QR Code (Version 4, 33x33 matrix, handles up to 80 bytes)
  uint8_t qrcodeData[qrcode_getBufferSize(4)];
  int8_t qrResult = qrcode_initText(&qrcode, qrcodeData, 4, ECC_LOW, QR_PAYLOAD.c_str());
  if (qrResult != 0) {
    Serial.printf("[QR] Error encoding QR: %d\n", qrResult);
  }

  // Render QR Code on the Left Side (scale 5: 33 * 5 = 165px)
  const int scale = 5;
  const int xOffset = 18;
  const int yOffset = 28;
  const int boxSize = (qrcode.size * scale) + 16;

  // Crisp White High-Contrast Background Box
  tft.fillRoundRect(xOffset - 8, yOffset - 8, boxSize, boxSize, 8, COLOR_WHITE);

  // Draw QR code modules
  for (uint8_t y = 0; y < qrcode.size; y++) {
    for (uint8_t x = 0; x < qrcode.size; x++) {
      if (qrcode_getModule(&qrcode, x, y)) {
        tft.fillRect(xOffset + (x * scale), yOffset + (y * scale), scale, scale, COLOR_BLACK);
      }
    }
  }

  // Right Side Info Panel (x = 210 to 310)
  tft.setTextColor(COLOR_CYAN);
  tft.setTextSize(2);
  tft.setCursor(215, 25);
  tft.print("AIRA");
  tft.setCursor(215, 45);
  tft.print("HUB");

  tft.drawFastHLine(215, 68, 95, COLOR_CYAN);

  // SD Status Badge
  tft.setCursor(215, 78);
  tft.setTextSize(1);
  if (sdReady) {
    tft.setTextColor(COLOR_GREEN);
    tft.print("SD: READY");
  } else {
    tft.setTextColor(COLOR_RED);
    tft.print("SD: NO CARD");
  }

  // Connected Users
  tft.setCursor(215, 98);
  tft.setTextColor(COLOR_MUTED);
  tft.print("Students:");
  tft.setCursor(215, 110);
  tft.setTextColor(COLOR_WHITE);
  tft.setTextSize(2);
  tft.print(WiFi.softAPgetStationNum());

  // Gateway IP
  tft.setTextSize(1);
  tft.setCursor(215, 138);
  tft.setTextColor(COLOR_MUTED);
  tft.print("Gateway:");
  tft.setCursor(215, 150);
  tft.setTextColor(COLOR_CYAN);
  tft.print("192.168.4.1");

  // Button switch hint box
  tft.fillRoundRect(212, 180, 100, 36, 6, COLOR_CARD);
  tft.drawRoundRect(212, 180, 100, 36, 6, COLOR_AMBER);
  tft.setTextColor(COLOR_AMBER);
  tft.setTextSize(1);
  tft.setCursor(220, 188);
  tft.print("PRESS BTN");
  tft.setCursor(220, 200);
  tft.print("FOR MANUAL");
}

// ─── MASTER DISPLAY DRAW ROUTINE ────────────────────────────────────────────
void drawHubScreen() {
  if (currentMode == MODE_MANUAL) {
    drawManualScreen();
  } else {
    drawQrScreen();
  }
}

// ─── HTTP API HANDLERS ──────────────────────────────────────────────────────

// GET /api/ping -> Device handshake
void handlePing() {
  soundBeep(80); // Quick chirp to indicate mobile client reached the hub
  StaticJsonDocument<128> doc;
  doc["status"] = "online";
  doc["hub_id"] = "AIRAMP-HUB-01";
  doc["version"] = "2.0.0";
  doc["sd_ready"] = sdReady;
  doc["clients"] = WiFi.softAPgetStationNum();

  String res;
  serializeJson(doc, res);
  server.send(200, "application/json", res);
}

// GET /api/manifest -> Returns offline learning materials JSON from MicroSD
void handleManifest() {
  if (!sdReady) {
    server.send(503, "application/json",
                "{\"error\":\"MicroSD card not available\"}");
    return;
  }

  File file = SD.open("/manifest.json", FILE_READ);
  if (!file) {
    // If manifest doesn't exist yet, return a clean default fallback
    String fallback = "{\"hub_id\":\"AIRAMP-HUB-01\",\"title\":\"AIRA Offline "
                      "Hub\",\"version\":\"1.0\",\"materials\":[]}";
    server.send(200, "application/json", fallback);
    return;
  }

  server.streamFile(file, "application/json");
  file.close();
}

// GET /download?file=... -> Streams PDF/module directly from MicroSD to phone
void handleFileDownload() {
  if (!sdReady) {
    server.send(503, "text/plain", "MicroSD card not ready");
    return;
  }

  if (!server.hasArg("file")) {
    server.send(400, "text/plain",
                "Missing file parameter. Usage: /download?file=/filename.pdf");
    return;
  }

  String filePath = server.arg("file");
  if (!filePath.startsWith("/")) {
    filePath = "/" + filePath;
  }

  if (!SD.exists(filePath)) {
    server.send(404, "text/plain", "File not found on MicroSD");
    return;
  }

  File file = SD.open(filePath, FILE_READ);
  if (!file) {
    server.send(500, "text/plain", "Failed to open file on MicroSD");
    return;
  }

  // Determine MIME type
  String contentType = "application/octet-stream";
  if (filePath.endsWith(".pdf"))
    contentType = "application/pdf";
  else if (filePath.endsWith(".json"))
    contentType = "application/json";
  else if (filePath.endsWith(".txt"))
    contentType = "text/plain";
  else if (filePath.endsWith(".html"))
    contentType = "text/html";

  // Stream file in chunks to phone
  server.streamFile(file, contentType);
  file.close();

  // Play audio confirmation chime upon successful download
  soundBeep(50, 2);
}

// File Upload Handler for Teacher (Over-The-Air without PC SD card reader!)
File uploadFile;
void handleFileUpload() {
  HTTPUpload &upload = server.upload();
  if (upload.status == UPLOAD_FILE_START) {
    String filename = upload.filename;
    if (!filename.startsWith("/"))
      filename = "/" + filename;
    Serial.printf("[SD UPLOAD] Starting: %s\n", filename.c_str());
    if (SD.exists(filename)) {
      SD.remove(filename);
    }
    uploadFile = SD.open(filename, FILE_WRITE);
  } else if (upload.status == UPLOAD_FILE_WRITE) {
    if (uploadFile) {
      uploadFile.write(upload.buf, upload.currentSize);
    }
  } else if (upload.status == UPLOAD_FILE_END) {
    if (uploadFile) {
      uploadFile.close();
      Serial.printf("[SD UPLOAD] Completed %u bytes\n", upload.totalSize);
      soundBeep(150, 1);
    }
  }
}

// Simple Web Portal homepage (fallback if opened in phone web browser)
void handleRoot() {
  String html = "<!DOCTYPE html><html><head><meta name='viewport' "
                "content='width=device-width, initial-scale=1.0'>";
  html += "<title>AIRA Offline Classroom Hub</title>";
  html += "<style>body{font-family:sans-serif;background:#0F172A;color:#F8FAFC;"
          "padding:24px;text-align:center;}";
  html += ".card{background:#1E293B;padding:20px;border-radius:16px;max-width:"
          "440px;margin:0 auto;box-shadow:0 8px 24px rgba(0,0,0,0.3);}";
  html += "h1{color:#10B981;font-size:22px;margin-bottom:4px;}";
  html += ".badge{background:#10B98126;color:#10B981;padding:4px "
          "10px;border-radius:8px;font-size:12px;font-weight:bold;display:"
          "inline-block;}";
  html +=
      ".btn{display:block;background:#10B981;color:#fff;text-decoration:none;"
      "padding:12px;margin-top:14px;border-radius:10px;font-weight:bold;}";
  html +=
      ".btn-sec{display:block;background:#334155;color:#fff;text-decoration:"
      "none;padding:10px;margin-top:10px;border-radius:10px;font-size:13px;}";
  html += "</style></head><body><div class='card'>";
  html += "<h1>AIRA Offline Station</h1>";
  html += "<p class='badge'>NO DATA OR INTERNET REQUIRED</p>";
  html += "<p style='color:#94A3B8;font-size:14px;'>You are connected directly "
          "to the ESP32 Classroom Hub. Open the <b>AIRAMP App</b> to sync your "
          "modules and quizzes automatically!</p>";
  html += "<a href='/api/manifest' class='btn'>View Hub Manifest (JSON)</a>";
  html += "<a href='/upload' class='btn-sec'>Wireless File Uploader</a>";
  html += "</div></body></html>";
  server.send(200, "text/html", html);
}

// ─── SETUP ──────────────────────────────────────────────────────────────────
void setup() {
  // 1. Lower CPU frequency to 160MHz (reduces peak digital power draw by 40%, preventing RF calibration voltage sag)
  setCpuFrequencyMhz(160);

  // 2. Disable software brownout detector
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);

  Serial.begin(115200);
  delay(400);
  Serial.println("\n========================================================");
  Serial.println("[AIRA] Initializing ESP32 Offline Learning Hub 2.0");
  Serial.println("========================================================");

  // 2. Repair corrupted NVS partition if damaged by previous brownout
  esp_err_t nvsRet = nvs_flash_init();
  if (nvsRet == ESP_ERR_NVS_NO_FREE_PAGES || nvsRet == ESP_ERR_NVS_NEW_VERSION_FOUND || nvsRet != ESP_OK) {
    Serial.println("[NVS] Repairing and re-formatting NVS flash partition...");
    nvs_flash_erase();
    nvs_flash_init();
    Serial.println("[NVS] NVS flash partition repaired cleanly.");
  }

  // Setup Button & Buzzer Pins
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  // Step 1: Start Wi-Fi Access Point (SoftAP)
  Serial.println("[AIRA] [1/5] Starting Wi-Fi SoftAP...");
  WiFi.mode(WIFI_AP);
  delay(100);
  WiFi.softAP(AP_SSID, AP_PASS);
  delay(300);

  IPAddress IP = WiFi.softAPIP();
  Serial.printf("[AP] Wi-Fi SSID: %s\n", AP_SSID);
  Serial.printf("[AP] Gateway IP: %s\n", IP.toString().c_str());

  delay(100);

  // Step 2: Initialize 2.0" ST7789 Color TFT Display
  Serial.println("[AIRA] [2/5] Initializing 2.0\" ST7789 Color Display...");
  tft.init(240, 320);
  tft.setRotation(1); // Landscape mode (320px wide, 240px high)
  tft.fillScreen(COLOR_BG);
  tft.setTextColor(COLOR_CYAN);
  tft.setTextSize(2);
  tft.setCursor(40, 100);
  tft.println("Starting AIRA Hub...");
  Serial.println("[TFT] Display initialized successfully.");

  delay(200); // Allow display power to stabilize

  // Step 3: Initialize MicroSD Card on Hardware VSPI (CS = D13)
  Serial.println("[AIRA] [3/5] Initializing MicroSD Card Module...");
  SPI.begin(SD_CLK_PIN, SD_MISO_PIN, SD_MOSI_PIN, SD_CS_PIN);
  if (SD.begin(SD_CS_PIN)) {
    sdReady = true;
    Serial.println("[SD] MicroSD Card mounted successfully!");
    uint64_t cardSize = SD.cardSize() / (1024 * 1024);
    Serial.printf("[SD] Card Size: %llu MB\n", cardSize);
  } else {
    sdReady = false;
    Serial.println("[SD] MicroSD Card Mount Failed! (Continuing in standalone mode)");
  }

  delay(200); // Allow SD card power to stabilize

  // Step 4: Configure Web Server Endpoints
  Serial.println("[AIRA] [4/5] Starting Web Server...");
  server.on("/", HTTP_GET, handleRoot);
  server.on("/api/ping", HTTP_GET, handlePing);
  server.on("/api/manifest", HTTP_GET, handleManifest);
  server.on("/download", HTTP_GET, handleFileDownload);
  server.on("/upload", HTTP_GET, []() {
    String page = "<!DOCTYPE html><html><body "
                  "style='font-family:sans-serif;background:#0F172A;color:#"
                  "F8FAFC;padding:30px;text-align:center;'>";
    page += "<h2>Wireless File Uploader (Teacher)</h2><form method='POST' "
            "action='/upload' enctype='multipart/form-data'>";
    page +=
        "<input type='file' name='data'/><br><br><input type='submit' "
        "value='Upload to MicroSD' style='padding:10px "
        "20px;background:#10B981;color:#fff;border:none;border-radius:8px;'/>";
    page += "</form></body></html>";
    server.send(200, "text/html", page);
  });
  server.on(
      "/upload", HTTP_POST,
      []() {
        server.send(
            200, "text/html",
            "<html><body "
            "style='background:#0F172A;color:#10B981;font-family:sans-serif;"
            "text-align:center;padding:40px;'><h2>File Uploaded "
            "Successfully!</h2><p><a href='/upload' "
            "style='color:#38BDF8;'>Upload Another File</a> | <a href='/' "
            "style='color:#38BDF8;'>Back to Home</a></p></body></html>");
      },
      handleFileUpload);
  server.enableCORS(true); // Allow mobile app fetch without CORS errors
  server.begin();
  Serial.println("[HTTP] Web Server started on port 80.");

  delay(100);

  // Step 5: Draw initial QR code and info on 2.0" Screen
  Serial.println("[AIRA] [5/5] Rendering Hub Screen...");
  drawHubScreen();
  Serial.println("[AIRA] All systems initialized! Hub is online and ready.\n");

  // Startup Sound (Joyful 3-beep chime)
  soundBeep(70, 3);
}

// ─── MAIN LOOP ──────────────────────────────────────────────────────────────
unsigned long lastClientCheck = 0;

void loop() {
  server.handleClient();

  // Check Button to toggle screen between QR Mode and Manual Mode (debounced 250ms)
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
    soundBeep(50); // Satisfying tactile click chime
    drawHubScreen();
  }

  // Check connected student count once per second (prevents hammering Wi-Fi driver mutex)
  if (millis() - lastClientCheck > 1000) {
    lastClientCheck = millis();
    int currentClients = WiFi.softAPgetStationNum();
    if (currentClients != lastConnectedClients) {
      lastConnectedClients = currentClients;
      drawHubScreen();
      if (currentClients > 0) {
        soundBeep(100); // Beep when a student connects
      }
    }
  }
}
