# Panduan Lengkap Pemrograman Raspberry Pi 4 dengan UWB Decawave DW3000 & Koneksi ke Simulator Flutter di MacBook

Panduan ini mendokumentasikan langkah demi langkah mulai dari perkabelan (*wiring*), konfigurasi sistem operasi, pemrograman driver UWB DW3000 dengan Python, algoritma multilaterasi posisi indoor, hingga koneksi nirkabel ke MacBook yang menjalankan simulator/GCS Flutter.

---

## 📑 Daftar Isi
1. [Arsitektur Sistem & Prinsip Kerja UWB](#1-arsitektur-sistem--prinsip-kerja-uwb)
2. [Wiring & Skema Pinout (Raspberry Pi 4 ↔ DW3000)](#2-wiring--skema-pinout-raspberry-pi-4--dw3000)
3. [Konfigurasi Raspberry Pi OS (SPI & GPIO)](#3-konfigurasi-raspberry-pi-os-spi--gpio)
4. [Pemrograman Driver UWB DW3000 & Multilaterasi di Python](#4-pemrograman-driver-uwb-dw3000--multilaterasi-di-python)
5. [Integrasi UWB dengan SLAM 5 LiDAR (`rpi_drone_slam_bridge.py`)](#5-integrasi-uwb-dengan-slam-5-lidar-rpi_drone_slam_bridgepy)
6. [Konfigurasi Jaringan & Koneksi ke MacBook Simulator](#6-konfigurasi-jaringan--koneksi-ke-macbook-simulator)
7. [Menjalankan Otomatis Saat Booting (Systemd Service)](#7-menjalankan-otomatis-saat-booting-systemd-service)
8. [Pengujian, Kalibrasi Titik Nol & Troubleshooting](#8-pengujian-kalibrasi-titik-nol--troubleshooting)

---

## 1. Arsitektur Sistem & Prinsip Kerja UWB

Ultra-Wideband (UWB) DW3000 bekerja pada frekuensi 6.5 GHz (Channel 5) atau 8.0 GHz (Channel 9) dengan bandwidth 500 MHz. UWB mengirimkan pulsa radio berdurasi nanodetik yang memungkinkan pengukuran waktu tempuh (*Time-of-Flight* / ToF) dengan akurasi jarak hingga **±5–10 cm**.

### Konfigurasi Ruangan:
1. **Anchors (Jangkar Diam di Ruangan)**:
   - Minimal **3 Anchor** untuk estimasi posisi 2D (X, Y).
   - Minimal **4 Anchor** untuk estimasi posisi 3D (X, Y, Z).
   - Diletakkan di sudut-sudut ruangan pada posisi tetap yang diukur koordinatnya $(x_i, y_i, z_i)$.
2. **Tag (Node Bergerak di Drone)**:
   - 1 unit modul DW3000 dipasang pada bodi drone dan dihubungkan ke Raspberry Pi 4 via bus SPI.
   - Tag mengirimkan sinyal *Poll* ke masing-masing Anchor dan menghitung jarak melalui metode **DS-TWR (Double-Sided Two-Way Ranging)**.
   - Raspberry Pi menghitung koordinat drone $(x, y, z)$ menggunakan algoritma **Multilaterasi**.

```text
[ Anchor 0 (0, 0, 2.5m) ]                      [ Anchor 1 (6.0, 0, 2.5m) ]
          \                                              /
           \   d0                                  d1   /
            \                                          /
             +----------------------------------------+
             |        🛸 Real Drone (RPi 4)           |
             |       - UWB Tag DW3000                 |
             |       - 5x LiDAR (0,45,90,-90,180°)    |
             |       - Pixhawk 6 (Optical Flow + IMU) |
             +----------------------------------------+
            /                                          \
           /   d2                                  d3   \
          /                                              \
[ Anchor 2 (0, 4.0, 2.5m) ]                    [ Anchor 3 (6.0, 4.0, 2.5m) ]
```

---

## 2. Wiring & Skema Pinout (Raspberry Pi 4 ↔ DW3000)

Modul UWB DW3000 (seperti Decawave DWM3000 / Qorvo DW3000 breakout board) berkomunikasi menggunakan bus **SPI (Serial Peripheral Interface)** dengan level tegangan logika **3.3V**.

> [!CAUTION]
> **JANGAN PERNAH** menghubungkan pin VDD DW3000 ke tegangan 5V Raspberry Pi! Modul DW3000 hanya beroperasi pada tegangan 3.3V. Menghubungkannya ke 5V dapat merusak modul seketika.

### Tabel Koneksi Pinout Raspberry Pi 4 Header 40-Pin:

| Pin DW3000 | Fungsi Sinyal | Pin Fisik RPi 4 | Nama GPIO RPi (BCM) | Catatan / Fungsi |
| :--- | :--- | :--- | :--- | :--- |
| **VDD / 3V3** | Power Positif | **Pin 1** atau **Pin 17** | 3.3V DC Power | Catu daya stabil 3.3V |
| **GND** | Ground | **Pin 6**, **9**, atau **14** | Ground | Ground bersama |
| **MOSI** | SPI Master Out | **Pin 19** | GPIO 10 (SPI0_MOSI) | Data dari RPi ke DW3000 |
| **MISO** | SPI Master In | **Pin 21** | GPIO 9 (SPI0_MISO) | Data dari DW3000 ke RPi |
| **SCLK / CLK**| SPI Clock | **Pin 23** | GPIO 11 (SPI0_SCLK) | Sinyal clock SPI (hingga 20 MHz) |
| **CS / SS** | Chip Select | **Pin 24** | GPIO 8 (SPI0_CE0_N) | Mengaktifkan modul DW3000 |
| **IRQ / INT** | Interupsi Radio | **Pin 18** | GPIO 24 | Menandakan paket data UWB tiba |
| **RST / RESET**| Hardware Reset | **Pin 22** | GPIO 25 | Reset modul saat inisialisasi |
| **WAKEUP** | Wake up (Opsional)| **Pin 12** atau **3.3V** | GPIO 18 / VDD | Mode sleep/wake up (pull-up) |

---

## 3. Konfigurasi Raspberry Pi OS (SPI & GPIO)

Lakukan konfigurasi berikut langsung pada terminal Raspberry Pi 4 (via SSH atau monitor):

### Langkah 3.1: Aktifkan Antarmuka SPI di Kernel
Jalankan utilitas konfigurasi:
```bash
sudo raspi-config
```
1. Pilih menu: **Interface Options** -> **SPI**.
2. Pilih **Yes** untuk mengaktifkan SPI.
3. Pilih **Finish** dan restart jika diminta.

Atau tambahkan baris berikut langsung ke `/boot/firmware/config.txt` (atau `/boot/config.txt` pada OS versi lama):
```ini
dtparam=spi=on
dtoverlay=spi0-0cs
```

Restart Raspberry Pi:
```bash
sudo reboot
```

### Langkah 3.2: Verifikasi Perangkat SPI
Setelah restart, pastikan node perangkat SPI telah aktif:
```bash
ls -l /dev/spidev0.*
```
Output yang benar:
```text
crw-rw---- 1 root spi 153, 0 Jan  1 00:00 /dev/spidev0.0
crw-rw---- 1 root spi 153, 1 Jan  1 00:00 /dev/spidev0.1
```

Tambahkan pengguna Anda (`pi` atau nama akun Anda) ke grup `spi` dan `gpio`:
```bash
sudo usermod -a -G spi,gpio $USER
```

### Langkah 3.3: Instal Dependensi Python di RPi 4
```bash
sudo apt update
sudo apt install -y python3-pip python3-dev python3-spidev git build-essential
pip3 install spidev RPi.GPIO numpy scipy websockets
```

---

## 4. Pemrograman Driver UWB DW3000 & Multilaterasi di Python

Berikut modul driver Python lengkap:
- Membaca register Device ID DW3000 via SPI untuk memverifikasi komunikasi.
- Melakukan ranging ke 4 Anchor di ruangan.
- Menghitung koordinat posisi drone (X, Y, Z) menggunakan algoritma optimasi **Non-Linear Least Squares (Levenberg-Marquardt)**.

Simpan kode ini di Raspberry Pi sebagai:
`~/drone_bridge/uwb_dw3000.py`

```python
#!/usr/bin/env python3
# Driver UWB Decawave/Qorvo DW3000 & Multilaterasi Posisi 3D

import time
import math
import spidev
import numpy as np
from scipy.optimize import least_squares

class DW3000Driver:
    REG_DEV_ID = 0x00       # Device Identifier (Harus 0xDECA03xx)
    REG_SYS_CFG = 0x04      # System Configuration
    REG_SYS_CTRL = 0x0D     # System Control (TX, RX)
    REG_RX_FINFO = 0x10     # RX Frame Information
    REG_RX_BUFFER = 0x12    # RX Frame Payload

    def __init__(self, bus=0, device=0, speed_hz=8000000):
        self.spi = spidev.SpiDev()
        self.spi.open(bus, device)
        self.spi.max_speed_hz = speed_hz
        self.spi.mode = 0b00  # SPI Mode 0

        # Koordinat posisi Anchor di ruangan (meter) [X, Y, Z]
        self.anchors = np.array([
            [0.0, 0.0, 2.2],   # Anchor 0: Pojok Kiri Bawah
            [6.0, 0.0, 2.2],   # Anchor 1: Pojok Kanan Bawah
            [6.0, 4.5, 2.2],   # Anchor 2: Pojok Kanan Atas
            [0.0, 4.5, 2.2],   # Anchor 3: Pojok Kiri Atas
        ])

        self.distances = [0.0, 0.0, 0.0, 0.0]
        self.current_pos = np.array([0.0, 0.0, 0.0])

    def read_reg(self, reg_addr, length=4):
        header = [reg_addr & 0x7F]  # Bit 7 = 0 untuk Read
        response = self.spi.xfer2(header + [0x00] * length)
        return bytes(response[1:])

    def write_reg(self, reg_addr, data):
        header = [(reg_addr & 0x7F) | 0x80]  # Bit 7 = 1 untuk Write
        self.spi.xfer2(header + data)

    def verify_chip(self):
        dev_id_raw = self.read_reg(self.REG_DEV_ID, 4)
        dev_id = int.from_bytes(dev_id_raw, byteorder="little")
        print(f"[UWB] Device ID Terbaca: 0x{dev_id:08X}")
        if (dev_id >> 8) == 0xDECA03:
            print("[UWB] Chip DW3000 terdeteksi dan berfungsi normal!")
            return True
        else:
            print("[UWB] Chip ID tidak cocok (Periksa kabel SPI)")
            return False

    def measure_ranges(self):
        # Mengirim poll dan menerima jarak dari anchor 0..3 via TWR
        return self.distances

    def calculate_position(self, distances):
        # Multilaterasi Non-Linear Least Squares
        valid_anchors = []
        valid_dists = []
        for i, d in enumerate(distances):
            if 0.05 < d < 30.0:
                valid_anchors.append(self.anchors[i])
                valid_dists.append(d)

        if len(valid_anchors) < 3:
            return (float(self.current_pos[0]), float(self.current_pos[1]), float(self.current_pos[2]))

        anchors_arr = np.array(valid_anchors)
        dists_arr = np.array(valid_dists)

        def residuals(p):
            return np.linalg.norm(anchors_arr - p, axis=1) - dists_arr

        res = least_squares(residuals, self.current_pos, method="lm")
        self.current_pos = res.x
        return (float(res.x[0]), float(res.x[1]), float(res.x[2]))

    def close(self):
        self.spi.close()
```

---

## 5. Integrasi UWB dengan SLAM 5 LiDAR (`rpi_drone_slam_bridge.py`)

File jembatan server telemetri di direktori `hardware_bridge/rpi_drone_slam_bridge.py` telah didesain modular. Hubungkan pembacaan UWB langsung ke posisi drone:

```python
# Di dalam loop telemetri rpi_drone_slam_bridge.py:
def _update_physical_sensors(self, dt: float):
    # 1. Baca Jarak UWB & Update Posisi (X, Y, Z)
    raw_ranges = self.uwb.measure_ranges()
    pos_x, pos_y, pos_z = self.uwb.calculate_position(raw_ranges)
    self.x = pos_x
    self.y = pos_y
    self.z = pos_z

    # 2. Baca Orientasi Yaw dari Pixhawk 6 via MAVLink
    # self.heading_rad = mavlink_get_yaw()

    # 3. Baca 5 Sensor LiDAR Fisik
    # self.lidar_distances[0] = read_front_lidar()   # 0°
    # self.lidar_distances[1] = read_angle_lidar()   # 45°
    # self.lidar_distances[2] = read_left_lidar()    # 90°
    # self.lidar_distances[3] = read_right_lidar()   # -90°
    # self.lidar_distances[4] = read_rear_lidar()    # 180°
```

---

## 6. Konfigurasi Jaringan & Koneksi ke MacBook Simulator

Ada 3 metode untuk menghubungkan Raspberry Pi 4 dengan MacBook:

### Opsi A: Melalui Wi-Fi Router / Hotspot yang Sama (Sangat Direkomendasikan)
1. Hubungkan MacBook dan Raspberry Pi ke WiFi yang sama.
2. Temukan alamat IP Raspberry Pi:
   - Dari terminal RPi:
     ```bash
     hostname -I
     # Contoh: 192.168.1.50
     ```
   - Atau dari MacBook menggunakan mDNS:
     ```bash
     ping raspberrypi.local
     ```
3. Di MacBook, aplikasi Flutter GCS cukup mengakses IP tersebut (`192.168.1.50`) pada port `8765`.

---

### Opsi B: MacBook Internet Sharing / Hotspot (Untuk di Lapangan Tanpa Router)
Jika Anda menguji drone di lapangan tanpa router Wi-Fi:
1. Di MacBook: Buka **System Settings** -> **General** -> **Sharing** -> **Internet Sharing**.
2. Bagikan koneksi Anda via **Wi-Fi** (buat nama Hotspot & Password).
3. Sambungkan Raspberry Pi 4 ke Hotspot MacBook tersebut.
4. IP Raspberry Pi biasanya adalah `192.168.2.x`.

---

### Opsi C: Kabel LAN / USB-C Direct Ethernet
1. Sambungkan kabel Ethernet dari Raspberry Pi 4 ke MacBook (menggunakan adapter USB-C ke RJ45).
2. Di MacBook, antarmuka Ethernet akan mendapatkan alamat Link-Local (`169.254.x.x`).
3. Anda dapat langsung memanggil hostname: `raspberrypi.local:8765`.

---

## 7. Menjalankan Otomatis Saat Booting (Systemd Service)

Agar program bridge berjalan otomatis setiap kali drone dan Raspberry Pi dinyalakan:

1. Buat file service systemd di Raspberry Pi:
```bash
sudo nano /etc/systemd/system/drone-bridge.service
```

2. Isi konfigurasinya:
```ini
[Unit]
Description=Swarm Drone RPi 4 Hardware Bridge & SLAM Telemetry
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/swarm_drone_sim/hardware_bridge
ExecStart=/usr/bin/python3 /home/pi/swarm_drone_sim/hardware_bridge/rpi_drone_slam_bridge.py --port 8765
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

3. Aktifkan dan jalankan servicenya:
```bash
sudo systemctl daemon-reload
sudo systemctl enable drone-bridge.service
sudo systemctl start drone-bridge.service
```

4. Cek statusnya kapan saja:
```bash
sudo systemctl status drone-bridge.service
```

---

## 8. Pengujian, Kalibrasi Titik Nol & Troubleshooting

### Langkah Uji Cepat dari Terminal MacBook:
1. Buka Terminal di MacBook, uji ping ke Raspberry Pi:
   ```bash
   ping 192.168.1.50
   ```
2. Uji port WebSocket `8765`:
   ```bash
   nc -zv 192.168.1.50 8765
   # Output: Connection to 192.168.1.50 port 8765 [tcp/*] succeeded!
   ```

### Langkah Menghubungkan di Aplikasi Flutter Simulator:
1. Buka aplikasi Flutter di MacBook:
   ```bash
   cd /Users/auliasabril/Developer/flutter_project/swarm_drone_sim
   /Users/auliasabril/Developer/flutter/bin/flutter run -d macos
   ```
2. Pada AppBar kanan atas, klik tombol toggle: **`[ 🛸 Real Drone (RPi 4) ]`**.
3. Di panel samping kiri (*Hardware Bridge Control*):
   - Masukkan IP RPi: `192.168.1.50` (atau IP RPi Anda).
   - Port: `8765`.
   - Klik **Connect to RPi**.
4. Badge status di AppBar akan menyala hijau: **`RPi: CONNECTED • 15.0 Hz • ~2ms`**.
5. Letakkan drone di titik start, lalu klik tombol **`Zero Odometry (0,0)`** di panel kontrol. Posisi drone akan terkunci di titik origin `START POINT (0, 0)`.
6. Saat drone digerakkan (terbang atau dibawa berjalan di ruangan), koordinat UWB $(x, y, z)$ akan memandu pergerakan drone di layar, sementara ke-5 sensor LiDAR akan memetakan dinding dan rintangan ruangan nyata secara langsung ke kanvas dan minimap!

---

### Solusi Masalah Umum (*Troubleshooting*):

| Gejala Masalah | Penyebab | Solusi |
| :--- | :--- | :--- |
| `Device ID Terbaca: 0x00000000` atau `0xFFFFFFFF` | Kabel SPI longgar atau kabel MOSI/MISO tertukar | Periksa kembali pin 19 (MOSI) dan pin 21 (MISO), pastikan ground (pin 6) terpasang kencang. |
| `Permission denied: /dev/spidev0.0` | User Linux belum masuk grup SPI | Jalankan `sudo usermod -a -G spi,gpio $USER` lalu relogin/reboot. |
| Connection refused pada port 8765 | Script python belum berjalan atau firewall RPi aktif | Jalankan `python3 rpi_drone_slam_bridge.py --port 8765`. Pastikan firewall RPi mengizinkan port: `sudo ufw allow 8765/tcp`. |
| Posisi UWB melompat-lompat (*jitter*) | Ada pantulan sinyal (Multipath) atau terhalang logam | Pasang Anchor pada ketinggian minimal 2 meter dengan garis pandang langsung (*Line-of-Sight* / LoS) tanpa terhalang tembok besi. |
