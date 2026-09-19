# Raspberry Pi 4 Drone Hardware Bridge (5x LiDAR + SLAM)

Jembatan komunikasi nirkabel antara **drone fisik (Raspberry Pi 4)** dan **Flutter Ground Control Station**.

## 🔌 Spesifikasi Hardware Drone
- **Companion Computer**: Raspberry Pi 4 Model B (2GB/4GB/8GB)
- **Flight Controller**: Pixhawk 6 (MAVLink telemetry via UART `/dev/ttyAMA0`)
- **LiDAR Sensors (5x)**:
  - 1x Depan ($0^\circ$)
  - 1x Serong Kanan Depan ($45^\circ$)
  - 1x Kiri ($90^\circ$)
  - 1x Kanan ($-90^\circ$)
  - 1x Belakang ($180^\circ$)
- **Optical Flow**: PMW3901 (SPI)
- **UWB**: Decawave DW3000

---

## 🚀 Panduan Menjalankan

### 1. Mode Uji Coba (Mock / Demo Mode)
Anda dapat langsung menguji koneksi tanpa sensor fisik di Mac atau RPi:
```bash
cd hardware_bridge
python3 -m pip install -r requirements.txt
python3 rpi_drone_slam_bridge.py --mock --port 8765
```

### 2. Di Raspberry Pi 4 Asli
1. Sambungkan Raspberry Pi dan laptop Flutter ke jaringan WiFi / Hotspot yang sama.
2. Cari IP Raspberry Pi:
   ```bash
   hostname -I
   # Contoh output: 192.168.1.50
   ```
3. Jalankan server bridge:
   ```bash
   python3 rpi_drone_slam_bridge.py --port 8765
   ```
4. Di aplikasi Flutter:
   - Klik toggle **[ 🛸 Real Drone (RPi 4) ]** di bagian atas layar.
   - Masukkan IP `192.168.1.50` dan Port `8765`.
   - Klik **Connect**.
   - Ketika drone digerakkan dari titik start, ruangan nyata akan langsung terpetakan secara live di layar!

---

## 📖 Panduan Lengkap UWB DW3000 & Koneksi MacBook
Untuk panduan mendalam mengenai skema wiring SPI, konfigurasi Raspberry Pi OS, driver Python UWB DW3000, algoritma multilaterasi posisi, konfigurasi hotspot MacBook, dan pembuatan systemd service otomatis, silakan baca:
👉 **[UWB_DW3000_RPI4_SETUP_GUIDE.md](UWB_DW3000_RPI4_SETUP_GUIDE.md)**
