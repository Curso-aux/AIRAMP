# AIRA ESP32 Offline Learning Hub — Beginner's Hardware Build Guide

This step-by-step guide walks you through assembling and programming your **ESP32 Offline Learning Hub** completely from scratch, even if you have never built an electronics project before!

---

## 1. What You Have & How to Identify Each Part

| Component | What It Looks Like in Your Kit | What It Does |
| :--- | :--- | :--- |
| **ESP32 DevKit** | Black microcontroller board with Micro-USB port and two rows of pins | The brain of the hub: runs the Wi-Fi access point, local web server, and file streamer. |
| **0.96" OLED Display** | Small black rectangular screen with 4 pins (`GND`, `VCC`, `SCL`, `SDA`) | Displays the classroom QR code, Wi-Fi status, SD card health, and connected student count. |
| **MicroSD Module** | Blue rectangular board with a silver card slot and 6 side pins | Reads and streams PDF textbooks, modules, and quizzes directly from the SanDisk card. |
| **SanDisk 16GB MicroSD** | 16GB MicroSD card + full-size SD adapter | High-speed FAT32 storage for all your school modules and learning assets. |
| **Push Button** | Square button with a red cap and 4 metal legs | Toggles the OLED display ON/OFF to save power and prevent screen burn-in. |
| **Buzzer** | Small black cylindrical component with 2 legs | Emits an audible chime when the hub boots, when a student connects, and when downloads complete. |
| **Breadboard & Wires** | White plastic board with grids of holes + jumper wires | Lets you connect all components together without any soldering. |

### How to Pick the Right Buzzer (Active vs. Passive)
Your kit comes with two buzzers that look almost identical:
1. **Active Buzzer (Recommended — Use this one):** Look at the top and bottom.
   * Top usually has a **peelable sticker** with a `+` symbol (or text like *"Remove seal after washing"*).
   * The underside is **sealed with black epoxy resin** (you cannot see the green circuit board).
   * *Why:* Just sending power (HIGH) makes an instant, clean beep.
2. **Passive Buzzer:** The underside has an **exposed green circuit board** with visible copper traces and solder pads.

---

## 2. Step 1: MicroSD Card Setup (No Adapter Needed!)

> [!NOTE]
> **Good news:** Your brand new **SanDisk 16GB MicroSDHC card is ALREADY formatted as FAT32 straight from the factory!** All SDHC cards (4GB–32GB) come pre-formatted to FAT32 according to official SD card standards.

If your laptop does not have an SD card slot or you don't have a USB card reader adapter, choose one of these simple methods:

### Method A: Wireless Upload via ESP32 (Recommended — No Adapter Needed!)
1. Take the tiny SanDisk MicroSD card out of the package and slide it **directly into the blue MicroSD module** on your breadboard until it clicks.
2. Wire up your ESP32 and flash the firmware in Step 4.
3. On your laptop or phone, connect to the ESP32 Wi-Fi: **`AIRAMP-HUB-01`** (password: `aira1234`).
4. Open your web browser (Chrome or Edge) and go to:
   ```text
   http://192.168.4.1/upload
   ```
5. You will see the **AIRA Wireless File Uploader**! You can select and upload `manifest.json` and any `.pdf` modules directly from your computer to the MicroSD card wirelessly over Wi-Fi.

### Method B: Use an Android Smartphone
1. Insert the tiny MicroSD card into your Android phone's SIM/MicroSD tray.
2. Plug your phone into your PC with a USB cable (set USB mode to *File Transfer*).
3. Copy `manifest.json` and your PDF files into a `modules` folder on the card.
4. Take the card out and insert it into the blue MicroSD module.

### Method C: Standard PC Formatting (If you have an adapter)
1. Put the small **SanDisk 16GB MicroSD card** into the larger **SD Adapter**, then plug it into your computer's SD slot.
2. Format as `FAT32` $\rightarrow$ copy `manifest.json` and create a `modules` folder with your PDFs.

---

## 3. Step 2: Breadboard Basics (How Connections Work)

If you are new to breadboards, remember this simple rule:
* **The Long Outer Rails (+ and -):** Run **vertically** along the edges. They are used to share Power (`3.3V` or `5V`) and Ground (`GND`) across multiple components.
* **The Numbered Rows (1, 2, 3...):** Run **horizontally** in rows of 5 interconnected holes (`a-b-c-d-e` and `f-g-h-i-j`).
* **The Center Trench:** Divides the left side from the right side. The push button should straddle this trench so its legs don't short-circuit.

> [!TIP]
> If your ESP32 DevKit is wide and covers most holes on the breadboard, you can place the ESP32 on your desk and use **Male-to-Female DuPont jumper wires** to connect directly from the ESP32 header pins to the components on the breadboard!

---

## 4. Step 3: Complete Wiring / Pinout Table

Connect each component to your ESP32 DevKit according to this table:

### A. 0.96" OLED Display (I2C — 4 Wires)
| OLED Pin | ESP32 Pin | Purpose | Recommended Wire Color |
| :--- | :--- | :--- | :--- |
| **GND** | `GND` | Ground | Black |
| **VCC** | `3.3V` | 3.3V Power | Red |
| **SCL** | `GPIO 22` | I2C Clock | Yellow / White |
| **SDA** | `GPIO 21` | I2C Data | Blue / Green |

---

### B. MicroSD Card Module (SPI — 6 Wires)
| MicroSD Module Pin | ESP32 Pin | Purpose | Recommended Wire Color |
| :--- | :--- | :--- | :--- |
| **GND** | `GND` | Ground | Black |
| **VCC** | `5V` (or `VIN`) | 5V Power for on-board voltage regulator | Red |
| **MISO** | `GPIO 19` | Master-In Slave-Out (Data to ESP32) | Green |
| **MOSI** | `GPIO 23` | Master-Out Slave-In (Data from ESP32) | Blue |
| **SCK / CLK** | `GPIO 18` | SPI Clock | Yellow |
| **CS / SS** | `GPIO 5` | Chip Select | Orange / White |

---

### C. Push Button (Screen On/Off Toggle — 2 Wires)
Place the button across the center divider of the breadboard:
| Button Leg | ESP32 Pin | Purpose |
| :--- | :--- | :--- |
| **Leg 1** | `GPIO 4` | Signal (uses ESP32 internal pull-up resistor) |
| **Leg 2 (same side or diagonal)** | `GND` | Pulls pin to LOW when button is pressed |

---

### D. Active Buzzer (Success & Connection Chime — 2 Wires)
| Buzzer Leg | ESP32 Pin | Purpose |
| :--- | :--- | :--- |
| **(+) Long Leg** | `GPIO 25` | Output signal to trigger beep |
| **(-) Short Leg** | `GND` | Ground |

---

### Wiring Master Diagram

```
                 ┌─────────────────────────────┐
                 │        ESP32 DEVKIT         │
                 │                             │
    OLED SCL ────┤ GPIO 22                     │
    OLED SDA ────┤ GPIO 21                     │
  BUTTON SIG ────┤ GPIO 4                      │
  BUZZER (+) ────┤ GPIO 25                     │
                 │                             │
    SD CS    ────┤ GPIO 5                      │
    SD SCK   ────┤ GPIO 18                     │
    SD MISO  ────┤ GPIO 19                     │
    SD MOSI  ────┤ GPIO 23                     │
                 │                             │
  OLED VCC   ────┤ 3.3V                        │
  SD VCC     ────┤ 5V / VIN                    │
  ALL GNDs   ────┤ GND (Power Rail)            │
                 └─────────────────────────────┘
```

---

## 5. Step 4: Setting Up Arduino IDE & Installing Libraries

1. Download and install [Arduino IDE](https://www.arduino.cc/en/software) (Version 2.x recommended).
2. **Add ESP32 Board Support:**
   * In Arduino IDE, open **File $\rightarrow$ Preferences**.
   * In the **Additional boards manager URLs** field, paste:
     ```
     https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
     ```
   * Click **OK**.
   * Go to **Tools $\rightarrow$ Board $\rightarrow$ Boards Manager...**
   * Search for `esp32` by Espressif Systems $\rightarrow$ Click **Install**.
3. **Install the Required Libraries:**
   Go to **Tools $\rightarrow$ Manage Libraries...** (or press `Ctrl + Shift + I`):
   * Search for `Adafruit SSD1306` $\rightarrow$ Click **Install** (Click *"Install All"* when asked for dependencies like `Adafruit GFX`).
   * Search for `QRcode` (by **Richard Moore**) $\rightarrow$ Click **Install**.
   * Search for `ArduinoJson` (by **Benoit Blanchon**) $\rightarrow$ Click **Install**.

---

## 6. Step 5: Flashing the Code to Your ESP32

1. Plug your ESP32 DevKit into your computer using your **Micro-USB cable**.
2. Open the ready-to-flash Arduino sketch file created in your workspace:  
   [aira_offline_hub.ino](file:///c:/Users/Neil/Documents/AIRA/AIRAMP/esp32_firmware/aira_offline_hub/aira_offline_hub.ino)
3. In Arduino IDE:
   * **Select Board:** `Tools $\rightarrow$ Board $\rightarrow$ esp32 $\rightarrow$ DOIT ESP32 DEVKIT V1` (or `ESP32 Dev Module`).
   * **Select Port:** `Tools $\rightarrow$ Port $\rightarrow$ COMx` (choose the port for your ESP32).
4. Click the **Upload** button (the arrow icon $\rightarrow$).
   > [!NOTE]
   > If the bottom console says `Connecting........____`, press and hold down the physical **BOOT** button on your ESP32 board for 2 seconds until the writing percentage (`Writing at 0x...`) starts, then release it.
5. Wait for `Done uploading`.

---

## 7. Step 6: Power On & First Test!

Once uploaded, observe your station:
1. **Startup Chime:** The buzzer will play a joyful **3-beep chime**!
2. **OLED Screen:** 
   * The 0.96" OLED screen will display the **AIRA Classroom QR Code** on the left!
   * The right side will show:
     ```
     AIRA HUB
     --------
     SD: READY
     Users: 0
     IP: .4.1
     [SCAN ME]
     ```
3. **Screen Toggle Test:** Press the red push button once. The OLED display will instantly turn **OFF** to sleep. Press it again, and it will turn back **ON** with a chirp!
4. **Student Connection Test:**
   * On your phone or laptop, open Wi-Fi settings.
   * Connect to Wi-Fi: **`AIRAMP-HUB-01`** (Password: **`aira1234`**).
   * As soon as your phone connects, the buzzer will **beep**, and the OLED display will instantly update to **`Users: 1`**!
5. **App Sync Test:**
   * Open the **AIRAMP App** on your phone $\rightarrow$ go to **Courses** or **Dashboard**.
   * Tap **"Scan QR"** on the *Classroom Offline Hub* card.
   * Point the camera at the OLED screen's QR code (or tap *Simulate Scan*).
   * Tap **"Download & Save All Offline"** — the buzzer will sound a **2-tone success chime** when files stream over local Wi-Fi from the SD card!
