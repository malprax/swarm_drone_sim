#include <SPI.h>
#include <DW1000.h>
#include <DW1000Ranging.h>

/**
 * Makerfabs ESP32 UWB - Drone Tag (Mobile Unit) Firmware
 * ======================================================
 * Berfungsi sebagai unit bergerak yang dipasang pada Drone.
 * Mengirim request pulsa radio UWB ke Anchor stasioner untuk menghitung
 * jarak Two-Way Ranging (ToF), lalu mengirimkan hasilnya lewat Serial USB
 * ke Raspberry Pi 4 (115200 baud).
 *
 * Hardware: Makerfabs ESP32 UWB (ESP32-WROVER + Decawave DWM1000)
 * Library : DW1000 by Thomas Trojer (DW1000-ng)
 */

// Konfigurasi pin resmi Makerfabs ESP32 UWB
const uint8_t PIN_RST = 27; // Reset
const uint8_t PIN_IRQ = 34; // Interrupt
const uint8_t PIN_SS  = 4;  // Chip Select (SPI SS)

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("================================================");
  Serial.println("🛸 MAKERFABS UWB DRONE TAG (MOBILE UNIT) READY");
  Serial.println("================================================");

  // Inisialisasi komunikasi hardware SPI Decawave
  DW1000Ranging.initCommunication(PIN_RST, PIN_SS, PIN_IRQ);
  DW1000Ranging.attachNewRange(newRange);
  DW1000Ranging.attachNewDevice(newDevice);
  DW1000Ranging.attachInactiveDevice(inactiveDevice);

  // Jalankan sebagai Mobile Tag dengan MAC Address unik
  DW1000Ranging.startAsTag("7D:00:22:EA:82:60:3B:9C", DW1000.MODE_LONGDATA_RANGE_ACCURACY);
}

void loop() {
  DW1000Ranging.loop();
}

void newRange() {
  // Format output serial yang dibaca otomatis oleh Python bridge di RPi 4:
  // DIST, <ShortAddress_Hex>, <Jarak_Meter>, <RX_Power_dBm>
  Serial.print("DIST,0x");
  Serial.print(DW1000Ranging.getDistantDevice()->getShortAddress(), HEX);
  Serial.print(",");
  Serial.print(DW1000Ranging.getDistantDevice()->getRange(), 3);
  Serial.print(",");
  Serial.println(DW1000Ranging.getDistantDevice()->getRXPower(), 1);
}

void newDevice(DW1000Device *device) {
  Serial.print("ANCHOR_FOUND,0x");
  Serial.println(device->getShortAddress(), HEX);
}

void inactiveDevice(DW1000Device *device) {
  Serial.print("ANCHOR_LOST,0x");
  Serial.println(device->getShortAddress(), HEX);
}
