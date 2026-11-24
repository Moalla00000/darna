#pragma once
#include <IPAddress.h>

// -----------------------------------------------------------------------------
// Darna ESP32 configuration
//
// Copy this file to `secrets.h` and fill in your own values:
//
//   cp backend/include/secrets.example.h backend/include/secrets.h
//
// `secrets.h` is gitignored. Never commit real credentials.
// The ESP32 only supports 2.4 GHz Wi-Fi networks.
// -----------------------------------------------------------------------------

// Wi-Fi network name (SSID) and password.
const char* const WIFI_SSID = "YOUR_WIFI_SSID";
const char* const WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// Static network configuration for the ESP32.
//
// LOCAL_IP must be inside your router's subnet, outside its DHCP pool (or
// reserved for this device), and must match ESP32_BASE_URL in the Flutter
// app's `.env` file. Example: 192.168.1.200.
const IPAddress LOCAL_IP(192, 168, 1, 200);

// Your router's LAN IP address.
const IPAddress GATEWAY(192, 168, 1, 1);

// Subnet mask for your LAN.
const IPAddress SUBNET(255, 255, 255, 0);

// DNS servers (not required for local-only operation, but kept for completeness).
const IPAddress PRIMARY_DNS(8, 8, 8, 8);
const IPAddress SECONDARY_DNS(8, 8, 4, 4);
