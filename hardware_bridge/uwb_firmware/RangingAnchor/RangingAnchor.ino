/*
Makerfabs ESP32 UWB - Anchor (Base Station) Firmware
Official Tested Code
===================================================
*/

#include <SPI.h>
#include "DW1000Ranging.h"

#define ANCHOR_ADD "86:17:5B:D5:A9:9A:E2:9C"

#define SPI_SCK 18
#define SPI_MISO 19
#define SPI_MOSI 23
#define DW_CS 4

// connection pins
const uint8_t PIN_RST = 27; // reset pin
const uint8_t PIN_IRQ = 34; // irq pin
const uint8_t PIN_SS = 4;   // spi select pin

void setup()
{
    Serial.begin(115200);
    delay(1000);
    Serial.println("================================================");
    Serial.println("📡 MAKERFABS UWB ANCHOR READY (OFFICIAL)");
    Serial.println("================================================");

    // Wajib: Inisialisasi pin SPI khusus Makerfabs ESP32 UWB
    SPI.begin(SPI_SCK, SPI_MISO, SPI_MOSI);
    DW1000Ranging.initCommunication(PIN_RST, PIN_SS, PIN_IRQ);

    DW1000Ranging.attachNewRange(newRange);
    DW1000Ranging.attachBlinkDevice(newBlink);
    DW1000Ranging.attachInactiveDevice(inactiveDevice);

    // Jalankan sebagai Anchor dengan mode standar Makerfabs
    DW1000Ranging.startAsAnchor(ANCHOR_ADD, DW1000.MODE_LONGDATA_RANGE_LOWPOWER, false);
}

void loop()
{
    DW1000Ranging.loop();
}

void newRange()
{
    Serial.print("Drone Tag [0x");
    Serial.print(DW1000Ranging.getDistantDevice()->getShortAddress(), HEX);
    Serial.print("] -> Jarak Fisik: ");
    Serial.print(DW1000Ranging.getDistantDevice()->getRange());
    Serial.println(" m");
}

void newBlink(DW1000Device *device)
{
    Serial.print("Drone Tag terhubung! Short: 0x");
    Serial.println(device->getShortAddress(), HEX);
}

void inactiveDevice(DW1000Device *device)
{
    Serial.print("Drone Tag offline: 0x");
    Serial.println(device->getShortAddress(), HEX);
}
