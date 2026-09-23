# 📘 DOKUMENTASI LENGKAP PENGATURAN HARDWARE & GROUND STATION
### Swarm Drone SLAM Simulator • Raspberry Pi 4 • ESP32 UWB • Flutter GCS

Dokumentasi ini mencatat secara menyeluruh semua konfigurasi, kode program, perbaikan bug, dan langkah integrasi dari awal antara **MacBook (Flutter Ground Station)**, **Raspberry Pi 4 (Companion Computer Drone)**, dan **Modul UWB (Ultra-Wideband)**.

---

## 🏗️ 1. Arsitektur Sistem Keseluruhan

```
+-------------------------------------------------------------+
|                 MacBook (Ground Control Station)            |
|                  Flutter Web (Google Chrome)                |
|                  IP: 10.172.100.x (Satu Jaringan WiFi)      |
+------------------------------+------------------------------+
                               |
                   WebSocket (ws://10.172.100.22:8765)
                   JSON Telemetry Stream (15 Hz)
                               |
                               v
+-------------------------------------------------------------+
|                     Raspberry Pi 4 Model B                  |
|                      IP: 10.172.100.22                      |
|            Script: ~/rpi_drone_slam_bridge.py               |
+------------------------------+------------------------------+
                               |
        +----------------------+----------------------+
        | (USB Serial /dev/ttyUSB0)                   | (I2C Bus /dev/i2c-1)
        v                                             v
+-----------------------------+             +-------------------+
|   Makerfabs ESP32 UWB Tag   |             | 5x LiDAR Sensors  |
|  Decawave DWM1000 (Drone)   |             | TF-Luna / VL53L1X |
+--------------^--------------+             +-------------------+
               |
         Radio UWB (ToF)
               |
               v
+-----------------------------+
|  Makerfabs ESP32 UWB Anchor |
|   (Titik Acuan di Meja)     |
+-----------------------------+
```

---

## 💻 2. Konfigurasi di Sisi MacBook (Flutter Ground Station)

### A. Dependensi `pubspec.yaml`
Untuk menghubungkan Flutter Web ke WebSocket Raspberry Pi tanpa crash browser, package resmi **`web_socket_channel`** ditambahkan:
```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  get: ^4.7.3
  path_provider: ^2.1.6
  web_socket_channel: ^3.0.3
```

### B. Perbaikan Kode di Flutter

1. **`lib/services/hardware_bridge_service.dart`**:
   * **Masalah Awal:** Menggunakan `dart:io` (`WebSocket.connect`) yang menyebabkan error browser `Unsupported operation: Platform._version`.
   * **Perbaikan:** Diganti menggunakan `WebSocketChannel.connect(Uri.parse(targetUri))` dari `package:web_socket_channel`. Sekarang 100% kompatibel di Web Chrome, Mac, Windows, Linux, dan Mobile.

2. **`lib/controllers/simulation_controller.dart`**:
   * Menambahkan logika **Standby Guard** pada fungsi `_updateRealDroneSLAM`:
     ```dart
     if (drone.isStandby) {
       drone.currentSensorRays = [];
       return; // Drone diam di titik (0,0), tidak menggambar dinding palsu
     }
     ```
   * Jika jarak sensor bernilai `<= 0` (sensor belum dicolok), ray sensor otomatis di-skip sehingga denah ruangan bersih dari dinding acak.

3. **`lib/views/arena_canvas.dart`**:
   * **Efek LED Beacon Blinking:** Saat drone dalam status `standby`, ke-4 lampu LED sudut drone berkedip-kedip berdenyut (strobe pulse effect) seperti lampu navigasi pesawat.
   * Baling-baling (propeller) berhenti berputar saat drone diam di meja.

4. **`lib/views/widgets/control_panel.dart` & `minimap_panel.dart`**:
   * Memperbaiki bug `RenderFlex overflow` pada layar sempit menggunakan `LayoutBuilder`, `Expanded`, dan `Wrap`.

5. **`lib/utils/csv_helper.dart`**:
   * Menambahkan guard `!kIsWeb` agar tidak memanggil fungsi `Platform.isMacOS` yang tidak didukung browser.

### C. Menjalankan Ground Station di MacBook
```bash
cd /Users/auliasabril/Developer/flutter_project/swarm_drone_sim
flutter run -d chrome
```
* Buka browser Chrome, klik toggle **Real Drone (RPi 4)**.
* Masukkan IP Raspberry Pi: `10.172.100.22` | Port: `8765`.
* Klik **Connect to Raspberry Pi**.

---

## 🍓 3. Konfigurasi di Sisi Raspberry Pi 4

### A. Persiapan Sistem & Library
Jalankan di terminal Raspberry Pi:
```bash
# 1. Update repositori paket
sudo apt update

# 2. Install library Python yang dibutuhkan
sudo apt install -y python3-pip python3-websockets python3-serial

# 3. Aktifkan servis SSH agar bisa transfer file dari MacBook
sudo systemctl enable --now ssh
```

> **Tips Jika Lupa Password Akun `swarm`:**
> Ketik langsung di terminal monitor Raspberry Pi:
> ```bash
> sudo passwd swarm
> ```
> Masukkan password baru (misal: `swarm123`). Tidak akan meminta password lama!

### B. Mengirim File Bridge dari MacBook ke Raspberry Pi
Buka terminal di MacBook:
```bash
cd /Users/auliasabril/Developer/flutter_project/swarm_drone_sim
scp hardware_bridge/rpi_drone_slam_bridge.py swarm@10.172.100.22:~/
```

### C. Menjalankan Python Telemetry Bridge di Raspberry Pi

1. **Mode Standby Default (Drone Diam di 0,0, LED Kedap-Kedip, Tanpa Dinding Palsu):**
   ```bash
   python3 ~/rpi_drone_slam_bridge.py --port 8765
   ```
   *(Sangat cocok untuk pengujian awal saat sensor fisik belum dipasang).*

2. **Mode Deteksi Hardware Nyata (`--hw`):**
   ```bash
   python3 ~/rpi_drone_slam_bridge.py --hw --port 8765
   ```
   *Script akan otomatis memindai port I2C untuk LiDAR dan port serial `/dev/ttyUSB0` untuk UWB.*

3. **Mode Demo Virtual Room Walk (`--demo`):**
   ```bash
   python3 ~/rpi_drone_slam_bridge.py --demo --port 8765
   ```
   *(Digunakan jika ingin melihat simulasi drone berpatroli memutari ruangan virtual).*

---

## 📡 4. Konfigurasi Modul UWB (Makerfabs ESP32 UWB - Decawave DWM1000)

### A. Hasil Identifikasi Fisik & Port
* **Modul:** Makerfabs ESP32 UWB (ESP32-WROVER + Decawave DWM1000).
* **Port USB RPi:** Terdeteksi sebagai chip Silicon Labs CP2104 pada `/dev/ttyUSB0`.
* **Cek Port di RPi:**
  ```bash
  ls -l /dev/ttyUSB*
  # Output: /dev/ttyUSB0
  ```

### B. Penjelasan Pesan `RX_TIMEOUT`
Saat modul Tag dicolokkan ke Raspberry Pi dan diintip menggunakan miniterm:
```bash
python3 -m serial.tools.miniterm /dev/ttyUSB0 115200
```
Muncul output:
```text
FAIL,230,,229822,229,RX_TIMEOUT,,,0x018200F7
```
* **Penyebab:** Modul di drone berfungsi sebagai **TAG (Inisiator)** yang aktif memancarkan gelombang radio mencari pasangannya. Pesan `RX_TIMEOUT` muncul karena modul **ANCHOR (Titik Acuan di meja)** belum dinyalakan.

### C. Pembuatan Modul Anchor (Modul ke-2) di Arduino IDE (MacBook)

1. **Pengaturan Arduino IDE:**
   * **Board:** `ESP32 Dev Module` (atau `ESP32 Wrover Module`)
   * **Library:** `DW1000 by Thomas Trojer` (install via Library Manager)
   * **Port:** Pilih port USB ESP32 di MacBook (`/dev/cu.usbserial-...`)

> [!IMPORTANT]
> **TEMUAN KRUSIAL: Hardware Anda adalah Makerfabs ESP32 UWB DW3000 (Bukan DW1000)!**
> * Modul menggunakan transceiver **DecaWave/Qorvo DWM3000** (ditandai dengan antena putih bertuliskan `< UWB62`).
> * Pesan crash `EXCCAUSE: 0x00000006` (*Integer Divide By Zero*) terjadi karena firmware lama mencoba membaca register chip DW1000 pada chip DW3000, sehingga inisialisasi SPI gagal dan CPU panik.
> * Library resmi **Dw3000** dari Makerfabs kini sudah terpasang di MacBook Anda di: `~/Documents/Arduino/libraries/Dw3000`.

2. **File Firmware Anchor Resmi DW3000:**
   Buka file sketch berikut di Arduino IDE:
   `hardware_bridge/uwb_firmware/DW3000_Anchor/DW3000_Anchor.ino`

3. **Kode Firmware Anchor DW3000 (`DW3000_Anchor.ino`):**
```cpp
#include "dw3000.h"
#include "SPI.h"

extern SPISettings _fastSPI;

#define PIN_RST 27
#define PIN_IRQ 34
#define PIN_SS 4

#define TX_ANT_DLY 16385
#define RX_ANT_DLY 16385
#define ALL_MSG_COMMON_LEN 10
#define ALL_MSG_SN_IDX 2
#define RESP_MSG_POLL_RX_TS_IDX 10
#define RESP_MSG_RESP_TX_TS_IDX 14
#define RESP_MSG_TS_LEN 4
#define POLL_RX_TO_RESP_TX_DLY_UUS 900

static dwt_config_t config = {
    5,                /* Channel number. */
    DWT_PLEN_128,     /* Preamble length. Used in TX only. */
    DWT_PAC8,         /* Preamble acquisition chunk size. Used in RX only. */
    9,                /* TX preamble code. Used in TX only. */
    9,                /* RX preamble code. Used in RX only. */
    1,                /* Standard 8 symbol SFD */
    DWT_BR_6M8,       /* Data rate. */
    DWT_PHRMODE_STD,  /* PHY header mode. */
    DWT_PHRRATE_STD,  /* PHY header rate. */
    (129 + 8 - 8),    /* SFD timeout */
    DWT_STS_MODE_OFF, /* STS disabled */
    DWT_STS_LEN_64,   
    DWT_PDOA_M0       
};

// ... Inisialisasi SPI & Handler Respon Ranging Anchor ...
```
Saat sketch ini di-upload ke modul di MacBook, modul di Raspberry Pi (`range_rx`) yang tadinya mengeluarkan `RX_TIMEOUT` akan seketika berubah menampilkan jarak real-time:
```text
DIST: 1.25 m
DIST: 1.27 m
```
---

## 📋 5. Ringkasan Perintah Penting (Cheat Sheet)

| Aksi | Perangkat | Perintah |
| :--- | :--- | :--- |
| **Jalankan GCS Flutter** | MacBook | `flutter run -d chrome` |
| **Kirim File ke RPi** | MacBook | `scp hardware_bridge/rpi_drone_slam_bridge.py swarm@10.172.100.22:~/` |
| **Cek IP RPi** | Raspberry Pi | `hostname -I` |
| **Cek Port USB UWB** | Raspberry Pi | `ls -l /dev/ttyUSB*` |
| **Intip Data Serial UWB** | Raspberry Pi | `python3 -m serial.tools.miniterm /dev/ttyUSB0 115200` |
| **Jalankan Bridge RPi** | Raspberry Pi | `python3 ~/rpi_drone_slam_bridge.py --port 8765` |
| **Jalankan Bridge + HW** | Raspberry Pi | `python3 ~/rpi_drone_slam_bridge.py --hw --port 8765` |
| **Reset Password RPi** | Raspberry Pi | `sudo passwd swarm` |
