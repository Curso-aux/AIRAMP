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
#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"

// ─── PIN DEFINITIONS ────────────────────────────────────────────────────────
// OLED Display (I2C)
#define I2C_SDA_PIN    21
#define I2C_SCL_PIN    22
#define SCREEN_WIDTH   128
#define SCREEN_HEIGHT  64
#define OLED_RESET     -1
#define SCREEN_ADDRESS 0x3C  // Common I2C address for 0.96" OLED

// MicroSD Card Module (VSPI)
#define SD_CS_PIN      13
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
SPIClass spiSD(VSPI);

// ─── STATE VARIABLES ────────────────────────────────────────────────────────
enum DisplayMode {
  MODE_QR,
  MODE_MANUAL
};

DisplayMode currentMode = MODE_QR;
bool oledOn = true;
bool oledPresent = false;
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
  if (!oledOn || !oledPresent) return;

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
  if (!oledOn || !oledPresent) return;

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

bool initSDCard();

// GET /api/ping -> Device handshake
void handlePing() {
  soundBeep(80); // Quick chirp to indicate mobile client reached the hub
  if (!sdReady) {
    initSDCard();
  }
  StaticJsonDocument<384> doc;
  doc["status"] = "online";
  doc["hub"] = "AIRAMP-HUB-01";
  doc["ssid"] = AP_SSID;
  doc["password"] = AP_PASS;
  doc["ip"] = "192.168.4.1";
  doc["sd_ready"] = sdReady;
  doc["clients"] = WiFi.softAPgetStationNum();
  if (sdReady) {
    doc["card_size_mb"] = (uint32_t)(SD.cardSize() / (1024 * 1024));
    doc["total_bytes"] = (uint32_t)SD.totalBytes();
    doc["used_bytes"] = (uint32_t)SD.usedBytes();
  }

  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

// POST /api/manifest -> Updates the curriculum manifest on the MicroSD card
void handleSaveManifest() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Missing JSON body\"}");
    return;
  }

  String body = server.arg("plain");
  if (!sdReady) {
    server.send(503, "application/json", "{\"status\":\"error\",\"message\":\"MicroSD module not mounted\"}");
    return;
  }

  if (SD.exists("/manifest.json")) {
    SD.remove("/manifest.json");
  }

  File file = SD.open("/manifest.json", FILE_WRITE);
  if (!file) {
    server.send(500, "application/json", "{\"status\":\"error\",\"message\":\"Failed to open /manifest.json for write\"}");
    return;
  }

  file.print(body);
  file.close();

  soundBeep(80, 2);
  Serial.println("[Manifest] Successfully updated /manifest.json on MicroSD card!");
  server.send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Manifest updated successfully\"}");
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
  doc["qrPayload"] = QR_PAYLOAD;

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

// GET /download?file=filename.pdf -> Streams file from MicroSD (supports transparent GZIP decompression)
void handleDownload() {
  if (!server.hasArg("file")) {
    server.send(400, "text/plain", "Missing 'file' parameter");
    return;
  }

  String rawName = server.arg("file");
  if (!rawName.startsWith("/")) {
    rawName = "/" + rawName;
  }

  String targetPath = "";
  bool isCompressed = false;

  if (sdReady) {
    if (SD.exists("/modules" + rawName)) {
      targetPath = "/modules" + rawName;
    } else if (SD.exists("/modules" + rawName + ".gz")) {
      targetPath = "/modules" + rawName + ".gz";
      isCompressed = true;
    } else if (SD.exists(rawName)) {
      targetPath = rawName;
    } else if (SD.exists(rawName + ".gz")) {
      targetPath = rawName + ".gz";
      isCompressed = true;
    } else if (rawName.startsWith("/modules/")) {
      String sub = rawName.substring(8);
      if (SD.exists(sub)) {
        targetPath = sub;
      } else if (SD.exists(sub + ".gz")) {
        targetPath = sub + ".gz";
        isCompressed = true;
      }
    }
  }

  if (targetPath == "" || !SD.exists(targetPath)) {
    server.send(404, "text/plain", "File not found on SD card: " + rawName);
    return;
  }

  File file = SD.open(targetPath, FILE_READ);
  if (!file) {
    server.send(500, "text/plain", "Failed to open file");
    return;
  }

  String contentType = "application/octet-stream";
  if (isCompressed) {
    server.sendHeader("Content-Encoding", "gzip");
    String baseName = targetPath.substring(0, targetPath.length() - 3);
    if (baseName.endsWith(".pdf")) contentType = "application/pdf";
    else if (baseName.endsWith(".json")) contentType = "application/json";
    else if (baseName.endsWith(".txt")) contentType = "text/plain";
    else if (baseName.endsWith(".html") || baseName.endsWith(".htm")) contentType = "text/html";
  } else {
    if (targetPath.endsWith(".pdf")) contentType = "application/pdf";
    else if (targetPath.endsWith(".json")) contentType = "application/json";
    else if (targetPath.endsWith(".txt")) contentType = "text/plain";
    else if (targetPath.endsWith(".html") || targetPath.endsWith(".htm")) contentType = "text/html";
    else if (targetPath.endsWith(".zip")) contentType = "application/zip";
    else if (targetPath.endsWith(".gz")) {
      contentType = "application/gzip";
      server.sendHeader("Content-Encoding", "gzip");
    }
  }

  server.streamFile(file, contentType);
  file.close();

  // Play a happy 2-tone beep upon successful download transfer!
  soundBeep(80, 2);
}

// POST or GET /api/delete?file=filename.pdf -> Deletes file from MicroSD
void handleDeleteFile() {
  if (!server.hasArg("file")) {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Missing 'file' parameter\"}");
    return;
  }

  String filename = server.arg("file");
  bool removed = false;

  if (sdReady) {
    String modPath = filename.startsWith("/") ? filename : ("/modules/" + filename);
    if (SD.exists(modPath)) {
      removed = SD.remove(modPath);
    } else if (SD.exists(modPath + ".gz")) {
      removed = SD.remove(modPath + ".gz");
    } else {
      String rootPath = filename.startsWith("/") ? filename : ("/" + filename);
      if (SD.exists(rootPath)) {
        removed = SD.remove(rootPath);
      } else if (SD.exists(rootPath + ".gz")) {
        removed = SD.remove(rootPath + ".gz");
      }
    }
  }

  soundBeep(60);
  server.send(200, "application/json", "{\"status\":\"ok\",\"message\":\"File deleted\",\"removed\":" + String(removed ? "true" : "false") + "}");
}

// ─── WIRELESS FILE UPLOAD OVER WI-FI ────────────────────────────────────────
File uploadFile;
String lastUploadedFilename = "";
size_t lastUploadedSize = 0;

// Helper to auto-register an uploaded material in /manifest.json
void appendItemToManifest(const String& id, const String& title, const String& subject, const String& fileType, uint32_t sizeBytes, const String& fileName, bool isCompressed) {
  if (!sdReady) return;

  DynamicJsonDocument doc(4096);
  if (SD.exists("/manifest.json")) {
    File f = SD.open("/manifest.json", FILE_READ);
    if (f) {
      deserializeJson(doc, f);
      f.close();
    }
  }

  if (!doc.containsKey("hubId")) {
    doc["hubId"] = "AIRAMP-HUB-01";
    doc["hubName"] = "AIRA Offline Classroom Station";
    doc["sectionName"] = "Grade 10";
    doc["teacherName"] = "Faculty Instructor";
    doc["qrPayload"] = QR_PAYLOAD;
  }

  JsonArray items;
  if (!doc.containsKey("items")) {
    items = doc.createNestedArray("items");
  } else {
    items = doc["items"].as<JsonArray>();
  }

  bool updated = false;
  for (JsonObject item : items) {
    String existingFile = item["fileName"] | "";
    String existingId = item["id"] | "";
    if (existingFile == fileName || existingId == id) {
      item["title"] = title;
      item["subjectName"] = subject;
      item["fileType"] = fileType;
      item["sizeBytes"] = sizeBytes;
      item["fileName"] = fileName;
      item["isCompressed"] = isCompressed;
      updated = true;
      break;
    }
  }

  if (!updated) {
    JsonObject newItem = items.createNestedObject();
    newItem["id"] = id;
    newItem["title"] = title;
    newItem["subjectName"] = subject;
    newItem["fileType"] = fileType;
    newItem["sizeBytes"] = sizeBytes;
    newItem["fileName"] = fileName;
    newItem["isCompressed"] = isCompressed;
  }

  SD.remove("/manifest.json");
  File outFile = SD.open("/manifest.json", FILE_WRITE);
  if (outFile) {
    serializeJson(doc, outFile);
    outFile.close();
    Serial.printf("[Manifest] Updated with %s (Compressed: %s)\n", fileName.c_str(), isCompressed ? "yes" : "no");
  }
}

// POST /api/manifest/append -> Appends or updates a material item in /manifest.json
void handleAppendManifest() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Missing JSON body\"}");
    return;
  }

  StaticJsonDocument<512> doc;
  DeserializationError err = deserializeJson(doc, server.arg("plain"));
  if (err) {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Invalid JSON\"}");
    return;
  }

  String id = doc["id"] | ("mat_" + String(millis()));
  String title = doc["title"] | "Classroom Material";
  String subject = doc["subjectName"] | "General";
  String fileType = doc["fileType"] | "pdf";
  uint32_t sizeBytes = doc["sizeBytes"] | 0;
  String fileName = doc["fileName"] | "";
  bool isCompressed = doc["isCompressed"] | false;

  appendItemToManifest(id, title, subject, fileType, sizeBytes, fileName, isCompressed);
  soundBeep(80, 2);
  server.send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Material registered in manifest\"}");
}

// GET /upload -> Interactive Material Uploader with Client-Side GZIP Compression
const char UPLOAD_HTML[] PROGMEM = R"rawliteral(<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>AIRA Hub - Material Uploader</title>
<style>
*{box-sizing:border-box;margin:0;padding:0;}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:#0F172A;color:#F8FAFC;padding:20px;display:flex;justify-content:center;min-height:100vh;align-items:center;}
.card{background:#1E293B;border:1px solid #334155;border-radius:18px;width:100%;max-width:480px;padding:26px;box-shadow:0 12px 32px rgba(0,0,0,0.4);}
.badge{display:inline-block;background:rgba(16,185,129,0.15);color:#10B981;font-weight:700;font-size:11px;padding:4px 10px;border-radius:20px;margin-bottom:10px;border:1px solid rgba(16,185,129,0.3);}
h1{font-size:20px;font-weight:700;color:#F8FAFC;margin-bottom:4px;}
p.sub{font-size:13px;color:#94A3B8;line-height:1.4;margin-bottom:16px;}
.dropzone{border:2px dashed #475569;border-radius:14px;padding:22px 16px;text-align:center;cursor:pointer;transition:all 0.2s;background:#0F172A;margin-bottom:16px;}
.dropzone:hover,.dropzone.dragover{border-color:#10B981;background:rgba(16,185,129,0.06);}
.dropzone svg{width:36px;height:36px;fill:#10B981;margin-bottom:6px;}
.dropzone p{font-size:13px;color:#CBD5E1;font-weight:600;}
.dropzone span{font-size:11px;color:#64748B;}
input[type=file]{display:none;}
.compress-box{background:rgba(16,185,129,0.08);border:1px solid rgba(16,185,129,0.3);border-radius:12px;padding:12px 14px;margin-bottom:16px;}
.compress-row{display:flex;align-items:center;justify-content:space-between;cursor:pointer;}
.compress-label{display:flex;align-items:center;gap:8px;font-size:13px;font-weight:600;color:#10B981;}
.switch{position:relative;width:42px;height:24px;}
.switch input{opacity:0;width:0;height:0;}
.slider{position:absolute;cursor:pointer;top:0;left:0;right:0;bottom:0;background:#475569;border-radius:24px;transition:0.2s;}
.slider:before{position:absolute;content:"";height:18px;width:18px;left:3px;bottom:3px;background:white;border-radius:50%;transition:0.2s;}
input:checked+.slider{background:#10B981;}
input:checked+.slider:before{transform:translateX(18px);}
.compress-desc{font-size:11.5px;color:#94A3B8;margin-top:6px;line-height:1.35;}
.preview-box{display:none;background:#0F172A;border:1px solid #334155;border-radius:10px;padding:12px;margin-bottom:16px;}
.preview-row{display:flex;justify-content:space-between;font-size:12px;margin-bottom:4px;color:#CBD5E1;}
.savings-badge{display:inline-block;background:#10B981;color:#0F172A;font-weight:bold;font-size:11px;padding:3px 8px;border-radius:8px;margin-top:4px;}
.field{margin-bottom:12px;text-align:left;}
.field label{display:block;font-size:11px;font-weight:600;color:#94A3B8;margin-bottom:4px;text-transform:uppercase;letter-spacing:0.5px;}
.field input,.field select{width:100%;background:#0F172A;border:1px solid #334155;border-radius:8px;color:#F8FAFC;padding:10px 12px;font-size:13px;outline:none;}
.field input:focus,.field select:focus{border-color:#10B981;}
.manifest-check{display:flex;align-items:center;gap:8px;font-size:12px;color:#CBD5E1;margin:12px 0 16px;}
.manifest-check input{cursor:pointer;accent-color:#10B981;}
.btn{background:#10B981;color:#0F172A;border:none;width:100%;padding:13px;border-radius:10px;font-weight:700;font-size:14px;cursor:pointer;transition:background 0.2s;}
.btn:hover{background:#059669;color:#fff;}
.btn:disabled{background:#334155;color:#64748B;cursor:not-allowed;}
.progress-box{display:none;margin-top:16px;}
.progress-bar-bg{width:100%;height:8px;background:#334155;border-radius:4px;overflow:hidden;margin:8px 0;}
.progress-bar-fill{height:100%;width:0%;background:#10B981;transition:width 0.15s;}
.progress-text{display:flex;justify-content:space-between;font-size:11px;color:#94A3B8;}
.success-box{display:none;text-align:center;padding:20px 0;}
.success-icon{width:50px;height:50px;border-radius:50%;background:rgba(16,185,129,0.2);color:#10B981;display:inline-flex;align-items:center;justify-content:center;font-size:26px;margin-bottom:12px;}
.success-box h2{font-size:18px;color:#10B981;margin-bottom:6px;}
.success-box p{font-size:12.5px;color:#94A3B8;margin-bottom:16px;}
.footer-links{margin-top:16px;text-align:center;}
.footer-links a{color:#38BDF8;font-size:12px;text-decoration:none;}
</style>
</head>
<body>
<div class="card">
  <div class="header">
    <div class="badge">100% OFFLINE ESP32 HUB</div>
    <h1>Upload Material to SD Card</h1>
    <p class="sub">Transmit PDFs, quizzes, or modules wirelessly over Wi-Fi with optional instant compression.</p>
  </div>

  <div id="uploadFormContainer">
    <div class="dropzone" id="dropzone" onclick="document.getElementById('fileInput').click()">
      <svg viewBox="0 0 24 24"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM14 13v4h-4v-4H7l5-5 5 5h-3z"/></svg>
      <p id="dropzoneText">Choose file or drag & drop</p>
      <span>Supports .pdf, .json, .txt, .docx, .zip, .gz</span>
    </div>
    <input type="file" id="fileInput">

    <div class="compress-box">
      <div class="compress-row" onclick="document.getElementById('compressToggle').click()">
        <span class="compress-label">
          <span>⚡</span> Compress material before sending
        </span>
        <label class="switch" onclick="event.stopPropagation()">
          <input type="checkbox" id="compressToggle" checked onchange="updateCompressionPreview()">
          <span class="slider"></span>
        </label>
      </div>
      <p class="compress-desc">Compresses file in your browser using GZIP. Dramatically speeds up Wi-Fi upload and saves up to 70% MicroSD space!</p>
    </div>

    <div class="preview-box" id="previewBox">
      <div class="preview-row"><span>Original Size:</span><b id="origSizeText">-</b></div>
      <div class="preview-row"><span>Transfer Size:</span><b id="compSizeText" style="color:#10B981;">-</b></div>
      <div id="savingsBadgeContainer"></div>
    </div>

    <div class="field">
      <label for="titleInput">Material Title</label>
      <input type="text" id="titleInput" placeholder="e.g. Module 1: Cellular Biology">
    </div>

    <div class="field">
      <label for="subjectInput">Subject</label>
      <input type="text" id="subjectInput" placeholder="e.g. Science, Mathematics, English">
    </div>

    <div class="manifest-check">
      <input type="checkbox" id="autoManifestCheck" checked>
      <label for="autoManifestCheck">Auto-add to classroom manifest (manifest.json)</label>
    </div>

    <button class="btn" id="uploadBtn" onclick="startUpload()" disabled>Upload to MicroSD Card</button>

    <div class="progress-box" id="progressBox">
      <div class="progress-text">
        <span id="progressStatus">Uploading to ESP32...</span>
        <span id="progressPercent">0%</span>
      </div>
      <div class="progress-bar-bg">
        <div class="progress-bar-fill" id="progressBar"></div>
      </div>
      <div class="progress-text">
        <span id="progressBytes">-</span>
      </div>
    </div>
  </div>

  <div class="success-box" id="successBox">
    <div class="success-icon">&#10003;</div>
    <h2>Upload Complete!</h2>
    <p id="successSummary">Material has been successfully saved to the MicroSD card.</p>
    <button class="btn" onclick="resetForm()">Upload Another File</button>
  </div>

  <div class="footer-links">
    <a href="/">&larr; Back to Hub Home</a> | <a href="/api/manifest" target="_blank">View Manifest (JSON)</a>
  </div>
</div>

<script>
let selectedFile = null;
let compressedBlob = null;
let isCompressedReady = false;

const dropzone = document.getElementById('dropzone');
const fileInput = document.getElementById('fileInput');
const dropzoneText = document.getElementById('dropzoneText');
const compressToggle = document.getElementById('compressToggle');
const previewBox = document.getElementById('previewBox');
const origSizeText = document.getElementById('origSizeText');
const compSizeText = document.getElementById('compSizeText');
const savingsBadgeContainer = document.getElementById('savingsBadgeContainer');
const titleInput = document.getElementById('titleInput');
const subjectInput = document.getElementById('subjectInput');
const uploadBtn = document.getElementById('uploadBtn');

dropzone.addEventListener('dragover', (e) => { e.preventDefault(); dropzone.classList.add('dragover'); });
dropzone.addEventListener('dragleave', () => dropzone.classList.remove('dragover'));
dropzone.addEventListener('drop', (e) => {
  e.preventDefault();
  dropzone.classList.remove('dragover');
  if (e.dataTransfer.files.length > 0) handleFileSelect(e.dataTransfer.files[0]);
});

fileInput.addEventListener('change', (e) => {
  if (e.target.files.length > 0) handleFileSelect(e.target.files[0]);
});

function formatBytes(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
}

async function handleFileSelect(file) {
  selectedFile = file;
  dropzoneText.textContent = file.name;
  uploadBtn.disabled = false;

  if (!titleInput.value) {
    titleInput.value = file.name.replace(/\.[^/.]+$/, '').replace(/[_-]/g, ' ');
  }
  if (!subjectInput.value) {
    subjectInput.value = 'General';
  }

  await updateCompressionPreview();
}

async function updateCompressionPreview() {
  if (!selectedFile) return;

  const shouldCompress = compressToggle.checked && !selectedFile.name.endsWith('.gz') && !selectedFile.name.endsWith('.zip');
  previewBox.style.display = 'block';
  origSizeText.textContent = formatBytes(selectedFile.size);

  if (shouldCompress && window.CompressionStream) {
    compSizeText.textContent = 'Compressing preview...';
    try {
      const stream = selectedFile.stream().pipeThrough(new CompressionStream('gzip'));
      compressedBlob = await new Response(stream).blob();
      isCompressedReady = true;

      const compSize = compressedBlob.size;
      compSizeText.textContent = formatBytes(compSize) + ' (.gz)';

      const savedPercent = Math.max(0, Math.round((1 - (compSize / selectedFile.size)) * 100));
      savingsBadgeContainer.innerHTML = '<span class="savings-badge">Saved ' + savedPercent + '% bandwidth & storage!</span>';
    } catch (e) {
      compSizeText.textContent = formatBytes(selectedFile.size) + ' (Standard)';
      savingsBadgeContainer.innerHTML = '';
      compressedBlob = null;
      isCompressedReady = false;
    }
  } else {
    compSizeText.textContent = formatBytes(selectedFile.size) + ' (Uncompressed)';
    savingsBadgeContainer.innerHTML = '';
    compressedBlob = null;
    isCompressedReady = false;
  }
}

function startUpload() {
  if (!selectedFile) return;

  uploadBtn.disabled = true;
  document.getElementById('progressBox').style.display = 'block';
  const progressBar = document.getElementById('progressBar');
  const progressPercent = document.getElementById('progressPercent');
  const progressBytes = document.getElementById('progressBytes');
  const progressStatus = document.getElementById('progressStatus');

  const willCompress = compressToggle.checked && compressedBlob && isCompressedReady;
  const uploadPayload = willCompress ? compressedBlob : selectedFile;
  const fileName = willCompress && !selectedFile.name.endsWith('.gz') ? (selectedFile.name + '.gz') : selectedFile.name;

  progressStatus.textContent = 'Uploading to ESP32...';

  const formData = new FormData();
  formData.append('data', uploadPayload, fileName);

  const xhr = new XMLHttpRequest();
  xhr.open('POST', '/upload', true);
  xhr.setRequestHeader('Accept', 'application/json');

  xhr.upload.onprogress = (e) => {
    if (e.lengthComputable) {
      const pct = Math.round((e.loaded / e.total) * 100);
      progressBar.style.width = pct + '%';
      progressPercent.textContent = pct + '%';
      progressBytes.textContent = formatBytes(e.loaded) + ' / ' + formatBytes(e.total);
    }
  };

  xhr.onload = async () => {
    if (xhr.status === 200) {
      progressBar.style.width = '100%';
      progressPercent.textContent = '100%';
      progressStatus.textContent = 'Saved to MicroSD!';

      // Auto-register in manifest if checked
      if (document.getElementById('autoManifestCheck').checked && fileName !== 'manifest.json') {
        try {
          const isPdf = fileName.toLowerCase().includes('.pdf');
          const isQuiz = fileName.toLowerCase().includes('.json');
          const payload = {
            id: 'mat_' + Date.now(),
            title: titleInput.value || selectedFile.name,
            subjectName: subjectInput.value || 'General',
            fileType: isPdf ? 'pdf' : (isQuiz ? 'quiz' : 'module'),
            sizeBytes: uploadPayload.size,
            fileName: fileName,
            isCompressed: willCompress
          };
          await fetch('/api/manifest/append', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(payload)
          });
        } catch (_) {}
      }

      document.getElementById('uploadFormContainer').style.display = 'none';
      document.getElementById('successBox').style.display = 'block';
      document.getElementById('successSummary').textContent =
        'Stored as "' + fileName + '" (' + formatBytes(uploadPayload.size) + (willCompress ? ', compressed' : '') + ').';
    } else {
      progressStatus.textContent = 'Upload failed (Error ' + xhr.status + ')';
      uploadBtn.disabled = false;
    }
  };

  xhr.onerror = () => {
    progressStatus.textContent = 'Connection error. Check Wi-Fi!';
    uploadBtn.disabled = false;
  };

  xhr.send(formData);
}

function resetForm() {
  selectedFile = null;
  compressedBlob = null;
  isCompressedReady = false;
  fileInput.value = '';
  titleInput.value = '';
  dropzoneText.textContent = 'Choose file or drag & drop';
  previewBox.style.display = 'none';
  uploadBtn.disabled = true;
  document.getElementById('progressBox').style.display = 'none';
  document.getElementById('progressBar').style.width = '0%';
  document.getElementById('uploadFormContainer').style.display = 'block';
  document.getElementById('successBox').style.display = 'none';
}
</script>
</body>
</html>
)rawliteral";

void handleUploadPage() {
  server.send_P(200, "text/html", UPLOAD_HTML);
}

void handleFileUpload() {
  HTTPUpload& upload = server.upload();
  if (upload.status == UPLOAD_FILE_START) {
    String filename = upload.filename;
    if (!filename.startsWith("/")) {
      if (filename.endsWith(".pdf") || filename.endsWith(".json") || filename.endsWith(".txt") || 
          filename.endsWith(".doc") || filename.endsWith(".docx") || filename.endsWith(".html") || 
          filename.endsWith(".htm") || filename.endsWith(".gz") || filename.endsWith(".zip")) {
        if (!SD.exists("/modules")) SD.mkdir("/modules");
        filename = "/modules/" + filename;
      } else {
        filename = "/" + filename;
      }
    }
    Serial.printf("[Upload] Starting: %s\n", filename.c_str());
    if (SD.exists(filename)) {
      SD.remove(filename);
    }
    uploadFile = SD.open(filename, FILE_WRITE);
    lastUploadedFilename = upload.filename;
    lastUploadedSize = 0;
  } else if (upload.status == UPLOAD_FILE_WRITE) {
    if (uploadFile) {
      uploadFile.write(upload.buf, upload.currentSize);
    }
  } else if (upload.status == UPLOAD_FILE_END) {
    if (uploadFile) {
      uploadFile.close();
      lastUploadedSize = upload.totalSize;
      Serial.printf("[Upload] Complete! Stored: %s, Size: %u bytes\n", lastUploadedFilename.c_str(), upload.totalSize);
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

// ─── SD CARD INITIALIZATION & HOT-MOUNT ─────────────────────────────────────
bool initSDCard() {
  if (sdReady) return true;

  Serial.println("[SD] Attempting MicroSD mount...");
  Serial.printf("[SD] Pins: CS=%d, CLK=%d, MOSI=%d, MISO=%d\n", SD_CS_PIN, SD_CLK_PIN, SD_MOSI_PIN, SD_MISO_PIN);

  // Single mount attempt at safe breadboard speed
  bool mounted = SD.begin(SD_CS_PIN, spiSD, 4000000);

  if (mounted) {
    uint8_t cardType = SD.cardType();
    Serial.printf("[SD] SD.begin() returned OK. cardType = %d\n", cardType);
    if (cardType != CARD_NONE) {
      sdReady = true;
      uint64_t cardSize = SD.cardSize() / (1024 * 1024);
      const char* typeStr = "Unknown";
      if (cardType == CARD_MMC) typeStr = "MMC";
      else if (cardType == CARD_SD) typeStr = "SDSC";
      else if (cardType == CARD_SDHC) typeStr = "SDHC";

      Serial.printf("[SD] MicroSD Card Mounted! Type: %s, Size: %llu MB\n", typeStr, cardSize);

      if (!SD.exists("/modules")) {
        SD.mkdir("/modules");
      }

      if (!SD.exists("/manifest.json")) {
        File f = SD.open("/manifest.json", FILE_WRITE);
        if (f) {
          f.print("{\"hubId\":\"AIRAMP-HUB-01\",\"hubName\":\"AIRA Classroom Station\",\"sectionName\":\"Grade 10\",\"teacherName\":\"Faculty Instructor\",\"qrPayload\":\"WIFI:S:AIRAMP-HUB-01;T:WPA;P:aira1234;;AIRAMP:SEC=Grade 10;IP=192.168.4.1\",\"items\":[]}");
          f.close();
          Serial.println("[SD] Initialized clean /manifest.json on MicroSD card.");
        }
      }
      return true;
    } else {
      Serial.println("[SD] SD.begin() OK but cardType == CARD_NONE.");
    }
  } else {
    Serial.println("[SD] SD.begin() returned FAIL. Card not detected.");
  }

  sdReady = false;
  return false;
}

// ─── SETUP ──────────────────────────────────────────────────────────────────
void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);
  Serial.begin(115200);
  delay(500);
  Serial.println("\n\n========================================");
  Serial.println("   AIRAMP ESP32 OFFLINE HUB STARTING   ");
  Serial.println("========================================");
  Serial.printf("ESP32 Chip Rev: %d, CPU Freq: %d MHz\n", ESP.getChipRevision(), ESP.getCpuFreqMHz());
  Serial.printf("Free Heap: %d bytes\n", ESP.getFreeHeap());

  // Setup Button & Buzzer Pins
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  // Initialize OLED Display (I2C) with hardware timeout protection
  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
  Wire.setTimeOut(50);

  if (display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    oledPresent = true;
    Serial.println("[OLED] Display initialized successfully.");
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(14, 26);
    display.println("Starting AIRA Hub...");
    display.display();
  } else {
    oledPresent = false;
    Serial.println("[OLED] Display NOT detected.");
  }

  // Prepare SPI bus pins but DO NOT call SD.begin() yet
  // (On ESP32 Core 3.x, SD.begin() can crash if card is missing or not FAT32)
  pinMode(SD_CS_PIN, OUTPUT);
  digitalWrite(SD_CS_PIN, HIGH);
  pinMode(SD_MISO_PIN, INPUT_PULLUP);
  spiSD.begin(SD_CLK_PIN, SD_MISO_PIN, SD_MOSI_PIN, SD_CS_PIN);
  Serial.println("[SPI] Bus initialized. SD mount deferred to avoid boot crash.");

  // Start Wi-Fi SoftAP (No router / internet needed)
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASS);
  IPAddress IP = WiFi.softAPIP();
  Serial.printf("[WiFi] SoftAP Started! SSID: %s | IP: %s\n", AP_SSID, IP.toString().c_str());

  // Register Web Server Routes
  server.on("/", handleRoot);
  server.on("/api/ping", handlePing);
  server.on("/api/manifest", HTTP_GET, handleManifest);
  server.on("/api/manifest", HTTP_POST, handleSaveManifest);
  server.on("/api/manifest/append", HTTP_POST, handleAppendManifest);
  server.on("/download", handleDownload);
  server.on("/api/delete", HTTP_POST, handleDeleteFile);
  server.on("/api/delete", HTTP_GET, handleDeleteFile);
  server.on("/upload", HTTP_GET, handleUploadPage);
  server.on("/upload", HTTP_POST, []() {
    String jsonResp = "{\"status\":\"ok\",\"message\":\"Uploaded successfully to MicroSD\",\"fileName\":\"" + lastUploadedFilename + "\",\"sizeBytes\":" + String(lastUploadedSize) + "}";
    server.send(200, "application/json", jsonResp);
  }, handleFileUpload);
  server.enableCORS(true);
  server.begin();
  Serial.println("[HTTP] Web Server started on port 80.");

  // Draw initial QR code and info on OLED
  drawHubScreen();

  // Startup Sound (Joyful 3-beep chime)
  soundBeep(70, 3);

  Serial.println("\n[READY] Hub is running. SD will be tested in 10 seconds...");
  Serial.println("[READY] Or press the BUTTON to test SD card now.\n");
}

// ─── MAIN LOOP ──────────────────────────────────────────────────────────────
void loop() {
  server.handleClient();

  // Deferred SD card mount: try once after 10 seconds of stable boot
  static bool firstSdAttemptDone = false;
  if (!sdReady && !firstSdAttemptDone && millis() > 10000) {
    firstSdAttemptDone = true;
    Serial.println("\n[SD] === DEFERRED SD CARD TEST ===");
    if (initSDCard()) {
      Serial.println("[SD] SUCCESS! MicroSD is working!");
      soundBeep(80, 2);
      drawHubScreen();
    } else {
      Serial.println("[SD] FAILED. Check: card inserted? FAT32 format? wiring?");
    }
  }

  // Check Button to toggle OLED screen and retry SD mount
  int btnState = digitalRead(BUTTON_PIN);
  if (btnState == LOW && (millis() - lastButtonPress > 250)) {
    lastButtonPress = millis();
    if (!sdReady) {
      Serial.println("\n[BUTTON] Manual SD card test...");
      if (initSDCard()) {
        Serial.println("[SD] SUCCESS! Card mounted on button press!");
        soundBeep(80, 2);
      } else {
        Serial.println("[SD] Still not mounting. Check card & wiring.");
      }
    }
    if (currentMode == MODE_QR) {
      currentMode = MODE_MANUAL;
      Serial.println("[BUTTON] Switched to MANUAL MODE");
    } else {
      currentMode = MODE_QR;
      Serial.println("[BUTTON] Switched to QR CODE MODE");
    }
    soundBeep(60);
    drawHubScreen();
  }

  // Update OLED when student client connects or disconnects
  int currentClients = WiFi.softAPgetStationNum();
  if (currentClients != lastConnectedClients) {
    lastConnectedClients = currentClients;
    drawHubScreen();
    if (currentClients > 0) {
      soundBeep(100);
    }
  }
}

